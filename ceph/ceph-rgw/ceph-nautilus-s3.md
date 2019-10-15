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
192.168.62.11 ceph1
192.168.62.12 ceph2
192.168.62.13 ceph3
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

- Cài đặt ceph-deploy

`yum install -y ceph-deploy`

- Khởi tạo và copy key sang các máy khác

```
su cephuser
ssh-keygen -t rsa
ssh-copy-id cephuser@ceph1
ssh-copy-id cephuser@ceph2
ssh-copy-id cephuser@ceph3
```

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

- Phân quyền

`chmod 600 ~/.ssh/config`

#### 1.3 Thực hiện trên 2 node còn lại

- Đồng bộ time

```
sed -i 's/server 0.centos.pool.ntp.org iburst/server 192.168.64.11 iburst/g' /etc/chrony.conf
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
mon_initial_members = ceph1
mon_host = 192.168.62.11
auth_cluster_required = cephx
auth_service_required = cephx
auth_client_required = cephx

osd pool default size = 3
osd pool default min size = 1
osd pool default pg num = 128
osd pool default pgp num = 128


# Choose a reasonable crush leaf type
# 0 for a 1-node cluster.
# 1 for a multi node cluster in a single rack
# 2 for a multi node, multi chassis cluster with multiple hosts in a chassis
# 3 for a multi node cluster with hosts across racks, etc.
osd_crush_chooseleaf_type = 1

public network = 192.168.62.0/24
cluster network = 192.168.63.0/24

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
rgw enable usage log = true
rgw dns name = s3.cloudchuanchi.com

[client.rgw.ceph2]
host = ceph2
rgw enable usage log = true
rgw dns name = s3.cloudchuanchi.com

[client.rgw.ceph3]
host = ceph3
rgw enable usage log = true
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

- Cài đặt ceph dashboard

`yum install ceph-mgr-dashboard -y`

- Enable dashboard trên host mgr (ceph1)

```
ceph mgr module enable dashboard
ceph dashboard create-self-signed-cert
ceph dashboard set-login-credentials <username> <password>
ceph mgr services
```

Truy cập vào theo địa chỉ `https://<ip-ceph1>:8443` để kiểm tra

<img src="https://i.imgur.com/g9lGIb7.png">

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


### 3. Cấu hình RGW

