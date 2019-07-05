# Placement Groups

Khi tạo pool, bạn sẽ buộc phải khai báo `pg_num`. Dưới đây là một số giá trị thường được dùng.

- Dưới 5 OSD giá trị thường là 128
- Từ 5-10 OSD giá trị thường là 512
- từ 10-50 giá trị thường là 1024

**PGs được sử dụng như thế nào?**

<img src="https://i.imgur.com/1AGaxwa.png">

Ceph client sẽ tính toán đâu là pg mà object nên được đặt vào.

Các objects trong cùng 1 pg sẽ được lưu xuống 1 set OSDs. Ví dụ nếu replicate size là 2 thì pg sẽ lưu xuống 2 OSD.

<img src="https://i.imgur.com/Pz9qiaN.png">

Nếu một OSD bị hỏng, sẽ có 1 cái khác được assign vào trong pg và osd mới này sẽ được fill bởi các nhận bản của toàn bộ dữ liệu trên osd trong cùng pg với nó. Nếu số replicate thay đổi từ 2 sang 3 thì sẽ có thêm 1 OSd nữa được thêm vào. PGs không sở hữu OSD, nó share OSD với các PG khác .

**Tradeoffs**

Độ bền và sự phân phối dữ liệu sẽ yêu cầu nhiều PG nhưng số lượng PG nên được giảm thiểu để tránh việc tốn quá nhiều tài nguyên RAM vs CPU.

**Lựa chọn số PGs**

Nếu bạn có trên 50 OSD thì con số được khuyến cáo đó là 50-100 PGs trên 1 OSD.

Đối với từng pool, ta có công thức sau

```
             (OSDs * 100)
Total PGs =  ------------
             pool size
```

**Set số lượng pg**

Sau khi set số lượng khi tạo pool, bạn chỉ có thể tăng số lượng pg chứ không thể giảm.

`ceph osd pool set {pool-name} pg_num {pg_num}`

Một khi bạn thay đổi số lượng pg thì bạn cũng phải thay đổi số lượng pgp trước khi cluster thực hiện rebalance. Đây là số lượng của pg sẽ được CRUSH xem xét tới để đặt. Việc tăng số lượng pg sẽ làm cho dữ liệu được migrate sang pg mới. Tuy nhiên hành động này sẽ không được thực thi nếu như số lượng pgp chưa được tăng. Số lượng pgp được khuyến cáo là nên bằng với số lượng pg.

`ceph osd pool set {pool-name} pgp_num {pgp_num}`

**Lấy số lượng pg**

`ceph osd pool get {pool-name} pg_num`

**Lấy thông số pg**

`ceph pg dump [--format {format}]`

format ở đây có plain và json.

**Lấy thông tin về các stuck pg**

`ceph pg dump_stuck inactive|unclean|stale|undersized|degraded [--format <format>] [-t|--threshold <seconds>]`

**Lấy PGs map**

`ceph pg map {pg-id}`

**Lấy thông số pg**

`ceph pg {pg-id} query`

**Scrub một pg**

`ceph pg scrub {pg-id}`

**Ưu tiên BACKFILL/RECOVERY trên 1 pg**

```
ceph pg force-recovery {pg-id} [{pg-id #2}] [{pg-id #3} ...]
ceph pg force-backfill {pg-id} [{pg-id #2}] [{pg-id #3} ...]
```

**Revert lost**

Nếu PG lost 1 hoặc nhiều object và bạn từ bỏ việc tìm kiếm nó, thì bạn sẽ phải đánh dấu rằng object đó đã `lost`

`ceph pg {pg-id} mark_unfound_lost revert|delete`
