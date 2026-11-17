# Bàn giao backend chức năng 1, 2, 5 và lịch sử thông báo

Phạm vi theo **mục I** của `AI Plant Care (1).docx`: Auth, Hồ sơ, Lịch chăm sóc. Frontend không được thay đổi. Backend đã có thể tạo lịch theo loài, đọc dự báo thật, tạo việc đến hạn và ghi thông báo vào hộp thư ứng dụng, trước khi module AI hoàn thành.

## Trạng thái và phần còn chờ

| Phần | Trạng thái / phụ thuộc |
| --- | --- |
| Đăng ký, đăng nhập, email/Google, khôi phục, logout | Có sẵn; xem AUTH_SETUP.md |
| Hồ sơ: tên, email, ảnh Google, số cây/số quét | Đã làm; chưa có cây/quét thì trả 0 |
| Xem/chỉnh/bật/tắt lịch tưới/bón phân | Đã làm trên cây thuộc người gọi |
| Khởi tạo lịch từ chu kỳ loài và sinh việc | Đã làm; không cần gọi AI trong module này |
| Điều chỉnh hạn theo Open-Meteo | Đã làm cho cây ngoài trời có vị trí, có snapshot/lý do |
| Việc trong ngày theo múi giờ | Đã làm API đọc |
| Tạo thông báo đến hạn + xem lịch sử/đánh dấu đã đọc | Đã làm; chống ghi trùng theo lần chăm sóc |
| Gọi planner ngay sau quét/thêm cây | **Chờ module 3/4**: sau khi lưu cây/loài thành công thì gọi dịch vụ sync; không code module quét hoặc thêm cây ở đây |
| Đánh dấu hoàn thành / nhật ký / điều trị | **Chờ module 6**; planner đã đọc care_logs để tính chu kỳ kế tiếp, không tự giả lập đã tưới |
| Push FCM/APNs lên điện thoại | **Chưa code**: cần chốt nhà cung cấp, device token, credentials và quyền thông báo từ app. Hộp thư trong DB không đồng nghĩa đã gửi push |
| Dark Mode, thông tin app, avatar mặc định | UI/cài đặt thiết bị; không cần API mới |

Mật khẩu backend hiện tối thiểu 8 ký tự (tài liệu mô tả tối thiểu 6). Frontend cần thống nhất hiển thị giới hạn 8 đang dùng, không gửi ô confirm_password.

## Thiết lập / chạy

Chạy tại `backend` với Node.js 24:

```sh
npm ci
npm run db:generate
npm run db:status
npm run dev
```

Hai migration mới đã được áp trên Supabase chung: `202611160001_notifications` và `202611160002_smart_care`. Project DB mới hoặc DB local cần người quản lý chạy `npm run db:migrate`. Không seed/test ghi fixture lên Supabase chung.

Mở terminal khác trong backend để chạy tác vụ nhắc liên tục:

```sh
npm run reminders:watch
```

Mỗi lượt quét theo batch 50 cây, chạy tuần tự; đợi 60 giây sau khi lượt trước xong. Ctrl+C dừng. Chế độ này giữ cache thời tiết 1 giờ giữa các lượt. Chạy đúng một lượt bằng `npm run reminders:run`. Sau build có thể dùng `node dist/jobs/reminders.js --watch` trong tiến trình worker được host quản lý. Server API **không tự khởi động worker**. Tắt máy/worker thì không có tác vụ nền; phải host cả API lẫn worker để nhắc khi mọi người không mở máy.

Open-Meteo không cần API key cho bản giáo dục/phi thương mại này; khi chuyển sang thương mại cần kiểm tra gói/điều khoản của nhà cung cấp. Tọa độ cây được gửi tới Open-Meteo để lấy dự báo. Không tự lấy vị trí GPS người dùng; API vườn cây của nhóm cần nhận vị trí do người dùng chọn và được phép lưu.

## Hợp đồng với bạn làm AI / vườn cây / nhật ký

Module AI/vườn cây lưu các trường hiện đã có trong DB:

- `plants.owner_id`: UUID Auth, `species_id`: loài đã xác định hoặc null.
- `plant_species.watering_days`, `fertilizing_days`: chu kỳ nguyên 1–365 ngày từ nguồn chăm sóc đã thống nhất; ghi `care_source`. Không biến phần trăm confidence thành chu kỳ. Planner chỉ dùng loài `care_status=verified` để khởi tạo lịch. Gemini tạo đề xuất riêng, xem [API bổ sung và duyệt dữ liệu](CARE_DATA_AI.md).
- `plants.environment`: indoor/outdoor/unknown. `latitude`, `longitude`: cặp tọa độ hợp lệ hoặc cả hai null.
- `profiles.timezone`: múi giờ IANA, mặc định Asia/Ho_Chi_Minh.

