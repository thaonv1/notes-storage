# Một số command để xem logical layout của một ceph cluster

### Overview

Để nhìn một cách tổng quát nhất topology, ta sử dụng câu lệnh

`ceph osd tree`

Câu lệnh này show cho chúng ta kiến trúc của CRUSH buckets, bao gồm tên của từng bucket, khối lượng, trạng thái,...

```
# ceph osd tree
ID WEIGHT TYPE NAME UP/DOWN REWEIGHT PRIMARY-AFFINITY
-1 974.89661 root default
-14 330.76886 rack r1
-2 83.56099 host data001
0 3.48199 osd.0 up 1.00000 1.00000
...
23 3.48199 osd.23 up 1.00000 1.00000
-3 80.08588 host data002
24 3.48199 osd.24 up 1.00000 1.00000
25 3.48199 osd.25 up 1.00000 1.00000
26 3.48199 osd.26 up 1.00000 1.00000
27 3.48199 osd.27 up 1.00000 1.00000
28 3.48199 osd.28 up 1.00000 1.00000
29 3.48199 osd.29 up 1.00000 1.00000
30 3.48199 osd.30 up 1.00000 1.00000
31 3.48199 osd.31 up 1.00000 1.00000
32 3.48199 osd.32 up 1.00000 1.00000
34 3.48199 osd.34 up 1.00000 1.00000
35 3.48199 osd.35 up 1.00000 1.00000
36 3.48199 osd.36 up 1.00000 1.00000
37 3.48199 osd.37 up 1.00000 1.00000
38 3.48199 osd.38 up 1.00000 1.00000
39 3.48199 osd.39 down 0 1.00000
40 3.48199 osd.40 up 1.00000 1.00000
41 3.48199 osd.41 up 1.00000 1.00000
42 3.48199 osd.42 up 1.00000 1.00000
43 3.48199 osd.43 up 1.00000 1.00000
44 3.48199 osd.44 up 1.00000 1.00000
45 3.48199 osd.45 up 1.00000 1.00000
46 3.48199 osd.46 up 1.00000 1.00000
47 3.48199 osd.47 up 1.00000 1.00000
-4 83.56099 host data003
48 3.48199 osd.48 up 1.00000 1.00000
...
-5 83.56099 host data004
72 3.48199 osd.72 up 1.00000 1.00000
...
95 3.48199 osd.95 up 1.00000 1.00000
-15 330.76810 rack r2
-6 83.56099 host data005
96 3.48199 osd.96 up 1.00000 1.00000
...
-7 80.08557 host data006120 3.48199 osd.120 up 1.00000 1.00000
...
-8 83.56055 host data007
33 3.48169 osd.33 up 1.00000 1.00000
144 3.48169 osd.144 up 1.00000 1.00000
...
232 3.48169 osd.232 up 1.00000 1.00000
-9 83.56099 host data008
168 3.48199 osd.168 up 1.00000 1.00000
-16 313.35965 rack r3
-10 83.56099 host data009
192 3.48199 osd.192 up 1.00000 1.00000
...
-11 69.63379 host data010
133 3.48169 osd.133 up 1.00000 1.00000
...
-12 83.56099 host data011
239 3.48199 osd.239 up 1.00000 1.00000
...
-13 76.60388 host data012
...
286 3.48199 osd.286 up 1.00000 1.00000
```

Dòng đầu tiên phía sau header

`-1 974.89661 root default`

Cột đầu tiên là ID mà Ceph sử dụng internally, chúng ta không cần quá quan tâm. Cột thứ 2 chính là CRUSH weight. Mặc định thì CRUSH sẽ dựa vào dung lượng raw tính theo đơn vị là TB. Có thể nhận thấy, đây là tổng dung lượng của các bucket bên dưới.

Vì tỉ lệ replicate là 3 cho nên chỉ có khoảng 324 TB là có thể sử dụng được. 2 cột cuối cùng có giá trị lần lượt là root và default cho chúng ta biết CRUSH bucket này là gốc và tên nó là mặc định.

Dòng tiếp theo

`-14 330.76886 rack r1`

Hiển thị loại bucket là rack, với dung lượng vào gần 330 TB.

Tiếp theo ta có

`-2 83.56099 host data001`

Hiển thị loại bucket là host. Tiếp đến ở mỗi host bucket, ta có các OSD entries.

`24 3.48199 osd.24 up 1.00000 1.00000`

