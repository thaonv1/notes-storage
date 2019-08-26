# Hướng dẫn cài đặt Ceph theo specific minor version

## Mục tiêu

- Cài đặt ceph bằng ceph deploy theo minor version (vdu Luminous 12.2.8)  vì hiện tại ceph-deploy không cho phép bạn specify minor version

## Các bước thực hiện

Ở bài này, mình sẽ cài đặt Ceph Luminous 12.2.8

Mô hình bao gồm:

- 3 node Ceph OSD + MON
- 1 node Ceph Deploy
- 1 Node Local Repo

### 1. Cấu hình repo offline trên node local repo

- Cài đặt ngix

```
yum install epel-release -y
yum install nginx -y
```

- Bật nginx

```
systemctl start nginx
systemctl enable nginx
systemctl status nginx
```

- Thêm rule firewalld

```
firewall-cmd --zone=public --permanent --add-service=http
firewall-cmd --zone=public --permanent --add-service=https
firewall-cmd --reload
```

- Cài đặt package để tạo và quản lí repo

`yum install createrepo  yum-utils wget -y`

- Tạo repo folder

`mkdir -p /var/www/html/repos/{SRPMS,x86_64,noarch}`

- Tải về các gói tuong ứng đối với 3 folder ở 3 đường link sau

```
https://download.ceph.com/rpm-luminous/el7/SRPMS/
https://download.ceph.com/rpm-luminous/el7/noarch/
https://download.ceph.com/rpm-luminous/el7/x86_64/
```
Ngoài ra, ta cũng có thể download từ đường link repo của alibaba cloud

`http://mirrors.aliyun.com/ceph/`

Ta có thể dùng wget

```
mkdir /tmp/SRPMS
cd /tmp/SRPMS && wget -r --no-parent https://download.ceph.com/rpm-luminous/el7/SRPMS/

mkdir /tmp/noarch
cd /tmp/noarch && wget -r --no-parent https://download.ceph.com/rpm-luminous/el7/noarch/

mkdir /tmp/x86_64
cd /tmp/x86_64 && wget -r --no-parent -A '*-12.2.8-0.el7.x86_64.rpm' https://download.ceph.com/rpm-luminous/el7/x86_64/
```

**Lưu ý:**

Vì ở repo SRPMS và noarch không chỉ có các package của ceph theo version nên ta sẽ tải hết về  và loại bỏ sau

Sau khi tải về xong, copy toàn bộ các package trong các thư mục /tmp/ vào các folder tương ứng trong thư mục `/var/www/html/repos/` mà ta đã tạo trước đó. (Lưu ý chỉ copy package)

```
mv /tmp/SRPMS/download.ceph.com/rpm-luminous/el7/SRPMS/* /var/www/html/repos/SRPMS/
mv /tmp/SRPMS/download.ceph.com/rpm-luminous/el7/noarch/* /var/www/html/repos/noarch/
mv /tmp/SRPMS/download.ceph.com/rpm-luminous/el7/x86_64/* /var/www/html/repos/x86_64/

cd /var/www/html/repos/x86_64/ && rm -rf repodata index.html
cd /var/www/html/repos/SRPMS/ && rm -rf repodata index.html
cd /var/www/html/repos/noarch/ && rm -rf repodata index.html
```

Ta sẽ lọc các packages trong thư mục `/var/www/html/repos/SRPMS/`

Trong các package `ceph`, ta sẽ chỉ giữ lại version `12.2.8` như hình dưới

<img src="https://i.imgur.com/ZFcOinR.png">

Các package khác có thể giữ nguyên vì nó sẽ lấy cái mới nhất.

Ta có thể dùng lệnh sau

`rm -rf $(ls /var/www/html/repos/SRPMS/ -I "ceph-12.2.8-0.el7.src.rpm" | grep ceph-12)`

- Thực hiện tạo repo

```
createrepo -v /var/www/html/repos/SRPMS/
createrepo -v /var/www/html/repos/x86_64/
createrepo -v /var/www/html/repos/noarch/
```

- Cấu hình nginx

`vi /etc/nginx/conf.d/repos.conf`

```
server {
        listen   80;
        server_name  10.10.11.243;
        root   /var/www/html/repos;
        location / {
                index  index.php index.html index.htm;
                autoindex on;	#enable listing of directory index
        }
}
```

Restart lại nginx sau đó truy cập lại kiểm tra

<img src="https://i.imgur.com/H5H5qM5.png">

### 2. Cài đặt Ceph

- Tham khảo cách cài đặt ceph cluster 3 node bằng ceph deploy tại link sau

https://github.com/thaonguyenvan/notes-storage/blob/master/ceph/setup/ceph-deploy-mimic-centos7.md

- Tới bước sửa dụng ceph deploy để install, ta sẽ sử dụng câu lệnh thay thế như sau

`ceph-deploy install --repo-url http://10.10.11.243/ ceph1 ceph2 ceph3`

Sau khi cài đặt xong, check lại version `ceph version`

- Ngoài ra, ta cũng có thể khai báo repo và cài đặt bằng tay (chưa kiểm chứng)

```
cat <<EOF> /etc/yum.repos.d/ceph.repo
[ceph]
name=Ceph packages for $basearch
baseurl=http://10.10.11.243/x86_64/
enabled=1
priority=2
gpgcheck=0
gpgkey=https://download.ceph.com/keys/release.asc

[ceph-noarch]
name=Ceph noarch packages
baseurl=http://10.10.11.243/noarch
enabled=1
priority=2
gpgcheck=0
gpgkey=https://download.ceph.com/keys/release.asc

[ceph-source]
name=Ceph source packages
baseurl=http://10.10.11.243/SRPMS
enabled=0
priority=2
gpgcheck=0
gpgkey=https://download.ceph.com/keys/release.asc
EOF
```

```
yum -y install epel-release
sudo yum -y install ceph ceph-radosgw ceph-deploy
yum -y install htop sysstat iotop iftop ntp ntpdate
```

**Tham khảo:**

http://www.strugglesquirrel.com/2019/04/23/centos7%E9%83%A8%E7%BD%B2ceph/

https://www.tecmint.com/setup-local-http-yum-repository-on-centos-7/

https://github.com/thaonguyenvan/notes-storage/blob/master/ceph/setup/ceph-deploy-mimic-centos7.md

https://docs.ceph.com/ceph-deploy/docs/install.html#local-mirrors
