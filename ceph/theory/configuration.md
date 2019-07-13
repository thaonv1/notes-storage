# Cấu hình Ceph

## 1. Storage device

Có 2 daemon lưu trữ dữ liệu vào ổ đĩa:

- Ceph OSD
- Ceph Monitor

### OSD backend

Có 2 cách để OSD quản lý dữ liệu nó lưu trữ

**BLUESTORE**

- Quản lí trực tiếp các thiết bị. Nó loại bỏ các layer ở giữa ví dụ như file system để tăng hiệu năng
- Quản lí metadata với RockDB
- Toàn bộ dữ liệu và metadata được checksum.
- Dữ liệu có thể được nén trước khi lưu xuống disk
- Phân tầng metadata theo các thiết bị
- Copy-on-write

**FILESTORE**

Dựa vào filesystem kết hợp với key/value database. FileStore là lựa chọn duy nhất cho tới bản Luminous, tuy nhiên nó gặp phải một số vấn đề về sự phụ thuộc hiệu năng bởi nó được thiế kế để lưu object dựa trên filesystem.

## 2. Configuring Ceph

Quá trình start Ceph service sẽ bao gồm việc start 3 tiến trình sau:

- Ceph Monitor (ceph-mon)
- Ceph Manager (ceph-mgr)
- Ceph OSD Daemon (ceph-osd)

### 2.1 OPTION NAMES

Toàn bộ các option đều có tên duy nhất với chữ thường và đấu gạch dưới. Khi dùng với command line, dấu gạch giữa ( `-` ) và dấu gạch dưới ( `_` ) là như nhau

### 2.2 Config source

Dưới đây là danh sách các source config mà ceph nhận theo thứ tự, cái ở dưới sẽ override cái trên:

- default value
- monitor's configuration database
- configuration file
- environment variables
- command line arguments
- runtime overrides set by an administrator

**BOOTSTRAP OPTIONS**

Vì một số tùy chọn ảnh hưởng tới khả năng giao tiếp với monitor, các thực và nhận các cấu hình nên chúng cần được lưu trữ trong file cấu hình, nó bao gồm:

- `mon_host` : danh sách các monitors
- `mon_dns_serv_name` : dns srv để định danh monitor thông qua dns
- `mon_data, osd_data, mds_data, mgr_data` : thư mục chưa dữ liệu
- `keyring, keyfile, and/or key` : Thông tin về credential để xác thực

**SKIPPING MONITOR CONFIG**

Để bỏ qua quá trình nhận cấu hình từ monitor, thêm option `--no-mon-config`. Dùng trong trường hợp tất cả các cấu hình đều được quản lý thông qua các file hoặc khi monitor down nhưng người quản trị vẫn muốn thực thi một số tác vụ bảo trì.

### 2.3 METAVARIABLES

Ceph sẽ lấy giá trị tại thời điểm hiện tại của metavariable khi nó được sử dụng trong cấu hình.

- `$cluster` : tên cluster, mặc định là `ceph`
- `$type` : daemon or process type. ví dụ `/var/lib/ceph/$type`
- `$id` : daemon or client id
- `$host` : hostname

### 2.4 THE CONFIGURATION FILE

Khi start, các ceph process sẽ tìm kiếm file cấu hình ở các vị trí sau:

1. `$CEPH_CONF` environment variable

2. -c path/path (i.e., the -c command line argument)

3. /etc/ceph/$cluster.conf

4. ~/.ceph/$cluster.conf

5. ./$cluster.conf (i.e., in the current working directory)

`$cluster` là cluster name (mặc định là `ceph`)

### 2.5 RUNTIME CHANGES

Ceph cho phép thay đổi cấu hình khi đang chạy. Nó khá hữu ích khi cần tăng hoặc giảm log debug.

`ceph config set osd.123 debug_ms 20`

Tuy nhiên có 1 lưu ý đó là nếu option tương tự được set ở trong file cấu hình thì các setting thông qua monitor sẽ bị ignore bởi nó có priority thấp hơn.

**OVERRIDE VALUE**

Bạn cũng có thể set cấu hình tạm thời sử dụng `ceph tell` command. Những cấu hình này sẽ override các giá trị nhưng nó sẽ mất nếu daemon restart.

Có 2 cách:

- Từ bất kì host nào

`ceph tell <name> config set <option> <value>`

ví dụ:

`ceph tell osd.123 config set debug_osd 20`

- từ host mà process đang chạy, ta connect trực tiếp thông qua socket

`ceph daemon <name> config set <option> <value>`

ví dụ:

`ceph daemon osd.4 config set debug_osd 20`

Lưu ý rằng câu lệnh `ceph config show` sẽ show ra giá trị đã được override.

### 2.6 VIEWING RUNTIME SETTINGS

`ceph config show osd.0`

Ngoài ra bạn cũng có thể xem thông qua admin socket

