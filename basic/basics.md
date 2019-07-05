# Một số ghi chép cơ bản về storage

## Mục lục


### 1. Partition table

Partition table là một bảng nằm trên disk của các hệ điều hành, nó mô tả các partitions ở trên disk đó. Khi nhắc tới partition table và partition map thì người ta thường nói tới  MBR partition table của Master Boot Record (MBR). Tuy nhiên nó cũng được dùng cho các định dạng khác như GPT.

Ta thường được nghe tới 2 thuật ngữ khá phổ biến đó là MBR và GPT. Chúng là các khái niệm để mô tả về các kiểu cấu trúc phân vùng, nó định nghĩa nơi lưu trữ thông tin, vị trí partition bắt đầu, kết thúc... Để có thể sử dụng ổ đĩa, bạn sẽ phải phân vùng partition cho nó. MBR và GPT chính là 2 cách để lưu thông tin phân cùng trên ổ đĩa. Thông tin này bao gồm những phân vùng bắt đầu từ đâu, do đó để hệ điều hành biết những Sector nào thuộc về phân vùng nào và phân vùng nào được dùng để khởi động. Điều đó chính là nguyên nhân tại sao bạn phải chọn MBR hoặc GPT để tạo phân vùng trên ổ đĩa.

**Hạn chế của MBR**

MBR được viết tắt từ Master Boot Record. Nó lần đầu tiên được giới thiệu trong IBM PC DOS 2.0 vào năm 1983.
Nó được gọi là Master Boot Record bởi vì MBR là Sector khởi động đặc biệt tại vị trí bắt đầu của ổ đĩa. Sector này bao gồm Boot Loader cho hệ điều hành được cài đặt và thông tin về những phân vùng Logic của ổ đĩa.

Boot Loader là một đoạn mã nhỏ để tải Boot Loader lớn hơn từ phân vùng khác trên ổ đĩa. Nếu bạn đã cài đặt Windows, những bit ban đầu của Boot Loader Windows nằm tại đây – đó là nguyên nhân tại sao bạn có thể chữa MBR của mình nếu như Windows không khởi động được. Nếu bạn đã cài đặt Linux, Boot Loader GRUB thường được tìm thấy trong MBR.

MBR làm việc với những ổ đĩa có kích thước lên tới 2TB, nhưng nó không thể điều khiển được ổ đĩa có dung lượng lưu trữ lớn hơn 2TB .
MBR chỉ hỗ trợ tới 4 phân vùng ưu tiên, nếu muốn có nhiều hơn, bạn phải tạo một trong những phân vùng gốc là “phân vùng mở rộng” – Extended Partition – và tạo những phân vùng logic bên trong.

**Ưu điểm của GPT**

GPT được viết tắt GUID Partition Table. Nó là chuẩn mới dần thay thế cho MBR. Nó liênkết với UEFI - UEFI đang thay thế cho BIOS cũ kĩ trên nhiều motherboard mới. GPT thay thế cho hệ thống phân vùng MBR cũ bằng thứ gì đó hiện đại hơn.
Nó được gọi là GUID Partition Table bởi vì mọi phân vùng trên ổ đĩa của bạn có “nhận diện đơn nhất trên tổng thể” GUID (globally unique identifier).

Hệ thống này không có những hạn chế như của MBR. Những ổ đĩa có thể có dung lượng càng lớn và sẽ phụ thuộc vào hệ điều hành và hệ thống dữ liệu của nó. GPT cho phép gần như không giới hạn số lượng phân vùng và chỉ phụ thuộc vào hệ điều hành. Windows cho phép tới 128 phân vùng trên ổ đĩa GPT và bạn không cần tạo những phân vùng mở rộng.
Trên ổ đĩa MBR, dữ liệu phân vùng và dữ liệu khởi động được đặt ở một vị trí. Nếu dữ liệu này bị ghi đè hoặc bị hỏng thì bạn sẽ gặp rắc rối lớn. Nhưng với những ổ đĩa GPT sẽ lưu trữ nhiều bản sao dữ liệu này qua nhiều nơi do đó có thể khôi phục lại nếu như gặp lỗi.

GPT cũng lưu trữ những giá trị CRC (cyclic redundancy check) để kiểm tra xem những dữ liệu của nó có còn nguyên vẹn, nếu dữ liệu bị hỏng, GPT có thể đưa ra cảnh báo vấn đề này và cố gắng khôi phục dữ liệu bị hỏng từ vị trí khác trên đĩa. MBR không có cách nào để biết xem dữ liệu của nó có trục trặc hay không.

### 2. Cache

Mặc định thì linux sẽ sử dụng một phần ram chưa dùng để làm cache cho disk, vậy nên đôi khi bạn sẽ thấy số lượng ram còn lại rất ít, tuy nhiên điều đó không thực sự đúng.

