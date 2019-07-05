# Quản lí user trong Ceph

<img src="https://i.imgur.com/URhJsU7.png">

Khi ceph được chạy với tính năng authen và author thì bạn sẽ phải khia báo 1 user chỉ định kèm theo keyring chứa secret key của nó. Nếu bạn không khai báo, thì mặc định ceph sẽ sử dụng `client.admin` và sẽ tìm bất cứ keyring nào trong cấu hình.

**Background**

Ceph user sẽ phải truy cập vào pool đẻ đọc và ghi dữ liệu, ngoài ra nó cũng cần phải được cấp quyền thông qua câu lệnh quản trị.

- User

User ở đay có thể là cá nhân hoặc một hệ thống/ứng dụng nào đó. Tạo ra user cho phép bạn quản lí ai sẽ là người được tuy cập tới cluster, pool hoặc dữ liệu trong pool. Ceph có khái niệm về loại người dùng, đối với mục đích quản lí thì loại này luôn là `client`. Ceph nhận dạng user theo cấu trúc `TYPE.ID` ví dụ `client.admin`. Nguyên nhân nằm ở việc  Ceph Monitors, OSDs, and Metadata Servers sử dụng giao thức  `Cephx` nhưng chúng không phải là client.

- AUTHORIZATION (CAPABILITIES)

Ceph sử dụng term `capabilities` (caps) để mô tả việc ủy quyền cho các tài khoản đã được xác thực đối với các tài nguyên trong cluster.

Cú pháp :

`{daemon-type} '{cap-spec}[, {cap-spec} ...]'`

- Monitor Caps:

```
mon 'allow {access-spec}'
mon 'profile {name}'
```

cu pháp `{access-spec}`:

`* | all | [r][w][x]`

- OSD Caps

```
osd 'allow {access-spec} [{match-spec}]'
osd 'profile {name} [pool={pool-name} [namespace={namespace-name}]]'
```

cú pháp `{access-spec}`:

```
* | all | [r][w][x] [class-read] [class-write]
class {class name} [{method name}]
```

cú pháp `{match-spec}`

```
pool={pool-name} [namespace={namespace-name}] [object_prefix {prefix}]
[namespace={namespace-name}] tag {application} {key}={value}
```

- POOL

- APPLICATION TAGS

- NAMESPACE

Đây là dạng nhóm các object trong một pool, các truy cập tới pool sau này có thể được giới hạn ở mức namespace, cái này rất hữu dụng khi viết các ứng dụng truy cập tới object storage của ceph.

**Quản lí user**

- List user

`ceph auth ls`

- Get user

`ceph auth get {TYPE.ID}`

- Add user

Có khá nhiều cách để add user

- ceph auth add: This command is the canonical way to add a user. It will create the user, generate a key and add any specified capabilities.
- ceph auth get-or-create: This command is often the most convenient way to create a user, because it returns a keyfile format with the user name (in brackets) and the key. If the user already exists, this command simply returns the user name and key in the keyfile format. You may use the -o {filename} option to save the output to a file.
- ceph auth get-or-create-key: This command is a convenient way to create a user and return the user’s key (only). This is useful for clients that need the key only (e.g., libvirt). If the user already exists, this command simply returns the key. You may use the -o {filename} option to save the output to a file.

Khi tạo user, bạn có thể không khai báo capabilities, tuy nhiên user đó sẽ không có quyền gì ngoài việc xác thực, tất nhiên bạn cũng có thể thêm quyền cho nó sau này.
Một user thông thường sẽ có quyền read đối với monitors và quyền đọc ghi với từng pool cụ thể:

```
ceph auth add client.john mon 'allow r' osd 'allow rw pool=liverpool'
ceph auth get-or-create client.paul mon 'allow r' osd 'allow rw pool=liverpool'
ceph auth get-or-create client.george mon 'allow r' osd 'allow rw pool=liverpool' -o george.keyring
ceph auth get-or-create-key client.ringo mon 'allow r' osd 'allow rw pool=liverpool' -o ringo.key
```

- Thay đổi user capabilities

Câu lệnh `ceph auth caps` cho phép bạn overwrite capabilities hiện tại, để lấy capabilities hiện tại, sử dụng câu lệnh `ceph auth get USERTYPE.USERID`. Để add thêm, bạn có thể sử dụng câu lệnh:

`ceph auth caps USERTYPE.USERID {daemon} 'allow [r|w|x|*|...] [pool={pool-name}] [namespace={namespace-name}]' [{daemon} 'allow [r|w|x|*|...] [pool={pool-name}] [namespace={namespace-name}]']`

VD:

```
ceph auth get client.john
ceph auth caps client.john mon 'allow r' osd 'allow rw pool=liverpool'
ceph auth caps client.paul mon 'allow rw' osd 'allow rwx pool=liverpool'
ceph auth caps client.brian-manager mon 'allow *' osd 'allow *'
```

- Xóa user

`ceph auth del {TYPE}.{ID}`

- Print key

`ceph auth print-key {TYPE}.{ID}`

- Import user

`ceph auth import -i /path/to/keyring`

**Quản lí keyring**

Khi bạn truy cập tới Ceph thông qua ceph client, nó sẽ tìm kiếm local keyring. Ceph sẽ đặt tên cho keyring theo 4 cái tên như bên dưới, do đó bạn không cần phải đặt tên cho chúng trừ khi muốn ghi đè.

```
/etc/ceph/$cluster.$name.keyring
/etc/ceph/$cluster.keyring
/etc/ceph/keyring
/etc/ceph/keyring.bin
```

- Tạo keyring

Để tạo ra keyring trống

`ceph-authtool --create-keyring /path/to/keyring`

Khi tạo keyring với nhiều user, ta nên đặt tên theo cluster và để nó trong thư mục cấu hình mặc định, nhờ đó mà khi thực hiện các câu lệnh ta không cần phải khai báo.

- Add user cho keyring

`sudo ceph-authtool /etc/ceph/ceph.keyring --import-keyring /etc/ceph/ceph.client.admin.keyring`

- Tạo user

`sudo ceph-authtool -n client.ringo --cap osd 'allow rwx' --cap mon 'allow rwx' /etc/ceph/ceph.keyring`

User này vẫn chỉ đang ở keyring, bạn cần phải thêm nó vào clusster

`sudo ceph auth add client.ringo -i /etc/ceph/ceph.keyring`
