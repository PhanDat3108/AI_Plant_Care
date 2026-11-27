# Tích hợp push nhắc chăm sóc

Backend dùng Firebase Cloud Messaging (FCM). Lịch chăm sóc, lịch sử thông báo và thiết bị nằm trong PostgreSQL Supabase. Flutter cần tích hợp Firebase Messaging của project `ai-plant-care-9c78b`, xin quyền thông báo và đăng ký thiết bị với API dưới đây.

## Luồng gửi

1. Sau đăng nhập, Flutter gửi FCM registration token cùng một UUID ổn định cho lần cài app.
2. Khi tạo lời nhắc tưới/bón phân, trigger PostgreSQL tạo lượt gửi cho từng thiết bị đang hoạt động của chủ cây trong cùng transaction với thông báo.
3. Cron gọi `POST /api/v1/internal/reminders/run` mỗi 5 phút. Sau bước đồng bộ lịch, backend xử lý tối đa 20 lượt gửi đang chờ.
4. Firebase chấp nhận thì delivery chuyển sang `sent`. Người dùng đọc thông báo vẫn được ghi riêng trong `notifications.read_at`.
5. Lỗi tạm thời được thử lại ở các lượt cron sau. Một lần cài app đổi tài khoản sẽ được liên kết với tài khoản mới và hủy các lượt gửi còn chờ cho tài khoản cũ.

## Triển khai backend

Các thay đổi gồm migration `202611240001_push_notifications`, Firebase Admin SDK và biến môi trường dưới đây.

Trên Render đặt Secret File `firebase-admin.json` và cấu hình:

```ini
GOOGLE_APPLICATION_CREDENTIALS=/etc/secrets/firebase-admin.json
PUSH_ENABLED=true
```

Mặc định `PUSH_ENABLED=false` để có thể triển khai code trước khi bật gửi. Thực hiện theo thứ tự:

1. Cài dependencies và generate client trong thư mục backend.

   ```bash
   npm ci --include=dev
   npm run db:generate
   ```

2. Áp dụng migration vào database mà backend dùng. Kiểm tra `DIRECT_URL` đang trỏ đúng database.

   ```bash
   npm run db:migrate
   npm run db:status
   ```

3. Deploy code mới trên Render và bật `PUSH_ENABLED=true` cùng đường dẫn credential.
4. Giữ cron đã cấu hình với method POST, header `X-Cron-Secret` và URL `https://ai-plant-care.onrender.com/api/v1/internal/reminders/run`.
5. Backend local có thể khai báo đường dẫn khóa trước khi chạy lệnh kiểm tra FCM.

   ```bash
   export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.config/ai-plant-care/firebase-admin.json"
   npm run push:check
   ```

Lệnh `push:check` dùng FCM dry-run để xác minh khóa và quyền gửi. Nó có thể chạy cả khi `PUSH_ENABLED=false`. Chỉ kiểm thử nhận trên điện thoại mới xác nhận được quyền Android và hiển thị thông báo.

## API dành cho Flutter

Base URL là `https://ai-plant-care.onrender.com/api/v1`. Các request đều cần `Authorization: Bearer <Supabase access_token>`.

### Đăng ký hoặc cập nhật thiết bị

`POST /notifications/devices`, JSON body:

```json
{
  "installation_id": "9f87c98e-13fb-4841-bc8f-50c3f82d910b",
  "token": "<FCM registration token từ FirebaseMessaging.getToken()>",
  "platform": "android"
}
```

- Flutter tạo UUID `installation_id` một lần và lưu trên điện thoại. Dùng lại UUID đó khi token thay đổi hoặc đổi tài khoản.
- `platform` nhận `android` hoặc `ios`. iOS cần cấu hình APNs riêng trước khi kiểm thử.
- Token có độ dài 20–4096 ký tự, không chứa khoảng trắng.
- Gọi sau đăng nhập, khi app mở với phiên hợp lệ và khi `onTokenRefresh` trả token mới.
- Backend lấy chủ sở hữu từ phiên đăng nhập. Body chỉ nhận ba trường trên.
- Có thể gọi trước lần đầu GET /me. Backend tạo hồ sơ cơ bản nếu cần.
- Chế độ DEV_AUTH_BYPASS trả 403 cho đăng ký push. Dùng tài khoản Supabase thật.

Phản hồi HTTP 200:

