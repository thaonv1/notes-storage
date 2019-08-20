# Một số ghi chép với Ceph RGW

## 1. GC trong Ceph RGW

Khi người dùng thực hiện xóa object, các object này sẽ được xóa khỏi bucket index pool và người dùng sẽ không thấy nó nữa, tuy nhiên Ceph sẽ chỉ dọn dẹp không gian lưu trữ được dùng cho chúng ở bên dưới sau 1 khoảng thời gian nhất định. Quá trình này đuược gọi là Garbage Collection (Thu gom rác) or GC.

Thông thường thì GC thường xảy ra trong 3 trường hợp sau:

- Người dùng thực hiện việc xóa dữ liệu và dung lượng được chiếm bởi các object handled bởi GC.
- Người dùng overwrite object, lúc này các object cũ sẽ chiếm dụng không gian lưu trữ và nó cũng được handle bởi GC.
Ở đây có một lưu ý, nếu người dùng upload lại file với tên trùng với một trong số các object đã có, nó sẽ được overwirte và phần cũ, như ta đã biết, được xử lí bởi GC. Để tránh quá trình này, ta có thể suử dụng versioning.
- Người dùng thực hiện việc upload, một số shadow file được tạo ra trong quá trình này kèm theo một số dữ liệu được gen ra cũng sẽ được xử lý bởi gc.

Để view toàn bộ các objects ở trong queue đang được chờ để gc

`# radosgw-admin gc list`

GC là hoạt động ngầm có thể được chạy liên tục hoặc chạy trong lúc load thấp phụ thuộc vào configure của Ceph Admin. Mặc định thì GC sẽ được chạy liên tục.

Lưu ý rằng có một số trường hợp vượt quá tầm kiểm soát của GC, đặc biệt là đối với các trường hợp xóa 1 số lượng lớn object ngay sau khi upload. Lúc này thì admin có thể config để tăng priority của gc dựa vào những tham số sau.

`rgw_gc_obj_min_wait`: Thời gian tối thiểu theo giây trước khi dọn dẹp dữ liệu. Mặc định thì nó là 2h, đối với khối lượng lớn workload. cấu hình này có thể lấy đi rất nhiều dung lượng hoặc để lại một số lượng lớn các objects đã xóa chờ dọn dẹp. Để tránh điều này, xem xet việc giám nó xuống.

`rgw_gc_processor_period`: Cấu hình của gc cycle runtime. Nghĩa là thời gian giữa các lần start các GC threads. Nếu gc mất nhiều thời gian hơn thông số này, ceph sẽ không chờ để chạy tiếp GC cycle một lần nữa.

`rgw_gc_max_concurrent_io ` : Cấu hình này quy định số lượng IO operations tối đa mà GC thread có thể dùng khi mà dọn dẹp dữ liệu. Trong các trường hợp khối lượng lớn thì nên xem xet tăng.

`rgw_gc_max_trim_chunk` : Cấy hình này define số lượng max keys để  remove từ gc log trong 1 single operation. Có thể tăng nó lên nếu muốn dọn dẹp nhiều objects hơn trong 1 lần chạy GC.


## Phân tích quá trình GC

GC process overview

<img src="https://i.imgur.com/ZvXFuNt.png">

Sau khi xóa object, dữ kiệu rác sẽ được đánh dấu trong pool `.rgw.gc`

Số lượng công việc xóa đồng thời được xác định bởi tham số `rgw_gc_max_objs`. Tham số này tương ứng với số lượng object trong resource pool `.rgw.gc`

Sau khi mà dữ liệu được xóa, thời gian mà thùng rác giữ lại dữ liệu được xác định bởi tham số `rgw_gc_obj_min_wait`

Tiếp đó `rgw_gc_processor_period` xác định bao lâu thì quá trình gc được rotate.

`rgw_gc_processor_max_time` xác định thời gian tối đa cuả mỗi một gc, tránh việc nó hoạt động quá lâu dẫn tới hiệu năng hệ thống giảm.

Một vài tips để tuning :

- Xem xét việc tăng `rgw_gc_max_objs` nếu business của bạn sẽ cần nhiều GC operations.

- Xem xét tải của storage device, nếu thiết bị tốc độ thấp và load cao thì có thể tăng thông số `Rgw_gc_processor_max_time` lên.

- Xem xét giảm `rgw_gc_obj_min_wait` (mặc định 2h) nếu muốn giam thời gian lấy lại dung lượng storage.

- `Rgw_gc_processor_period` Nếu mà số lượng entries của một gc nhỏ, bạn có thể giảm thông số này xuống.

## Thực hành đối với gc

Cấu hình gc mặc định

```
rgw_enable_gc_threads = true
rgw_gc_max_concurrent_io = 10
rgw_gc_max_objs = 32
rgw_gc_max_trim_chunk = 16
rgw_gc_obj_min_wait = 7200
rgw_gc_processor_max_time = 3600
rgw_gc_processor_period = 3600
```

Ta có thể xem các object đã đến hạn

`radosgw-admin gc list`

Hoặc cả những cái chưa đến hạn

`radosgw-admin gc list --include-all`

Để thực hiện quá trình gc bằng tay

`radosgw-admin gc process`

Thực hiện quá trình gc bao gồm cả những dữ liệu chưa hết hạn

`radosgw-admin gc process --include-all`

Khi xóa bucket, ta có thể bypass qua quá trình gc bằng option --bypass-gc

`radosgw-admin bucket rm --bucket=test --bypass-gc --purge-data`