`ceph daemon osd.0 config show`

## 3. NETWORK CONFIGURATION

### 3.1 IP TABLES

Mặc định thì daemons sẽ bind port theo range từ 6800 tới 7300. Bạn có thể cấu hình range này.

Ở một số bản phân phối, linux sẽ reject tất cả các inbound request ngoại trừ ssh. Bạn nên xóa rule này và thay thế bằng 1 số rule khác hợp lí hơn.

**MONITOR IP TABLES**

Monitor mặc định sẽ lắng nghe ở port 6789 và hoạt động trên public network.

**MDS AND MANAGER IP TABLES**

Ceph metadata server và manager mặc định sẽ lắng nghe ở port available đầu tiên bắt đầu từ 6800 trên public network.

Bạn nên mở all port trong range từ 6800 tới 7300.

**OSD IP TABLES**

Giống với MDS và MGR, mặc định OSD cũng sẽ bind port từ 6800. Mỗi một Ceph OSD daemon chạy có thể dùng tới 4 port:

- 1 cái cho việc nói chuyện với client và monitor
- 1 cái cho việc gửi dữ liệu tới các OSDs khác
- 2 cái để heartbeating trên mỗi interface

<img src="https://i.imgur.com/TDrLUgc.png">

Khi mà daemon này restart, có thể nó sẽ bind port mới. Vì thế bạn nên mở rule cho cả range trên cả 2 network.

### 3.2 NETWORK CONFIG SETTINGS

**BIND**

- `ms bind port min` : Port nhỏ nhất mà osd hoặc mds sẽ bind
- `ms bind port max` : Port nhỏ nhất mà osd hoặc mds sẽ bind
- `ms bind ipv6` : Cho phép bind ipv6

**HOSTS**

- `mon addr`: Danh sách {ip}:{port} client có thể dùng để kết nối tới ceph monitor
- `mon priority` : Mức độ ưu tiên, giá trị càng thấp thì càng được uue tiên khi mà client kết nối tới, mặc định là 0

## 4. CEPHX CONFIG

### 4.1 DEPLOYMENT SCENARIOS

**CEPH-DEPLOY**

Khi dùng ceph deploy thì bạn không cần phải bootstrap monitor bằng tay, đồng thời cũng không cần tạo user `client.admin` và keyring.

Khi bạn thực hiện câu lệnh

`ceph-deploy new {initial-monitor(s)}`

Ceph sẽ tạo monitor keyring cho bạn và nó cũng sẽ gen file cấu hình chứa 1 số cầu hình mặc định, trong đó có việc sử dụng Cephx

```
auth_cluster_required = cephx
auth_service_required = cephx
auth_client_required = cephx
```

Khi bạn thực hiện câu lệnh `ceph-deploy mon create-initial`, Ceph sẽ bootstrap monitor đầu tiên, nhận keyring file. Ngoài ra, nó cũng nhận key cho phép ceph-deploy và ceph-volume khả năng activate OSD và MDS.

Khi bạn thực hiện câu lệnh `ceph-deploy admin {node-name}`, bạn sẽ push file config và keyring của client.admin tới thư mục `/etc/ceph` trên node khác. Nhờ thế, bạn có thể thực hiện các tác vụ quản lí thông qua command line trên node đó.

**MANUAL DEPLOYMENT**

Khi bạn cấu hình ceph bằng tay, bạn sẽ phải bootstrap ceph monitor, tạo user và keyring bằng tay. Tham khảo cách bootstrap monitor [tại đây]()

### 4.3 ENABLING/DISABLING CEPHX

**ENABLING CEPHX**

Khi mà bật cephx, ceph sẽ tìm kiếm keyring ở thư mục mặc định `/etc/ceph/$cluster.$name.keyring`.

**DISABLING CEPHX**

Để disable cephx, setting các dòng sau vào file cấu hình

```
auth cluster required = none
auth service required = none
auth client required = none
```

Sau đó restart lại cluster.

## 5. MONITOR CONFIG

Chức năng chính của monitor đó là quản lí cluster map, ngoài ra nó cũng cup cấp xác thực và logging. Ceph sẽ ghi toàn bộ thay đổi vào một Paxos instance và Paxos sẽ ghi các thay đổi dưới dạng key/value để lưu trữ.

<img src="https://i.imgur.com/nvm7s5k.png">

**Cluster map**

Cluster map bao gồm mon map, osd map, pg map và mds map. Cluster map theo dõi một số thứ quan trọng như là những tiến trình nào đang up, running hay down, những pg nào active hoặc degraded ... Khi có sự thay đổi về trạng thái của cluster, cluster map sẽ update và ảnh hưởng tới trạng thái hiện tại của cluster . Ngoài ra, Ceph cũng quản lí lịch sử của map version và chúng được gọi là `epoch`.

