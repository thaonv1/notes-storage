# Tổng quan về CEPH

Vì đã có khá nhiều bài viết về ceph nên mình sẽ chỉ tổng hợp tóm tắt lại trong đây những ý mà mình thấy hay.

## 1. Lịch sử hình thành

CEPH được bắt đầu từ 1 dự án tiến sĩ tại University of California, Santa Cruz, của Sage Weil vào năm 2003. Khởi đầu, Ceph cung cấp file system storage với gần 40k dòng code C++. Lawrence Livermore National Laboratory là nơi hỗ trợ cho Weil tiếp tục phát triển ceph trong giai đoạn 2003-2007. Sage Weil cũng là co-founder của DreamHost, 1 công ty chuyên về domain và hosting, đây là nơi hỗ trợ cho việc phát triển ceph trong giai đoạn 2007-2011. Năm 2012, Sage Weil thành lập lên Intank để mở rộng sử ảnh hưởng của CEPH. Đến năm 2014 thì Intank được mua lại bởi Red Hat.

Ceph thực chất là viết tắt của cephalopod, một loài vật thuộc họ Cephalopoda. Bởi vì nó không phải là viết tắt, nên không cần thiết phải viết hoa tất cả các chữ cái khi nhắc tới Ceph.

## 2. Thành phần

### Reliable Autonomic Distributed Object Store (RADOS)

Nền tảng của Ceph là một kho lưu trữ dữ liệu cấp thấp có tên RADOS, cung cấp một backend chung cho nhiều dịch vụ của người dùng.

<img src="https://i.imgur.com/hnkR4uo.png">

RADOS là một lớp hệ thống lưu trữ đối tượng cung cấp khung và tính sẵn có của dữ liệu mà tất cả các dịch vụ Ceph được sử dụng bởi người dùng đều được đặt lên phía trên.
RADOS là:

- Có sẵn cao mà không có điểm thất bại duy nhất (SPoF)
- Đáng tin cậy và kiên cường
- Tự sửa lỗi
- Tự quản lí
- Thích nghi
- Có thể mở rộng
- Không tìm thấy trên Galactica

RADOS quản lí sự phân tán dữ liệu trong CEPH. Tính sẵn sàng của dữ liệu được đảm bảo bởi các thao tác vận hành cần thiết như recover lại dữ liệu bị hỏng, đảm bảo tính cân bằng cho cluster khi có thêm hoặc bớt dung lượng. Nền tảng cho việc này chính là thuật toán CRUSH.


### MONs

Trong tất cả các thuật ngữ trong hệ sinh thái Ceph, Ceph MON có lẽ là cái tên dễ gây hiểu lầm nhất. MON thực hiện nhiều hơn là chỉ theo dõi trạng thái cụm. Nó đóng vai trò như một trọng tài, cảnh sát giao thông và bác sĩ cho toàn bộ cụm. Với OSD, Ceph MON, nói đúng ra là một daemon (ceph-mon) giao tiếp với các MON ngang hàng, OSD và người dùng, duy trì và phân phối thông tin quan trọng khác nhau cho các hoạt động cụm. Trong thực tế, thuật ngữ này cũng được sử dụng để chỉ các máy chủ mà các tiến trìh này chạy, đó là Monitor nodes, mon nodes, or simply mons.

Như với tất cả các thành phần Ceph khác, MON cần được phân phối, dự phòng và có tính sẵn sàng cao đồng thời đảm bảo tính nhất quán dữ liệu nghiêm ngặt mọi lúc. MON thực hiện điều này bằng cách tham ra vào một sophisticated quorum sử dụng thuật toán có tên PAXOS. Nên cung cấp ít nhất ba mon cho các cluster chạy production, ngoài ra thì con số này cũng nên là số lẻ để tránh hiện tượng bị split brain khi có vấn đề với network.

Các dữ liệu được quản lí bởi MONs bao gồm maps of OSDs, other MONs, placement groups, and the CRUSH map. Những thứ này sẽ mô tả đâu là nơi dữ liệu nên được đặt vào và tìm thấy. MONs vì thế chính là người phân phối, nó thực hiện rồi update lại cho các thành phần khác.

### Object Storage Daemons (OSDs)

OSD cung cấp storage số lượng lớn cho tất cả dữ liệu người dùng trong Ceph. Nói một cách chính xác, OSD là tiến trình (ceph-osd) chạy trên storage host quản lý dữ liệu đọc, ghi và tính toàn vẹn. Tuy nhiên, trên thực tế, OSD cũng được sử dụng để chỉ bộ sưu tập dữ liệu cơ bản, thiết bị lưu trữ đối tượng, mà một OSD cụ thể quản lý. Khi cả hai được liên kết mật thiết với nhau, người ta cũng có thể nghĩ khá hợp lý về một OSD như là sự kết hợp hợp lý của tiến trình và thành phần lưu trữ phía dưới. Đôi khi, người ta có thể thấy OSD cũng được sử dụng để chỉ toàn bộ máy chủ / máy chủ lưu trữ các quy trình và dữ liệu này, mặc dù thực tế thì ta có thể coi máy chủ như là một OSD node chứa hàng tá OSDs riêng lẻ.

