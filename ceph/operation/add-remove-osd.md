# Hướng dẫn thêm, xóa, thay osd, mon

## 1. Add OSDs

### 1.1 Use ceph-deploy

**List disk**

`ceph-deploy disk list {node-name [node-name]...}`

**Zap disk (delete partition table)**

`ceph-deploy disk zap {osd-server-name}:{disk-name}`

**Create osds**

`ceph-deploy osd create --data {data-disk} {node-name}`

**List osd deployed in node**

`ceph-deploy osd list {node-name}`

## 2. Remove osd

### 2.1 Use ceph-deploy

- Trước khi bị remove, osd thường ở trạng thái `up and in`, bạn cần phải take out nó ra khỏi cluser trước

`ceph osd out {osd-num}`

- Truy cập vào host và stop osd daemon cho osd đó

`sudo systemctl stop ceph-osd@{osd-num}`

- Remove osd (từ luminous trở lên)

`ceph osd purge {id} --yes-i-really-mean-it`

- Xóa trong file cấu hình nếu có

- Unmount LVM Volume group

`umount /var/lib/ceph/osd/ceph-{osd-num}`

- Xóa bỏ LVM Volume Group của OSD

`vgremove ceph-...`

## 3. Add mons

### 3.1 Use ceph-deploy

`ceph-deploy mon add {mon-node}`

## 4. Remove mon

### 4.1 Use ceph-deploy

`ceph-deploy mon destroy {mon-node}`
