# Hướng dẫn cài đặt Ceph Mimic manual trên CentOS 7

## 1. Mô hình

<img src="https://i.imgur.com/MPP1G4l.png">

Môi trường:

- Virtualization: KVM
- OS: CentOS 7
- Ceph version: Mimic

## 2. Hướng dẫn cài đặt môi trường trên cả 3 node

- Cấu hình hostname

`hostnamectl set-hostname {ceph1,ceph2,ceph3}`

- Cấu hình file host

```
cat <<EOF>> /etc/hosts
192.168.40.21 ceph1
192.168.40.22 ceph2
192.168.40.23 ceph3
EOF
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

- Khởi tạo repo

```
cat <<EOF> /etc/yum.repos.d/ceph.repo
[ceph]
name=Ceph packages for $basearch
baseurl=https://download.ceph.com/rpm-mimic/el7/x86_64/
enabled=1
priority=2
gpgcheck=1
gpgkey=https://download.ceph.com/keys/release.asc

[ceph-noarch]
name=Ceph noarch packages
baseurl=https://download.ceph.com/rpm-mimic/el7/noarch
enabled=1
priority=2
gpgcheck=1
gpgkey=https://download.ceph.com/keys/release.asc

[ceph-source]
name=Ceph source packages
baseurl=https://download.ceph.com/rpm-mimic/el7/SRPMS
enabled=0
priority=2
gpgcheck=1
gpgkey=https://download.ceph.com/keys/release.asc
EOF
```

- Cấu hình ntp

```
yum install -y ntp ntpdate ntp-doc
ntpdate -qu 0.centos.pool.ntp.org 1.centos.pool.ntp.org 2.centos.pool.ntp.org
systemctl start ntpd
systemctl enable ntpd
timedatectl set-ntp true
hwclock  -w
```

- Cài đặt các packages

```
yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum -y install yum-plugin-priorities
yum -y install snappy leveldb gdisk python-argparse gperftools-libs
yum install ceph -y
```

## 3. Khởi tạo và cấu hình ceph

- Gen uuid trên node bất kì

`uuidgen`

- Khởi tạo cấu hình ceph

```
cat <<EOF> /etc/ceph/ceph.conf
[global]
fsid = 3329642c-6e79-4e89-9e06-5443f102011e
public network = 192.168.40.0/24
cluster network = 192.168.40.0/24
mon initial members = ceph1, ceph2, ceph3
mon host =  192.168.40.21, 192.168.40.22, 192.168.40.23
auth cluster required = cephx
auth service required = cephx
auth client required = cephx
osd journal size = 1024
osd pool default size = 3
osd pool default min size = 2
osd pool default pg num = 100
osd pool default pgp num = 100
osd crush chooseleaf type = 1
EOF
```

**Lưu ý:**

Thay đổi các thông số cho phù hợp.

**Các cấu hình sau thực hiện trên node ceph1**

- Khởi tạo keyring và monitor secret key

`ceph-authtool --create-keyring /tmp/ceph.mon.keyring --gen-key -n mon. --cap mon 'allow *'`

- Khởi tạo user client.admin, administrator keyring và gán user cho keyring

`sudo ceph-authtool --create-keyring /etc/ceph/ceph.client.admin.keyring --gen-key -n client.admin --set-uid=0 --cap mon 'allow *' --cap osd 'allow *' --cap mds 'allow *' --cap mgr 'allow *'`

- Khởi tạo user client.bootstrap-osd, bootstrap-osd keyring và gán user cho keyring

`sudo ceph-authtool --create-keyring /var/lib/ceph/bootstrap-osd/ceph.keyring --gen-key -n client.bootstrap-osd --cap mon 'profile bootstrap-osd'`

- Thêm các key vừa gen vào `ceph.mon.keyring`

```
sudo ceph-authtool /tmp/ceph.mon.keyring --import-keyring /etc/ceph/ceph.client.admin.keyring
sudo ceph-authtool /tmp/ceph.mon.keyring --import-keyring /var/lib/ceph/bootstrap-osd/ceph.keyring
```

- Khởi tạo monitor map

`monmaptool --create --add {hostname} {ip-address} --fsid {uuid} /tmp/monmap`

ví dụ:

`monmaptool --create --add ceph1 192.168.40.21 --add ceph2 192.168.40.22 --add ceph3 192.168.40.23 --fsid 3329642c-6e79-4e89-9e06-5443f102011e /tmp/monmap`

- Khởi tạo thư mục mặc định trên monitor host

`sudo -u ceph mkdir /var/lib/ceph/mon/{cluster-name}-{hostname}`

Ví dụ:

`sudo -u ceph mkdir /var/lib/ceph/mon/ceph-ceph1`

- Phân quyền

```
chown -R ceph:ceph /tmp/ceph.mon.keyring
chown -R ceph:ceph /tmp/monmap
```

- Tạo các monitor daemon(s)

`sudo -u ceph ceph-mon [--cluster {cluster-name}] --mkfs -i {hostname} --monmap /tmp/monmap --keyring /tmp/ceph.mon.keyring`

Ví dụ:

`sudo -u ceph ceph-mon --mkfs -i ceph1 --monmap /tmp/monmap --keyring /tmp/ceph.mon.keyring`

- Tạo `done` file

`sudo touch /var/lib/ceph/mon/ceph-ceph1/done`

- start monitor

```
sudo systemctl start ceph-mon@ceph1
systemctl enable ceph-mon@ceph1
```

## 4. Mở rộng cluster

### 4.1 Khởi tạo mgr

**Lưu ý:**

Muốn tạo mgr cho node nào thì thực hiện trên node đó

- Khởi tạo user

`ceph auth get-or-create mgr.ceph1 mon 'allow profile mgr' osd 'allow *' mds 'allow *'`

- Khởi tạo folder cho mgr

```
sudo -u ceph mkdir /var/lib/ceph/mgr/ceph-ceph1
sudo ceph auth get-or-create mgr.ceph1 mon 'allow profile mgr' osd 'allow *' mds 'allow *' -o /var/lib/ceph/mgr/ceph-ceph1/keyring
sudo chown -R ceph:ceph /var/lib/ceph/mgr
```

- Khởi động service

```
systemctl start ceph-mgr@ceph1.service
systemctl enable ceph-mgr@ceph1.service
```

### 4.2 Thêm OSD

- Lấy key bootstrap OSD

`ceph auth get client.bootstrap-osd -o /var/lib/ceph/bootstrap-osd/ceph.keyring`

- Tạo OSD

```
ceph-volume lvm zap /dev/vdb

ceph-volume lvm create --data /dev/vdb
```
