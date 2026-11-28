# Chạy nhắc chăm sóc bằng cron-job.org

Backend cung cấp `POST /api/v1/internal/reminders/run`. Đây là API nội bộ cho scheduler, không dùng token người dùng và không gửi secret xuống Flutter. Khi `CRON_SECRET` chưa cấu hình, API trả 503; thiếu/sai header trả 401.

## Render

Thêm `CRON_SECRET` trong Environment: chuỗi ngẫu nhiên ít nhất 32 ký tự, tối đa 256. Lưu và deploy. Không commit secret vào repo. Giữ nguyên database/Auth env của Web Service. Không cần migration hay Render Cron Job trả phí.

## cron-job.org

1. Tạo tài khoản tại https://console.cron-job.org/.
2. Create cronjob: URL `https://ai-plant-care.onrender.com/api/v1/internal/reminders/run`.
3. Lịch mỗi 5 phút (`*/5 * * * *`), phương thức POST.
4. Trong Advanced, thêm header `X-Cron-Secret`: đúng giá trị CRON_SECRET trên Render, không gồm `CRON_SECRET=`. Body có thể để trống.
5. Bật Enable job và Save để chạy tự động. Test Run chỉ chạy thử một lượt; xem lịch sử thực thi. Thành công trả HTTP 200 và số processed/notifications_created. Bật cảnh báo lỗi phù hợp.

Khi Render đang ngủ, lần gọi đầu có thể timeout trước khi máy chủ khởi động xong; kiểm tra lượt kế tiếp. Không cam kết nhắc chính xác từng phút. Không cấu hình lịch dày hơn chỉ để giữ máy chủ thức. Với nhiều cây, tác vụ có thể vượt thời gian chờ HTTP của dịch vụ cron; khi đó cần chia lô hoặc chuyển sang worker.

## Cơ chế và kết quả

Service dùng lại reminderService/carePlanner, đọc cây trong DB, đồng bộ lịch (thời tiết khi có đủ vị trí/môi trường), tạo thông báo đến hạn. Một advisory lock trong PostgreSQL chống chạy đồng thời giữa các lượt gọi API này; DB tự nhả khóa khi transaction/connection kết thúc. Không chạy thêm CLI --watch song song với cron này. Dữ liệu nhắc trùng được xử lý theo logic carePlanner hiện có. Partial failure trả 503 REMINDER_RUN_INCOMPLETE để theo dõi/thử lại; các cây đã xử lý có thể đã commit.

Kết quả 200 có `skipped: true, reason: ALREADY_RUNNING` nếu lượt trước còn chạy, hoặc `skipped: false, processed, failed, notifications_created`. 200 với 0 thông báo là bình thường nếu chưa đến hạn hoặc chưa đủ dữ liệu tạo lịch.

Frontend gọi GET /notifications và /notifications/unread-count để đọc hộp thư. Thông báo chăm sóc phù hợp được trigger DB đưa vào `push_deliveries` cho thiết bị đã đăng ký; cron HTTP chạy worker gửi FCM. Cần `PUSH_ENABLED`, Firebase Admin và quyền thông báo Android; xem [push](PUSH_NOTIFICATIONS.md). HTTP 200 không chứng minh điện thoại đã nhận: có thể không có việc đến hạn, không có thiết bị hoặc lượt gửi đang chờ thử lại. Trạng thái gửi thành công chỉ chứng minh FCM chấp nhận yêu cầu.

Test thực tế phải có cây test với dữ liệu chăm sóc/lịch hợp lệ và đến hạn. Không gửi secret qua query string hoặc log. Có thể đổi secret trên Render và cron-job.org cùng lúc nếu cần thu hồi.
