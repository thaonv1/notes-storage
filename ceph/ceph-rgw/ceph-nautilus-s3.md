# Hướng dẫn cài đặt và cấu hình Ceph Nautilus RGW

## Mục lục

1. Cài đặt môi trường

2. Cài đặt Ceph cluster

3. Cấu hình RGW

4. Cài đặt Nginx

-----------------------------

### 1. Cài đặt môi trường

#### 1.1 Thực hiện trên tất cả các node

- Đặt hostname

`hostnamectl set-hostname {ceph1,ceph2,ceph3}`

- Update

`yum update -y`

- Cài đặt epel-release

`yum install epel-release -y`

- Install byobu

`yum install byobu -y`

- Cấu hình file host

```
cat <<EOF>> /etc/hosts
192.168.10.11 ceph1
192.168.10.12 ceph2
192.168.10.13 ceph3
EOF
```

- Cài đặt package

`yum install -y chrony python-setuptools yum-plugin-priorities`

- Tạo user dùng cho ceph-deploy

```
sudo useradd -d /home/cephuser -m cephuser
sudo passwd cephuser

echo "cephuser ALL = (root) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/cephuser
sudo chmod 0440 /etc/sudoers.d/cephuser
```

- Thêm rule cho firewalld

```
firewall-cmd --add-port=6789/tcp --permanent
firewall-cmd --add-port=6800-7100/tcp --permanent
firewall-cmd --reload
```

- Cấu hình selinux

```
sed -i s/^SELINUX=.*$/SELINUX=permissive/ /etc/selinux/config
setenforce 0
```

- Hoặc disable

```
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
systemctl disable firewalld
systemctl stop firewalld
```

#### 1.2 Thực hiện trên node ceph1 (ceph-deploy)

- Tạo repo

```
cat <<EOF> /etc/yum.repos.d/ceph.repo
[ceph]
name=Ceph packages for $basearch
baseurl=https://download.ceph.com/rpm-nautilus/el7/x86_64/
enabled=1
priority=2
gpgcheck=1
gpgkey=https://download.ceph.com/keys/release.asc

[ceph-noarch]
name=Ceph noarch packages
baseurl=https://download.ceph.com/rpm-nautilus/el7/noarch
enabled=1
priority=2
gpgcheck=1
gpgkey=https://download.ceph.com/keys/release.asc

[ceph-source]
name=Ceph source packages
baseurl=https://download.ceph.com/rpm-nautilus/el7/SRPMS
enabled=0
priority=2
gpgcheck=1
gpgkey=https://download.ceph.com/keys/release.asc
EOF

yum update -y
```

- Cài đặt ceph-deploy

`yum install -y ceph-deploy`

- Cấu hình ssh config

```
cat <<EOF>>  ~/.ssh/config
Host ceph1
   Hostname ceph1
   User cephuser
Host ceph2
   Hostname ceph2
   User cephuser
Host ceph3
   Hostname ceph3
   User cephuser
EOF
```

- Khởi tạo và copy key sang các máy khác

```
su cephuser
ssh-keygen -t rsa
sudo ssh-copy-id -o StrictHostKeyChecking=no -i /home/cephuser/.ssh/id_rsa.pub cephuser@ceph1
sudo ssh-copy-id -o StrictHostKeyChecking=no -i /home/cephuser/.ssh/id_rsa.pub cephuser@ceph2
sudo ssh-copy-id -o StrictHostKeyChecking=no -i /home/cephuser/.ssh/id_rsa.pub cephuser@ceph3
```

- Cấu hình time

```
sed -i 's/server 0.centos.pool.ntp.org iburst/ \
server 1.vn.pool.ntp.org iburst \
server 0.asia.pool.ntp.org iburst \
server 3.asia.pool.ntp.org iburst/g' /etc/chrony.conf
sed -i 's/server 1.centos.pool.ntp.org iburst/#/g' /etc/chrony.conf
sed -i 's/server 2.centos.pool.ntp.org iburst/#/g' /etc/chrony.conf
sed -i 's/server 3.centos.pool.ntp.org iburst/#/g' /etc/chrony.conf
sed -i 's/#allow 192.168.0.0\/16/allow 0\/0/g' /etc/chrony.conf
systemctl enable chronyd.service
systemctl start chronyd.service
systemctl restart chronyd.service
chronyc sources
```

- Set hwclock

`hwclock --systohc`

#### 1.3 Thực hiện trên 2 node còn lại

- Đồng bộ time

```
sed -i 's/server 0.centos.pool.ntp.org iburst/server 192.168.10.11 iburst/g' /etc/chrony.conf
sed -i 's/server 1.centos.pool.ntp.org iburst/#/g' /etc/chrony.conf
sed -i 's/server 2.centos.pool.ntp.org iburst/#/g' /etc/chrony.conf
sed -i 's/server 3.centos.pool.ntp.org iburst/#/g' /etc/chrony.conf
systemctl enable chronyd.service
systemctl start chronyd.service
systemctl restart chronyd.service
chronyc sources
```

- Set hwclock

`hwclock --systohc`

### 2. Cài đặt ceph cluster

- Chuyển sang user `cephuser`

`su cephuser`

- Tạo folder

`mkdir my-cluster && cd my-cluster`

- Tạo cluster

`ceph-deploy new ceph1`

- Chỉnh file cấu hình `ceph.conf`

