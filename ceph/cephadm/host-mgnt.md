# Host Management

## 1. List host

`ceph orch host ls [--format yaml] [--host-pattern <name>] [--label <label>] [--host-status <status>] [--detail]`

## 2. Add host

```
ssh-copy-id -f -i /etc/ceph/ceph.pub root@*<new-host>*
ceph orch host add *<newhost>* [*<ip>*] [*<label1> ...*]
```

## 3. Remove host

```
ceph orch host drain *<host>*
```

Đợi cho đến khi toàn bộ service dc remove

`ceph orch host rm <host>`

Trường hợp host đã offline

`ceph orch host rm <host> --offline --force`

## 4. Host label

Label là nhãn và có thể được gán cho host, 1 host có thể có nhiều label

```
ceph orch host add my_hostname --labels=my_label1
ceph orch host label rm my_hostname my_label
```

## 5. Các label đặc biệt

- `_no_schedule` : ko deploy daemon nào trên host này
- `_no_autotune_memory` : ko autotune mem ở node này
- `_admin` : sẽ tự chuyển key + ceph.conf sang node này

## 6. Maintainance mode

- Sẽ stop toàn bộ daemon trên node này

```
ceph orch host maintenance enter <hostname> [--force] [--yes-i-really-mean-it]
ceph orch host maintenance exit <hostname>
```

Lưu ý khi dùng `--yes-i-really-mean-it` có thể gây ra vấn đề mất dữ liệu.

## 7. Rescan

Rescan để scan lại các external resource

`ceph orch host rescan <hostname> [--with-summary]`

## 8. Tạo nhiều host 1 lần

Add nhiều host 1 lần bằng cách tạo file yaml

```
service_type: host
hostname: node-00
addr: 192.168.0.10
labels:
- example1
- example2
---
service_type: host
hostname: node-01
addr: 192.168.0.11
labels:
- grafana
---
service_type: host
hostname: node-02
addr: 192.168.0.12
```

`ceph orch apply -i file`

## 9. Location of host

```
service_type: host
hostname: node-00
addr: 192.168.0.10
location:
  rack: rack1
```

## 10. Tuning profile

```
profile_name: 23-mon-host-profile
placement:
  hosts:
    - mon-host-01
    - mon-host-02
settings:
  fs.file-max: 1000000
  vm.swappiness: '13'
```

`ceph orch tuned-profile apply -i <tuned-profile-file-name>`

Các setting này sẽ được set vào `/etc/sysctl.d/` của từng host.

Để view profile

`ceph orch tuned-profile ls`

Remove profile

`ceph orch tuned-profile rm <profile-name>`

Chỉnh profile

`ceph orch tuned-profile add-setting <profile-name> <setting-name> <value>`
`ceph orch tuned-profile rm-setting <profile-name> <setting-name>`

## 11. SSH

Cephadm dùng ssh key để remote tới các host khác, khi cluster được bootstrap thì key sẽ được gen. 

Để gen key mới

`ceph cephadm generate-key`

Để lấy pubkey

`ceph cephadm get-pub-key`

Xóa key

`ceph cephadm clear-key`

Import key

```
ceph config-key set mgr/cephadm/ssh_identity_key -i <key>
ceph config-key set mgr/cephadm/ssh_identity_pub -i <pub>
```

Cần restart lại mgr daemon

`ceph mgr fail`

### Đổi default user

Mặc định cephadm dùng root, để đổi sang user khác

`ceph cephadm set-user <user>`

### Chỉnh ssh config

Mặc định thì cephadm sẽ tự gen config

```
Host *
User root
StrictHostKeyChecking no
UserKnownHostsFile /dev/null
```

Để chỉnh

`ceph cephadm set-ssh-config -i <ssh_config_file>`

Hoặc clear config

`ceph cephadm clear-ssh-config`

Cấu hình file ssh config location

`ceph config set mgr mgr/cephadm/ssh_config_file <path>`

## FQDN 

`cephadm` yêu cầu hostname được add bằng command `ceph orch host add` phải giống với hostname của host đó nếu ko sẽ warning `CEPHADM_STRAY_HOST`

Có 2 cách để có thể set hostname

- 1 là bare hostname. `hostname` sẽ trả về hostname và `hostname -f` sẽ trả về fqdn
- 2 là dùng fqdn. trong trường hợp này sẽ ngược lại với case 1.