Mỗi OSD trong cụm Ceph lưu trữ một tập hợp dữ liệu. Ceph là một hệ thống phân tán không có nút cổ chai truy cập tập trung. Nhiều giải pháp lưu trữ truyền thống chứa một hoặc hai đơn vị đứng đầu là các thành phần duy nhất mà người dùng tương tác, dẫn đến tắc nghẽn hiệu suất và giới hạn tỷ lệ. Tuy nhiên ceph-client, các máy ảo, ứng dụng, v.v., giao tiếp trực tiếp với OSD của cụm. Các hoạt động Tạo, Đọc, Cập nhật và Xóa (CRUD) được gửi bởi client và được thực hiện bởi các tiến trình OSD quản lý bộ nhớ bên dưới.

Ceph tổ chức dữ liệu thành các đơn vị được gọi là placement groups (PGs). Một PG đóng vai trò là mức độ chi tiết mà tại đó các quyết định và hoạt động khác nhau trong cụm được đưa ra. PG là tập hợp các đối tượng được nhóm lại với nhau và thường có số lượng từ hàng nghìn đến hàng chục nghìn. Mỗi PG duy trì nhiều bản sao trên các OSD khác nhau, các node, rack hoặc thậm chí các trung tâm dữ liệu là một phần quan trọng cho phép Ceph đảm bảo về tính sẵn sàng cao và độ bền dữ liệu. PG được phân phối theo các ràng buộc đã xác định để tránh tạo các điểm nóng và để giảm thiểu tác động của các lỗi máy chủ và cơ sở hạ tầng. Theo mặc định, Ceph duy trì ba bản sao dữ liệu, đặt một bản sao của mỗi PG trên ba OSD khác nhau nằm trên ba máy chủ khác nhau. Để có thêm khả năng chịu lỗi, có thể thêm cấu hình để đảm bảo rằng các máy chủ đó được đặt trong ba racks trong trung tâm dữ liệu riêng biệt. Các OSDs  duy trì liên lạc định kì với nhau, khi một OSD gặp lỗi, các OSD còn lại sẽ tự động thực hiện quá trình nhân bản dữ liệu.

### Ceph manager

Bản phát hành Kraken đã mang đến sự ra mắt của trình nền Ceph Manager (ceph-mgr), chạy cùng với MON để cung cấp các dịch vụ toàn cụm thông qua kiến trúc plugin. Mặc dù việc khai thác ceph-mgr vẫn còn non trẻ, nhưng nó có nhiều tiềm năng:

- Quản lý trạng thái ổ đĩa và khung gầm / đèn định vị
- Tạo và quản lý bản đồ của các client như rbd-mirror và RADOS gateway, trước đây ít được tích hợp
- Quản lý toàn diện các sản phẩm của Ceph
- Quản lý tốt hơn các hoạt động tái cấu trúc và tái cân bằng.
- Tích hợp với các hệ thống kiểm kê bên ngoài như RackTables, NetBox, HP SIM và Cisco UCS Manager
- Giao diện cho các hệ thống giám sát / số liệu như Nagios, Icinga, Graphite và Prometheus

### RADOS GateWay (RGW)

Các máy chủ Ceph RGW cung cấp giao diện kiểu API có khả năng mở rộng cao cho dữ liệu được sắp xếp dưới dạng các đối tượng được chứa trong các bucket. Các dịch vụ RESTful tương thích với cả S3 của Amazon và Swift của OpenStack đều có thể được kích hoạt, bao gồm tích hợp trực tiếp với Keystone.

<img src="https://i.imgur.com/b27Dbde.png">

### Admin host

Việc quản lý các cụm Ceph thường được thực hiện thông qua một bộ công cụ giao diện dòng lệnh (CLI). Trong khi một số người quản lý Ceph thực hiện các hành động này từ một hoặc nhiều máy chủ MON, những người khác chọn cung cấp một hoặc nhiều máy chủ độc lập, dành riêng cho mục đích này.

### CephFS MetaData server (MDS)

Để cung cấp file system storage, Ceph cần lưu trữ thêm metadata bao gồm

- Permissions
- Hierarchy
- Names
- Timestamps
- Owners
- Mostly POSIX compliant. mostly.

CephFS MDS được thiết kế để scaling. Thực tế thì dữ liệu không được ném thẳng vào Ceph MDS. Nói một cách rõ hơn thì MDS cung cấp control plane còn RADOS thì cung cấp data plane. Trên thực tế, metadata được quản lí bởi CEPH MDS cũng được lưu trên các OSD cùng với dữ liệu thật.

<img src="https://i.imgur.com/blSpNQb.png">
