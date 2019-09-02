# Hướng dẫn cài đặt CEPH nautilus bằng ceph-deploy trên CentOS 7

## 1. Mô hình

<img src="https://i.imgur.com/MPP1G4l.png">

Môi trường:

- Virtualization: KVM
- OS: CentOS 7
- Ceph version: Nautilus

## 2. Hướng dẫn cài đặt môi trường

### 2.1 Thực hiện trên tất cả các node

- Update

`yum install -y update`

- Đặt hostname

`hostnamectl set-hostname {ceph1,ceph2,ceph3}`

- Cài đặt packages

```
yum install -y chrony openssh-server python-setuptools yum-plugin-priorities
```

- Nếu openssh chưa được kích hoạt

```
systemctl start sshd
systemctl enable sshd
```

- Thêm file host

```
cat <<EOF>> /etc/hosts
10.10.11.240 ceph1
10.10.11.241 ceph2
10.10.11.242 ceph3
EOF
```

- Khởi tạo user ceph-deploy

```
sudo useradd -d /home/ceph-deploy -m ceph-deploy
echo "ceph-deploy:thaonv" | chpasswd

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

- Hoặc disable firewalld & selinux

```
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
systemctl disable firewalld
systemctl stop firewalld
```

### 2.2 Thực hiện trên node ceph-deploy (ceph1)

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

- cài đặt package

```
yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
sudo yum install -y ceph-deploy
```

- Khởi tạo và copy key sang các máy khác

```
ssh-keygen -t rsa -f /root/.ssh/id_rsa -q -P ""
sudo ssh-copy-id -o StrictHostKeyChecking=no -i /root/.ssh/id_rsa.pub ceph-deploy@ceph1
sudo ssh-copy-id -o StrictHostKeyChecking=no -i /root/.ssh/id_rsa.pub ceph-deploy@ceph2
sudo ssh-copy-id -o StrictHostKeyChecking=no -i /root/.ssh/id_rsa.pub ceph-deploy@ceph3
```

Nhập pass khi được yêu cầu.

- Cấu hình ssh config

```
cat <<EOF>>  ~/.ssh/config
Host ceph1
   Hostname ceph1
   User ceph-deploy
Host ceph2
   Hostname ceph2
   User ceph-deploy
Host ceph3
   Hostname ceph3
   User ceph-deploy
EOF
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
sed -i 's/server 0.centos.pool.ntp.org iburst/server 10.10.11.240 iburst/g' /etc/chrony.conf
sed -i 's/server 1.centos.pool.ntp.org iburst/#/g' /etc/chrony.conf
sed -i 's/server 2.centos.pool.ntp.org iburst/#/g' /etc/chrony.conf
sed -i 's/server 3.centos.pool.ntp.org iburst/#/g' /etc/chrony.conf
systemctl enable chronyd.service
systemctl start chronyd.service
systemctl restart chronyd.service
chronyc sources
```

## 3. Hướng dẫn khởi tạo cluster bằng ceph-deploy

### 3.1 Thực hiện trên node ceph-deploy (ceph1)

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

`mkdir my-cluster && cd my-cluster`

- Khởi tạo cluster mới

`ceph-deploy new ceph1`

- Chỉnh sửa file cấu hình `ceph.conf` vừa được tạo. Ta thêm vào section [global] 2 dòng sau

```
public network = 10.10.11.0/24
cluster network =  10.10.11.0/24
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

- thêm osd

```
ceph-deploy osd create --data /dev/vda ceph1
ceph-deploy osd create --data /dev/vda ceph2
ceph-deploy osd create --data /dev/vda ceph3
```

**Hướng dẫn thêm osd với block.db sử dụng cho BlueStore**

Kịch bản:

Trên node Ceph1 ta có 1 ổ SSD (`sda`) làm block.db và 1 ổ HDD (`sdb`) làm block data

- Lấy key bootstrap OSD

```
ceph auth get client.bootstrap-osd -o /var/lib/ceph/bootstrap-osd/ceph.keyring
```

- Kiểm tra

`ceph-volume lvm list`

- Tạo volume group cho block data

`vgcreate ceph-block-0 /dev/sdb`

- Tạo logical volume cho block data

`lvcreate -l 100%FREE -n block-0 ceph-block-0`

- Tạo volume group cho bloc db.

`vgcreate ceph-db-0 /dev/sdb`

Dung lượng khuyến cáo là không nhỏ hơn `4%` của block data nên ta sẽ tính toán và tạo ra logical volume cho block db 1 cách hợp lý. Giả sử ở đây ta có ổ `sdb` là 1T, thì ta sẽ tạo ra lv với dung lượng 40G để làm block db

`lvcreate -L 40GB -n db-0 ceph-db-0`

- Tạo osd

`ceph-volume lvm create --bluestore --data ceph-block-0/block-0 --block.db ceph-db-0/db-0`

- Kiểm tra

`ceph -s`
