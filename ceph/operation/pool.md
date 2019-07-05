# Các thao tác với pools

Pool sẽ cung cấp cho bạn:

- Khả năng phục hồi: Bạn có thể set được số lần nhân bản dữ liệu cho từng pool.
- Placement Groups: Thiết lập số lượng pg cho từng pool, một OSD thông thường sẽ có khoảng 100 pg.
- CRUSH Rules: Khi bạn lưu dữ liệu trong pool, vị trí của dữ liệu và các nhân bản của chúng sẽ được quyết định bởi CRUSH Rules.
- snapshot

**List pool**

ceph osd lspools

**Create pool**

```
ceph osd pool create {pool-name} {pg-num} [{pgp-num}] [replicated] \
     [crush-rule-name] [expected-num-objects]
ceph osd pool create {pool-name} {pg-num}  {pgp-num}   erasure \
     [erasure-code-profile] [crush-rule-name] [expected_num_objects]
```

Bắt đầu từ Luminous, pool sẽ cần phải được khai báo ứng dụng sử dụng nó. Trong đó, pool với CephFS hoặc pool được tạo bởi RGW sẽ được khai báo tự động, pool dùng cho rbd thì nên được khai báo thông quan rbd tool. Các trường hợp khác có thể khai báo bằng tay thông qua câu lệnh sau:

`ceph osd pool application enable {pool-name} {application-name}`

**SET POOL QUOTAS**

`ceph osd pool set-quota {pool-name} [max_objects {obj-count}] [max_bytes {bytes}]`

**Delte pool**

`ceph osd pool delete {pool-name} [{pool-name} --yes-i-really-really-mean-it]`

Lưu ý: Bạn cần phải có flag `mon_allow_pool_delete` được set bằng `True` trong cấu hình của Monitors.

Nếu bạn tự tạo ra rule của mình, bạn nên xem xét xóa chúng khi bạn xóa pool

`ceph osd pool get {pool-name} crush_rule`

Nếu bạn tạo ra user với permission riêng cho pool, bạn cũng nên xem xét việc xóa chúng

```
ceph auth ls | grep -C 5 {pool-name}
ceph auth del {user}
```

**Rename pool**

`ceph osd pool rename {current-pool-name} {new-pool-name}`

**show pool stats**

`rados df`

**Make a snapshot**

`ceph osd pool mksnap {pool-name} {snap-name}`

**Remove snapshot**

`ceph osd pool rmsnap {pool-name} {snap-name}`

**Set pool value**

`ceph osd pool set {pool-name} {key} {value}`

**Get pool values**

`ceph osd pool get {pool-name} {key}`

**Set number replicas**

`ceph osd pool set {poolname} size {num-replicas}`

**Get number of replica**

`ceph osd dump | grep 'replicated size'`