```
[global]
fsid = 148fb1b9-e20e-49e1-9e3a-634d0f1ca57d
mon_initial_members = ceph01, ceph02, ceph03
mon_host = 192.168.10.11
auth_cluster_required = cephx
auth_service_required = cephx
auth_client_required = cephx

osd pool default size = 2
osd pool default min size = 1
osd pool default pg num = 128
osd pool default pgp num = 128


# Choose a reasonable crush leaf type
# 0 for a 1-node cluster.
# 1 for a multi node cluster in a single rack
# 2 for a multi node, multi chassis cluster with multiple hosts in a chassis
# 3 for a multi node cluster with hosts across racks, etc.
osd_crush_chooseleaf_type = 1

public network = 192.168.10.0/24
cluster network = 192.168.10.0/24

# Debug config
debug_lockdep = 0/0
debug_context = 0/0
debug_crush = 0/0
debug_mds = 0/0
debug_mds_balancer = 0/0
debug_mds_locker = 0/0
debug_mds_log = 0/0
debug_mds_log_expire = 0/0
debug_mds_migrator = 0/0
debug_buffer = 0/0
debug_timer = 0/0
debug_filer = 0/0
debug_objecter = 0/0
debug_rados = 0/0
debug_rbd = 0/0
debug_journaler = 0/0
debug_objectcacher = 0/0
debug_client = 0/0
debug_osd = 0/0
debug_optracker = 0/0
debug_objclass = 0/0
debug_filestore = 0/0
debug_journal = 0/0
debug_ms = 0/0
debug_mon = 0/0
debug_monc = 0/0
debug_paxos = 0/0
debug_tp = 0/0
debug_auth = 0/0
debug_finisher = 0/0
debug_heartbeatmap = 0/0
debug_perfcounter = 0/0
debug_rgw = 0/0
debug_hadoop = 0/0
debug_asok = 0/0
debug_throttle = 0/0
rbd_default_format = 2


# --> Allow delete pool -- NOT RECOMMEND
mon_allow_pool_delete = false

#rbd_cache = true
#bluestore_block_db_size = 5737418240
#bluestore_block_wal_size = 2737418240

# Disable auto update crush => Modify Crushmap OSD tree  
# osd_crush_update_on_start = false

# Backfilling and recovery
osd_max_backfills = 1
osd_recovery_max_active = 1
osd_recovery_max_single_start = 1
osd_recovery_op_priority = 1

# Osd recovery threads = 1
osd_backfill_scan_max = 16
osd_backfill_scan_min = 4
mon_osd_backfillfull_ratio = 0.95

# Scrubbing
osd_max_scrubs = 1
osd_scrub_during_recovery = false
# osd scrub begin hour = 22
# osd scrub end hour = 4

# Max PG / OSD
mon_max_pg_per_osd = 500

[client.rgw.ceph1]
host = ceph1
rgw frontends = beast
rgw dns name = s3.cloudchuanchi.com

[client.rgw.ceph2]
host = ceph2
rgw frontends = beast
rgw dns name = s3.cloudchuanchi.com

[client.rgw.ceph3]
host = ceph3
rgw frontends = beast
rgw dns name = s3.cloudchuanchi.com
```

- Cài đặt ceph trên các node

`ceph-deploy install ceph1 ceph2 ceph3 --release nautilus`

- Kiểm tra version

`ceph --version`

- Khởi động mon

`ceph-deploy mon create-initial`

- cấu hình client.admin xuống các node ceph còn lại để khi thực hiện các cli trên đó sẽ không cần phải chỉ định key nữa

`ceph-deploy admin ceph1 ceph2 ceph3`

- Thêm mgr daemon

`ceph-deploy mgr create ceph1 ceph2 ceph3`

- Add mon xuống 2 node còn lại

```
ceph-deploy mon add ceph2
ceph-deploy mon add ceph3
```

- Kiểm tra trạng thái

`ceph -s`

- Enable dashboard trên host mgr (ceph1)

```
yum install ceph-mgr-dashboard -y
ceph mgr module enable dashboard
ceph dashboard create-self-signed-cert
ceph dashboard set-login-credentials <username> <password>
ceph mgr services
```

Truy cập vào theo địa chỉ `https://<ip-ceph01>:8443` để kiểm tra

#### Tạo osd

- Ví dụ ta có 2 ổ là `sdb` dùng để lưu block db + service pools và `sdc` để lưu data

- Lấy key bootstrap OSD

`ceph auth get client.bootstrap-osd -o /var/lib/ceph/bootstrap-osd/ceph.keyring`

- Kiểm tra

`ceph-volume lvm list`

- Tạo volume group cho block data

`vgcreate ceph-block-0 /dev/sdc`

- Tạo logical volume cho block data

`lvcreate -l 100%FREE -n block-0 ceph-block-0`

- Tạo volume group cho block db.

`vgcreate ceph-db-0 /dev/sdb`

- Tạo logical volume để lưu block db

`lvcreate -L 40GB -n db-0 ceph-db-0`

- Tạo logical volume để lưu services pool

`lvcreate -L 40GB -n index-0 ceph-db-0`

- Tạo osd lưu data

`ceph-volume lvm create --bluestore --data ceph-block-0/block-0 --block.db ceph-db-0/db-0`

- Tạo osd lưu service pool

`ceph-volume lvm create --bluestore --data ceph-db-0/index-0`
