# Hướng dẫn cấu hình để host static web trên Ceph RGW

- Thay đổi cấu hình của RGW, bổ sung một số option sau

```
rgw enable static website = true
rgw dns s3website name = web.cloudchuanchi.com
```

Lưu ý: Domain sử dụng cho tính năng này không được trùng với domain của dịch vụ standard

- Thêm bản tin dns trỏ về domain mới tương tự như đối với dịch vụ lưu trữ standard

- Change cert để nó apply cho cả 2 subdomain

```
sudo certbot certonly --server https://acme-v02.api.letsencrypt.org/directory \
  --manual \
  --preferred-challenges dns-01 \
  -d s3.cloudchuanchi.com \
  -d web.cloudchuanchi.com \
  -d *.s3.cloudchuanchi.com \
  -d *.web.cloudchuanchi.com \
  --agree-tos \
  --manual-public-ip-logging-ok
```

- Apply cert mới cho nginx

## Hướng dẫn host website với s3cmd

- Tạo bucket, domain sinh ra có dạng `bucket.web.cloudchuanchi.com`

`s3cmd mb s3://$DOMAIN`

- Change policy thành public

`s3cmd setacl --acl-public s3://$DOMAIN`

- Tạo website

`s3cmd ws-create --ws-index=index.html s3://$DOMAIN`

- Thay đổi đường dẫn của các file tĩnh trong các file html hoặc css trỏ về domain trên rgw

Ví dụ: `<link rel="stylesheet" type="text/css" href="https://test.s3.cloudchuanchi.com/test/css/test.css">`

- Sync các file của website lên bucket

`s3cmd sync --acl-public ./ s3://$DOMAIN`

- Thay đổi content type đối với các file css, js hoặc font

```
s3cmd modify --mime-type="text/css" s3://test/css/animate.css
s3cmd modify --mime-type="application/javascript" s3://test/js/ajaxchimp.js
s3cmd modify --mime-type="font/opentype" s3://test/fonts/Linearicons-Free.eot
```

- Kiểm tra bằng cách truy cập vào domain được sinh ra xem website launch lên còn vấn đề gì không.

Lưu ý: Đối với một số trang có font riêng và ta phải load từ bucket về thì có thể sẽ bị block CORS, trên console của brpwser hiển thị lỗi `...has been blocked by CORS policy: No 'Access-Control-Allow-Origin' header is present on the requested resource..`

Ta tiến hành thêm file `rules.xml` như sau

```
<?xml version="1.0" encoding="UTF-8"?>
<CORSConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
    <CORSRule>
        <AllowedOrigin>*</AllowedOrigin>
        <AllowedMethod>GET</AllowedMethod>
        <AllowedMethod>HEAD</AllowedMethod>
        <MaxAgeSeconds>3000</MaxAgeSeconds>
        <AllowedHeader>Authorization</AllowedHeader>
    </CORSRule>
</CORSConfiguration>
```

Sau đó apply rule này cho bucket chứa website

```
s3cmd setcors rules.xml s3://test
```