```json
{
  "success": true,
  "data": {
    "id": "<UUID bản ghi thiết bị>",
    "installation_id": "9f87c98e-13fb-4841-bc8f-50c3f82d910b",
    "platform": "android",
    "active": true
  },
  "error": null,
  "message": "OK"
}
```

Lưu `data.id` để gỡ thiết bị. API không trả token. Cùng installation của cùng người dùng sẽ giữ ID khi đăng ký lại hoặc đổi token. Khi đổi người dùng, API trả ID mới.

### Gỡ thiết bị khi đăng xuất hoặc tắt push

`DELETE /notifications/devices/:id`.

Gọi bằng phiên hiện tại trước `POST /auth/logout` và trước khi xóa token đăng nhập. Khi API gỡ thành công, xóa ID thiết bị đã lưu. Nếu mất mạng, thông báo cho người dùng rằng việc ngừng push trên server cần được thử lại khi có kết nối.

Phản hồi HTTP 200 có `data: { "removed": true }`. Gọi lặp hoặc dùng ID ngoài tài khoản trả `removed: false`. Backend xóa các delivery còn chờ qua khóa ngoại cascade. API đăng xuất hiện tại cần đi cùng bước gỡ thiết bị này để ngừng push trên đúng máy.

### Xử lý push

Payload có phần `notification` gồm `title`, `body` và phần `data`:

```json
{
  "notification_id": "<UUID thông báo>",
  "kind": "water",
  "screen": "notifications"
}
```

- Android ở nền dùng payload notification để hiện thông báo khi đã được cấp quyền.
- Khi app đang mở, Flutter xử lý `onMessage` để hiển thị thông báo hoặc làm mới biểu tượng chuông.
- Bấm thông báo mở màn lịch sử thông báo sau khi kiểm tra phiên đăng nhập. Xử lý cả `getInitialMessage` và `onMessageOpenedApp`.
- Dùng `notification_id` để chống xử lý lặp. Backend đặt cùng Android notification tag cho các lần thử của một lời nhắc.
- Lấy nội dung đầy đủ bằng API lịch sử hiện có. Nội dung push được cắt còn tối đa 500 ký tự.
- Gọi `PATCH /notifications/:id/read` khi người dùng thực sự xem thông báo.

## Cơ chế thử lại và giới hạn

`push_deliveries` có các trạng thái `pending`, `processing`, `sent`, `failed`, `skipped`. Các worker lấy lượt gửi bằng khóa hàng và SKIP LOCKED. Lease 15 phút cho phép lấy lại công việc sau khi process bị dừng. Tối đa 8 lần thử, thời gian chờ tăng từ 1 phút đến tối đa 1 giờ. Lời nhắc hết hạn sau 24 giờ kể từ lúc tạo.

Thiết bị đăng ký mới chỉ nhận lời nhắc được tạo sau thời điểm đăng ký. Các thông báo trước migration giữ trong lịch sử. Token hết hiệu lực được vô hiệu hóa. Một lỗi của token cũ sẽ không vô hiệu hóa token vừa được refresh.

Backend kiểm tra lại công việc trước khi gửi. Thông báo đã đọc, công việc đã hoàn thành/bị xóa, lịch bị tắt và thiết bị đã gỡ sẽ được bỏ qua. Lượt gửi đã được Firebase tiếp nhận trước khi người dùng đăng xuất vẫn có thể đến máy.

FCM và database là hai hệ thống riêng. Nếu FCM đã nhận nhưng server dừng trước khi ghi trạng thái, lần thử lại có thể gửi trùng. Android dùng cùng tag và Flutter xử lý theo notification_id để hạn chế trùng. `sent` ghi nhận FCM chấp nhận yêu cầu, còn việc điện thoại nhận phụ thuộc mạng và quyền thông báo.

Cron trả thêm trường `data.push`:

```json
{
  "enabled": true,
  "claimed": 2,
  "sent": 1,
  "retry": 1,
  "failed": 0,
  "skipped": 0
}
```

Kiểm tra các bộ đếm này cùng `push_deliveries.last_error`. HTTP 200 vẫn có thể kèm lượt gửi đang chờ thử lại. Chỉ ghi mã lỗi trong DB, giữ kín token và khóa. Chạy cron mỗi 5 phút có thể khiến lời nhắc đến muộn vài phút. Render khởi động lại hoặc điện thoại mất mạng có thể kéo dài thời gian này.

