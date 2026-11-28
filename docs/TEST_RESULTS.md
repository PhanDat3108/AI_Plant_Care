# Kết quả kiểm tra — 28/11/2026

Kiểm tra working tree dựa trên commit `a365623`, gồm các sửa lỗi Auth và quyền nhật ký chưa commit. Không phải chứng nhận production hoặc mọi chức năng không còn lỗi.

| Kiểm tra | Kết quả |
|---|---|
| Backend lint, typecheck, build | Đạt |
| Flutter analyze --no-pub | Không có vấn đề |
| Flutter test --no-pub | 19/19 đạt |
| Backend unit | 163/163, 20 file |
| PostgreSQL tạm `test:db:isolated` | 54/54, 6 file; áp đủ 9 migration |

Test mới kiểm tra: không trả nhật ký của người khác khi gửi lại request ID; từ chối JSON Auth hỏng/rỗng và token sai kiểu/trống; đăng ký trả session hợp lệ; logout nhận 204. HTTP nhà cung cấp được mock; DB integration dùng cluster tạm, không ghi Supabase chung.

Các mục chưa nghiệm thu: toàn bộ màn hình trên máy thật, SMTP/recovery mobile, giao nhận FCM thật, cấu hình Render hiện tại, hiệu năng nhiều người dùng và rà soát secret toàn bộ nội dung lịch sử Git. Xem [hồ sơ nộp](SUBMISSION.md). Kết quả phía dưới là lịch sử, không phải số test hiện tại.

---

## Lịch sử kiểm tra — 27/11/2026

Kiểm tra trên working tree trong lượt hoàn thiện hồ sơ; chưa phải chứng nhận toàn bộ chức năng production.

| Kiểm tra | Kết quả |
|---|---|
| Backend `npm run typecheck` | Đạt |
| Backend `npm test` | 136/136, 18 file đạt |
| Flutter `flutter analyze` | Không có vấn đề |
| Flutter `flutter test` | 19/19 đạt |
| Trợ năng widget nút chính | Android tap target và labeled tap target đạt |

## Thay đổi test backend

Test nền tảng từng gọi `/plants`, trong khi router hiện mount `/garden`. Đổi sang route thật và giữ kiểm tra owner lấy từ token, không lấy từ query. Kiểm tra UUID tại garden; kiểm tra giới hạn phân trang tại notifications (garden hiện trả toàn bộ danh sách, không áp dụng tham số limit của test cũ).

Mock fetch phải tạo Response mới cho mỗi lần gọi: garden hiện có middleware xác thực cả ở router cha và router con; tái sử dụng một Response khiến body đã đọc, dẫn tới lỗi giả trong test. Việc xác thực hai lần là điểm có thể tối ưu sau, chưa thay đổi hành vi middleware trong lượt này.

## Test Flutter bổ sung

- Email thiếu/sai định dạng/khoảng trắng.
- Mật khẩu đăng nhập và biên độ dài mật khẩu đăng ký.
- Tên trống, xác nhận mật khẩu sau khi sửa mật khẩu gốc.
- Lưu/thay cặp token, xóa cả hai khi đăng xuất.
- Chặn gửi lặp trong lúc nút loading và cho gửi lại khi hết loading.
- Trợ năng nút chính; chưa phải đánh giá trợ năng toàn bộ app.

Các test hiện có tiếp tục kiểm tra URL ảnh, preview lịch, chỉnh lịch và điều hướng.

## Chưa kiểm tra trong lượt này

Database integration tests, tất cả màn hình trên máy thật, hiệu năng, lịch sử Git chứa secret, Google login/push trên chứng chỉ release mới. Video demo và phản hồi người dùng cần thực hiện theo SUBMISSION.md. Không tính template chưa điền là bằng chứng người dùng thử.

## Đóng gói

`flutter build apk --release` đạt; APK 57,7 MB. `apksigner verify --print-certs` xác nhận chứng chỉ riêng AI Plant Care. Checksum và fingerprint nằm trong RELEASE.md. Khóa ký và mật khẩu được Git ignore, không được đưa vào hồ sơ nộp. Còn cảnh báo tương thích KGP tương lai của camera_android_camerax; chưa sửa dependency vì SDK hiện tại build thành công.

## Bổ sung: nhắc quá hạn hằng ngày — 27/11/2026

Sau thay đổi backend: unit test 136/136 đạt; database integration test trên PostgreSQL tạm riêng 54/54 đạt (6 file). Không chạy test này trên Supabase production. Đã sửa thêm hai test foundation dùng route `/plants` cũ sang `/garden`.

Kiểm tra mới: đúng giờ địa phương, không gửi sớm, chống trùng khi hai lượt sync đồng thời, ngày địa phương khác UTC, không gửi bù dồn các ngày bỏ lỡ, không lặp cùng ngày với thông báo gốc, dừng khi hoàn thành/tắt lịch, thông báo quá hạn vào hàng đợi push và không gửi nếu đã hoàn thành trước lúc worker xử lý. Provider push được giả lập; chưa xác minh giao nhận FCM thật hoặc triển khai Render cho thay đổi này.

## Bổ sung: xử lý Open-Meteo 429

Backend typecheck/build đạt, unit test 143/143, database tạm 54/54 đạt. Bảy test provider mới kiểm tra dùng chung instance, gộp bấm lặp, cooldown toàn vị trí, Retry-After số giây/HTTP date, backoff khi lỗi lặp, cache còn hạn trong cooldown và tránh request khác vị trí đồng thời. HTTP được giả lập; chưa xác nhận nhà cung cấp đã gỡ giới hạn cho IP Render.
