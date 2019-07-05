# Common tasks

## 1. Flags

Ceph có một số cờ thể hiện các trạng thái của Ceph.

Một trong số những cờ được dùng nhiều nhất đó là `noout`, sẽ làm cho Ceph không tự động đưa bất cứ OSD nào vào trạng thái down. Bởi vì không có OSD nào out khi cờ này được thiết lập nên cluster sẽ không bắt đầu quá trình backfill / recovery để đảm bảo sự vẹn toàn dữ liệu nhân bản. Rất hữu dụng khi thực hiện các thao tác bảo trì bao gồm việc reboot.

Dưới đây là ví dụ về việc reboot 1 OSD node. Trước tiên ta sẽ chạy `ceph -s` để check trạng thái chung.

```
ceph -s
cluster 3369c9c6-bfaf-4114-9c31-576afa64d0fe
health HEALTH_OK
monmap e2: 5 mons at {mon001=10.8.45.10:6789/0,mon002=10.8.45.11:6789/0,mon003=10.8.45.1
election epoch 24, quorum 0,1,2,3,4 mon001,mon002,mon003,mon004,mon005
osdmap e33039: 280 osds: 280 up, 280 in
flags sortbitwise,require_jewel_osds
pgmap v725092: 16384 pgs, 1 pools, 0 bytes data, 1 objects
58364 MB used, 974 TB / 974 TB avail
16384 active+clean
```

Ta thấy trạng thái của cluster đang là `HEALTH_OK` và đã có 2 cờ được set sẵn đó là `sortbitwise` và `require_jewel_osds`. Trong đó cờ `sortbitwise` để sắp xếp 1 số thay đổi cần thiết cho các tính năng mới. Còn cờ `require_jewel_osds` để ngăn các OSD không phải version Jewel join vào cluster. Cả hai đều được khuyến cáo set cho các cluster từ Jewel trở về sau.

Sau khi chắc chắn cluster vẫn OK, ta sẽ set noout để ngăn việc recovery. Lưu ý rằng trạng thái cluster sẽ chuyển qua `HEALTH_WARN`

```
# ceph osd set noout
set noout
```

```
# ceph status
cluster 3369c9c6-bfaf-4114-9c31-576afa64d0fe
health HEALTH_WARN
noout flag(s) set
```

Tại thời điểm này, ta có thể shutdown OSD node. Nếu chúng ta không set cờ `noout` thì sau khi mà tắt OSD node, Ceph sẽ tiến hành quá trình map dữ liệu mới đến các node còn lại. Sau này khi mà host up trở lại thì Ceph sẽ lại map ngược lại dữ liệu vào vị trí cũ. Ta thấy điều này sẽ làm double việc dịch chuyển dữ liệu.

```
ceph status
  cluster 3369c9c6-bfaf-4114-9c31-576afa64d0fe
    health HEALTH_WARN
      3563 pgs degraded
      3261 pgs stuck unclean
      3563 pgs undersized
      20/280 in osds are down
      noout flag(s) set
    monmap e2: 5 mons at {mon001=10.8.45.10:6789/0,mon002=10.8.45.11:6789/0,mon003=10.8.45.1
      election epoch 24, quorum 0,1,2,3,4 mon001,mon002,mon003,mon004,mon005
    osdmap e33187: 280 osds: 260 up, 280 in; 3563 remapped pgs
      flags noout,sortbitwise,require_jewel_osds
    pgmap v725174: 16384 pgs, 1 pools, 0 bytes data, 1 objects
      70498 MB used, 974 TB / 974 TB avail
        12821 active+clean
          3563 active+undersized+degraded
```

Sau khi host up, ta tiến hành gỡ bỏ cờ `noout` để cluster trở về trạng thái bình thường.

## 2. Service management

Mỗi một thành phần Ceph MON, OSD, RGW, MDS. Manager đều được xây dựng dưới dạng Linux service nên việc tắt bật chúng cũng khác nhau qua từng bản phân phối.

