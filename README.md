# AI Plant Care

Nền tảng Phase 1 cho ứng dụng chăm sóc cây của nhóm sinh viên. Bản demo có bảy màn hình tiếng Việt, gửi ảnh JPEG/PNG từ Flutter tới Express, hiển thị kết quả giả lập, mở vườn và lịch chăm sóc từ PostgreSQL. Dữ liệu quét mock giống nhau cho mọi ảnh. Đăng ký/đăng nhập dùng Supabase khi đã cấu hình.

| Thư mục | Nội dung |
| --- | --- |
| `apps/mobile` | Flutter 3.47.5, Dart 3.13.4, Material 3, Riverpod, Dio, go_router, image_picker, Supabase Flutter và dependency thông báo local |
| `apps/api` | Node 24, TypeScript, Express 5, Prisma, Zod, Vitest, migration và seed |
| `infra` | Docker Compose PostgreSQL 16 cho máy cá nhân |
| `docs`, `.github` | Tài liệu nhóm, CI và mẫu PR |

### Clone và chạy backend

Cài Git, Node 24 và Flutter theo [macOS](docs/SETUP_MACOS.md) hoặc [Windows](docs/SETUP_WINDOWS.md). Trên Linux dùng Flutter SDK stable cùng phiên bản và Android Studio. Thay `OWNER` bằng tài khoản hoặc tổ chức của nhóm.

```sh
git clone https://github.com/OWNER/ai-plant-care.git
cd ai-plant-care
node -e "require('fs').copyFileSync('apps/api/.env.example','apps/api/.env',require('fs').constants.COPYFILE_EXCL)"
npm ci
npm run db:generate
```

Lệnh sao chép dành cho lần đầu. File mẫu bật mock và user demo cố định trong development. Để chạy đầy đủ vườn và lịch bằng Docker:

```sh
docker compose -f infra/docker-compose.yml up -d --wait
npm run db:migrate
npm run db:seed
npm run dev
```

Nếu dùng Supabase Postgres, đặt hai URL trong `apps/api/.env` rồi chạy từ bước migrate. Nhóm trưởng quản lý migration cho database chung. Nếu chỉ demo quét ảnh, có thể chạy `npm run dev` ngay sau generate. Kiểm tra [health local](http://localhost:3100/api/v1/health) trong trình duyệt. Vườn và lịch cần database đã migrate. Dừng API bằng Ctrl+C và dừng DB bằng `docker compose -f infra/docker-compose.yml stop`.

### Chạy Flutter

Trong terminal thứ hai, từ gốc repo:

```sh
cd apps/mobile
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run
```

Android Emulator mặc định dùng `http://10.0.2.2:3100/api/v1`. iOS Simulator mặc định dùng `http://127.0.0.1:3100/api/v1`. Với điện thoại thật, dùng cùng Wi-Fi, cho phép kết nối tới port 3100 trên máy phát triển và thay IP ví dụ bằng IP LAN của máy:

```sh
flutter run --dart-define=API_BASE_URL=http://192.168.1.25:3100/api/v1
```

Dùng HTTPS cho bản triển khai. Trong **Tài khoản**, xem trạng thái máy chủ. Từ trang chủ mở **Quét ảnh cây → Chọn từ thư viện** hoặc **Chụp ảnh → Phân tích ảnh**. Màn hình kết quả gắn nhãn **Dữ liệu giả lập**. Trên emulator/simulator hãy thêm ảnh vào thư viện trước. Quay lại **Vườn của tôi**, mở một cây rồi xem **Lịch chăm sóc** để kiểm tra seed.

### Chuyển sang dịch vụ thật

- Supabase Auth và Postgres cấu hình độc lập. Đặt `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `DEV_AUTH_BYPASS=false` ở API. Chạy Flutter với `--dart-define=SUPABASE_URL=https://PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=PUBLIC_KEY`. Xác nhận email nếu project bật xác nhận.
- Đặt `KINDWISE_API_KEY`, `PERENUAL_API_KEY`, `MOCK_EXTERNAL_APIS=false` rồi khởi động lại backend. Open-Meteo dùng endpoint dự báo công cộng. Mỗi lần quét thật gọi nhận diện và khám sức khỏe riêng, có thể tiêu hao hai lượt dịch vụ.
- Ảnh quét hiện chỉ xử lý trong bộ nhớ. Upload lâu dài lên Supabase Storage, lưu lịch sử và gửi thông báo theo lịch là phần việc sau Phase 1.

### Cộng tác

Mỗi thành viên tạo `feat/ten-chuc-nang` hoặc `fix/ten-loi`, push branch rồi mở PR vào `main`. Chờ CI và review trước khi merge. Xem [quy trình nhóm](docs/TEAM_WORKFLOW.md), [đóng góp](CONTRIBUTING.md), [kiến trúc](docs/ARCHITECTURE.md), [API](docs/API.md) và [database](docs/DATABASE.md).

### Kiểm thử tích hợp

Tại gốc repo, chạy `npm run lint`, `npm run typecheck`, `npm test` và `npm run build`. Để chạy thêm test cách ly hai owner, dùng database local đã migrate và đặt `TEST_DATABASE=true` cho tiến trình test (PowerShell: `$env:TEST_DATABASE="true"`). CI bật test này với PostgreSQL riêng.

Khi API local đang chạy ở chế độ demo, từ apps/mobile chạy:
```sh
flutter test --dart-define=LIVE_MOCK_API=http://127.0.0.1:3100/api/v1
```
Bộ test gửi một PNG qua cùng hàm upload mà màn hình quét sử dụng. Khi bỏ dart-define, Flutter chỉ chạy các test độc lập với server.