Ở ví dụ này, các ổ là SAS SSD với dung lượng 3840 GB. Sự chênh lệch so với thông số bên trên có thể được giải thích bởi một số yêu tố sau:

- Dung lượng của marketing capacity là base 10 units, thực tế là base 2 units
- Mỗi một drive mất 10GB cho journal
- XFS file system overhead

Ta cũng thấy rằng 1 OSD của node data002 đang down, có thể do tiến trình bị tắt hoặc là phần cứng bị lỗi. CRUSH weight thì không thay đổi nhưng mà weight adjustment thì được set thành 0, đồng nghĩa với việc nhưng dữ liệu từng được ở đó đã được chuyển đi đâu đó. Khi mà chúng ta restart tiến trình thành công, thì weight adjustment sẽ trở lại thành 1 và dữ liệu được quay lại.

Lưu ý rằng IDs vủa OSD không phải lúc nào cũng tuần tự mà nó phụ thuộc vào nhiều yếu tố. Như phía trên ta cũng thấy rằng osd số 33 nằm ở host `data007` thay vì `data002` là bởi một số sự kiện sau đã xảy ra:

- Ổ cứng fail trên `data002` đã bị loại bỏ
- Ổ cứng fail trên `data007` đã bị loại bỏ
- Thay thế ổ trên `data007` và tạo osd mới

Khi mà deploy một osd mới thì ceph sẽ pick số bé nhất chưa được sử dụng.

Rất nhiều ceph command hỗ trợ các option `-f json` hoặc `-f json -pretty` với đầu ra sẽ là dạng json.

### Drilling down

**OSD dump**

Lệnh ceph osd dump cho thấy rất nhiều thông tin cấp thấp hơn về các cluster. Bao gồm một danh sách các pool với các thuộc tính của chúng và một danh sách các OSD, mỗi nhóm bao gồm reweight adjustment, trạng thái và hơn thế nữa. Lệnh này chủ yếu được sử dụng trong các tình huống khắc phục sự cố bất thường.

```
[root@ceph1 ~]# ceph osd dump | head
epoch 24
fsid caad6829-f7fd-476b-8920-ecc1c6030af0
created 2019-06-20 10:49:50.924003
modified 2019-06-27 17:19:48.746936
flags sortbitwise,recovery_deletes,purged_snapdirs
crush_version 12
full_ratio 0.95
backfillfull_ratio 0.9
nearfull_ratio 0.85
require_min_compat_client jewel
```

**OSD list**

Hiển thị danh sách OSD được deploy trong cụm.

```
[root@ceph1 ~]# ceph osd ls
0
1
2
3
```

**OSD find**

Tìm kiếm host nơi osd được đặt, phù hợp khi muốn kiểm tra trong trường hợp có osd down.

```
[root@ceph1 ~]# ceph osd find 1
{
    "osd": 1,
    "ip": "192.168.40.22:6800/33396",
    "osd_fsid": "a7fc9689-ebc7-4f60-b099-f903ee9a8d8d",
    "crush_location": {
        "host": "ceph2",
        "root": "default"
    }
}
```

**CRUSH dump**

Câu lệnh này hiển thị giống với `ceph osd tree` nhưng ở dạng json.

**Pools**

Để list các pool, sử dụng 1 trong 2 câu lệnh

```
# rados lspools
rbd
# ceph osd lspools
1 rbd,
```

Để xem thêm thông tin chi tiết

`ceph osd pool ls detail`

Nếu có 1 pool nào đó không có tên

`rados rmpool "" "" --yes-i-really-really-mean-it`

**Monitors**

Ceph MONs hoạt động như một cluster, sử dụng thuật toán Paxos để đảm bảo tính tin cậy và thống nhất. Thông tin được thu thập bởi MONs bao gồm:

- The mon map, which includes names, addresses, state, epoch, and so on for all
- MONs in the cluster. The mon map is vital for quorum maintenance and client connections.
- The CRUSH map, which includes similar information for the collection of OSDs holding Ceph's payload data.
- The MDS map of CephFS MetaData Servers.
- The PG map of which OSDs house each PG.
- Cluster flags.
- Cluster health.
- Authentication keys and client capabilities.

Thông tin về mon map và quorum status có thể được hiển thị bởi 2 câu lệnh sau

```
ceph mon stat
ceph mon dump
```

**CephFS**

`ceph mds stat` hoặc `ceph mds dump` để check status của Ceph's MDS