### 2.1 Systemd

Systemd quản lí các service theo dạng units, để show toàn bộ Ceph units

`systemctl status ceph.target`

Để start toàn bộ các ceph daemons đang chạy

```
# systemctl start ceph.target
```

Để tắt toàn bộ các daemons

`sudo systemctl stop ceph\*.service ceph\*.target`

List các systemd units của ceph

`sudo systemctl status ceph\*.service ceph\*.target`

Start toàn bộ daemon theo loại

```
sudo systemctl start ceph-osd.target
sudo systemctl start ceph-mon.target
sudo systemctl start ceph-mds.target
```

Stop toàn bộ daemon theo loại

```
sudo systemctl stop ceph-mon\*.service ceph-mon.target
sudo systemctl stop ceph-osd\*.service ceph-osd.target
sudo systemctl stop ceph-mds\*.service ceph-mds.target
```



Để tắt cụ thể các OSDs instance, ta khai báo OSD number của nó, còn các instance của các dịch vụ khác, ta khai báo hostname

```
# systemctl stop ceph-osd@11
# systemctl start ceph-osd@11
# systemctl stop ceph-mds@monhost-003
# systemctl start ceph-mds@monhost-003
# systemctl stop ceph-mon@monhost-002
# systemctl start ceph-mon@monhost-002
# systemctl stop ceph-radosgw@rgwhost-001
# systemctl start ceph-radosgw@rgwhost-001
```

## 3. Health check

Ceph có một số message thông báo health check giúp người dùng biết tình trạng gì đang xảy tới với cluster của mình

### 3.1 Manager

**MGR_MODULE_DEPENDENCY**

Manager module không thể thực hiện được dependency check.

**MGR_MODULE_ERROR**

Manager module gặp lỗi.

### 3.2 OSDs

**OSD_DOWN**

Một hoặc nhiều OSD được đánh dấu là down. Ceph-osd daemon có thể đã bị dừng hoặc peers OSDs không thể tìm thấy đối phương. Nguyên nhân thường do daemon bị crash, host bị down hoặc network xảy ra vấn đề. Trường hợp daemon bị crash, có thể tìm thêm thông tin tại file log `/var/log/ceph/ceph-osd.*`

**OSD_<CRUSH TYPE>_DOWN**

Toàn bộ OSD với CRUSH subtree được đánh dấu là down. Ví dụ có thể là toàn bộ OSD trên 1 host.

**OSD_ORPHAN**

OSD xuất hiện trong CRUSH map hierarchy  nhưng ko tồn tại. Ta có thể xóa trong hierarchy  bằng câu lệnh

`ceph osd crush rm osd.<id>`

**OSD_FULL**

Một hoặc nhiều OSDs đã vượt ngưỡng và từ chối ghi dữ liệu.

Ta có thể check mức độ sử dụng thông qua câu lệnh

`ceph df`

Xem ratio

`ceph osd dump | grep full_ratio`

Cách "chữa cháy" tạm thời là tăng ratio lên để có time tăng dung lượng

`ceph osd set-full-ratio <ratio>`

**OSD_BACKFILLFULL**

Một hoặc nhiều OSDs đã đạt đến ngưỡng backfillfull, điều nãy sẽ ngăn cản việc rebalance dữ liệu tới OSD này.

**OSD_NEARFULL**

Một hoặc nhiều OSDs đã đạt đến ngưỡng nearfull. Đây là cảnh báo sớm cho việc cluster đang dần đạt tới ngưỡng.

**OSDMAP_FLAGS**

Một hoặc nhiều cờ đã được set cho cluster, các cờ này bao gồm

