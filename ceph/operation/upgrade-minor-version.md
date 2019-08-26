# Hướng dẫn upgrade Ceph minor version

## Kịch bản

Ceph 3 node đang chạy MON, OSD (bluestore), MGR sử dụng version Luminous (12.2.8) muốn thực hiện upgrade lên version mới nhất của Luminous là 12.2.12.

## Hướng dẫn thực hiện

Ta sẽ thực hiện từng node một

- Kiểm tra version

`ceph versions`

- Kiểm tra trạng thái

`ceph -s`

- Check xem có những osd nào đang chạy trên node này bằng câu lệnh `df -h`

<img src="https://i.imgur.com/3zCgmR0.png">

- Set noout

`ceph osd set noout`

- Stop toàn bộ các service ceph đang chạy

```
systemctl stop ceph-osd@3
systemctl stop ceph-mon@ceph3
systemctl stop ceph-mgr@ceph3
```

- Check lại repo trong `/etc/yum.repos.d/ceph.repo`

Nếu chưa có, tiến hành tạo bằng câu lệnh sau

```
cat <<EOF> /etc/yum.repos.d/ceph.repo
[ceph]
name=Ceph packages for $basearch
baseurl=https://download.ceph.com/rpm-luminous/el7/x86_64/
enabled=1
priority=2
gpgcheck=1
gpgkey=https://download.ceph.com/keys/release.asc

[ceph-noarch]
name=Ceph noarch packages
baseurl=https://download.ceph.com/rpm-luminous/el7/noarch
enabled=1
priority=2
gpgcheck=1
gpgkey=https://download.ceph.com/keys/release.asc

[ceph-source]
name=Ceph source packages
baseurl=https://download.ceph.com/rpm-luminous/el7/SRPMS
enabled=0
priority=2
gpgcheck=1
gpgkey=https://download.ceph.com/keys/release.asc
EOF
```

- Clean và update

```
yum clean all

yum update -y
```

- Sau khi hoàn tất update, bật lại các service của ceph

```
systemctl start ceph-osd@3
systemctl start ceph-mon@ceph3
systemctl start ceph-mgr@ceph3
```

- Unset flag noout

`ceph osd unset noout`

- Check lại trạng thái

`ceph -s`
