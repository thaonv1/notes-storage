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

Để có thể bootstrap được một cluster ceph, ta cần một số thứ sau:

- Unique Identifier: `fsid` chính là id định danh duy nhất của cluster, viết tắt của `File System ID`, tên này có từ hồi ceph chỉ focus vào file system.
- Cluster Name: Tên của cluster mặc định sẽ là ceph
- Monitor Name: Mỗi một mon instance sẽ có 1 cái tên, thường thì nó là hostname vì mỗi một host thường sẽ chạy 1 mon.
- Monitor Map: Để bootstrap initial monitor bạn cần tạo monitor map. Mon map này yêu cầu fsid, cluster name và ít nhất 1 host name và ip
- Monitor Keyring: Các mon giao tiếp với nhau thông qua keyring
- Administrator Keyring: Để sử dụng Ceph cli, bạn cần phải có user `client.admin`. vì thế bạn cần phải gen user và keyring đồng thời add user vào monitor keyring.

**Các bước cụ thể:**

- Gen uuid trên node bất kì

`uuidgen`

- Khởi tạo cấu hình ceph

```
cat <<EOF> /etc/ceph/ceph.conf
[global]
fsid = 3329642c-6e79-4e89-9e06-5443f102011e
public network = 192.168.40.0/24
cluster network = 192.168.40.0/24
mon initial members = ceph1
mon host =  192.168.40.21
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

Trong đó, lưu ý 1 số cấu hình quan trọng:

- `mon initial members`: Ceph yêu cầu tối thiểu là 1 mon, option này sẽ define initial monitor bắt buộc phải là member của cluster nếu muốn tạo quorum. Vì thế nếu bạn define 3 member thì bạn sẽ phải đảm bảo nó up toàn bộ.
- `osd pool default min size`: Số lượng bản replica tối thiểu, trong trường hợp nhỏ hơn, ceph sẽ không cho client write.

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

`monmaptool --create --add ceph1 192.168.40.21 --fsid 3329642c-6e79-4e89-9e06-5443f102011e /tmp/monmap`

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

- Kiểm tra cluster

`ceph -s`

**Lưu ý:**

- Khuyến cáo ta cần chạy ít nhất 3 mon để đảm bảo quá trình quorum hoạt động. Vì thế, ta nên add thêm 2 mon trên 2 host còn lại.

- Đầu tiên, ta sẽ copy keyring của client.admin để thực thi ceph cli trên 2 node còn lại. Từ máy chủ `ceph1`:

```
scp /etc/ceph/ceph.client.admin.keyring root@ceph2:/etc/ceph/ceph.client.admin.keyring
scp /etc/ceph/ceph.client.admin.keyring root@ceph3:/etc/ceph/ceph.client.admin.keyring
```
- Tiếp tục tạo thư mục cho mon trên 2 node còn lại

```
sudo -u ceph mkdir /var/lib/ceph/mon/ceph-ceph2
sudo -u ceph mkdir /var/lib/ceph/mon/ceph-ceph3
```

- Tiếp theo ta cần gen keyring và monmap trên 2 node còn lại

```
ceph auth get mon. -o keyring
ceph mon getmap -o monmap
```

Hoặc ta có thể copy từ máy chủ `ceph1` qua

```
scp /tmp/monmap root@ceph2:/tmp/monmap
scp /tmp/ceph.mon.keyring  root@2:/tmp/ceph.mon.keyring
```

Làm tương tự với node `ceph3`

- Phần quyền

```
chown ceph:ceph keyring
chown ceph:ceph monmap
```

- Khởi tạo mon từ key và monmap trên 2 node còn lại

```
sudo -u ceph ceph-mon --mkfs -i ceph2 --monmap monmap --keyring keyring
sudo -u ceph ceph-mon --mkfs -i ceph3 --monmap monmap --keyring keyring

```

- Tạo `done` file

```
sudo touch /var/lib/ceph/mon/ceph-ceph2/done
sudo touch /var/lib/ceph/mon/ceph-ceph3/done
```

- start monitor

```
sudo systemctl start ceph-mon@ceph2
systemctl enable ceph-mon@ceph2
```

```
sudo systemctl start ceph-mon@ceph3
systemctl enable ceph-mon@ceph3
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

**Hoặc bạn cũng có thể tạo osd theo cách thủ công**

- Lấy key bootstrap OSD

`ceph auth get client.bootstrap-osd -o /var/lib/ceph/bootstrap-osd/ceph.keyring`

- Tạo osd

```
ceph-volume lvm zap /dev/vdb

sudo ceph-volume lvm prepare --data /dev/vdb

ceph-volume lvm list

sudo ceph-volume lvm activate {ID} {FSID}
```