**CONSISTENCY**

Ceph client và các daemon khác dùng file cấu hình để tìm ra monitor, trong khi đó thì các monitor tìm kiếm nhau thông qua monitor map.

Ceph monitor luôn tìm kiếm 1 bản copy được lưu local của monmap khi àm tìm kiếm các monitor khác. Việc sử dụng monmap thay vì file cấu hình này sẽ tránh được các lỗi có thể gây tới cho cụm cluster ví dụ như sai cú pháp trong file cấu hình.

Mỗi một thay đổi của monmap đều phải đi qua giải thuật Paxos. Các ceph mon sẽ phải đồng ý với update của monmap để đảm bảo rằng tất cả các mon trong quorum đều có bản mới nhất. Như vậy nếu mà các ceph mon sử dụng file cấu hình thì các thay đổi sẽ không thể được update và phân phối một cách tự động.

### 5.1 CONFIGURING MONITORS

Các cấu hình cho monitor được đặt trong section `[mon]`, hoặc nếu muốn cấu hình cụ thể cho mon, các bạn hayxchir định tên mon trong section, ví dụ `[mon.a]`


**Cấu hình bắt buộc**

Cấu hình bắt buộc của mon bao gồm hostname và địa chỉ monitor của từng monitor.

```
[mon]
        mon host = hostname1,hostname2,hostname3
        mon addr = 10.0.0.10:6789,10.0.0.11:6789,10.0.0.12:6789
```

hoặc

```
[mon.a]
        host = hostname1
        mon addr = 10.0.0.10:6789
```

**STORAGE CAPACITY**

Khi mà cluster đạt tới giới hạn lưu trữ (dựa theo thông số `mon osd full ratio`) ceph sẽ không cho phép người dùng ghi dữ liệu. Dưới đây là ảnh mô tả cluster ceph với 33 ceph node, mỗi node có 1 osd, mỗi osd có dung lượng khoảng 3TB, như vậy cả cụm ta có khoảng 99 TB. Với tỉ lệ ratio là 0.95 thì ceph sẽ không cho client ghi dữ liệu nếu chỉ còn 5TB.

<img src="https://i.imgur.com/E1C0umV.png">

- `mon osd full ratio` : phần trăm của dung lượng ổ đĩa đã sử dụng trước khi OSD được báo là full
- `mon osd backfillfull ratio` : Phần trăm của dung lượng ổ đĩa trước khi OSD được báo rằng đã quá lớn để có thể backfillfull
- `mon osd nearfull ratio` : phần trăm của dung lượng ổ đĩa đã sử dụng trước khi OSD được báo là gần full

**MONITOR STORE SYNCHRONIZATION**

Khi bạn chạy production cluster với nhiều mon, mỗi một mon sẽ check để xem là các mon còn lại có được bản mới nhất của cluster map chưa. Ta có thể chia mon thành 3 role:

- Leader: là mon đầu tiên nhận được paxos version của cluster map gần nhất
- Provider: là mon có version mới nhất của cluster map nhưng không phải là mon đầu tiên nhận được.
- Requester: mon bị out khỏi cluster và phải đồng bộ lại để nhận được vesion mới nhất trước khi nó có thể rejoin

Các role này cho phép leader giao việc đồng bộ cho provider để tránh việc leader bị overload.

<img src="https://i.imgur.com/JeaK5SW.png">

### 5.2 POOL SETTINGS

- `mon allow pool delete` : Cho phép remove pool. Mặc định là fail
- `osd pool default flag nodelete` : Ngăn việc xóa pool
- `osd pool default flag nopgchange` : Không cho phép thay đổi số lượng pg
- `osd pool default flag nosizechange` : Không cho phép thay đổi size pool

## 6. CONFIGURING MONITOR/OSD INTERACTION

### 6.1 OSDS CHECK HEARTBEATS

Mỗi một ceph OSD daemon sẽ check heartbeat của các osd daemons khác mỗi 6 giây. Bạn có thể thay đổi cấu hình này với tùy chọn `osd heartbeat interval` trong section `[osd]` ở file config hoặc setting runtime. Nếu các ceph OSD daemon không show được heartbeat trong vòng 20 giây thì osd có thể bỏ qua nó và báo lại với monitor. Bạn cũng có thể thay đổi thời gian này bằng tùy chọn `osd heartbeat grace` trong file cấu hình.

<img src="https://i.imgur.com/q00HG7y.png">

### 6.2 OSDS REPORT DOWN OSDS

Để tránh trường hợp osd report nằm trên cùng 1 rack với osd down và network của rack đó có vấn đề, Ceph sử dụng peer report. Cụ thể thì nó sử dụng 2 report từ các subtree khác nhau để có thể đánh dấu OSD down.

<img src="https://i.imgur.com/h7cwHOK.png">

### 6.3 OSDS REPORT PEERING FAILURE