- full - the cluster is flagged as full and cannot service writes
- pauserd, pausewr - paused reads or writes
- noup - OSDs are not allowed to start
- nodown - OSD failure reports are being ignored, such that the monitors will not mark OSDs down
- noin - OSDs that were previously marked out will not be marked back in when they start
- noout - down OSDs will not automatically be marked out after the configured interval
- nobackfill, norecover, norebalance - recovery or data rebalancing is suspended
- noscrub, nodeep_scrub - scrubbing is disabled
- notieragent - cache tiering activity is suspended

Các cờ này được set và unset theo cú pháp sau

```
ceph osd set <flag>
ceph osd unset <flag>
```

**OSD_FLAGS**

Các cờ này dành riêng cho osd, chúng bao gồm

- noup: OSD is not allowed to start
- nodown: failure reports for this OSD will be ignored
- noin: if this OSD was previously marked out automatically after a failure, it will not be marked in when it stats
- noout: if this OSD is down it will not automatically be marked out after the configured interval

Để set và unset các cờ này, thực hiện theo cú pháp sau

```
ceph osd add-<flag> <osd-id>
ceph osd rm-<flag> <osd-id>
```

**OLD_CRUSH_TUNABLES**

Báo hiệu CRUSH map đang dùng những thiết lập cũ và nên dược update.

**OLD_CRUSH_STRAW_CALC_VERSION**

CRUSH map đang dùng phương thức tính toán cũ, không tối ưu.

**CACHE_POOL_NO_HIT_SET**

Sử dụng cho các cache pool, một trong các cache pool đang chưa được cấu hình `hit set` để theo dõi mức độ sử dụng cũng như loại bỏ các dữ liệu cũ.

Cú pháp cấu hình hit set

```
ceph osd pool set <poolname> hit_set_type <type>
ceph osd pool set <poolname> hit_set_period <period-in-seconds>
ceph osd pool set <poolname> hit_set_count <number-of-hitsets>
ceph osd pool set <poolname> hit_set_fpp <target-false-positive-rate>
```

**POOL_FULL**

Một hoặc nhiều pools đã đạt tới ngưỡng quota và không thể write

Bạn có thể xem ngưỡng thông qua câu lệnh sau

`ceph df detail`

để set quota

```
ceph osd pool set-quota <poolname> max_objects <num-objects>
ceph osd pool set-quota <poolname> max_bytes <num-bytes>
```

**PG_AVAILABILITY**

Tính sẵn sàng của dữ liệu bị giảm, có nghĩa là cluster không thể thực hiện việc đọc nghi dữ liệu đối với 1 vài dữ liệu trong cụm. Để xem rõ ràng hơn PGs nào đang bị ảnh hưởng, sử dụng câu lệnh sau

`ceph health detail`

Hầu hết nguyên nhân sẽ là do có 1 osd bị hỏng

**PG_DEGRADED**

Dữ liệu dự phòng đang có vấn đề, có nghĩa là cluster đang không thể đảm bảo tất cả đều có dự phòng. Cụ thể 1 hoặc nhiều osd đang:

- có cờ degraded or undersized
- không có cờ clean

Hầu hết nguyên nhân sẽ là do có 1 osd bị hỏng

**PG_DEGRADED_FULL**

Số lượng dữ liệu dự phòng bị giảm do thiếu không gian lưu trữ. cụ thể một hoặc nhiều PG đang có cờ backfill_toofull or recovery_toofull, báo hiệu rằng cluster không thể migrate hoặc recover dữ liệu bởi 1 hoặc nhiều osd đã vượt ngưỡng backfillfull

**PG_DAMAGED**

Data scrubbing phát hiện ra có vấn đề đối với sự nhất quán dữ liệu trong cụm.

**OSD_SCRUB_ERRORS**

Thường đi kèm với PG_DAMAGED.

**CACHE_POOL_NEAR_FULL**

Cache tier đang gần full. Được định nghĩa bởi target_max_bytes and target_max_objects trong cache pool. Khi tới ngưỡng, hoạt động write sẽ bị ngưng lại.

2 thông số này có thể được set thông qua câu lệnh

