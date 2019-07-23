# HTTP FRONTENDS, POOL PLACEMENT, STORAGE CLASSES, POOLS

## 1. HTTP FRONTENDS

### 1.1 Beast

Mới có kể từ bản mimic. Beast sử dụng Boost.

Các option:

- `port` và `ssl_port` : Set listening port cho ipv4 và ipv6. Mặc định là 80.
- `endpoint` và `ssl_endpoint` : Set listening address.
- `ssl_certificate` : Đường dẫn tới SSL certificate file
- `ssl_private_key` : Đường dẫn tới private key file.

### 1.2 Civetweb

Sử dụng Civetweb library, là một nhánh fork từ Mongoose.

Các option:

- `port` : Mặc định là 7480
- `num_threads` : Số lượng thread được tạo bởi Civetweb để xử lý các http connection.
- `request_timeout_ms` : Thời gian tính theo milisecond để Civetweb đợi dữ liệu tiếp theo trước khi từ bỏ.
- `ssl_certificate`
- `access_log_file` : Đường dẫn tới file chứa access log
- `error_log_file` : Đường dẫn tới file chứa error log

Ví dụ :

```
[client.rgw.gateway-node1]
rgw_frontends = civetweb request_timeout_ms=30000 error_log_file=/var/log/radosgw/civetweb.error.log access_log_file=/var/log/radosgw/civetweb.access.log
```

## 2. POOL PLACEMENT

### 2.1 PLACEMENT TARGETS

Placement targets kiểm soát pool nào sẽ được dùng để lưu trữ các bucket cụ thể. Vị trí đặt bucket được chọn ở thời điểm khởi tạo và không thể chỉnh sửa. Dùng câu lệnh sau để hiển thị các rule

`radosgw-admin bucket stats`

Cấu hình zonegroup  chứa danh sách các placement target với target ban đầu là `default-placement`. Cấu hình zone sau đó sẽ map từng zonegroup placement target vào storage của nó. Thông tin về zone placement sẽ bao gồm tên `index_pool` cho bucket index, tên `data_extra_pool` cho metadata và tên `data_pool` cho mỗi một storage class.

### 2.2 STORAGE CLASSES

Mới có ở bản Nautilus. Storage class được dùng để customize vị trí của object data, S3 bucket lifecycle rule có thể tự động hóa quá trình chuyển đổi object giữa các storage class.

Storage class được định nghĩa trong quan hệ với placement target. Mỗi một zonegroup placement target sẽ lên danh sách những storage class đang available cùng với 1 class ban đầu là `standard`.

### 2.3 ZONEGROUP/ZONE CONFIGURATION

Cấu hình placement được thực hiện với câu lệnh `radosgw-admin`

Để lấy cấu hình

`radosgw-admin zonegroup get`

Nếu bạn chưa từng tạo các cấu hình multisite thì sẽ có zone và zonegroup mặc định được tạo cho bạn và các thay đổi liên quan tới zone/zonegroup  sẽ không có hiệu lực nếu bạn không restart Ceph radosgw.

**ADDING A PLACEMENT TARGET**

Để tạo placement target mới với tên là `temporary`, đầu tiên ta sẽ thêm nó vào zonegroup

```
$ radosgw-admin zonegroup placement add \
      --rgw-zonegroup default \
      --placement-id temporary
```

Sau đó cung cấp info về zone placement mà nó target tới

```
$ radosgw-admin zone placement add \
      --rgw-zone default \
      --placement-id temporary \
      --data-pool default.rgw.temporary.data \
      --index-pool default.rgw.temporary.index \
      --data-extra-pool default.rgw.temporary.non-ec
```

### 2.4 CUSTOMIZING PLACEMENT

**DEFAULT PLACEMENT**

Mặc định thì 1 bucket mới sẽ sử dụng `default_placement` target của zonegroup. Zonegroup này có thể được thay đổi với câu lệnh

```
$ radosgw-admin zonegroup placement default \
      --rgw-zonegroup default \
      --placement-id new-placement
```

**USER PLACEMENT**

Ceph object gateway có thể override placement target mặc định bằng các cấu hình non-empty trường `default_placement` trong thông tin người dùng.

```
$ radosgw-admin user info --uid testid
{
    ...
    "default_placement": "",
    "default_storage_class": "",
    "placement_tags": [],
    ...
}
```

Nếu `placement target` của zonegroup chứa bất cứ một tag nào thì người dùng sẽ ko thể tạo bucket với placement target đó cho tới khi user info đó chứa ít nhất 1 matching placement tags. Cái này có thể được dùng để giới hạn truy cập tới từng loại storage.

Ta không thể chỉnh bằng tay vì thể phải chỉnh thông qua file json

```
$ radosgw-admin metadata get user:<user-id> > user.json
$ vi user.json
$ radosgw-admin metadata put user:<user-id> < user.json
```

## 3. Config pool

Ceph object gateway sử dụng một vài pool. Single name là `default` được tạo tự động với pool name bắt đầu bằng `default.rgw`

Khi radosgw hoạt động lần đầu trên zone pool ko tồn tại, nó sẽ tạo pool với các thông số về số pg mặc định. Các thông số này khá phù hợp với một số  pool tuy nhiên thì đối với một số pool đặc thù ta vẫn cần phải cấu hình lại.
