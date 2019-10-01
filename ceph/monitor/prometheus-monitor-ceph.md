# Hướng dẫn monitor Ceph với Prometheus

## 1. Monitor Ceph Cluster

- Trên node active ceph mgr, ta sẽ enable prometheus module

`ceph mgr module enable prometheus`

Check lại

`ceph mgr services`

<img src="https://i.imgur.com/Suzzk6Z.png">

- Trên node prometheus, ta add thêm cấu hình

```
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:9090']
  - job_name: 'ceph'
    scrape_interval: 5s
    static_configs:
      - targets: ['<ip-ceph-mgr>:9283']
```

- Restart lại service

`systemctl restart prometheus`

- Kiểm tra trong phần target status

<img src="https://i.imgur.com/rYBu66U.png">

## 2. Monitor Ceph RGW

- Đảm bảo trong cấu hình rgw có option sau để lưu lại usage

`rgw enable usage log = true`

- Tạo user mới với cap `usage=read` và `buckets=read`.

`radosgw-admin user create --uid=thaonv --display-name=thaonv`

`radosgw-admin caps add --uid=thaonv --caps="buckets=read;usage=read"`

- Clone repo

`git clone https://github.com/thaonguyenvan/radosgw_usage_exporter.git`

- Cài đặt

```
cd radosgw_usage_exporter
pip install requirements.txt
```

- Chạy thử bằng tay

```
chmod +x radosgw_usage_exporter.py
radosgw_usage_exporter.py [-H HOST] [-e ADMIN_ENTRY] [-a ACCESS_KEY] [-s SECRET_KEY] [-p PORT]
```

- Tạo user cho exporter

`useradd --no-create-home --shell /bin/false rgw_exporter`

- Chuyển file thực thi vào thư mục /usr/local/bin

```
cd radosgw_usage_exporter
cp radosgw_usage_exporter.py /usr/local/bin/
chown rgw_exporter:rgw_exporter /usr/local/bin/radosgw_usage_exporter.py
```

- Chạy exporter dưới dạng systemd

```
cat <<EOF >  /etc/systemd/system/rgw_exporter.service
[Unit]
Description=RGW Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=rgw_exporter
Group=rgw_exporter
Type=simple
ExecStart=/usr/local/bin/radosgw_usage_exporter.py -H http://172.16.4.215:7480 -a 5P1P40WOBNJACME6448Z -s eQyx7pMQVIeeeEIR0ZEG3rmA1Sr0GJjYRjlBXnxG

[Install]
WantedBy=multi-user.target
EOF
```

- Khởi động service

```
systemctl daemon-reload
systemctl start rgw_exporter
systemctl enable rgw_exporter
```

- Truy cập đường dẫn để kiểm tra `http://172.16.4.215:9242/metrics`

<img src="https://i.imgur.com/IA7qk5S.png">


**Grafana dashboard**

`https://github.com/ceph/ceph/tree/master/monitoring/grafana/dashboards`
