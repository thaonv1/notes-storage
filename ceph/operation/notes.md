# Một số ghi chép với Ceph

## 1. Thay đổi cấu hình

Thay đổi trong thư mục dùng để cài ceph thông qua ceph-deploy.

`vi ceph.conf`

Sau đó push config tới các node trong hệ thống

`ceph-deploy --overwrite-conf config push ceph1`

Cuối cùng là restart lại service, tùy từng cấu hình mà ta sẽ restart lại các service tương ứng.
