# Hướng dẫn cài đặt Ceph RGW Nautilus trên CentOS 7

## Mục lục

- 1. Mô hình
- 2. Cấu hình Ceph cluster
- 3. Cấu hình Ceph RGW
- 4. Cấu hình Nginx

### 1. Mô hình

<img src="../images/ceph-rgw.png">

### 2. Cấu hình Ceph cluster

Tham khảo [tại đây](ceph-deploy-nautilus-centos7.md)

### 3. Cấu hình Ceph RGW

- Thêm rule cho firewalld nếu bạn chưa disable

```
sudo firewall-cmd --zone=public --add-port 7480/tcp --permanent
sudo firewall-cmd --reload
```

- Cài đặt Ceph RGW

```
cd my-cluster
ceph-deploy install --rgw ceph1 ceph2 ceph3
ceph-deploy rgw create ceph1 ceph2 ceph3
```

- Mặc định sẽ tạo ra 4 pool đó là

```
.rgw.root
default.rgw.control
default.rgw.meta
default.rgw.log
```

- Ta sẽ xóa toàn bộ các pool này đi

Đầu tiên cần bổ sung config cho phép xóa pool trong file `ceph.conf` ở thư mục `my-cluster`

```
cat << EOF >> ceph.conf

mon_allow_pool_delete = true
EOF
```

Sau đó push config sang các node khác

```
ceph-deploy --overwrite-conf config push ceph1 ceph2 ceph3
```

Restart lại service ceph-mon trên các node

`systemctl restart ceph-mon@$(hostname)`

Xóa toàn bộ các pool

```
ceph osd pool delete .rgw.root .rgw.root --yes-i-really-really-mean-it
ceph osd pool delete default.rgw.control default.rgw.control --yes-i-really-really-mean-it
ceph osd pool delete default.rgw.meta default.rgw.meta --yes-i-really-really-mean-it
ceph osd pool delete default.rgw.log default.rgw.log --yes-i-really-really-mean-it
```