Khi chúng ta có nhiều ứng dụng cần tới ram, disk cache sẽ trả lại những gì nó đã mượn. Ngoài ra, cache cũng không bao giờ sử dụng swap.

Hiện nay có 3 options cache chính, đó là:

- Write-through: Dữ liệu sẽ được ghi vào cache và cả storage, phù hợp với các ứng dụng ghi và đọc thường xuyên bởi nó có độ trễ khi đọc khá thấp nhưng nó vẫn chậm hơn write back.
- Write-around: Dữ liệu được ghi trực tiếp, bỏ qua cache. Nó tránh được tình trạng vị flood khi ghi nhưng đọc sẽ chậm hơn.
- Write-back: Dữ liệu sẽ được ghi vào ram trước, do vậy nó nhanh hơn nhưng dữ liệu sẽ không được đảm bảm an toàn trong trường hợp chưa ghi được xuống disk mà mất điện đột ngột.

**Một số kĩ thuật cache trên linux**

#### dm-cache

dm-cache là một thành phần kernel Linux, là khung để mapping các block devices lên các virtual block devices. Nó cho phép một hoặc nhiều thiết bị lưu trữ nhanh, chẳng hạn như ổ đĩa flash (SSD), hoạt động như một bộ đệm (cache) cho một hoặc nhiều thiết bị lưu trữ chậm hơn như ổ đĩa cứng (HDD).

Thiết kế của dm-cache yêu cầu ba thiết bị lưu trữ vật lý để tạo ra một khối kết hợp duy nhất; dm-cache sử dụng các thiết bị lưu trữ đó để lưu trữ riêng dữ liệu thực tế, dữ liệu bộ đệm và siêu dữ liệu cần thiết.

<img src="https://i.imgur.com/enuu2pk.png">

#### bcache

Bcache lần đầu tiên được tích hợp từ linux kernel-3.10. Nó được thiết kế xoay quanh các tính năng độc đáo của SSD dựa trên flash và sử dụng cấu trúc btree / log hỗn hợp để theo dõi vùng lưu trữ. Nó được thiết kế để tránh random write. Trình tự bcache sẽ điền vào erease block và sau đó loại bỏ trước khi sử dụng lại (dữ liệu được lưu trong bộ nhớ cache có thể là bất kỳ sector nào trong bucket. Bcache giảm thiểu chi phí random write, nó sẽ điền vào một bucket theo thứ tự). Hỗ trợ cả write-through và write-back, mặc định write-back bị tắt nhưng bạn hoàn toàn có thể bật nó lại.

<img src="https://i.imgur.com/yp5q9Gk.png">

Theo mặc định, bcache không lưu trữ IO tuần tự, chỉ lưu trữ các lần đọc và ghi ngẫu nhiên. Để tránh việc ghi ngẫu nhiên, bcache chuyển đổi ghi ngẫu nhiên thành ghi tuần tự, đầu tiên ghi vào SSD, sau đó ghi lại vào bộ đệm bằng bộ đệm SSD cho một số lượng lớn ghi và cuối cùng ghi ghi vào đĩa hoặc mảng. Đặc điểm của SSD là tốc độ IO ngẫu nhiên rất nhanh, nhưng sự cải thiện của IO tuần tự theo thứ tự lớn không lớn. Bcache sẽ phát hiện IO liên tiếp và bỏ qua nó; nó cũng sẽ ghi lại kích thước IO trung bình động cho mỗi tác vụ. Khi kích thước IO trung bình vượt quá giá trị ngưỡng, IO phía sau tác vụ sẽ bị bỏ qua, do đó bản sao lưu hoặc bản sao tệp lớn có thể được truyền trong suốt.

#### lvmcache

lvm-cache hoạt động trên đỉnh của dm-cache, nó sử dụng lv có tốc độ nhanh để cải thiện tốc độ cho các lv có tốc độ chậm hơn.
Do các yêu cầu từ dm-cache (trình điều khiển hạt nhân), LVM tiếp tục chia nhóm bộ đệm LV thành hai thiết bị - cache data LV and cache metadata LV.cache data LV là nơi các bản sao của các khối dữ liệu được giữ từ LV gốc để tăng tốc độ. cache metadata LV chứa thông tin kế toán chỉ định nơi lưu trữ các khối dữ liệu (ví dụ: trên LV gốc hoặc trên dữ liệu bộ đệm LV). Người dùng nên làm quen với các LV này nếu họ muốn tạo ra các LV lưu trữ tốt nhất và mạnh nhất. Tất cả các LV liên kết này phải nằm trong cùng một Tập Khối (VG).

### 3. Buffer