```
ceph osd pool set <cache-pool-name> target_max_bytes <bytes>
ceph osd pool set <cache-pool-name> target_max_objects <objects>
```

**TOO_FEW_PGS**

Số lượng PGs đạt ngưỡng thấp hơn `mon_pg_warn_min_per_osd` PGs trên 1 OSD. Điều này có thể ảnh hưởng tới performance.

**TOO_MANY_PGS**

Số lượng PGs đạt ngưỡng cao hơn `mon_pg_warn_min_per_osd`. Cluster sẽ ngăn việc tạo mới pool. Số lượng lớn pg có thể dẫn tới việc tiêu thụ nhiều ram hơn cho OSD daemons, tốc chộ peering chậm hơn khi OSD restart hoặc được thêm, bớt. Cách đơn giản nhất để giải quyết đó là add thêm phần cứng.

**SMALLER_PGP_NUM**

Một hoặc nhiều pool có số pgp_num nhỏ hơn pg_num. Điều này có nghĩa rằng PG count đã tăng trong khi placement behaviour thì không. Có thể được giải quyết bằng cách thay đổi để 2 giá trị này bằng nhau

`ceph osd pool set <pool> pgp_num <pg-num-value>`


**POOL_APP_NOT_ENABLED**

Pool đã tồn tại, có dữ liệu nhưng chưa được sử dụng bởi bất cứ một ứng dụng nào. Ta có thể giải quyết bằng cách đánh dấu rằng pool này đang được sử dụng bởi một ứng dụng nào đó ví dụ rbd

`rbd pool init <poolname>`

**POOL_FULL**

Pool đã đạt ngưỡng `mon_pool_quota_crit_threshold`

Để thay đổi pool quota

```
ceph osd pool set-quota <pool> max_bytes <bytes>
ceph osd pool set-quota <pool> max_objects <objects>
```

**POOL_NEAR_FULL**

Pool đã đạt ngưỡng `mon_pool_quota_warn_threshold`

**SLOW_OPS**

Một hoặc nhiều OSD  request đang mất nhiều time để xử lí. Nguyên nhân có thể là lượng tải cao, tốc độ ổ cứng chậm hoặc bug ứng dụng. Các request queue trên osd có thể được query với command bên dưới

`ceph daemon osd.<id> ops`

Tóm tắt các request chậm nhất gần đây có thể được hiển thị bởi câu lệnh

`ceph daemon osd.<id> dump_historic_ops`

Địa chỉ của OSD

`ceph osd find osd.<id>`

**PG_NOT_SCRUBBED**

Một hoặc nhiều PG đang chưa được scrubb. PG thường được scrubb mỗi `mon_scrub_interval` giây, và thông báo này sẽ được hiển thị nếu như sau `mon_warn_not_scrubbed` mà scrubb chưa được thực hiện.

Scrubb chỉ được thực hiện trên các clean pg. Bạn có thể dùng câu lệnh sau để bắt đầu scrubb trên clean pg.

`ceph pg scrub <pgid>`

**PG_NOT_DEEP_SCRUBBED**

Tương tự như trên nhưng là deep scrub

`ceph pg deep-scrub <pgid>`

## 4. MONITORING A CLUSTER

**Sử dụng cmd**

Bạn có thể tương tác với ceph dưới dạng interactive mode bằng cách gõ `ceph`

```
ceph
ceph> health
ceph> status
ceph> quorum_status
ceph> mon_status
```

Nếu bạn muốn khai báo folder không phải là mặc định

`ceph -c /path/to/conf -k /path/to/keyring health`

**Kiểm tra trạng thái cluster**

`ceph status`

hoặc

`ceph -s`

**Theo dõi cluster**

Sử dụng câu lệnh

`ceph -w` để in ra status và log chung của cluster.

**Theo dõi health check**

Ceph liên tục check health status. Khi health check fail, nó sẽ được phản ánh thông qua output của `ceph status`.

Ví dụ khi 1 OSD down thì nó sẽ được hiển thị như sau

