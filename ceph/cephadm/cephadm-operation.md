# CEPHADM OPERATIONS

## Xem log messages

`ceph -W cephadm`

Mặc định nó sẽ là info level. Để thay đổi sang debug.

```
ceph config set mgr mgr/cephadm/log_to_cluster_level debug
ceph -W cephadm --watch-debug
```

Xem log gần nhất

`ceph log last cephadm`

## Thay đổi trạng thái daemon

```
ceph orch daemon stop <name>
ceph orch daemon start <name>
ceph orch daemon restart <name>
```

Hoặc thay đổi tất cả daemon

```
ceph orch stop <name>
ceph orch start <name>
ceph orch restart <name>
```

### Redeploy hoặc reconfigure daemon

`ceph orch daemon redeploy <name> [--image <image>]`

`ceph orch daemon reconfig <name>`

### Rotate daemon authen key

`ceph orch daemon rotate-key <name>`

## Daemon log

mặc định thì ceph vẫn sẽ ghi log ra `/var/log/ceph`

Access qua journald

```
journalctl -u ceph-5c5a50ae-272a-455d-99e9-32c6a013e694@mon.foo
```

Để ghi log ra file, cần config như sau

```
ceph config set global log_to_file true
ceph config set global mon_cluster_log_to_file true
```

Disable ghi log ra journald 

```
ceph config set global log_to_stderr false
ceph config set global mon_cluster_log_to_stderr false
ceph config set global log_to_journald false
ceph config set global mon_cluster_log_to_journald false
```

Mặc định thì cephadm đã set rotation cho log nhưng có thể thay đổi tại `/etc/logrotate.d/ceph.<cluster-fsid>`

## Data location

- `/var/log/ceph/<cluster-fsid>` chứa log, tuy nhiên nó sẽ không có cho đến khi thay đổi config
- `/var/lib/ceph/<cluster-fsid>` chứa toàn bộ daemon data
- `/var/lib/ceph/<cluster-fsid>/<daemon-name` toàn bộ data của 1 daemon chỉ định
- `/var/lib/ceph/<cluster-fsid>/crash` chứa data về crash report.
- `/var/lib/ceph/<cluster-fsid>/removed` chứa data của daemon đã bị remove.

## Cephadm operation

### Pause

Toàn bộ các tiến trình chạy ngầm của cephadm sẽ bị dừng lại `ceph orch pause`

Để resume

`ceph orch resume`

### CEPHADM_STRAY_HOST

Tức là đang có 1 hoặc nhiều host có daemon chạy nhưng lại không được quản lý bở cephadm.

Để có thể thêm host đó vào

`ceph orch host add *<hostname>*`

Hoặc bạn có thể truy cập host đó và đảm bảo rằng không có service nào đang chạy.

Warning này có thể được disable

`ceph config set mgr mgr/cephadm/warn_on_stray_hosts false`

### CEPHADM_STRAY_DAEMON

Một hoặc nhiều daemon đang chạy và không được manage bởi cephadm

Cảnh báo này cũng có thể được disable

`ceph config set mgr mgr/cephadm/warn_on_stray_daemons false`

### CEPHADM_HOST_CHECK_FAILED

Khi cephadm không thể host check (1 là nó có thể access và excute ở host, 2 là nó thỏa mãn các điều kiện cơ bản như có thể chạy container và sync time). 

Có thể run check bằng tay

`ceph cephadm check-host *<hostname>*`

hoặc remove host có vấn đề

`ceph orch host rm *<hostname>*`

Cảnh báo này cũng có thể disable

`ceph config set mgr mgr/cephadm/warn_on_failed_host_check false`

### Config check

Cephadm sẽ check host để check về os, nic,...
Config check là optional feature, để enable

`ceph config set mgr mgr/cephadm/config_checks_enabled true`

## Client key và config

Cephadm có thể distribute key và file ceph.conf. Ngoài `/etc/ceph` nó còn lưu ở `/var/lib/ceph/<fsid>/config`. Mặc định thì nó sẽ distribute tới tất cả node có label `_admin`.

- List keyring

`ceph orch client-keyring ls`

- Đưa keyring vào quản lý

`ceph orch client-keyring set <entity> <placement> [--mode=<mode>] [--owner=<uid>.<gid>] [--path=<path>]`