Sau khi transaction thêm cây/ghi kết quả **đã commit**, gọi `carePlanner(db, weather).sync(ownerId, plantId)` hoặc endpoint tương ứng. Không gọi sync trong transaction đang giữ khóa cùng cây. Worker cũng sẽ phát hiện cây mới ở lượt chạy tiếp theo.

Quy ước module 6: đánh dấu done và tạo care_log có task_id/plant_id/kind đúng trong cùng transaction; retry giữ cùng request_id. Với chăm sóc ngoài lịch, care_log vẫn phải có plant_id/kind/performed_at chính xác. Khóa dòng plant trước rồi task khi thao tác đồng thời với planner để tránh tạo việc sai trong lúc sửa lịch. Không đặt state=done mà không ghi nhật ký: planner trả cảnh báo CARE_LOG_REQUIRED_* và không tự tạo lịch tiếp bằng dữ liệu đoán.

## Chính sách lịch và thời tiết (MVP v1)

- Khởi tạo 2 lịch water/fertilize nếu loài đã duyệt có chu kỳ tương ứng. Giờ mặc định 08:00 theo timezone hồ sơ. Loài chưa duyệt trả `CARE_DATA_REVIEW_REQUIRED`; loài đã duyệt nhưng thiếu chu kỳ thì bỏ qua loại việc đó và trả cảnh báo. Lịch thủ công đã tồn tại vẫn được giữ.
- Chu kỳ nền tính từ ngày bắt đầu lịch, hoặc lần chăm sóc cùng loại mới nhất nếu muộn hơn. Mỗi lịch giữ một việc pending. Chưa hoàn thành thì giữ việc quá hạn, không tự đánh dấu đã tưới và không tạo vô hạn việc trùng.
- Lịch đã chỉnh tay được giữ nguyên; sync không ghi đè chu kỳ/giờ/enabled bằng dữ liệu loài. Khi đổi loài, nhóm cần quyết định có reset lịch hay không; hiện vẫn giữ lịch đã tồn tại.
- PUT thay đổi quy tắc sẽ đặt starts_at mới, bỏ qua các việc pending cũ, giữ việc done/nhật ký. Lượt sync tiếp theo tính lại. PUT cùng dữ liệu không reset chu kỳ. Bật lại cùng ngày khôi phục đúng occurrence nếu nó bị skipped do sửa lịch.
- Múi giờ được tính bằng Temporal, không cộng cứng 24 giờ khi qua ngày đổi DST.
- Chỉ điều chỉnh **nhắc tưới cho cây ngoài trời**. Mưa dự báo vào ngày hạn gốc ≥5 mm và xác suất ≥60% → lùi 1 ngày. Nếu không có điều kiện mưa này, dự báo ngày trước hạn nóng ≥35°C và mưa <1 mm, chu kỳ ≥3 ngày → nhắc **kiểm tra độ ẩm** sớm 1 ngày.
- Các ngưỡng trên là quy tắc sản phẩm minh bạch, chưa phải mô hình độ ẩm đất/tối ưu sinh học. Thông báo yêu cầu kiểm tra đất trước khi tưới; không kết luận phải tưới chỉ dựa vào nhiệt độ.
- Không tự đổi lịch bón phân theo thời tiết khi chưa có quy tắc chuyên môn. Cây trong nhà/unknown giữ lịch nền; chuyển vào nhà sẽ gỡ điều chỉnh thời tiết chưa thông báo.
- Luôn tính từ original_due_at, không lùi thêm một ngày ở mỗi lượt chạy. Không sửa hạn của việc đã phát thông báo. Thời tiết lỗi, thiếu giá trị hoặc quá cũ thì giữ due_at hiện tại. Ngoài cửa sổ dự báo 7 ngày dùng lịch nền, các lượt sau cập nhật khi đến gần.
- Khi due_at ≤ hiện tại, tạo một notification với event_key theo task ID. Rerun/concurrent worker không tạo trùng. Nội dung lịch sử là snapshot, vẫn còn khi cây bị xóa. Không lặp nhắc mỗi ngày cho một task chưa hoàn thành.

## API cho frontend

Mọi API cần Bearer token; tiền tố `/api/v1`. Response chung `{success,data,error,message}`. Người dùng không được truyền owner_id để chọn dữ liệu người khác; sai chủ trả 404.

### Hồ sơ

`GET /me` bổ sung:

