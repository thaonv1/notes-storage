# Tích hợp ceph với OpenStack Ussuri bằng Kolla Ansible

## Yêu cầu

- Đã có 1 cụm OpenStack Ussuri được deploy bằng Kolla Ansible
- Đã có 1 cụm Ceph Octopus

## Tích hợp

Từ phía ceph, tạo những pool cần thiết.

```
ceph osd pool create volumes 64 64
ceph osd pool create images 64 64
ceph osd pool create backups 64 64
rbd pool init volumes
rbd pool init images
rbd pool init backups
```

Tạo các thư mục cấu hình trên node Controller - Kolla Ansible

```
mkdir -p /etc/kolla/config/cinder/
mkdir -p /etc/kolla/config/cinder/cinder-volume
mkdir -p /etc/kolla/config/cinder/cinder-backup
mkdir -p /etc/kolla/config/glance/
mkdir -p /etc/kolla/config/nova/
```

Từ ceph chuyển cấu hình sang node CTL

```
ssh 10.10.30.61 sudo tee /etc/kolla/config/cinder/cinder-volume/ceph.conf < /etc/ceph/ceph.conf
ssh 10.10.30.61 sudo tee /etc/kolla/config/cinder/cinder-backup/ceph.conf < /etc/ceph/ceph.conf
ssh 10.10.30.61 sudo tee /etc/kolla/config/nova/ceph.conf < /etc/ceph/ceph.conf
ssh 10.10.30.61 sudo tee /etc/kolla/config/glance/ceph.conf < /etc/ceph/ceph.conf
```

Tiếp đó gen key trên ceph

```
ceph auth get-or-create client.glance mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=images'
ceph auth get-or-create client.cinder mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=volumes, allow rwx pool=images'
ceph auth get-or-create client.cinder-backup mon 'profile rbd' osd 'profile rbd pool=backups'
```

Chuyển key qua node CTL

```
ceph auth get-or-create client.cinder | ssh 10.10.30.61 sudo tee /etc/kolla/config/cinder/cinder-volume/ceph.client.cinder.keyring
ceph auth get-or-create client.cinder | ssh 10.10.30.61 sudo tee /etc/kolla/config/cinder/cinder-backup/ceph.client.cinder.keyring
ceph auth get-or-create client.cinder-backup | ssh 10.10.30.61 sudo tee /etc/kolla/config/cinder/cinder-backup/ceph.client.cinder-backup.keyring
ceph auth get-or-create client.cinder | ssh 10.10.30.61 sudo tee /etc/kolla/config/nova/ceph.client.cinder.keyring
ceph auth get-or-create client.glance | ssh 10.10.30.61 sudo tee /etc/kolla/config/glance/ceph.client.glance.keyring
```

Sửa file `/etc/kolla/globals.yml` trên node CTL

```
enable_cinder_backup: "no"
glance_backend_ceph: "yes"
cinder_backend_ceph: "yes"
nova_backend_ceph: "no"

ceph_glance_keyring: "ceph.client.glance.keyring"
ceph_glance_user: "glance"
ceph_glance_pool_name: "images"
ceph_cinder_keyring: "ceph.client.cinder.keyring"
ceph_cinder_user: "cinder"
ceph_cinder_pool_name: "volumes"
```

**Note: Ở đây mình không dùng ceph cho backup và backend cho nova nên mình sẽ để 2 phần đó là "no"**

Thêm file cấu hình `/etc/kolla/config/glance/glance-api.conf`

```
[DEFAULT]
show_image_direct_url = True

[glance_store]
default_store = rbd
stores = file,http,rbd
rbd_store_pool = images
rbd_store_user = glance
rbd_store_ceph_conf = /etc/ceph/ceph.conf
rbd_store_chunk_size = 8
```

Tương tự, ta cũng thêm file cấu hình `/etc/kolla/config/cinder/cinder-volume.conf`

```
[DEFAULT]
notification_driver = messagingv2
enabled_backends = ceph
glance_api_version = 2
[ceph]
volume_driver = cinder.volume.drivers.rbd.RBDDriver
volume_backend_name = ceph
rbd_pool = volumes
rbd_ceph_conf = /etc/ceph/ceph.conf
rbd_flatten_volume_from_snapshot = false
rbd_max_clone_depth = 5
rbd_store_chunk_size = 4
rados_connect_timeout = -1
rbd_user = cinder
rbd_secret_uuid = 45003861-f01b-4c34-ae1c-20b6d540fc6b
report_discard_supported = true
```

**Lưu ý:** Tham số `cinder_rbd_secret_uuid` ta có thể lấy trong file `/etc/kolla/passwords.yml`

Cuối cùng ta sẽ reconfigure lại cụm

```
kolla-ansible -i multinode reconfigure
```

