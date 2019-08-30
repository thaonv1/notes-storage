# Cấu hình nginx làm proxy cho ceph rgw

## 1. Cài đặt ceph radosgw

Xem thêm (tại đây)[]

**Lưu ý:** Cấu hình ceph rgw

```
[client.rgw.cephaio]
host = cephaio
rgw dns name = cephaio.thaonv.com
```

## 2. Cấu hình dns wildcard

- Cài package

`yum install bind* -y`

- Sửa file `/etc/named.conf`

```
listen-on port 53 { any; };
allow-query     { localhost; 10.10.11.0/24; };

zone "thaonv.com" IN {
type master;
file "db.thaonv.com";
allow-update { none; };
};
```

- Tạo file `/var/named/db.thaonv.com`

```
@ 86400 IN SOA thaonv.com. root.thaonv.com. (
20091028 ; serial yyyy-mm-dd
10800 ; refresh every 15 min
3600 ; retry every hour
3600000 ; expire after 1 month +
86400 ); min ttl of 1 day
@ 86400 IN NS thaonv.com.
@ 86400 IN A 10.10.11.240
* 86400 IN CNAME @
```

`10.10.11.240` là ip  của ceph rgw

- Sửa file `/etc/resolv.conf`

```
search thaonv.com
nameserver 10.10.11.242
```

- start dịch vụ

`sudo systemctl start named.service`

- Check config

```
named-checkconf /etc/named.conf
named-checkzone thaonv.com /var/named/db.thaonv.com
```

- Ping thử

`ping cephaio.thaonv.com`

<img src="https://i.imgur.com/vcyIacn.png">

## 3. Cài đặt và cấu hình nginx

- Cài package

`yum install epel-release -y && yum install nginx -y`

- Cấu hình file config

`vi /etc/nginx/conf.d/cephaio.thaonv.com.conf`

```
server {
	listen 80;
	server_name *.thaonv.com;

	location / {
		proxy_set_header X-Real-IP $remote_addr;
		proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
		proxy_set_header Host $host;
		proxy_set_header X-Forwarded-Proto $scheme;
		proxy_pass http://10.10.11.240:7480;
		#proxy_pass_request_headers on;
		proxy_redirect off;
		client_max_body_size 0;
		proxy_buffering off;
	}
}
```

- Chỉnh port mặc định 80 của nginx trong file `/etc/nginx/nginx.conf`

- Start nginx

```
systemctl start nginx
systemctl enable nginx
```

- Từ máy client, trỏ dns server về máy ta vừa cài dns server rồi truy cập vào đường dẫn `http://cephaio.thaonv.com`

<img src="https://i.imgur.com/6xCM9X7.png">

## 4. Dùng s3cmd để truy cập

Tải s3cmd

`yum install s3cmd -y`

Config

`s3cmd --configure`

```
Enter new values or accept defaults in brackets with Enter.
Refer to user manual for detailed description of all options.

Access key and Secret key are your identifiers for Amazon S3. Leave them empty for using the env variables.
Access Key [ZE0V04QKEDPGDCAWU9E8]: FI3ZBVBF8SI1FNLMHX9M
Secret Key [wWmKB4mknj7lMPVNKbLYEQqauXBt3JqE52WIANoc]: K6Fne8250Yydq0efQzhnfRH89aXVDSozxY8YX3gR
Default Region [US]:

Use "s3.amazonaws.com" for S3 Endpoint and not modify it to the target Amazon S3.
S3 Endpoint [cephaio.thaonv.com]: cephaio.thaonv.com

Use "%(bucket)s.s3.amazonaws.com" to the target Amazon S3. "%(bucket)s" and "%(location)s" vars can be used
if the target S3 system supports dns based buckets.
DNS-style bucket+hostname:port template for accessing a bucket [%(bucket)s.cephaio.thaonv.com]: %(bucket)s.cephaio.thaonv.com

Encryption password is used to protect your files from reading
by unauthorized persons while in transfer to S3
Encryption password:
Path to GPG program [/usr/bin/gpg]:

When using secure HTTPS protocol all communication with Amazon S3
servers is protected from 3rd party eavesdropping. This method is
slower than plain HTTP, and can only be proxied with Python 2.7 or newer
Use HTTPS protocol [No]: No

On some networks all internet access must go through a HTTP proxy.
Try setting it here if you can't connect to S3 directly
HTTP Proxy server name:

New settings:
  Access Key: FI3ZBVBF8SI1FNLMHX9M
  Secret Key: K6Fne8250Yydq0efQzhnfRH89aXVDSozxY8YX3gR
  Default Region: US
  S3 Endpoint: cephaio.thaonv.com
  DNS-style bucket+hostname:port template for accessing a bucket: %(bucket)s.cephaio.thaonv.com
  Encryption password:
  Path to GPG program: /usr/bin/gpg
  Use HTTPS protocol: True
  HTTP Proxy server name:
  HTTP Proxy server port: 0

Test access with supplied credentials? [Y/n] Y
Please wait, attempting to list all buckets...
Success. Your access key and secret key worked fine :-)

Now verifying that encryption works...
Not configured. Never mind.

Save settings? [y/N] y
Configuration saved to '/root/.s3cfg'
```

- Tạo thử bucket

`s3cmd mb s3://thaonv`