Buffer là một phần trên RAM được sử dụng dể CPU lữu trữ dữ liệu một cách tạm thời, dữ liệu mà nó lưu chính tới từ các thiết bị input/output có tốc độ khác nhau, nhờ vậy cpu có thể làm thêm các tác vụ khác.

Khi so sánh với cache thì ta có một số những sự khác biệt chính sau:

- cache là vùng lưu trữ tốc độ cao trong khi đó buffer chỉ là vùng lưu trữ bình thường trên ram
- cache được tạo từ static ram sẽ nhanh hơn là dynamic ram của Buffer
- buffer được dùng cho các tiến trình input/output, trong khi đó cache được dùng chính cho quá trình đọc ghi vào ổ đĩa.
- cache có thể được tạo từ 1 phần ổ đĩa trong khi buffer thì chỉ có thể được tạo từ ram
- buffer có thể được dử dụng trên bàn phím để chỉnh sửa lỗi trong khi cache thì không.

### 4. IOPS

IOPS - Input/Output operation per Second là đơn vị đo lường được sử dụng cho các thiết bị lưu trữ như HDD, SSD hoặc SAN – cho biết số lượng tác vụ Write hoặc Read được hoàn thành trong 1 giây. Số IOPS được publish bởi các nhà sản xuất thiết bị, và không liên quan gì đến các ứng dụng đo lường hiệu năng cả, tuỳ theo cảm tính mà các Sys Admin có thể dùng các ứng dụng đo lường khác nhau (như IOmeter, DiskSpd..).

Nói một cách dễ hiểu, thông số IOPS càng cao thì tốc độ xử lý càng nhanh, số tác vụ được xử lý sẽ nhiều hơn. Tuy nhiên, có trường hợp IOPS quá cao đến giới hạn vật lý sẽ gây ra tình trạng thắt cổ chai (IOPS quá cao --> Latency cao --> giảm throughput).

Đối với IOPS, thứ quan trọng nhất cần được chú ý đến là tỉ lệ Read và Write (thông thường tỉ lệ này là 70% (read) và 30 (Write) - có thể tùy chỉnh được).

**Throughput, latency và IOPS**

Đây là ba tham số quan trọng trong các hệ thống storage. Để dễ hiểu ba khái niệm này có thể map với hoạt động ship hàng từ điểm A đến B.

- số lượng chuyến đi thưc hiện trong một khoảng thời gian là IOPS
- số hàng chuyển được trong một khoảng thời gian chính là throughput
- latency là độ trễ trung bình trong tất cả các chuyến đi trong một khoảng thời gian đã thực hiện

Khoảng thời gian này giả sử là một ngày đi.

Ba tham số này, đặc biệt là hai tham số IOPS và latency phản ánh chất lượng phục vụ nhưng ko phải lúc nào cũng song hành với nhau kiểu một chỉ số tốt thì các chỉ số còn lại cũng tốt theo:

Có thể một ngày có nhiều chuyến hàng nhưng có những chuyến hàng chuyển nhanh, có chuyến hàng chuyển chậm, IOPS cao nhưng latency trung bình cũng lại cao.

Có thể một ngày có ít chuyến hàng nhưng mỗi chuyến lại chở full tải thì throughput lại cao dù IOPS thấp vì Throughput = IOPS * IO Average size (IO average size cao thì throughput cao)

Có thể latency trung bình thấp nhưng số hàng chuyển cũng không vì thế mà cao được do ít đơn hàng (application ít request vào storage)

Nhưng không phải vì thế mà các tham số này không có ảnh hưởng lên nhau:
khi IOPS quá cao, chạm đến giới hạn vật lý của hệ thống thì sẽ gây high latency
high latency không xử lý ngay sẽ làm giảm throughput vì data không thực sự được chuyển đến đúng nơi cần đến mà bị nghẽn lại ( busy cũng cao theo )

**IOPS sequential vs random**

Khi đo iops của hệ thống ta thường quan tâm tới các hoạt động tuần tự và ngẫu nhiên. Hoạt động tuần tự truy cập các vị trí trên thiết bị lưu trữ theo cách liền kề và thường được dùng với các kích thước truyền dữ liệu lớn, ví dụ: 128 kB. Hoạt động ngẫu nhiên truy cập các vị trí trên thiết bị lưu trữ theo cách không liền kề và thường được dùng với các kích thước truyền dữ liệu nhỏ, ví dụ: 4kB.