## Kiểm thử

```bash
npm run typecheck
npm run lint
npm test
npm run test:db:isolated
npm run build
```

Bộ DB test tạo PostgreSQL tạm để kiểm tra migration, enqueue nguyên tử, quyền sở hữu, refresh token, đổi tài khoản, gửi đồng thời, lease hết hạn, backoff và hủy lời nhắc. Dữ liệu và FCM sender trong test đều là fixture.

Kiểm thử trên Android sau khi tích hợp Flutter:

1. Đăng nhập, cho phép thông báo và đăng ký thiết bị.
2. Tạo lịch tưới đến hạn cho cây test rồi đưa app về nền.
3. Đợi cron, kiểm tra `data.push.sent`, máy nhận push và màn lịch sử có thông báo.
4. Chạy cron lần nữa để kiểm tra lượt đã sent được bỏ qua.
5. Gỡ thiết bị, đăng xuất rồi thử một lời nhắc mới để kiểm tra máy đã ngừng nhận theo tài khoản cũ.

## Nhắc lại việc quá hạn (backend, 27/11/2026)

Sau thông báo đến hạn đầu tiên, nếu nhiệm vụ còn pending và lịch vẫn bật, backend tạo tối đa một thông báo nhắc lại mỗi ngày theo múi giờ tài khoản, từ giờ local_time của lịch trở đi. Nội dung là “Bạn chưa ghi nhận tưới nước/bón phân”, kèm tên cây và lời nhắc kiểm tra trước khi chăm sóc. Đọc thông báo không có nghĩa đã hoàn thành nhiệm vụ.

Event key gốc `care-task:<task-id>` giữ nguyên; lần nhắc lại dùng `care-task:<task-id>:overdue:<YYYY-MM-DD>`. Unique index sẵn có chống trùng giữa cron và đồng bộ thủ công. Push nhận diện cả hai dạng key và kiểm tra nhiệm vụ vẫn pending, lịch bật, thiết bị còn active trước khi gửi. Không cần migration, không đổi hợp đồng API/frontend.

Ghi nhật ký chăm sóc cập nhật chu kỳ; hoàn thành nhiệm vụ hoặc tắt lịch dừng nhắc lại cho nhiệm vụ đó. Backend không tự coi cây đã được tưới, không đẩy ngày due_at để che việc quá hạn. Nhãn “Lần nhắc tiếp theo” trên frontend vẫn có thể hiển thị ngày cũ.

Cần cron-job.org bật và gọi endpoint reminders/run thành công. Cron 5 phút/lần sẽ gửi ở lượt chạy đầu tiên từ giờ đặt trở đi, không bảo đảm chính xác đến từng giây. Nếu bỏ lỡ nhiều ngày, không gửi bù một loạt thông báo từng ngày. Lần thông báo gốc chưa từng được tạo vẫn được xử lý theo cơ chế catch-up hiện tại, sau đó nhắc lại hằng ngày; không tạo thêm nhắc lại trong cùng ngày với thông báo gốc.

## Chống gọi dồn Open-Meteo

Các luồng HTTP đồng bộ, tạo care data và cron dùng chung provider trong một tiến trình backend: cache kết quả hợp lệ 1 giờ theo tọa độ/múi giờ, gộp yêu cầu cùng vị trí. Không phát nhiều request thời tiết khác vị trí đồng thời; vị trí chưa lấy được giữ lịch cũ và có thể thử ở lượt sync sau.

HTTP 429 kích hoạt cooldown chung ít nhất 15 phút, tăng gấp đôi khi tiếp tục lỗi (phần backoff tối đa 24 giờ). Tôn trọng Retry-After dạng số giây hoặc HTTP date nếu yêu cầu chờ lâu hơn. Log WEATHER_RATE_LIMITED có retry_at UTC, không in tọa độ. Trong cooldown vẫn dùng cache còn hạn; không dùng dự báo hết hạn hoặc bịa dự báo để báo thành công.

Cache/cooldown nằm trong bộ nhớ: mất khi restart và không chia sẻ giữa nhiều process/replica. Không thể bảo đảm hết 429 nếu IP hosting dùng chung bị nhà cung cấp giới hạn. Không cần API key hay thay đổi frontend cho bản sửa này.
