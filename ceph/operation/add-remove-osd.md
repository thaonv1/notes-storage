# Hướng dẫn thêm, xóa, thay osd

## Add OSDs

**List disk**

`ceph-deploy disk list {node-name [node-name]...}`

**Zap disk (delete partition table)**

`ceph-deploy disk zap {osd-server-name}:{disk-name}`

**Create osds**

`ceph-deploy osd create --data {data-disk} {node-name}`
