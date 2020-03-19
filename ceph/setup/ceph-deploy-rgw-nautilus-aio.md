# Hướng dẫn cài đặt Ceph RGW aio bằng ceph deploy

# Hướng dẫn cài đặt ceph radosgw all in one trên CentOS 7

## Mục lục

- [1. Mô hình + IP Plan](#1)
- [2. Hướng dẫn cài đặt ceph bằng ceph-deploy](#2)
- [3. Hướng dẫn cài đặt ceph radosgw](#3)
- [4. Hướng dẫn xóa cầu hình ceph đi cài lại](#4)

-----------------------------------------------

<a name="1"></a>
1. Mô hình + IP Plan

- OS: CentOS 7
- Ceph version: Nautilus

3 HDD trong đó:

- Mỗi disk có dung lượng 50 GB
- `sda` để cài OS
- `sdb`, `sdc` và `sdd` để làm OSD

1 NIC để làm public + replicate network

<img src="https://i.imgur.com/tvuf1HT.png">

<a name="2"></a>
2. Hướng dẫn cài đặt ceph bằng ceph-deploy

- Cài đặt hostname

`hostnamectl set-hostname cephaio`

- Chỉnh SELinux

```
sed -i s/^SELINUX=.*$/SELINUX=permissive/ /etc/selinux/config
setenforce 0
```

- Mở port cho Ceph trên Firewalld

```
systemctl start firewalld
systemctl enable firewalld
sudo firewall-cmd --zone=public --add-port=80/tcp --permanent
sudo firewall-cmd --zone=public --add-port=2003/tcp --permanent
sudo firewall-cmd --zone=public --add-port=4505-4506/tcp --permanent

sudo firewall-cmd --zone=public --add-port=6789/tcp --permanent

sudo firewall-cmd --zone=public --add-port=6800-7300/tcp --permanent
sudo firewall-cmd --zone=public --add-port=7480/tcp --permanent
sudo firewall-cmd --zone=public --add-port=8443/tcp --permanent
sudo firewall-cmd --reload
```

- Hoặc có thể disable firewall

```
sudo systemctl disable firewalld
sudo systemctl stop firewalld
```

- Cấu hình file host

```
cat << EOF >> /etc/hosts
10.10.11.240 cephaio
EOF
```

- Cấu hình NTP

```
yum install -y ntp ntpdate ntp-doc
ntpdate -qu 0.centos.pool.ntp.org 1.centos.pool.ntp.org 2.centos.pool.ntp.org
systemctl start ntpd
systemctl enable ntpd
timedatectl set-ntp true
hwclock  -w
```

- Cài đặt `epel-release` và `python-setuptools`

```
yum install epel-release -y
yum install python-setuptools -y
yum update -y
```

- Cấu hình cmd log

`curl -Lso- https://raw.githubusercontent.com/nhanhoadocs/scripts/master/Utilities/cmdlog.sh | bash`

- Tạo user cho ceph-deploy

```
useradd -d /home/cephuser -m cephuser
passwd cephuser
```

Cấp quyền root cho user vừa tạo

```
echo "cephuser ALL = (root) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/cephuser
chmod 0440 /etc/sudoers.d/cephuser
sed -i s'/Defaults requiretty/#Defaults requiretty'/g /etc/sudoers
```

- Tạo ssh key

`echo -e "\n" | ssh-keygen -t rsa -N ""`

- Cấu hình ssh file config

```
echo '
Host cephaio
        Hostname cephaio
        User cephuser' > ~/.ssh/config
```

Thay đổi quyền

`chmod 644 ~/.ssh/config`

Thiết lập keypair

```
ssh-keyscan cephaio >> ~/.ssh/known_hosts
ssh-copy-id cephaio
```

Lưu ý: Nhập pass khi được yêu cầu

- Khởi tạo repo

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

```
yum install ceph-deploy -y
```

- Tạo cluster dir

`mkdir ceph-cluster && cd ceph-cluster`

- Khởi tạo cấu hình

`ceph-deploy new cephaio`

- Thêm vào cấu hình ceph

```
cat << EOF >> ceph.conf
osd pool default size = 1
osd pool default min size = 1
osd pool default pg num = 64
osd pool default pgp num = 64

osd crush chooseleaf type = 0

public network = 10.10.11.0/24
cluster network = 10.10.11.0/24

[client.rgw.cephaio]
host = cephaio
rgw enable usage log = true
EOF
```

- Cài đặt ceph

`ceph-deploy install cephaio`

- Khởi tạo mon

`ceph-deploy mon create-initial`

- Khởi tạo c quyền admin

`ceph-deploy admin cephaio`

- Thiết lập các OSD

`ceph-deploy disk list cephaio`

```
ceph-deploy disk zap cephaio /dev/sdb
ceph-deploy disk zap cephaio /dev/sdc
ceph-deploy disk zap cephaio /dev/sdd
```

```
ceph-deploy osd create cephaio --data /dev/sdb
ceph-deploy osd create cephaio --data /dev/sdc
ceph-deploy osd create cephaio --data /dev/sdd
```

- Khởi tạo ceph-mgr

`ceph-deploy mgr create cephaio`

- Điều chỉnh crush map

```
cd ~/ceph-cluster/
ceph osd getcrushmap -o map.bin
crushtool -d map.bin -o map.txt
sed -i 's/step chooseleaf firstn 0 type host/step chooseleaf firstn 0 type osd/g' ~/ceph-cluster/map.txt
crushtool -c map.txt -o map-new.bin
ceph osd setcrushmap -i map-new.bin
```

- Khởi tạo dashboard

```
yum install ceph-mgr-dashboard -y
ceph mgr module enable dashboard
ceph dashboard create-self-signed-cert
ceph dashboard set-login-credentials <username> <password>
ceph mgr services
```

- Truy cập vào dashboard với username và password cấu hình ở trên

`https://<ip-cephaio>:8443`

- Kiểm tra

`ceph -s`

<a name="3"></a>
## 3. Hướng dẫn cài đặt ceph radosgw

- Khởi tạo ceph radosgw

`ceph-deploy rgw create cephaio`

- List các pool được tạo

`ceph osd pool ls`

Mặc định sẽ có những pool sau được tạo

```
.rgw.root
default.rgw.control
default.rgw.meta
default.rgw.log
```

Sau khi đẩy dữ liệu, sẽ có 2 pool nữa được tạo ra đó là

```
default.rgw.buckets.data
default.rgw.buckets.index
```

Mặc định , RGW sử dụng port 7480

<img src="https://i.imgur.com/FbX8EMY.png">

- Thêm user cho dashboard

`radosgw-admin user create --uid=<user_id> --display-name=<display_name> \
    --system`

- Cung cấp thông tin cho dashboard

```
ceph dashboard set-rgw-api-access-key <access_key>
ceph dashboard set-rgw-api-secret-key <secret_key>
```

- Kiểm tra trên dashboard

<img src="https://i.imgur.com/NDRnL8B.png">

Để tạo radosgw user

`radosgw-admin user create --uid={username} --display-name="{display-name}"`

Để show radosgw user

`radosgw-admin user info --uid={username}`

Để tải s3cmd

`yum install s3cmd -y`

Để config s3cmd

`s3cmd --configure`

Để tạo bucket

`s3cmd mb s3://first-bucket`

Để tạo file 1G

`dd if=/dev/zero of=1g.bin bs=1G count=1`

Để đưa file 1G vào bucket vừa tạo

`s3cmd put 1g.bin s3://first-bucket`

<a name="4"></a>
## 4. Hướng dẫn xóa cấu hình ceph đi cài lại

Trường hợp muốn xóa cluster đi cài lại, ta tiến hành như sau

```
cd ~/ceph-cluster
ceph-deploy --username cephuser purge cephaio
ceph-deploy --username cephuser purgedata cephaio
ceph-deploy --username cephuser forgetkeys
rm -rf ceph.*
```

- Xóa các repo của ceph trong `/etc/yum.repos.d/`

- Thêm lại các repo

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

- Xóa các volume group đã tạo trước đó

```
vgs
vgremove xxx-xxx-xxx-xxxx
```

Sau đó tiến hành cài lại bằng ceph-deploy