Cấu hình theo hướng dẫn [tại đây](https://github.com/thaonguyenvan/notes-storage/blob/master/ceph/setup/ceph-rgw-nautilus.md)

- Thêm user cho dashboard

`radosgw-admin user create --uid=<user_id> --display-name=<display_name> \
    --system`

- Cung cấp thông tin cho dashboard

```
$ ceph dashboard set-rgw-api-access-key <access_key>
$ ceph dashboard set-rgw-api-secret-key <secret_key>
```

- Kiểm tra trên dashboard

<img src="https://i.imgur.com/NDRnL8B.png">


### 4. Cấu hình nginx

- Cài đặt

```
yum install epel-release -y
yum install nginx -y
```

- Start

`systemctl enable --now nginx`

- Cấu hình virtual host cho rgw trên cả 2 node

```
cat << EOF >> /etc/nginx/conf.d/radosgw.conf
upstream radosgw{
  server 192.168.62.11:7480;
  server 192.168.62.12:7480;
  server 192.168.62.13:7480;
}

server {

        listen 80;
        server_name *.cloudchuanchi.com;

        location / {
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header Host $host;
                proxy_set_header X-Forwarded-Proto $scheme;
                proxy_pass http://radosgw;
                client_max_body_size 0;
        }
}
EOF
```

- Check và reload nginx

```
nginx -t
nginx -s reload
```

- Truy cập vào địa chỉ `s3.cloudchuanchi.com` và kiểm tra

<img src="https://i.imgur.com/6xCM9X7.png">

- Cài đặt keepalived

`yum install -y keepalived`

- Thêm sysctl conf

```
echo "net.ipv4.ip_nonlocal_bind = 1" >> /etc/sysctl.conf
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p
```

- Backup cấu hình

`cp /etc/keepalived/keepalived.{conf,conf.bk}`

- Cấu hình keepalived trên node nginx master

```
cat << EOF > /etc/keepalived/keepalived.conf
vrrp_script chk_nginx {
        script "killall -0 nginx"     
        interval 2
        weight 4
}

vrrp_instance VI_1 {
    state MASTER
    interface eth0
    mcast_src_ip 103.124.92.18
    virtual_router_id 50
    priority 100
    advert_int 1
    authentication {
        auth_type AH
        auth_pass S3@Cloud365
    }
    virtual_ipaddress {
        103.124.92.22
    }
    track_script
    {
        chk_nginx
    }
}
EOF
```

- Cấu hình trên node backup

```
cat << EOF > /etc/keepalived/keepalived.conf
vrrp_script chk_nginx {
        script "killall -0 nginx"     
        interval 2
        weight 4
}

vrrp_instance VI_1 {
    state BACKUP
    interface eth0
    mcast_src_ip 103.124.92.20
    virtual_router_id 50
    priority 98
    advert_int 1
    authentication {
        auth_type AH
        auth_pass S3@Cloud365
    }
    virtual_ipaddress {
        103.124.92.22
    }
    track_script
    {
        chk_nginx
    }
}
EOF
```

- Thêm firewalld

```
firewall-cmd --direct --permanent --add-rule ipv4 filter INPUT 0 --in-interface eth0 --destination 224.0.0.0/8 --protocol vrrp -j ACCEPT
firewall-cmd --direct --permanent --add-rule ipv4 filter OUTPUT 0 --out-interface eth0 --destination 224.0.0.0/8 --protocol ah -j ACCEPT
firewall-cmd --direct --permanent --add-rule ipv4 filter INPUT 0 --in-interface eth0 --destination 224.0.0.0/8 --protocol vrrp -j ACCEPT
firewall-cmd --direct --permanent --add-rule ipv4 filter OUTPUT 0 --out-interface eth0 --destination 224.0.0.0/8 --protocol ah -j ACCEPT
firewall-cmd --reload
```

- Start service

`systemctl enable --now keepalived`

- Kiểm tra bằng cách truy cập vào ip vip hoặc domain đã trỏ. Sau đó tắt nginx hoặc shutdown 1 node đi để kiểm tra tính HA.

### 5. Cấu hình SSL

- Cài đặt cert-bot

`yum install certbot-nginx -y`

- Tạo cert trên 1 node

```
sudo certbot --server https://acme-v02.api.letsencrypt.org/directory -d \
*.s3.cloudchuanchi.com -d s3.cloudchuanchi.com --manual --preferred-challenges dns-01 certonly --agree-tos
```

- Trong quá trình tạo cert ta sẽ phải thêm 2 bản tin dns txt, chờ 1 vài phút cho các bản tin dns cập nhật rồi bấm enter

- Sau đó bổ sung thêm config cho node ta vừa tạo cert

```
upstream radosgw{
  server 192.168.62.11:7480;
  server 192.168.62.12:7480;
  server 192.168.62.13:7480;
}

server {

#       listen 80;
        server_name *.cloudchuanchi.com;

        location / {
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header Host $host;
                proxy_set_header X-Forwarded-Proto $scheme;
                proxy_pass http://radosgw;
                client_max_body_size 0;
		            proxy_buffering off;
            	  proxy_request_buffering off;
        }
        listen 443 ssl;
        server_name *.cloudchuanchi.com;
        ssl_certificate /etc/letsencrypt/live/s3.cloudchuanchi.com/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/s3.cloudchuanchi.com/privkey.pem;
}
server {
        server_name *.cloudchuanchi.com;
	      return 301 https://$host$request_uri;
}
```

- Reload lại nginx và kiểm tra

- Copy cert sang con còn lại

```
scp /etc/letsencrypt/live/s3.cloudchuanchi.com/fullchain.pem root@ip-nginx2
scp /etc/letsencrypt/live/s3.cloudchuanchi.com/privkey.pem root@ip-nginx2
```

- Reload lại nginx bên node còn lại
