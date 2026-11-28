# Hồ sơ nộp và demo

## Checklist

- [ ] Link Git giảng viên đọc được; mỗi thành viên có commit.
- [ ] Người mới làm theo README và chạy Android, ghi thời gian thực tế.
- [ ] APK release ký riêng, kiểm tra Google login và push trên chính APK đem nộp.
- [ ] Video máy thật 3–5 phút.
- [ ] Báo cáo ≤10 trang: kiến trúc, quyết định kỹ thuật, test, hạn chế.
- [ ] Slide ≤10 trang.
- [ ] Bảng phân công, phần trăm đóng góp và xác nhận thành viên.
- [ ] README mục Dùng AI và docs/ai đã lọc bí mật.
- [ ] Rà soát secret toàn bộ lịch sử Git, thu hồi nếu từng lộ.

## Kịch bản quay 4–5 phút

1. 0:00–0:30: giới thiệu, mở app trên máy thật; dùng tài khoản thử riêng chưa có cây để thể hiện trạng thái trống.
2. 0:30–1:30: nhận diện ảnh cây, đọc kết quả, lưu vào vườn; dùng ảnh có quyền sử dụng.
3. 1:30–2:15: mở cây, đổi tên, xem hướng dẫn; chẩn đoán ảnh bệnh đã chuẩn bị.
4. 2:15–3:00: sửa lịch tưới, xem lần nhắc tiếp theo, nhật ký và nhiệm vụ.
5. 3:00–3:45: tắt mạng, tải lại màn dữ liệu, quay thông báo lỗi và thao tác thử lại sau khi bật mạng.
6. 3:45–4:30: thông báo, hồ sơ; mô tả hạn chế và cấu trúc hệ thống. Chỉ quay push nếu đã xác nhận lịch đến hạn, cron bật và quyền thông báo được cấp; không hứa giờ chính xác khi cron chạy định kỳ.

Không dùng ảnh quay từ máy ảo thay cho bằng chứng máy thật. Không quay khóa cấu hình hoặc tài khoản cá nhân.

## Phiếu phản hồi người thử thật

Trạng thái: CHƯA THU THẬP. Sao chép bảng cho mỗi lần thử; chỉ điền từ trải nghiệm thực.

| Mục | Nội dung người thử điền |
|---|---|
| Ngày, bản APK/commit | |
| Bí danh người thử, đồng ý ghi phản hồi | |
| Thiết bị, Android | |
| Tác vụ đã làm | |
| Tác vụ thành công/thất bại | |
| Lỗi và bước tái hiện | |
| Nhận xét, đề xuất | |
| Người xử lý và kết quả kiểm tra lại | |

## Bảng đóng góp

Nhóm điền tên, phần phụ trách, liên kết commit, phần trăm (tổng 100%), phần đã tự chạy và khả năng giải thích. Không suy ra tỷ lệ từ số commit vì một người có thể dùng nhiều tên Git.

## Danh mục bàn giao

| Hạng mục | Vị trí / phần cần bổ sung |
|---|---|
| Repository | Điền link và xác nhận giảng viên có quyền đọc |
| README | README gốc + frontend/backend; cần người mới chạy thử và ghi thời gian |
| APK | Build theo RELEASE.md; thêm link tải bản đã test, commit và checksum |
| Video máy thật 3–5 phút | Chưa có link trong hồ sơ; quay cả luồng lỗi và dữ liệu trống |
| Báo cáo ≤10 trang | Thêm file/link bản cuối |
| Slides ≤10 trang | Thêm file/link bản cuối |
| Bảng đóng góp | Điền bảng dưới, tổng 100%, cả nhóm xác nhận |
| Hồ sơ AI | docs/ai; thành viên bổ sung phần sử dụng thực tế đã lọc bí mật |

| Thành viên | Phần phụ trách thực tế | Commit/PR | Tỷ lệ | Đã tự kiểm thử và giải thích |
|---|---|---|---|---|
| Điền tên từng thành viên | | | | |

## Đối chiếu rubric

| Tiêu chí | Điểm tối đa | Bằng chứng và giới hạn |
|---|---:|---|
| Chức năng | 20 | Đã có các module chính; cần demo end-to-end, recovery mobile chưa hoàn chỉnh |
| UI/UX | 15 | Cần kiểm tra loading/lỗi/trống, màn nhỏ/lớn và tap target toàn app |
| Kiến trúc/state | 15 | FE tách screens/services/models; BE route/controller/service; thành viên phải giải thích mã |
| Dữ liệu/xử lý lỗi | 10 | Owner checks, validation, fallback thời tiết; cần kiểm thử mạng thật |
| Kiểm thử | 10 | Flutter 19 test gồm widget; backend unit + DB; xem TEST_RESULTS.md |
| Bảo mật | 10 | Auth, owner scope, secrets phía server; chưa chứng nhận toàn bộ lịch sử Git sạch |
| Tài liệu/quy trình | 10 | README/docs/AI đã có; còn bảng đóng góp và bằng chứng người mới chạy ≤15 phút |
| Trình bày | 10 | Chấm qua video, slide và bảo vệ trực tiếp; chưa thể chấm từ code |

Điểm cộng tối đa 10: AI qua backend (3), CI analyze/test (2), trợ năng hoặc song ngữ (2), APK release ký (2), phản hồi người dùng thật (1). Có cấu hình/test riêng lẻ chưa đồng nghĩa đạt trọn điểm: cần Actions của commit nộp, APK thực tế, demo AI và bằng chứng trợ năng phù hợp. App chưa song ngữ. Không tự điền phản hồi hoặc điểm trình bày khi chưa thực hiện.
