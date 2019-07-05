# Scrubs and Log

## 1. Scrubs

Data corruption ít khi xảy ra nhưng nó vẫn là một mối lo ngại. Ceph có một phương thức để cảnh báo cho người dùng khi trường hợp này xảy ra: scrubs. Ý tưởng là check mỗi mảnh dữ liệu sao chép để đảm bảo rằng chúng thống nhất với nhau.  Khi mà PG được quét, primary OSD của PG đó  tính toán checksum của dữ liệu và yêu cầu các OSDs khác trong cùng PG đó đặt giống nó. Sau đó checksum sẽ được so sánh, nếu chúng đồng ý, mọi thứ đều ổn. Nếu chúng không đồng ý, Ceph sẽ đưa vào trạng thái inconsistent.

Ceph scrubs có 2 kiểu là: light và deep.

Light scrubs rất nhẹ, nó được thực hiện cho tất cả PG hàng ngày. Nó chỉ check và so sánh metadata mà không làm ảnh hưởng tới dữ liệu.

Trong khi đó, deep scrubs thì đọc và checksum của toàn bộ PG objects payload data. Bởi vì mỗi một mảnh nhân bản của PG có thể chứa tới cả GB dữ liệu, nên nó sẽ yêu cầu nhiều resource hơn một chút. Ngoài ra, nó cũng mất nhiều time để hoàn thành hơn, nên thường thì nó sẽ chạy theo chu kì, mặc định là 1 tuần 1 lần.

Có thể thay đổi giá trị này trong file ceph.conf `osd_deep_scrub_interval` nếu thấy 1 tuần là hơi ngắn và có thể dẫn tới nhiều kết quả không mong muốn. Ta cũng có option cho phép tắt scrub trong quá trình recovery dữ liệu. `osd_deep_scrub_interval` nếu được set `false`.

Scrubs cũng có thể được thiết lập qua injection trong trường hợp không muốn restart lại các daemons.

`ceph tell osd.* injectargs '--osd_deep_scrub_interval 2419200'`

Lưu ý rằng ta cũng có thể tắt tạm thời scrubs đi.

```
# ceph osd set noscrub
set noscrub
# ceph osd set nodeep-scrub
set nodeep-scrub

# ceph osd unset noscrub
# ceph osd unset nodeep-scrub
```

Dưới đây là ví dụ về inconsistent PG.

```
Dec 15 10:55:44 csx-ceph1-020 kernel: end_request: I/O error, dev
sdh, sector 1996791104
Dec 15 10:55:44 csx-ceph1-020 kernel: end_request: I/O error, dev
sdh, sector 3936989616
Dec 15 10:55:44 csx-ceph1-020 kernel: end_request: I/O error, dev
sdh, sector 4001236872
Dec 15 13:00:18 csx-ceph1-020 kernel: XFS (sdh1): xfs_log_force:
error 5 returned.
Dec 15 13:00:48 csx-ceph1-020 kernel: XFS (sdh1): xfs_log_force:
error 5 returned.
```

Log của Ceph cũng báo rằng deep scrubbing đã phát hiện ra dữ liệu bị ảnh hưởng

```
2015-12-19 09:10:30.403351 osd.121 10.203.1.22:6815/3987 10429 :
[ERR] 20.376b shard 121: soid
a0c2f76b/rbd_data.5134a9222632125.0000000000000001/head//20
candidate had a read error
2015-12-19 09:10:33.224777 osd.121 10.203.1.22:6815/3987 10430 :
[ERR] 20.376b deep-scrub 0 missing, 1 inconsistent objects
2015-12-19 09:10:33.224834 osd.121 10.203.1.22:6815/3987 10431 :
[ERR] 20.376b deep-scrub 1 errors
```

Ngay lập tức thì nó cũng ảnh hưởng tới output của ceph health và ceph status

```
root@csx-a-ceph1-001:~# ceph status
cluster ab84e9c8-e141-4f41-aa3f-bfe66707f388
health HEALTH_ERR 1 pgs inconsistent; 1 scrub errors
osdmap e46754: 416 osds: 416 up, 416 in
pgmap v7734947: 59416 pgs: 59409 active+clean, 1
active+clean+inconsistent, 6 active+clean+scrubbing+deep
root@csx-a-ceph1-001:~# ceph health detail
HEALTH_ERR 1 pgs inconsistent; 1 scrub errors
pg 20.376b is active+clean+inconsistent, acting [11,38,121]
1 scrub errors
```

Ta có thể thấy log báo osd.121 là nơi có inconsistent PG, ta có thể remove osd from service hoặc sửa chữa bằng tay

`ceph pg repair 20.376b`

## 2. Logs

Ceph có thể được cấu hình để đẩy log trực tiếp thông qua syslog hoặc rsyslog service, mặc định thì nó ghi ra local file. Tại đây, các file log được quản lí bởi logrotate trong linux. Đây là cấu hình rotate mặc định của Ceph bản mimic.

```
[root@ceph1 ~]# cat /etc/logrotate.d/ceph
/var/log/ceph/*.log {
    rotate 7
    daily
    compress
    sharedscripts
    postrotate
        killall -q -1 ceph-mon ceph-mgr ceph-mds ceph-osd ceph-fuse radosgw || pkill -1 -x "ceph-mon|ceph-mgr|ceph-mds|ceph-osd|ceph-fuse|radosgw" || true
    endscript
    missingok
    notifempty
    su root ceph
}
```

Như vậy mặc định là 7 ngày, ta có thể tăng lên tuy nhiên cần lưu ý về dung lượng sẵn có của ổ cứng.

### 2.1 MON Logs

Mặc định, MONs ghi log tại `/var/log/ceph/ceph-mon.hostname.log`. Ở mỗi MON server thì đều có global cluster log được ghi tại `/var/log/ceph/ceph.log`.

### 2.2 OSD logs

OSD log cũng nằm trong thư mục `/var/log/ceph`

### 2.3 Debug levels

```
--- logging levels ---
0/ 5 none
0/ 0 lockdep
0/ 0 context
```

Ceph cho phép người dùng control level của log. Các level này là tách biệt giữa các subsystem. Ngoài ra thì các subsystem này cũng có level tách biệt giữa thông tin được giữ trong memory và message trong log file. Số càng cao thì càng tăng mức độ log.

```
[global]
debug ms = 1
[mon]
debug mon = 15/20
debug paxos = 20
debug auth = 20
```

Số đầu tiên là cho output log, số thứ 2 là cho memory. 2 số này cách nhau bở 1 dấu gạch chéo, nếu chỉ khai báo một thì ceph sẽ apply cho cả hai.

Ta có thể sử dụng admin socket hoặc injections nếu không muốn restart lại toàn bộ MONs daemons. Lưu ý rằng ta vẫn sẽ thay đổi ceph.conf để phòng trường hợp các daemons bị restart.

`ceph tell osd.666 injectargs '--debug-filestore 0/0 --debug-osd 0/0'debug_filestore`

Trường hợp file log quá lớn và không còn dung lượng để compress, ta có thể xóa và khởi tạo lại mà không cần restart OSD daemon.

```
# rm /var/log/ceph/ceph-osd.666.log
# ceph daemon osd.666 log reopen
```

Để apply cho toàn bộ các osd thông qua injection

```
ceph tell osd.* injectargs '--debug-filestore 0/0 --debug-osd 0/0'
```
