# Hướng dẫn cài đặt CEPH mimic bằng ceph-deploy trên CentOS 7

## 1. Mô hình

<img src="https://i.imgur.com/MPP1G4l.png">

Môi trường:

Virtualization: KVM
OS: CentOS 7
Ceph version: Mimic

## 2. Hướng dẫn cài đặt môi trường

### 2.1 Thực hiện trên tất cả các node

- Update

`yum install -y update`

- Đặt hostname

`hostnamectl set-hostname {ceph1,ceph2,ceph3}`

- Cài đặt packages

```
yum install -y chrony openssh-server
yum install python-setuptools
systemctl start sshd
systemctl enable sshd
yum install -y yum-plugin-priorities
```

- Thêm file host

```
cat <<EOF>> /etc/hosts
192.168.40.21 ceph1
192.168.40.22 ceph2
192.168.40.23 ceph3
EOF
```

- Khởi tạo user ceph-deploy

```
sudo useradd -d /home/ceph-deploy -m ceph-deploy
echo "ceph-deploy:meditech2019" | chpasswd

echo "ceph-deploy ALL = (root) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ceph-deploy
sudo chmod 0440 /etc/sudoers.d/ceph-deploy
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

### 2.2 Thực hiện trên node ceph-deploy

- Tạo repo

```
cat << EOM > /etc/yum.repos.d/ceph.repo
[ceph-noarch]
name=Ceph noarch packages
baseurl=https://download.ceph.com/rpm-mimic/el7/noarch
enabled=1
gpgcheck=1
type=rpm-md
gpgkey=https://download.ceph.com/keys/release.asc
EOM
```

- cài đặt package

```
yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
sudo yum update
sudo yum install -y ceph-deploy
```
- Xóa repo ceph vừa tạo

`rm -rf /etc/yum.repos.d/ceph.repo`

- Khởi tạo và copy key sang các máy khác

```
ssh-keygen
sudo ssh-copy-id ceph-deploy@ceph1
sudo ssh-copy-id ceph-deploy@ceph2
sudo ssh-copy-id ceph-deploy@ceph3
```

Nhập pass khi được yêu cầu.

- Cấu hình ssh config

```
vi  ~/.ssh/config

Host ceph1
   Hostname ceph1
   User ceph-deploy
Host ceph2
   Hostname ceph2
   User ceph-deploy
Host ceph3
   Hostname ceph3
   User ceph-deploy
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

### 2.3 Cấu hình trên 2 node còn lại

- Đồng bộ time

```
sed -i 's/server 0.centos.pool.ntp.org iburst/server 192.168.40.21 iburst/g' /etc/chrony.conf
sed -i 's/server 1.centos.pool.ntp.org iburst/#/g' /etc/chrony.conf
sed -i 's/server 2.centos.pool.ntp.org iburst/#/g' /etc/chrony.conf
sed -i 's/server 3.centos.pool.ntp.org iburst/#/g' /etc/chrony.conf
systemctl enable chronyd.service
systemctl start chronyd.service
systemctl restart chronyd.service
chronyc sources
```

## 3. Hướng dẫn khởi tạo cluster bằng ceph-deploy

### 3.1 Thực hiện trên node ceph-deploy

- Sử dụng tài khoản `root`

**Lưu ý: Nếu trước đó cụm đã cài ceph, bạn cần gỡ bỏ nó trước khi cài mới**

- Truy cập vào thư mục cài đặt

`cd my-cluster`

- Gỡ các phiên bản ceph đã cài nếu có

```
ceph-deploy --username ceph-deploy purge ceph1 ceph2 ceph3
ceph-deploy --username ceph-deploy purgedata ceph1 ceph2 ceph3  
ceph-deploy --username ceph-deploy forgetkeys
rm -rf ceph.*
```

**Nếu chưa từng cài đặt ceph, ta bỏ qua và thực hiện từ bước phía dưới**

- Tạo thư mục chưa cấu hình

`mkdir my-cluster`

- Khởi tạo cluster mới

`ceph-deploy new ceph1`

- Chỉnh sửa file cấu hình `ceph.conf` vừa được tạo. Ta thêm vào section [global] 2 dòng sau

```
public network = 192.168.40.0/24
cluster network =  192.168.40.0/24
```

- Cài đặt ceph trên các node

`ceph-deploy install ceph1 ceph2 ceph3`

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