```
health: HEALTH_WARN
        1 osds down
        Degraded data redundancy: 21/63 objects degraded (33.333%), 16 pgs unclean, 16 pgs degraded
```

Cùng lúc đó, log của nó cũng sẽ thông báo

```
2017-07-25 10:08:58.265945 mon.a mon.0 172.21.9.34:6789/0 91 : cluster [WRN] Health check failed: 1 osds down (OSD_DOWN)
2017-07-25 10:09:01.302624 mon.a mon.0 172.21.9.34:6789/0 94 : cluster [WRN] Health check failed: Degraded data redundancy: 21/63 objects degraded (33.333%), 16 pgs unclean, 16 pgs degraded (PG_DEGRADED)
```

**Check mức độ sử dụng**

`ceph df`

Section `GLOBAL` sẽ có các thông số sau

- SIZE: The overall storage capacity of the cluster.
- AVAIL: The amount of free space available in the cluster.
- RAW USED: The amount of raw storage used.
- % RAW USED: The percentage of raw storage used. Use this number in conjunction with the full ratio and near full ratio to ensure that you are not reaching your cluster’s capacity.

Tiếp theo là section `POOL`. Output của section này ko bảo gồm replicas, clones hoặc snapshot

- NAME: The name of the pool.
- ID: The pool ID.
- USED: The notional amount of data stored in kilobytes, unless the number appends M for megabytes or G for gigabytes.
- %USED: The notional percentage of storage used per pool.
- MAX AVAIL: An estimate of the notional amount of data that can be written to this pool.
- OBJECTS: The notional number of objects stored per pool.

**Check trạng thái osd**

`ceph osd stat`

hoặc

`ceph osd dump`

hoặc

`ceph osd tree`

**Check trạng thái mon**

`ceph mon stat`

hoặc

`ceph mon dump`

Để check quorum status, sử dung câu lệnh sau

`ceph quorum_status`

**PG Set**

Để lấy danh sách pg

`ceph pg dump`

Xem danh sách dưới dạng json

`ceph pg dump -o {filename} --format=json`
Để xem osd nào đang chứa pg này

`ceph pg map <pg_id>`

Kết quả của câu lệnh trên sẽ hiển thị osdmap epoch (eNNN), placement group number ({pg-num}), OSDs trong Up Set (up[]), và the OSDs trong acting set (acting[]).

`osdmap eNNN pg {raw-pg-num} ({pg-num}) -> up [0,1,2] acting [0,1,2]`

**Peering**

Trước khi bạn có thể ghi dữ liệu vào pg, nó buộc phải ở trạng thái active và nên ở trạng thái clean. Để xem trạng thái của pg, primary osd của pg sẽ tiến hành bắt cặp với secondary và tertiary OSD để thiết lập sự nhât quán về trạng thái của pg.

<img src="https://i.imgur.com/d1iWE6m.png">

**PLACEMENT GROUP STATES**

Để xem trạng thái của các pg

`ceph pg stat`

Câu lệnh trên sẽ hiển thị tổng số pg, có bao nhiêu pg đang ở trạng thái active+clean và tổng số dữ liệu lưu trữ.

PG ID bao gồm pool number theo sau bởi dấu chấm kèm với pg ID ở dạng hexa.

`{pool-num}.{pg-id}`

- CREATING

Khi bạn create pool, nó sẽ tạo ra số pg theo số mà bạn khai báo. Khi tạo xong, các OSDs nằm trong pg acting set sẽ peer với nhau. Một khi đã peer thì trạng thái sẽ chuyển qua active+clean và lúc này có thể lưu dữ liệu.

- PEERING

Khi ceph peering pg, các osd chứa các mảnh nhân bản của pg sẽ được thống nhất về trạng thái của dữ liệu mà metadata được lưu trong pg. Tuy vậy, việc hoàn thành peering không có nghĩa rằng mỗi một mảnh nhân bản đều có version cuối của bản chính.