Nếu OSD daemon không thể peer với bất kì OSD daemon nào khác, nó sẽ ping monitor để lấy bản copy mới nhất của cluster map mỗi 30 giây.

<img src="https://i.imgur.com/g4S7lzr.png">

### 6.4 OSDS REPORT THEIR STATUS

Sau khi `mon osd report timeout` kết thúc mà OSD không report lại cho Monitor thì OSD đó sẽ được coi là down.

<img src="https://i.imgur.com/YbwKfy7.png">

## 7. BLUESTORE CONFIG

Ở trường hợp đơn giản nhất, BlueStore sử dụng 1 storage device được chia làm 2 phần:

- 1 phân vùng nhỏ được format với định dạng xfs để lưu metadata. Thư mục này cũng chứa thông tin về OSD.
- Phần còn lại được quản lí trực tiếp bởi BlueStore chứa dữ liệu thực.

Ta cũng có thể deploy BlueStore trên 2 device.

- `WAL` device được dùng cho BlueStore internal journal. Nó chỉ hữu ích trong trường hợp sử dụng thiết bị nhanh hơn primary device (ví dụ SSD cho WAL và HDD cho primary)
- `DB` device được dùng dể lưu BlueStore internal metadata. Nếu DB device đầy, metadata sẽ trở lại lưu ở primary device. Ngoài ra nó cũng chỉ thực sự hữu ích nếu được lưu ở một thiết bị nhanh hơn.

Nếu bạn chỉ còn lại ít dung lượng của thiết bị tốc độ cao, ceph khuyến cáo bạn nên dùng nó cho `WAL` device. Còn nếu nhiều hơn, nên sử dụng cho DB device.

Single-device BlueStore OSD có thể được tạo bằng câu lệnh

`ceph-volume lvm prepare --bluestore --data <device>`

Để specify WAL hoặc DB device

`ceph-volume lvm prepare --bluestore --data <device> --block.wal <wal-device> --block.db <db-device>`

### 7.1 PROVISIONING STRATEGIES

Khác với FileStore, BlueStore có một số cashc để tạo Ceph OSD, ta có 2 cách phổ biến nhất:

**BLOCK (DATA) ONLY**

Dùng trong trường hợp tất cả các device cùng loại

`ceph-volume lvm create --bluestore --data /dev/sda`

Nếu logical volume đã được tạo cho từng device

`ceph-volume lvm create --bluestore --data ceph-vg/block-lv`

**BLOCK AND BLOCK.DB**

Nếu ta có cả 2 loại thiết bị nhanh và chậm, ceph khuyến cáo sử dụng device nhanh hơn cho `block.db`. Sizing cho `block.db` nên càng lớn càng tốt.

Lấy ví dụ ta có 4 thiết bị hdd và 1 ssd. Đầu tiên ta tạo các volume group

```
$ vgcreate ceph-block-0 /dev/sda
$ vgcreate ceph-block-1 /dev/sdb
$ vgcreate ceph-block-2 /dev/sdc
$ vgcreate ceph-block-3 /dev/sdd
```

Ta tiếp tục tạo logical volumes

```
$ lvcreate -l 100%FREE -n block-0 ceph-block-0
$ lvcreate -l 100%FREE -n block-1 ceph-block-1
$ lvcreate -l 100%FREE -n block-2 ceph-block-2
$ lvcreate -l 100%FREE -n block-3 ceph-block-3
```

Ta tạo 4 OSD cho 4 ổ hdd, vì thế ổ ssd với khoảng 200GB dung lượng ta sẽ chia ra làm 4 logical volume mỗi cái 50GB.

```
$ vgcreate ceph-db-0 /dev/sdx
$ lvcreate -L 50GB -n db-0 ceph-db-0
$ lvcreate -L 50GB -n db-1 ceph-db-0
$ lvcreate -L 50GB -n db-2 ceph-db-0
$ lvcreate -L 50GB -n db-3 ceph-db-0
```

Cuối cùng ta tạo 4 OSD

```
$ ceph-volume lvm create --bluestore --data ceph-block-0/block-0 --block.db ceph-db-0/db-0
$ ceph-volume lvm create --bluestore --data ceph-block-1/block-1 --block.db ceph-db-0/db-1
$ ceph-volume lvm create --bluestore --data ceph-block-2/block-2 --block.db ceph-db-0/db-2
$ ceph-volume lvm create --bluestore --data ceph-block-3/block-3 --block.db ceph-db-0/db-3
```

### 7.2 SIZING

Khi sử dụng mix 2 loại device, ta cần có đủ dung lượng của ssd. theo khuyến cáo, nó không được nhỏ hơn 40% so với dung lượng của OSD. Nếu không sử dụng 2 loại thì việc tạo ra phân vùng riêng cho block.db (hoặc block.wal) là không cần thiết. 
