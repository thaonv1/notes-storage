# Tích hợp CEPH với OpenStack
## Tích hợp Glance với CEPH

### Tạo các pool lưu trữ trên CEPH
Đứng trên CEPH01, thực hiện các lệnh sau

```
ceph osd pool create volumes 64 64
ceph osd pool create images 64 64
ceph osd pool create backups 64 64
```

Khởi tạo các pools.
```
rbd pool init volumes
rbd pool init images
rbd pool init backups
```

### Cài đặt các gói bổ trợ cho Controller và Compute

Cài các gói bổ trợ trên các node controller và compute cho việc tích hợp CEPH. Lưu ý cài trên tất cả các node controller, compute

```
yum install python-rbd -y
yum install ceph-common -y
```

Tạo thư mục cho ceph trên các node controller, compute

```
mkdir -p /etc/ceph/
```

### Cấu hình ceph cho các node controller và compute

Đứng tại CEPH01, thực hiện các bước dưới.

Copy file cấu hình ceph sang các node controller, compute. Khi được hỏi mật khẩu, hãy nhập mật khẩu root của các node controller và compute tương ứng.

```
ssh 192.168.80.131 sudo tee /etc/ceph/ceph.conf < /etc/ceph/ceph.conf
```

```
ssh 192.168.80.132 sudo tee /etc/ceph/ceph.conf < /etc/ceph/ceph.conf
```

Tạo user glance trên node ceph

```
ceph auth get-or-create client.glance mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=images'
```

Chuyển key sang node controller và phân quyền.

```
ceph auth get-or-create client.glance | ssh 192.168.80.131 sudo tee /etc/ceph/ceph.client.glance.keyring
```

```
ssh 192.168.80.131 sudo chown glance:glance /etc/ceph/ceph.client.glance.keyring
```

### Sửa file cấu hình của glance trên controller

Truy cập vào node controller `CTL01` và thực hiện cấu hình sau

```
crudini --set /etc/glance/glance-api.conf DEFAULT show_image_direct_url True
crudini --set /etc/glance/glance-api.conf glance_store default_store rbd
crudini --set /etc/glance/glance-api.conf glance_store stores file,http,rbd
crudini --set /etc/glance/glance-api.conf glance_store rbd_store_pool images
crudini --set /etc/glance/glance-api.conf glance_store rbd_store_user glance
crudini --set /etc/glance/glance-api.conf glance_store rbd_store_ceph_conf /etc/ceph/ceph.conf
crudini --set /etc/glance/glance-api.conf glance_store rbd_store_chunk_size 8
```

Khởi động lại glance 

```
systemctl restart openstack-glance-*
```

Tải image cirros để khởi tạo thử xem đã xuất hiện trên ceph hay chưa.

```
wget http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img

openstack image create "cirros-ceph" \
--file cirros-0.3.4-x86_64-disk.img \
--disk-format qcow2 --container-format bare \
--public
```

Truy cập vào node ceph01, thực hiện lệnh dưới để show ra ID của image

```
rbd -p images ls
```

Kết quả ta sẽ thấy như bên dưới là OK

```
[root@ceph01 ~]# rbd -p images ls
56bee1be-29fe-4d24-82bf-cc1be9a50d20
```

## Tích hợp Cinder với CEPH.
### Tao user cinder và backup tren node ceph

Tạo user cinder và backup

```
ceph auth get-or-create client.cinder mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=volumes, allow rwx pool=images'

ceph auth get-or-create client.cinder-backup mon 'profile rbd' osd 'profile rbd pool=backups'
```

### Chuyển key sang các node Controller

Trong hướng dẫn này chuyển sang CTL01. Lưu ý khi được hỏi mật khẩu, nhập mật khẩu user root của node controller.
```
ceph auth get-or-create client.cinder | ssh 192.168.80.131 sudo tee /etc/ceph/ceph.client.cinder.keyring
```

```
ssh 192.168.80.131 sudo chown cinder:cinder /etc/ceph/ceph.client.cinder.keyring
```

```
ceph auth get-or-create client.cinder-backup | ssh 192.168.80.131 sudo tee /etc/ceph/ceph.client.cinder-backup.keyring
```

```
ssh 192.168.80.131 sudo chown cinder:cinder /etc/ceph/ceph.client.cinder-backup.keyring
```

### Thực hiện sửa file cấu hình cinder trên controller