- ACTIVE

Khi hoàn thành peering thì pg sẽ chuyển sang active, lúc này đã sẵn sàng để ghi dữ liệu.

- CLEAN

Khi ở trạng thái này, primary OSD và các replica OSD đã được peer với nhau.

- DEGRADED

Khi dữ liệu được người dùng ghi xuống primary osd, thì osd đó sẽ có trách nhiệm ghi ra các bản sao lưu. Sau khi mà các object được osd lưu xuống, thì placement group sẽ giữ trạng thái `degraded` cho tới khi nào primary osd nhận được trường thông tin từ các osd khác rằng dữ liệu nhân bản đã được tạo thành công.

Nếu một osd down và tình trạng `degraded` được giữ nguyên thì ceph sẽ đánh dấu là node đó out khỏi cluster và remap lại các dữ liệu từ osd đó tới các osd khác. Khoảng thời gian giữa việc đánh dấu là down và out được quyết định bởi thông số `mon osd down out interval`, mặc định là 600s. Khi mà ceph không thể tìm thấy object mà nó nghĩ là ở trong pg thì pg đó cũng sẽ bị rơi vào trạng thái degraded.

- RECOVERING

Khi một OSD down rồi up trở lại, các dữ liệu trong pg sẽ phải được update để quay trở lại osd. Quá trình này gọi là recovering. Ceph có một số các tùy chọn cho việc này. `osd recovery delay start` cho phép OSD restart, re-peer hoặc thậm chí là xử lí một số request trước khi quá trình recovery diễn ra. `osd recovery thread timeout` sẽ thiếp lập thread timeout bởi rất có khả năng nhiều osd down, restart, re-peer tại một thời điểm. `osd recovery max active` giới hạn số recovery request của một osd. `osd recovery max chunk` sẽ giới hạn dung lượng dữ liệu để tránh ảnh hưởng tới network.

- BACK FILLING

Khi một osd gia nhập vào cluster, CRUSH sẽ reassign pg từ các osd đã có tới osd mới. Quá trình này được gọi là back filling, trong suốt quá trình này, sẽ có khá nhiều các trạng thái ví dụ như: backfill_wait, backfilling, backfill_toofull và incomplete.

Ceph cũng có một số các option cho state này, `osd_max_backfills`: số lần backfill nhiều nhất có thể tại một thời điểm, `backfill full ratio` sẽ cho phép OSd từ chối backfill request khi mà osd đó full ratio. `osd backfill retry interval` sẽ thiết lập thời gian retry sau khi mà osd refuse request đó.

- REMAPPED

Quá trình chuyển đổi từ acting set cũ sang acting set mới.

- STALE

Khi mà primary osd của pg không thể reporrt trạng thái của nó tới cho mon hoặc các osd khác báo rằng primary osd đã down thì ceph sẽ đưa pg vào trạng thái `stale`. Khi mới bắt đầu cluster thì state đa phần sẽ là stale cho tới khi quá trình peering hoàn thành.

**Xác định PG có vấn đề**

Ở một số trường hợp, ceph sẽ không thể tự giải quyết vấn đề khi pg gặp trục trặc. Các tình trạng này như sau:

- Unclean: Placement groups contain objects that are not replicated the desired number of times. They should be recovering.
- Inactive: Placement groups cannot process reads or writes because they are waiting for an OSD with the most up-to-date data to come back up.
- Stale: Placement groups are in an unknown state, because the OSDs that host them have not reported to the monitor cluster in a while (configured by mon osd report timeout).

Để xác định pg gặp vấn đề

`ceph pg dump_stuck [unclean|inactive|stale|undersized|degraded]`

**Tìm kiếm vị tri object**

Để lưu object vào Ceph, client sẽ phải khai báo tên object và pool, tương tự như thế khi muốn tìm kiếm vị trí của object này.

`ceph osd map {poolname} {object-name} [namespace]`
