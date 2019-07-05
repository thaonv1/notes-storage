# CRUSH MAPS

Ceph sử dụng giải thuật có tên là CRUSH để xác định cách lưu cúng như lấy dữ liệu từ việc tính toán vị trí lưu chúng. CRUSH map chứa danh sách các OSD, danh sách các `bucket` để tổng hợp thành các vị trí vật lí và 1 danh sách các rules để CRUSH biết cách replicate dữ liệu trong pool. Bằng cách này thì người quản trị có thể tách cụm cluster thành các phần vật lí để đảm bảo tính sẵn sàng.

## 1. CRUSH LOCATION

Vị trí của OSD trong CRUSH map được gọi là `crush location`. Các vị trí này được định nghĩa bởi giá trị key-value.

Ví dụ:

`root=default row=a rack=a2 chassis=a2a host=a2a1`

- Thứ tự của các cặp key-value không quan trọng
- Key name phải là type được định nghĩa bởi Ceph, bảo gồm `root, datacenter, room, row, pod, pdu, rack, chassis và host`. Tuy nhiên các loại này cũng có thể được customize bằng cách chỉnh sửa CRUSH map.
- Không cần thiết phải khai báo tất cả các loại trên. Mặc định thì Ceph sẽ set `root=default` và `host=HOSTNAME`

Dùng `osd crush update on start = false` để tránh việc osd tự verify vị trí trong crush map.

## 2. CRUSH STRUCTURE

**DEVICES**

Device chính là các `ceph-osd` daemon. Device có thể có `device class` đi kèm (vd hdd, ssd), cho phép chúng được trở thành mục tiêu của các crush rule.

**TYPES AND BUCKETS**

Các types này bao gồm

- osd (or device)
- host
- chassis
- rack
- row
- pdu
- pod
- room
- datacenter
- region
- root

Mỗi một node (device hoặc bucket) sẽ có weight đi kèm và thường thì nó được tính theo đơn vị TB.

**RULES**

Rule sẽ định nghĩa cách dữ liệu được phân bổ giữa các thiết bị trong cluster.

Thông thường thì CRUSH rule sẽ được khai báo thông qua command line. Ngoài ra thì bạn cũng có thể chỉnh crush map. Bạn có thể xem những rule nào đã được define

`ceph osd crush rule ls`

Bạn cũng có thể xem nội dung

`ceph osd crush rule dump`

**DEVICE CLASSES**

Mỗi một device sẽ có thể được set class theo kèm. Mặc định OSDs sẽ tự set class cho chúng thành `hdd, ssd, or nvme` dựa vào loại thiết bị dưới backend.

- Set device class:

`ceph osd crush set-device-class <class> <osd-name> [...]`

Một khi được set, thì nó sẽ không thể thay đổi cho tới khi cái class cũ được unset

`ceph osd crush rm-device-class <osd-name> [...]`

- placement rule chỉ định tới 1 device class cụ thể nào đó có thể được tạo ra với câu lẹnh sau:

`ceph osd crush rule create-replicated <rule-name> <root> <failure-domain> <class>`

- Pool đang dùng có thể được thay đổi rule thông qua câu lệnh

`ceph osd pool set <pool-name> crush_rule <rule-name>`

- Device classes được tạo ra bằng cách tạo ra `shadow` CRUSH hierarchy cho từng class. Rule sau này có thể phân tán dữ liệu dựa vào đó. Để xem CRUSH hierarchy kèm theo shadow:

`ceph osd crush tree --show-shadow`

## 3. MODIFYING THE CRUSH MAP

**ADD/MOVE AN OSD**

`ceph osd crush set {name} {weight} root={root} [{bucket-type}={bucket-name} ...]`

**ADJUST OSD WEIGHT**

`ceph osd crush reweight {name} {weight}`

**REMOVE AN OSD**

`ceph osd crush remove {name}`

**ADD A BUCKET**

`ceph osd crush add-bucket {bucket-name} {bucket-type}`

**MOVE A BUCKET**

`ceph osd crush move {bucket-name} {bucket-type}={bucket-name}, [...]`

**REMOVE A BUCKET**

Note A bucket must be empty before removing it from the CRUSH hierarchy.

`ceph osd crush remove {bucket-name}`

## 4. MANUALLY EDITING A CRUSH MAP

**GET A CRUSH MAP**

`ceph osd getcrushmap -o {compiled-crushmap-filename}`

**DECOMPILE A CRUSH MAP**

`DECOMPILE A CRUSH MAP`

**SECTIONS**

Trong file này có 6 section chính, đó là:

- tunables: The preamble at the top of the map described any tunables for CRUSH behavior that vary from the historical/legacy CRUSH behavior. These correct for old bugs, optimizations, or other changes in - behavior that have been made over the years to improve CRUSH’s behavior.
- devices: Devices are individual ceph-osd daemons that can store data.
- types: Bucket types define the types of buckets used in your CRUSH hierarchy. Buckets consist of a hierarchical aggregation of storage locations (e.g., rows, racks, chassis, hosts, etc.) and their assigned weights.
- buckets: Once you define bucket types, you must define each node in the hierarchy, its type, and which devices or other nodes it containes.
- rules: Rules define policy about how data is distributed across devices in the hierarchy.
- choose_args: Choose_args are alternative weights associated with the hierarchy that have been adjusted to optimize data placement. A single choose_args map can be used for the entire cluster, or one can be created for each individual pool.

**CRUSH MAP DEVICES**

Device có thể đi kèm với device class

```
# devices
device {num} {osd.name} [class {class}]
```

**CRUSH MAP BUCKET TYPES**

Đây là nơi define bucket types, bạn có thể thêm vào list theo cú pháp

`type {num} {bucket-name}`

**CRUSH MAP BUCKET HIERARCHY**

Thuật toán CRUSH phân tán dữ liệu dựa vào weight trên từng device. CRUSH phân tán dữ liệu và các nhân bản của chúng dựa vào cluster map mà bạn define. CRUSH map của bạn thể hiện mức độ sẵn sàng và các mối quan hệ logic giữa chúng.

Ta lấy ví dụ như hình dưới

<img src="https://i.imgur.com/Qpoij7H.png">

Khi declare 1 bucket, bạn phải chỉ định type, 1 tên và ID duy nhất, weight, bucket algorithm, hash,...

```
[bucket-type] [bucket-name] {
        id [a unique negative numeric ID]
        weight [the relative capacity/capability of the item(s)]
        alg [the bucket type: uniform | list | tree | straw ]
        hash [the hash type: 0 by default]
        item [item-name] weight [weight]
}
```

Theo ví dụ trên thì ta có thể declare như sau:

```
host node1 {
        id -1
        alg straw
        hash 0
        item osd.0 weight 1.00
        item osd.1 weight 1.00
}

host node2 {
        id -2
        alg straw
        hash 0
        item osd.2 weight 1.00
        item osd.3 weight 1.00
}

rack rack1 {
        id -3
        alg straw
        hash 0
        item node1 weight 2.00
        item node2 weight 2.00
}
```

**CRUSH MAP RULES**

Đây là những rule quyết định vị trí đặt dữ liệu trong pool.

```
rule <rulename> {

        ruleset <ruleset>
        type [ replicated | erasure ]
        min_size <min-size>
        max_size <max-size>
        step take <bucket-name> [class <device-class>]
        step [choose|chooseleaf] [firstn|indep] <N> <bucket-type>
        step emit
}
```
