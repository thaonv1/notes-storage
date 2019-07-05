# Các thông tin về cấu hình trong Ceph

### 1. Cluster naming and configuration

File cấu hình định nghĩa các Ceph component cần được startup và tìm kiếm lẫn nhau. Rất nhiều người nghĩ nó là `/etc/ceph/ceph.conf` nhưng thực tế các tên khác là hoàn toàn có thể. Thư mục mặc định là `/etc/ceph` còn tên file thì lại chính là tên của cluster, mặc định là ceph.

Rất nhiều ceph command mặc định coi cluster name là ceph, chúng ta có thể thêm tùy chọn `--cluster cephelmerman` để chỉ định tên.

Ceph sẽ cố gắng start daemon cho bất kì file config nào theo dạng `/etc/ceph/*.conf` trong thư mục `/etc/ceph`.

### 2. The Ceph configuration file

File cấu hình của ceph theo dạng ini format. Nó có 1 section dành cho global, một vài section dành cho các thành phần khác. Trong đó một vài là bắt buộc, một vài là tùy chọn.

Ví dụ:

```
# cat /etc/ceph/ceph.conf
[global]
fsid = 5591400a-6868-447f-be89-thx1138656b6
max open files = 131072
mon initial members = ceph-mon0
mon host = 192.168.42.10
public network = 192.168.42.0/24
cluster network = 192.168.43.0/24
[client.libvirt]
admin socket = /var/run/ceph/$cluster-$type.$id.$pid.$cctid.asok
log file = /var/log/ceph/qemu-guest-$pid.log
[osd]
osd mkfs type = xfs
osd mkfs options xfs = -f -i size=2048
osd mount options xfs = noatime,largeio,inode64,swalloc
osd journal size = 100
[client.restapi]
public addr = 192.168.42.10:5000
keyring = /var/lib/ceph/restapi/ceph-restapi/keyring
log file = /var/log/ceph/ceph-restapi.log
```

- Section `global` sẽ áp dụng cho toàn bộ thành phần của ceph. `fsid` là id duy nhất cho cluster.

`mon initial members` và `mon host` là bắt buộc, chúng khởi động Monitors và tìm lẫn nhau. Những dòng này cũng giúp Ceph OSD, RADOS GW và các daemon khác tìm thấy MONs.

`public network` cũng là bắt buộc, nó define địa chỉ cho Ceph's Monitor cluster. Nếu `cluster network` được định nghĩa, nó sẽ dành cho việc nhân bản dữ liệu, ngược lại nếu không được định nghĩa thì toàn bộ traffic sẽ đi qua public network.

- `[client.libvirt]` section chứa các cài đặt cho các virtualization như QEMU. section này là không bắt buộc.

- `osd` section thường nhận được sử chú ý nhiều nhất từ admin. Trong đó `osd mkfs type` dùng để định nghĩa FileStore OSDs sẽ dùng xfs, ext4 hoặc btrfs.
`osd mkfs options xfs` liệt kê các options được dùng trong quá trình chạy câu lệnh `mkfs.xfs`. Tiếp theo, `osd mount options xfs` chỉ được dùng nếu FileStore OSD được mount trong quá trình startup.

`osd journal size` là option cho phép định nghĩa dung lượng cho journal. Trong môi trường production thì con số được khuyến cáo là 10GB

- section cuối cùng là `client.restapi`, nó chỉ được yêu cầu khi sử dụng rest api để quản lý ceph từ phía ngoài.

### 3. Admin sockets

Mỗi một Ceph daemon sẽ lắng nghe yêu cầu trên admin socket để lấy hoặc thiết lập các tác vụ. Chúng ta có thể thấy các socket này trong folder `/var/run/ceph`

```
osd-1701# ls /var/run/ceph
ceph-osd.0.asok ceph-osd.10.asok ceph-osd.11.asok
ceph-osd.12.asok ceph-osd.13.asok ceph-osd.14.asok
ceph-osd.15.asok ceph-osd.16.asok ceph-osd.17.asok
ceph-osd.18.asok ceph-osd.19.asok ceph-osd.1.asok
ceph-osd.20.asok ceph-osd.21.asok ceph-osd.22.asok
ceph-osd.23.asok ceph-osd.2.asok ceph-osd.3.asok
ceph-osd.4.asok ceph-osd.5.asok ceph-osd.69.asok
ceph-osd.7.asok ceph-osd.8.asok ceph-osd.9.asok
mon-05# ls /var/run/ceph
ceph-mon.mon05.asok
```

Để tương tác với osd.0, đầu tiên ta cần ssh vào node đang chứa osd này và hỏi osd.0 admin socket coi nó có thể làm gì