Đối với ổ cứng và các thiết bị lưu trữ cơ điện (HDD), số IOPS ngẫu nhiên chủ yếu phụ thuộc vào thời gian tìm kiếm ngẫu nhiên của thiết bị lưu trữ, trong khi đó, đối với SSD và các thiết bị lưu trữ trạng thái rắn tương tự, số IOPS ngẫu nhiên chủ yếu phụ thuộc vào bộ điều khiển bên trong và giao diện bộ nhớ tốc độ. Trên cả hai loại thiết bị lưu trữ, số IOPS tuần tự (đặc biệt là khi sử dụng kích thước khối lớn) thường biểu thị băng thông duy trì tối đa mà thiết bị lưu trữ có thể xử lý. Thông thường IOPS tuần tự được báo cáo dưới dạng số MB / s đơn giản như sau:

IOPS x TransferSizeInBytes  = BytesPerSec

<img src="https://i.imgur.com/Ww1aegV.png">

**Queue Depth**

Khi một ứng dụng yêu cầu dữ liệu từ bộ điều khiển đĩa, bộ điều khiển có trách nhiệm tìm nạp dữ liệu từ ổ đĩa vật lý. Giả sử chỉ có một yêu cầu về dữ liệu nổi bật, bộ điều khiển sẽ chỉ cần tìm nạp dữ liệu và trả lại cho ứng dụng. Nếu một bộ điều khiển có nhiều yêu cầu chưa xử lý tại bất kỳ thời điểm nào, nó được cho là có độ sâu hàng đợi bằng với số lượng yêu cầu chưa xử lý. Khi có nhiều yêu cầu nổi bật, bộ điều khiển đĩa có tùy chọn chọn chuỗi để phục vụ chúng và nó sẽ cố gắng tối ưu hóa thứ tự để đạt được thông lượng dữ liệu tối đa. Các yêu cầu cho các khối dữ liệu nằm "gần nhau" trên ổ đĩa vật lý thường sẽ được phục vụ theo tuần tự. Các thuật toán tinh vi làm tăng tỷ lệ thông lượng dữ liệu bằng cách đặt tối ưu các yêu cầu đang chờ xử lý.

Như vậy queue depth là độ sâu hàng đợi mà bộ nhớ có thể xử lí. SSD có thể loại bỏ điều này vì nó có độ trễ rất thấp.

### 5. File vs Block vs Object Storage

**file storage**

Bạn đặt tên cho tệp, gắn thẻ chúng với siêu dữ liệu, sau đó sắp xếp chúng trong các thư mục trong thư mục và thư mục con. Quy ước đặt tên tiêu chuẩn giúp chúng đủ dễ tổ chức trong khi các công nghệ lưu trữ như NAS cho phép chia sẻ thuận tiện ở cấp thấp hơn. Nhiều công ty yêu cầu một cách tập trung, dễ dàng truy cập để lưu trữ các tệp và thư mục. File storage có thể đáp ứng các yêu cầu này với chi phí thường phải chăng trên một ngân sách doanh nghiệp nhỏ.

Use Cases

- File sharing: If you just need a place to store and share files in the office, the simplicity of file-level storage is where it’s at.

- Local archiving: The ability to seamlessly accommodate scalability with a scale-out NAS solution makes file-level storage a cost effective option for archiving files in a small data center environment.

- Data protection: Combined with easy deployment, support for standard protocols, native replication, and various drive technologies makes file-level storage a viable data protection solution.

**Block storage**

Block storage là những raw volume chứa các file được chia nhỏ thành các mảnh dữ liệu bằng nhau. Hệ điều hành sẽ quản lí chsung và có thể sử dụng chúng như các ổ đĩa riêng biệt.

Use Cases

- Databases: Block storage is common in databases and other mission-critical applications that demand consistently high performance.

- Email servers: Block storage is the defacto standard for Microsoft’s popular email server Exchange, which doesn’t support file or network-based storage systems.

- RAID: Block storage can create an ideal foundation for RAID arrays designed to bolster data protection and performance by combining multiple disks as independent volumes.

- Virtual machines: Virtualization software vendors such as VMware use block storage as file systems for the guest operating systems packaged inside virtual machine disk images.

**Object Based Storage**

Nó lưu dữ liệu dưới dạng các container riêng biệt được gọi là các objects. Bạn có thể gán cho object một id duy nhât và lưu nó vào bộ nhớ. Điều này làm cho việc tìm kiếm dữ liệu rất dễ dàng. Ngoài ra, việc scale đối với object storage cũng rất dễ dàng. Việc truy cập tới object storage được thông qua rest api.

Use Cases

Big data: Object storage has the ability to accommodate unstructured data with relative ease. This makes it a perfect fit for the big data needs of organizations in finance, healthcare, and beyond.

Web apps: You can normally access object storage through an API. This is why it’s naturally suited for API-driven web applications with high-volume storage needs.

Backup archives: Object storage has native support for large data sets and near infinite scaling capabilities. This is why it is primed for the massive amounts of data that typically accompany archived backups.
