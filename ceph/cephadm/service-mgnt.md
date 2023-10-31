# SERVICE MANAGEMENT

## 1. Service status

- Show danh sách service

`ceph orch ls [--service_type type] [--service_name name] [--export] [--format f] [--refresh]`

- Show trạng thái service

`ceph orch ls --service_type type --service_name <name> [--refresh]`

- Export service

`ceph orch ls --export`

Service sẽ được export dưới dạng file yaml và file này cũng có thể được dùng để config bằng command `ceph orch apply -i`

## 2. Daemon status

- List toàn bộ daemon

`ceph orch ps [--hostname host] [--daemon_type type] [--service_name name] [--daemon_id id] [--format f] [--refresh]`

- Lấy trạng thái của 1 daemon

`ceph orch ps --daemon_type osd --daemon_id 0`

## 3. Service

- Có thể set param cho service 

`ceph config set <service-name> <param> <value>`

## 4. Daemon placement

Lưu ý cái này, vì orch deploy daemon thì nó cần biết cần deploy vào đâu và số lượng nhiu.
Nên sử dụng yaml bởi vì câu lệnh `ceph orch apply <service-name>` sẽ thay thế câu lệnh trước đó.

Ví dụ nếu bạn chạy như sau:

```
ceph orch apply mon host1
ceph orch apply mon host2
ceph orch apply mon host3
```

Cuối cùng thì chỉ 1 mình host 3 có mon. Đó là bởi nó được chạy cuối cùng.
Để tránh việc này, ta có thể chạy như sau

`ceph orch apply mon "host1,host2,host3"`

Một cách khác là dùng file yaml

```
service_type: mon
placement:
  hosts:
   - host1
   - host2
   - host3
```

`ceph orch apply -i file.yaml`

Hoặc chỉ định rõ ràng

`ceph orch apply prometheus --placement="host1 host2 host3"`

hoặc yaml

```
service_type: prometheus
placement:
  hosts:
    - host1
    - host2
    - host3
```

### Placement qua label

Ta có thể đặt label cho từng host. Sau đó thì chỉ định placement. Ví dụ:

`ceph orch apply prometheus --placement="label:mylabel"`

```
service_type: prometheus
placement:
  label: "mylabel"
```

### Hoặc placement bằng matching chính xác

`ceph orch apply prometheus --placement='myhost[1-3]'`

```
service_type: prometheus
placement:
  host_pattern: "myhost[1-3]"
```

All host

`ceph orch apply node-exporter --placement='*'`

```
service_type: node-exporter
placement:
  host_pattern: "*"
```

### Thay đổi số lượng daemon

`ceph orch apply prometheus --placement=3`

Hoặc

`ceph orch apply prometheus --placement="3 host1 host2"`

```
service_type: prometheus
placement:
  count: 2
  hosts:
    - host1
    - host2
    - host3
```

### Cùng trên 1 host

```
service_type: rgw
placement:
  label: rgw
  count_per_host: 2
```

## Thuật toán

Cephadm lưu danh sách service cũng như vị trí của chúng. Nó sẽ liên tục so sánh giữa thực tế và cái mà nó đang lưu để xóa bỏ hoặc tạo thêm daemon nếu cần thiết. Nó sẽ thực hiện các việc sau:

- Đầu tiên, nó có 1 list các server, nó đương nhiên cũng sẽ có danh sách hostname, trường hợp nó ko thấy hostname, nó sẽ tìm label, trường hợp ko có label, nó sẽ chọn dựa trên host pattern, trường hợp ko có host partern nó sẽ chọn all.

## Extra arg

Limit số lượng cpu

```
service_type: mon
service_name: mon
placement:
  hosts:
    - host1
    - host2
    - host3
extra_container_args:
  - "--cpus=2"
```

Mount thêm file

```
extra_container_args:
  - "-v"
  - "/absolute/file/path/on/host:/absolute/file/path/in/container"
```

```
extra_container_args:
  - "-v"
  - "/opt/ceph_cert/host.cert:/etc/grafana/certs/cert_file:ro"
```

## Custom config file

```
service_type: grafana
service_name: grafana
custom_configs:
  - mount_path: /etc/example.conf
    content: |
      setting1 = value1
      setting2 = value2
  - mount_path: /usr/share/grafana/example.cert
    content: |
      -----BEGIN PRIVATE KEY-----
      V2VyIGRhcyBsaWVzdCBpc3QgZG9vZi4gTG9yZW0gaXBzdW0gZG9sb3Igc2l0IGFt
      ZXQsIGNvbnNldGV0dXIgc2FkaXBzY2luZyBlbGl0ciwgc2VkIGRpYW0gbm9udW15
      IGVpcm1vZCB0ZW1wb3IgaW52aWR1bnQgdXQgbGFib3JlIGV0IGRvbG9yZSBtYWdu
      YSBhbGlxdXlhbSBlcmF0LCBzZWQgZGlhbSB2b2x1cHR1YS4gQXQgdmVybyBlb3Mg
      ZXQgYWNjdXNhbSBldCBqdXN0byBkdW8=
      -----END PRIVATE KEY-----
      -----BEGIN CERTIFICATE-----
      V2VyIGRhcyBsaWVzdCBpc3QgZG9vZi4gTG9yZW0gaXBzdW0gZG9sb3Igc2l0IGFt
      ZXQsIGNvbnNldGV0dXIgc2FkaXBzY2luZyBlbGl0ciwgc2VkIGRpYW0gbm9udW15
      IGVpcm1vZCB0ZW1wb3IgaW52aWR1bnQgdXQgbGFib3JlIGV0IGRvbG9yZSBtYWdu
      YSBhbGlxdXlhbSBlcmF0LCBzZWQgZGlhbSB2b2x1cHR1YS4gQXQgdmVybyBlb3Mg
      ZXQgYWNjdXNhbSBldCBqdXN0byBkdW8=
      -----END CERTIFICATE-----
```

Để có thể chỉnh config, cần redeploy lại daemon

`ceph orch redeploy <service-name>`

## Remove service

`ceph orch rm <service-name>`

nó sẽ remove toàn bộ daemon của service.

## Hủy cơ chế auto deploy daemon

```
service_type: mgr
unmanaged: true
placement:
  label: mgr
```

`ceph orch set-unmanaged mon`

Để set lại

`ceph orch set-managed mon`

Sau khi disable, cephadm sẽ không deploy thêm mon nào nữa kể cả là khi placement match host mới thêm.

Lưu ý là `osd` service được dùng để track osd nên nó sẽ luôn là `unmanaged`.

## Deploy daemon bằng tay

Đầu tiên sẽ set unmanaged. Sau đó deploy mon bằng tay bằng câu lệnh sau:

`ceph orch daemon add <daemon-type>  --placement=<placement spec>`

## Remove daemon bằng tay

`ceph orch daemon rm <daemon name>... [--force]`