```
[root@ceph1 ~]# ceph daemon osd.0 help
{
    "calc_objectstore_db_histogram": "Generate key value histogram of kvdb(rocksdb) which used by bluestore",
    "compact": "Commpact object store's omap. WARNING: Compaction probably slows your requests",
    "config diff": "dump diff of current config and default config",
    "config diff get": "dump diff get <field>: dump diff of current and default config setting <field>",
    "config get": "config get <field>: get the config value",
    "config help": "get config setting schema and descriptions",
    "config set": "config set <field> <val> [<val> ...]: set a config variable",
    "config show": "dump current config settings",
    "config unset": "config unset <field>: unset a config variable",
    "dump_blacklist": "dump blacklisted clients and times",
    "dump_blocked_ops": "show the blocked ops currently in flight",
    "dump_historic_ops": "show recent ops",
    "dump_historic_ops_by_duration": "show slowest recent ops, sorted by duration",
    "dump_historic_slow_ops": "show slowest recent ops",
    "dump_mempools": "get mempool stats",
    "dump_objectstore_kv_stats": "print statistics of kvdb which used by bluestore",
    "dump_op_pq_state": "dump op priority queue state",
    "dump_ops_in_flight": "show the ops currently in flight",
    "dump_pgstate_history": "show recent state history",
    "dump_reservations": "show recovery reservations",
    "dump_scrubs": "print scheduled scrubs",
    "dump_watchers": "show clients which have active watches, and on which objects",
    "flush_journal": "flush the journal to permanent store",
    "flush_store_cache": "Flush bluestore internal cache",
    "get_command_descriptions": "list available commands",
    "get_heap_property": "get malloc extension heap property",
    "get_latest_osdmap": "force osd to update the latest map from the mon",
    "get_mapped_pools": "dump pools whose PG(s) are mapped to this OSD.",
    "getomap": "output entire object map",
    "git_version": "get git sha1",
    "heap": "show heap usage info (available only if compiled with tcmalloc)",
    "help": "list available commands",
    "injectdataerr": "inject data error to an object",
    "injectfull": "Inject a full disk (optional count times)",
    "injectmdataerr": "inject metadata error to an object",
    "list_devices": "list OSD devices.",
    "log dump": "dump recent log entries to log file",
    "log flush": "flush log entries to log file",
    "log reopen": "reopen log file",
    "objecter_requests": "show in-progress osd requests",
    "ops": "show the ops currently in flight",
    "perf dump": "dump perfcounters value",
    "perf histogram dump": "dump perf histogram values",
    "perf histogram schema": "dump perf histogram schema",
    "perf reset": "perf reset <name>: perf reset all or one perfcounter name",
    "perf schema": "dump perfcounters schema",
    "rmomapkey": "remove omap key",
    "set_heap_property": "update malloc extension heap property",
    "set_recovery_delay": "Delay osd recovery by specified seconds",
    "setomapheader": "set omap header",
    "setomapval": "set omap key",
    "smart": "probe OSD devices for SMART data.",
    "status": "high-level status of OSD",
    "trigger_deep_scrub": "Trigger a scheduled deep scrub ",
    "trigger_scrub": "Trigger a scheduled scrub ",
    "truncobj": "truncate object to length",
    "version": "get ceph version"
}
```

Để xem có bao nhiêu

```
[root@ceph1 ~]# ceph daemon osd.0 config show | wc -l
1473
```

Hơn 1k cấu hình. Tất nhiên là hầu hết chúng sẽ được khuyến cáo là chỉ động đến khi bạn thực sự cần thiết. Ta có một số cấu hình hay được sử dụng hơn bởi nó ảnh hưởng tới backfill and recovery

```
[root@ceph1 ~]# ceph daemon osd.0 config show | egrep backfill\|recovery
    "mon_osd_backfillfull_ratio": "0.900000",
    "osd_allow_recovery_below_min_size": "true",
    "osd_async_recovery_min_pg_log_entries": "100",
    "osd_backfill_retry_interval": "30.000000",
    "osd_backfill_scan_max": "512",
    "osd_backfill_scan_min": "64",
    "osd_debug_reject_backfill_probability": "0.000000",
    "osd_debug_skip_full_check_in_backfill_reservation": "false",
    "osd_debug_skip_full_check_in_recovery": "false",
    "osd_force_recovery_pg_log_entries_factor": "1.300000",
    "osd_kill_backfill_at": "0",
    "osd_max_backfills": "1",
    "osd_min_recovery_priority": "0",
    "osd_recovery_cost": "20971520",
    "osd_recovery_delay_start": "0.000000",
    "osd_recovery_forget_lost_objects": "false",
    "osd_recovery_max_active": "3",
    "osd_recovery_max_chunk": "8388608",
    "osd_recovery_max_omap_entries_per_chunk": "8096",
    "osd_recovery_max_single_start": "1",
    "osd_recovery_op_priority": "3",
    "osd_recovery_op_warn_multiple": "16",
    "osd_recovery_priority": "5",
    "osd_recovery_retry_interval": "30.000000",
    "osd_recovery_sleep": "0.000000",
    "osd_recovery_sleep_hdd": "0.100000",
    "osd_recovery_sleep_hybrid": "0.025000",
    "osd_recovery_sleep_ssd": "0.000000",
    "osd_scrub_during_recovery": "false",
```

Một cách nữa để lấy thông tin từ ceph daemon đó là `ceph tell` từ MON hoặc admin node.

```
[root@ceph1 ~]# ceph tell osd.* version
osd.0: {
    "version": "ceph version 13.2.6 (7b695f835b03642f85998b2ae7b6dd093d9fbce4) mimic (stable)"
}
osd.1: {
    "version": "ceph version 13.2.6 (7b695f835b03642f85998b2ae7b6dd093d9fbce4) mimic (stable)"
}
osd.2: {
    "version": "ceph version 13.2.6 (7b695f835b03642f85998b2ae7b6dd093d9fbce4) mimic (stable)"
}
osd.3: {
    "version": "ceph version 13.2.6 (7b695f835b03642f85998b2ae7b6dd093d9fbce4) mimic (stable)"
}
```

Cách này hạn chế về option hơn một chút so với việc dùng qua admin sockets. Ngoài ra thì ceph cũng đã thêm một số các command khác.

### 4. Injection

Đây là cách gần như nhanh nhất để thay đổi Ceph running config. Khi sử dụng, ta có thể tránh được việc phải restart rất nhiều daemon.
