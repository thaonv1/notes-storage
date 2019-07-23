# Admin guide

## 1. User management

User của ceph object storage có 2 loại :

- `user` : là user của s3 interface
- `Subuser` : là user của swift interface và nó đi kèm với `user`

### 1.1 Tạo user

Để tạo user cho s3 interface

`radosgw-admin user create --uid={username} --display-name="{display-name}" [--email={email}]`

###  1.2 Tạo subuser

Để tạo sub user bạn cần khai báo user id, subuser id và mức độ access của subuser.

`radosgw-admin subuser create --uid={uid} --subuser={uid} --access=[ read | write | readwrite | full ]`

Lưu ý ở đây full không giống với readwrite.

### 1.3 Get user info

`radosgw-admin user info --uid=johndoe`

### 1.4 MODIFY USER INFO

`radosgw-admin user modify --uid=johndoe --display-name="John E. Doe"`

### 1.5 USER ENABLE/SUSPEND

Bạn có thể suspend tạm thời user và enable trở lại sau,

`radosgw-admin user suspend --uid=johndoe`

Để enable trở lại

`radosgw-admin user enable --uid=johndoe`

### 1.6 REMOVE A USER

Khi bạn remove user, cả subuser cũng sẽ bị remove.

`radosgw-admin user rm --uid=johndoe`

Để remove subuser only

`radosgw-admin subuser rm --subuser=johndoe:swift`

### 1.7 ADD / REMOVE A KEY

Để add key

`radosgw-admin key create --uid=foo --key-type=s3 --access-key fooAccessKey --secret-key fooSecretKey`

Bạn có thể tạo ra nhiều s3 key cho user thuy nhiên với swift thì chỉ là 1.

Để remove key

`radosgw-admin key rm --uid=foo --key-type=s3 --access-key=fooAccessKey`

Để remove swift secret key

`radosgw-admin key rm -subuser=foo:bar --key-type=swift`

### 1.8 ADD / REMOVE ADMIN CAPABILITIES

Ceph Storage Cluster cung cấp admin api để cho phép người dùng thực hiện một số tính năng thông qua REST api. Mặc định thì user sẽ không có quyền access vào api này.

Để add cap cho user

`radosgw-admin caps add --uid={uid} --caps={caps}`

Bạn có thể add read, write, hoặc all cap cho user đối với bucket, metadata và useage.

`--caps="[users|buckets|metadata|usage|zone]=[*|read|write|read, write]"`

Ví dụ:

`radosgw-admin caps add --uid=johndoe --caps="users=*;buckets=*"`

Để remove cap

`radosgw-admin caps rm --uid=johndoe --caps={caps}`

## 2. QUOTA MANAGEMENT

Ceph object gateway cho phép bạn set quota cho người dùng và bucket được quản lí bởi user. Quota bao gồm giới hạn về số lượng object trong 1 bucket hoặc số lượng dung lượng tối đa mà bucket có thể giữ.

### 2.1 SET USER QUOTA

Trước khi bạn bật quota, bạn phải set quota parameter trước

`radosgw-admin quota set --quota-scope=user --uid=<uid> [--max-objects=<num objects>] [--max-size=<max size>]`

Ví dụ:

`radosgw-admin quota set --quota-scope=user --uid=johndoe --max-objects=1024 --max-size=1024B`

### 2.2 ENABLE/DISABLE USER QUOTA

Sau khi set quota, bạn có thể bật nó lên.

`radosgw-admin quota enable --quota-scope=user --uid=<uid>`

Hoặc disable nó đi

`radosgw-admin quota disable --quota-scope=user --uid=<uid>`

### 2.3 SET BUCKET QUOTA

Bucket quota được dapply cho các bucket được quản lí bởi uid chỉ định. Chúng độc lập đối với người dùng.

`radosgw-admin quota set --uid=<uid> --quota-scope=bucket [--max-objects=<num objects>] [--max-size=<max size]`

### 2.4 ENABLE/DISABLE BUCKET QUOTA

Một khi setup bucket quota xong, bạn có thể enable nó

`radosgw-admin quota enable --quota-scope=bucket --uid=<uid>`

Hoặc disable

`radosgw-admin quota disable --quota-scope=bucket --uid=<uid>`

### 2.5 GET QUOTA SETTINGS

`radosgw-admin user info --uid=<uid`

### 2.6 UPDATE QUOTA STATS

Thông tin về quota có thể được update ko đồng bộ

`radosgw-admin user stats --uid=<uid> --sync-stats`

### 2.7 GET USER USAGE STATS

`radosgw-admin user stats --uid=<uid>`

## 3. USEAGE

Ceph Object Gateway lưu lại usage cho từng user. Bạn có thể theo dõi bằng cách thêm `rgw enable usage log = true` trong sextion `[client.rgw]` ở file config.

Để show usage

`radosgw-admin usage show --uid=johndoe --start-date=2012-03-01 --end-date=2012-04-01`

Bạn cũng có thể show tóm tắt

`radosgw-admin usage show --show-log-entries=false`

Để dọn dẹp log usage

```
radosgw-admin usage trim --start-date=2010-01-01 --end-date=2010-12-31
radosgw-admin usage trim --uid=johndoe
radosgw-admin usage trim --uid=johndoe --end-date=2013-12-31
```
