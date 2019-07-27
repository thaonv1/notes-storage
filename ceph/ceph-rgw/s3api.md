# S3 API

Ceph hỗ trợ RESTful API tương thích với model access dữ liệu của Amazon S3 API.

Các feature support

<img src="https://i.imgur.com/xrVUu8M.png">

Các request header field không support

<img src="https://i.imgur.com/zQRybVU.png">

## 1. Entity và header phổ biến

### 1.1 Bucket and hostname

Có 2 kiểu để truy cập tới bucket, kiểu thứ nhất (hay được dùng) sẽ xác định bucket ở trên uri

```
GET /mybucket HTTP/1.1
Host: cname.domain.com
```

Kiểu thứ 2 sẽ xác định bucket thông qua tên ảo

```
GET / HTTP/1.1
Host: mybucket.cname.domain.com
```

Để cấu hình tên bucket ảo, bạn có thể set `rgw_dns_name = cname.domain.com` trong file `ceph.conf`, hoặc add `cname.domain.com` vào trong cấu hình zonegroup.

### 1.2 header

<img src="https://i.imgur.com/o6nYLq1.png">

## 2. Authentication & ACL

### 2.1 Authentication

Vì RGW sử dụng cơ chế authen giống như S3 nên yêu cầu request phải có access key kèm với authen code đã được mã hóa.

```
HTTP/1.1
PUT /buckets/bucket/object.mpeg
Host: cname.domain.com
Date: Mon, 2 Jan 2012 00:01:01 +0000
Content-Encoding: mpeg
Content-Length: 9999999

Authorization: AWS {access-key}:{hash-of-header-and-secret}
```

Trong đó `{access-key}` là giá trị của `access-key` được cung cấp, và `{hash-of-header-and-secret}` là giá trị hash của header string và secret key được cung cấp.

Để generate hash của header string và secret, bạn cần thực hiện những bước sau

- Lấy giá trị của header string
- Format nó theo canonical form
- Gen hmac sử dụng sha1
- Encode dưới dạng base64

Để lấy được header string ta lấy những giá trị sau:

- Thêm request type (PUT, POST, GET, DELETE) không chứa khoảng trắng
- Thêm date dưới dạng gmt
- Thêm request path

Ta cùng xem ví dụ dưới đây, request được authen sử dụng php

``` php
    $aws_access_key_id = 'V3T81OO8E5UG8OW6B3DL';
		$aws_secret_access_key = 'fgDta4M7idEpYSMHR0gkl982LHHbjo9l4cAJUmbJ';

		$headerString = 'PUT';
		$requestPath = '/admin/bucket';
		$date = gmdate("D, d M Y H:i:s +0000");
		$headerString = $headerString . "\n\n\n" . $date ."\n". $requestPath;

		$finalString = (string)$headerString;


		$pass = base64_encode(hash_hmac('sha1',$finalString,'fgDta4M7idEpYSMHR0gkl982LHHbjo9l4cAJUmbJ',$raw_output=TRUE));



		// echo $pass;

		// dd($finalString);

	    $client = new \GuzzleHttp\Client();
	    $url = "http://192.168.40.21:7480/admin/bucket";

	   	$response = $client->request('PUT', $url, ['headers' => [
		        'Authorization' => 'AWS V3T81OO8E5UG8OW6B3DL'.':'.$pass,
		        'Date' => $date
		],'query' => [
                'uid' => 'thaonv',
                'bucket' => 'first-bucket',
                'id' => 'd7549f55-14e9-4d6e-970e-7b7c01b8ec60.4215.1'
            ]]);

	    echo $response->getBody();
```