```json
{
  "id": "uuid",
  "display_name": "Đạt",
  "email": "user@example.com",
  "avatar_url": "https://...",
  "timezone": "Asia/Ho_Chi_Minh",
  "total_plants": 2,
  "total_ai_scans": 5,
  "isDemo": false
}
```

Email và URL avatar lấy từ phản hồi Auth đã xác minh, không dùng metadata email làm danh tính. URL avatar chỉ chấp nhận HTTPS; null thì frontend dùng ảnh mặc định. `avatar_key` cũ không phải URL tải ảnh. `total_ai_scans` đếm tất cả bản ghi scans của chủ (gồm bản demo nếu được lưu), không đếm request lỗi chưa lưu.

`PATCH /me` vẫn nhận `{display_name, timezone}`. Sau cập nhật có thể GET lại để lấy đầy đủ thống kê.

### Lịch và công việc

| API | Dùng để |
| --- | --- |
| GET /plants/:id/schedules | `{timezone, items}`; local_time trả HH:mm |
| PUT /plants/:id/schedules/water | Tạo/sửa toàn bộ lịch tưới |
| PUT /plants/:id/schedules/fertilize | Tạo/sửa toàn bộ lịch bón phân |
| POST /plants/:id/care-plan/sync | Body `{}`; tạo lịch mặc định còn thiếu, tính việc và điều chỉnh thời tiết, tạo inbox nếu đến hạn |
| GET /care-tasks?date=2026-11-20&state=pending&limit=20&offset=0 | Việc trong ngày theo timezone hồ sơ; bỏ date để dùng hôm nay |

Body PUT:

```json
{"interval_days":7,"local_time":"08:30","enabled":true}
```

Cần đủ cả ba trường. interval_days 1–365, giờ HH:mm hợp lệ, enabled boolean. Loại treat/phun thuốc chưa có lịch tự động vì thiếu chỉ định điều trị; không tự suy ra từ lịch tưới.

Sync trả `{plant_id, timezone, tasks, notifications_created, warnings, weather_source}`. Task có original_due_at, due_at, state, adjustment_reason, weather_snapshot. Snapshot gồm nguồn, ngày dự báo, lượng mưa, xác suất, nhiệt độ, thời điểm lấy và phiên bản policy. Frontend hiển thị lý do đổi lịch, ghi nguồn Open-Meteo khi hiển thị dữ liệu thời tiết.

Cảnh báo thường gặp: MISSING_WATER_INTERVAL, MISSING_FERTILIZE_INTERVAL, LOCATION_REQUIRED_FOR_WEATHER, ENVIRONMENT_UNKNOWN_BASELINE_ONLY, WEATHER_UNAVAILABLE_KEEP_EXISTING_DUE, CARE_LOG_REQUIRED_*. Không coi warnings là dữ liệu đã được AI điền đủ.

### Hộp thư thông báo

| API | Dùng để |
| --- | --- |
| GET /notifications?limit=20 | Mới nhất trước; trả `{items,next_cursor}` |
| GET /notifications?limit=20&cursor=... | Trang kế tiếp; dùng nguyên cursor, không tự tính offset |
| GET /notifications?unread=true | Chỉ thông báo chưa đọc |
| GET /notifications/unread-count | `{unread_count}` |
| PATCH /notifications/:id/read | Đánh dấu đã đọc; gọi lại giữ nguyên read_at |

Item có id, kind (water/fertilize/system), title, body, created_at, read_at. Không có thông báo thì items=[] và next_cursor=null. Không có API public để người dùng tự tạo thông báo cho người khác. Worker tạo inbox; phần gửi push và link mở chi tiết cây sẽ được tích hợp khi chốt hợp đồng với app.

## Kiểm thử

```sh
npm test
npm run test:db:isolated
npm run typecheck
npm run lint
npm run build
```

`test:db:isolated` tự dựng PostgreSQL tạm, áp migrations, chạy test rồi dọn DB; không đọc URL Supabase từ `.env`. Test bao gồm ownership, trạng thái đọc, phân trang cùng timestamp, stats, lịch thủ công, DST, mưa/nóng, fallback thời tiết, chống thông báo trùng, nhật ký mở chu kỳ tiếp theo. Dữ liệu test chỉ nằm trong DB tạm. Adapter đã kiểm tra phản hồi thật Open-Meteo ở tọa độ mẫu TP.HCM; không có cây demo nào được thêm vào DB chung.

Nguồn: [Open-Meteo Forecast](https://open-meteo.com/en/docs), [điều khoản/attribution](https://open-meteo.com/en/terms), [Temporal timezone](https://tc39.es/proposal-temporal/docs/zoneddatetime.html).
