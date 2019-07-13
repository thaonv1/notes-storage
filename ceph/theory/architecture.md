# Tìm hiểu về kiến trúc của Ceph

## 1. Ceph Storage Cluster

### 1.1 HIGH AVAILABILITY AUTHENTICATION

Ceph cung cấp 1 hệ thống xác thực là `cephx` để nhận diện người dùng và tránh các tấn công bên ngoài lợi dụng quá trình giao tiếp giữa các thành phần.

`Cephx` sử dụng key cho việc xác thực, cả client lẫn monitor cluster đều có bản sao secret key của client. Để sử dụng được cephx, người quản trị cần thiết lập user trước.

<img src="https://i.imgur.com/QxrZ04Q.png">

Client sử dụng command line để gen username và secret key. Hệ thống xác thực sẽ gen user và key, lưu lại 1 bản tại monitor đồng thời trả lại client.

Để xác thực với monitor, client sẽ truyền username gửi tới monitor, tại đây monitor sẽ gen 1 session key và mã hóa nó với secret key của client đó và trả lại phía client. Client sau đó giải mã nội dung để lấy session key, session key này sẽ xác định người dùng cho phiện hiện tại. Client sau đó yêu cầu một ticket, monitor sẽ gen ticket, mã hóa với secret key của user và trả ngược lại client. Client sẽ giải mã ticket và sử dụng nó để kí vào các request tới OSD và metadata server sau này.

<img src="https://i.imgur.com/HzJPqil.png">

`cephx` liên tục xác thực giữa client và ceph server. Mỗi một message giữa client và server sẽ đều được sign bởi ticket được nhắc ở trên.

<img src="https://i.imgur.com/c6ydhuF.png">

### 1.2 DYNAMIC CLUSTER MANAGEMENT

**POOL**

Pool trong ceph là khái niệm để chỉ các logical partition để lưu dữ liệu. Client sẽ nhận cluster map từ monitor và ghi dữ liệu xuống pool. Pool sẽ dựa vào các cài đặt cũng như rule đẻ xác định cách lưu dữ liệu:

<img src="https://i.imgur.com/HBb3oBC.png">

Pool phải có it nhất 3 para sau:

- Ownership/Access to Objects
- The Number of Placement Groups, and
- The CRUSH Rule to Use.

**MAPPING PGS TO OSDS**

Mỗi pool sẽ có một số lượng PG, CRUSH kết nối PGs với OSD một cách tự động. Khi client lưu dữ liệu, CRUSH sẽ map từng object tới PG.

Việc mapping này sẽ tạo ra 1 layer ở giữa OSD và client. Việc này cho phép ceph tự động được việc recover dữ liệu nếu OSD down rồi online trở lại. Dưới đây là cách CRUSH map các objects tới PG và PG tới OSD

<img src="https://i.imgur.com/xv5LEAX.png">

**CALCULATING PG IDS**

Khi client nhận được cluster map, nó sẽ biết về tất cả các monitor, OSD và metadata server tuy nhiên nó không biết về vị trí của các object.

Thứ này có thể tính toán được, client chỉ yêu cầu object ID và pool mà thôi. nó tính toán PG dựa vào tên object, hash code, tên pool và số lượng PG trong pool. Các bước như sau:

- Client nhập vào tên pool và object id
- Ceph lấy object id rồi hash nó
- Ceph tính toán để lấy PG id
- Ceph lấy pool id từ tên được cung cấp
- Ceph chuẩn bị pool id cho pg id

**REBALANCING**

Khi bạn add thêm OSD, cluster map sẽ được update. Theo cùng với đó là sự thay đổi về vị trí của các PG.  Hình dưới đây mô tả quá trình REBALANCING:

<img src="https://i.imgur.com/TgVbNv7.png">

### 1.3 CEPH PROTOCOL

**DATA STRIPING**

Vì các thiết bị lưu trữ có giới hạn throughput nên ceph hỗ trợ lưu stripping, một kiểu lưu trữ cho phép dữ liệu phân bổ đều lên các storage device để tăng performance. Kiểu lưu trữ này rất phổ biến ở RAID và đặc biệt là RAID 0.

Ở cách đơn giản nhất, Ceph client sẽ ghi các strip unit vào từng object một cho tới khi object đó đầy, nó sẽ nhảy qua object khác. Tuy nhiên hình thức này không tận dụng được tối đa lợi ích từ việc phân tán dữ liệu ra các pg của ceph.

<img src="https://i.imgur.com/uVN5C51.png">

Ở hình dưới đây, dữ liệu người dùng sẽ được lưu rải rác trong 1 object set bao gồm trong đó 4 object. Sau khi ghi hết tới lần ghi thứ 4, client sẽ xác định xem object set này đã đầy chưa, nếu chưa thì nó sẽ bắt đầu lại với strip thứ nhất. Nếu đầy rồi thì nó sẽ tạo ra 1 object set mới.

<img src="https://i.imgur.com/zlRT8Rl.png">

Có 3 variable sẽ quyết định cách ceph strip dữ liệu

- **Object Size** : Object trong ceph có một dung lượng nhất định
- **Stripe Width** : Dung lượng của từng strip unit.
- **Stripe Count** : client ghi 1 dải strip unit vào 1 danh sách các object được quy định bởi tham số này. Hay nói cách khác, đây chính là số lượng các object trong 1 object set.

**Lưu ý quan trọng:** Hãy thử test hiệu năng cấu hình stripping trước khi đưa cluster vào thực tế, bởi bạn sẽ không thể nào thay đổi các para này say khi mà stripe dữ liệu và ghi xuống các object.

Sau khi ghi vào object, giải thuật CRUSH sẽ map các object với các pg và pg với osd.