Truy cập vào node controller `CTL01` và sửa file cấu hình của cinder thông qua các lệnh bên dưới.

```
crudini --set /etc/cinder/cinder.conf DEFAULT notification_driver messagingv2
crudini --set /etc/cinder/cinder.conf DEFAULT enabled_backends ceph
crudini --set /etc/cinder/cinder.conf DEFAULT glance_api_version 2
crudini --set /etc/cinder/cinder.conf DEFAULT host ceph
crudini --set /etc/cinder/cinder.conf DEFAULT backup_driver cinder.backup.drivers.ceph
crudini --set /etc/cinder/cinder.conf DEFAULT backup_ceph_conf /etc/ceph/ceph.conf
crudini --set /etc/cinder/cinder.conf DEFAULT backup_ceph_user cinder-backup
crudini --set /etc/cinder/cinder.conf DEFAULT backup_ceph_chunk_size 134217728
crudini --set /etc/cinder/cinder.conf DEFAULT backup_ceph_pool backups
crudini --set /etc/cinder/cinder.conf DEFAULT backup_ceph_stripe_unit 0
crudini --set /etc/cinder/cinder.conf DEFAULT backup_ceph_stripe_count 0
crudini --set /etc/cinder/cinder.conf DEFAULT restore_discard_excess_bytes true

crudini --set /etc/cinder/cinder.conf ceph volume_driver cinder.volume.drivers.rbd.RBDDriver
crudini --set /etc/cinder/cinder.conf ceph volume_backend_name ceph
crudini --set /etc/cinder/cinder.conf ceph rbd_pool volumes
crudini --set /etc/cinder/cinder.conf ceph rbd_ceph_conf /etc/ceph/ceph.conf
crudini --set /etc/cinder/cinder.conf ceph rbd_flatten_volume_from_snapshot false
crudini --set /etc/cinder/cinder.conf ceph rbd_max_clone_depth 5
crudini --set /etc/cinder/cinder.conf ceph rbd_store_chunk_size 4
crudini --set /etc/cinder/cinder.conf ceph rados_connect_timeout -1
crudini --set /etc/cinder/cinder.conf ceph rbd_user cinder
crudini --set /etc/cinder/cinder.conf ceph rbd_secret_uuid edccdcf1-c181-491c-b539-727887281340
crudini --set /etc/cinder/cinder.conf ceph report_discard_supported true
```

Khởi động lại cinder.

```
systemctl enable openstack-cinder-backup.service
systemctl start openstack-cinder-backup.service
```

```
systemctl restart openstack-cinder-api.service openstack-cinder-volume.service openstack-cinder-scheduler.service openstack-cinder-backup.service
```

### Chuyển key sang các node Compute

Thực hiện bước này tại CEPH01. Khi được hỏi mật khẩu, hãy nhập mật khẩu root của COM01.

```
ceph auth get-or-create client.cinder | ssh 192.168.80.132 sudo tee /etc/ceph/ceph.client.cinder.keyring
```

```
ceph auth get-key client.cinder | ssh 192.168.80.132 tee /root/client.cinder.key
```

Gõ lệnh `uuidgen` tại CEPH1 và lưu output để sử dụng cho bước sau, giả sử output là 

```
a8b264e0-a34f-4dff-b8e4-0104221ba6a9
```

### Khai báo scret key cho Compute

Sử dụng output của lệnh `uuidgen` ở bên trên để tạo file `secret.xml` bằng lệnh bên dưới. Nếu có nhiều compute cần thực hiện hết trên các compute. Nhớ thay chuỗi trong kết quả của lệnh `uuidgen` tương ứng của bạn.

```
cat > secret.xml <<EOF
<secret ephemeral='no' private='no'>
  <uuid>a8b264e0-a34f-4dff-b8e4-0104221ba6a9</uuid>
  <usage type='ceph'>
    <name>client.cinder secret</name>
  </usage>
</secret>
EOF
```

Thực hiện lệnh để áp vào compute. Nhớ thay chuỗi trong kết quả của lệnh `uuidgen` tương ứng của bạn.

```
sudo virsh secret-define --file secret.xml
virsh secret-set-value --secret a8b264e0-a34f-4dff-b8e4-0104221ba6a9 --base64 $(cat client.cinder.key)
```

Khởi động lại service 

```
systemctl restart openstack-nova-compute
```