# Backend AI Plant Care

Node.js 24, Express 5, TypeScript, Prisma 7.10.1 và PostgreSQL 16+. Nền hiện có kết nối DB, migration, seed demo, xác minh Supabase access token, kiểm tra quyền đọc cây, validation, logging và xử lý lỗi tập trung.

## Chạy với DB Supabase chung của nhóm

Cài Node.js 24 và Git. Không cần Docker khi dùng Supabase. Các lệnh bên dưới chạy tại thư mục `backend`.

1. Nhận file `.env` từ Đạt qua kênh riêng của nhóm và đặt tại `backend/.env`. Đây là file chứa mật khẩu DB, không commit hoặc đưa vào ứng dụng Flutter. `.env.example` chỉ là mẫu, không kết nối được nếu chưa điền thông tin thật.
2. Kiểm tra repo có `backend/certs/supabase-ca.crt`. `DATABASE_URL` trong `.env` dùng `sslmode=verify-full&sslrootcert=certs/supabase-ca.crt`. Giữ đường dẫn tương đối này để dùng trên Windows/macOS, luôn chạy lệnh từ thư mục backend.
3. Cài dependencies và sinh Prisma Client:

```sh
npm ci
npm run db:generate
npm run dev
```

Mở http://localhost:3100/api/v1/ready. Kết quả đúng là HTTP 200 và:

```json
{"success":true,"data":{"status":"ready"},"error":null,"message":"OK"}
```

DB Supabase chung đã được áp dụng các migration ban đầu. Người mới nhận code không cần chạy lại migration hay seed. Không chạy `db:seed`, `prisma migrate reset` hoặc thử thay đổi bảng trên DB chung. Khi nhóm có migration mới đã được duyệt, người phụ trách DB chạy `npm run db:migrate`; thành viên cập nhật code rồi chạy `npm run db:generate`. Chạy kiểm thử ghi dữ liệu trên DB riêng.

Giữ `DEV_AUTH_BYPASS=false` với Supabase chung. Backend đã có API Auth và middleware xác minh token. Điền `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` theo project: `/health` và `/ready` công khai, các API `/me`, `/garden` cần token hợp lệ và cấu hình Auth. Chưa có token thì HTTP 401 là bình thường. Flutter đã tích hợp API; xem README frontend để cấu hình URL.

Mỗi lần đổi `.env`, dừng server bằng Ctrl+C rồi chạy lại `npm run dev`. Trên PowerShell nếu `npm.ps1` bị chặn, dùng `npm.cmd` thay cho `npm`.

### Xử lý lỗi thường gặp

- `DATABASE_UNAVAILABLE`: kiểm tra `DATABASE_URL`, Internet, chứng chỉ và trạng thái project. Thông báo này cũng có thể do SSL, không đồng nghĩa cần chạy lại migration.
- `self-signed certificate in certificate chain`: kiểm tra file CA và hai tham số SSL nêu trên; không tắt xác thực chứng chỉ.
- Cổng 3100 đã được dùng: dừng backend cũ trước khi chạy bản mới.
- Sửa `.env` mà API vẫn dùng cấu hình cũ: khởi động lại backend.

## Tùy chọn: chạy DB riêng trên máy (demo local)

Mở terminal tại thư mục backend:

```sh
npm ci
npm run env:init
npm run db:generate
npm run db:local
```

Lệnh cuối giữ terminal mở để chạy PostgreSQL thật trên 127.0.0.1:5433. Công cụ dev embedded-postgres tải binary theo hệ điều hành; đã khóa wrapper ở 16.15.0-beta.19 (PostgreSQL 16.15). Trên máy hiện tại dùng phương án này vì Docker Desktop không phản hồi. Dữ liệu lưu trong backend/.local/postgres, được Git bỏ qua. Ctrl+C dừng DB và giữ dữ liệu. Mở terminal thứ hai trong backend:

```sh
npm run db:migrate
npm run db:seed
npm run dev
```

Seed tạo tài khoản demo, hai loài, hai cây, hai lịch tưới và hai việc đến hạn. Chạy lại không nhân bản. Chu kỳ là dữ liệu minh họa để nhóm thử chức năng. Lệnh seed yêu cầu NODE_ENV=development và DEV_AUTH_BYPASS=true. Khi backend đã chạy, mở [health](http://127.0.0.1:3100/api/v1/health), [ready](http://127.0.0.1:3100/api/v1/ready), [vườn demo](http://127.0.0.1:3100/api/v1/garden) hoặc [hồ sơ demo](http://127.0.0.1:3100/api/v1/me).

Trên PowerShell nếu npm.ps1 bị chặn, dùng npm.cmd cho các lệnh npm. Flutter Android Emulator gọi http://10.0.2.2:3100/api/v1. Điện thoại thật dùng IP LAN của máy backend, cùng Wi-Fi và cho phép cổng 3100 trên firewall. Backend đang lắng nghe 0.0.0.0.

## Tùy chọn Docker

Cài và mở Docker Desktop, rồi dùng `npm run db:up` thay cho `npm run db:local`. Cổng mặc định cũng là 5433 nên chọn một cách chạy tại một thời điểm. Docker dùng volume postgres_data riêng; dữ liệu của db:local ở thư mục .local riêng. Chuyển cách chạy cần áp migration và seed cho database tương ứng.

```sh
npm run db:up
npm run db:migrate
npm run db:seed
npm run dev
```

`npm run db:stop` dừng DB Docker. Mật khẩu khởi tạo trong .env gắn với cluster/volume lần tạo đầu tiên. Đổi .env sau đó cần đồng thời đổi mật khẩu PostgreSQL bằng tài khoản quản trị.

## Supabase khi nhóm đã có project

Phần này dành cho người phụ trách khởi tạo project mới; thành viên dùng DB chung làm theo phần đầu README.

1. Từ mục Connect của Supabase, đặt DATABASE_URL cho runtime và DIRECT_URL cho migration trong backend/.env. Session pooler phù hợp khi máy chỉ có IPv4; lấy hostname và port chính xác từ dashboard. Cấu hình TLS theo hướng dẫn của project.
2. Chạy `npm run db:migrate`. Schema nghiệp vụ plantcare dành cho Express; giữ ngoài danh sách schema public của Data API. Runtime nên dùng role DB riêng với USAGE trên schema và quyền dữ liệu cần thiết; role migration quản lý DDL. Hai URL local ban đầu dùng tài khoản phát triển riêng của dự án.
3. Đặt SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY và DEV_AUTH_BYPASS=false. Flutter đăng nhập Google/email qua Supabase, gửi token đến API. Middleware gọi Supabase Auth để xác minh token rồi lấy user.id. GET /me tạo profile cho lần đăng nhập đầu, từ đó plants.owner_id liên kết profile.
4. Có thể chạy database/002_supabase_auth_optional.sql trong Supabase SQL Editor để ràng buộc profiles.id với auth.users.id. Mọi profile hiện có cần tương ứng một tài khoản Auth trước khi áp dụng. Seed demo cố định phù hợp database local.
5. Khi triển khai dùng NODE_ENV=production. Bypass bật ở staging/production làm ứng dụng từ chối khởi động. Chuẩn bị bucket private cho ảnh khi nhóm viết chức năng upload; schema lưu object key và metadata ảnh tham khảo.

Tên key trong .env.example là cấu hình mẫu. `env:init` tạo mật khẩu local ngẫu nhiên và không ghi đè .env hiện có. `GEMINI_API_KEY` dùng cho adapter bổ sung dữ liệu chăm sóc, chỉ lưu phía backend.

Nguồn kết nối [Supabase](https://supabase.com/docs/guides/database/connecting-to-postgres). Cấu hình Prisma 7 theo [tài liệu nâng cấp chính thức](https://www.prisma.io/docs/guides/upgrade-prisma-orm/v7).

## API nền hiện có

| Endpoint | Yêu cầu | Kết quả |
| --- | --- | --- |
| GET /api/v1/health | Công khai | Liveness của tiến trình và trạng thái demo auth |
| GET /api/v1/ready | Công khai | 200 khi đọc được bảng profiles; 503 khi DB/schema chưa sẵn sàng |
| GET /api/v1/me | Auth hoặc development demo | Hồ sơ và isDemo |
| GET /api/v1/garden?limit=20&offset=0 | Auth hoặc development demo | Cây của chủ đã xác minh, limit tối đa 100 |
| GET /api/v1/garden/:id | Auth hoặc development demo | Cây, loài và metadata ảnh bìa tham khảo nếu có |

Mọi response có success, data, error và message. Lỗi dùng mã INVALID_INPUT (400), UNAUTHORIZED (401), NOT_FOUND (404), AUTH_UNAVAILABLE/DATABASE_UNAVAILABLE (503), INTERNAL_ERROR (500). Header X-Request-ID dùng đối chiếu log. Log chỉ ghi method, path, status, thời gian và request ID.

Development bypass dùng UUID cố định trong src/config/demo.ts. Đã có lịch/thời tiết, hộp thư nhắc và Gemini bổ sung dữ liệu chăm sóc. CRUD vườn, upload/quét ảnh, ghi nhật ký và gửi push vẫn cần tích hợp với phần của nhóm.

## Cấu trúc để chia việc

Xem [sơ đồ phân lớp và bảng file theo chức năng](../docs/BACKEND_ARCHITECTURE.md). Luồng chính: **Routes → Controller → Service → Database**; mọi truy vấn dữ liệu của API và worker đặt tại service.

- src/config — kiểm tra .env, Prisma Client và người dùng demo.
- src/middlewares — xác thực token và chuyển lỗi thành JSON.
- src/routes — khai báo URL.
- src/controllers — nhận input và trả response.
- src/services — truy vấn dữ liệu, nơi thêm nghiệp vụ.
- prisma — schema ORM và SQL migration có thứ tự.
- database — seed và mô tả mô hình dữ liệu.
- tests/unit, tests/database — test HTTP độc lập và test trên PostgreSQL.

## Kiểm tra và thay đổi database

```sh
npm run lint
npm run typecheck
npm test
npm run test:db
npm run build
npm run db:status
```

test:db cần database đã migrate. Test tạo user/cây ngẫu nhiên và xóa fixture của chính nó. Dùng DB phát triển riêng khi chạy. Auth thật được thay bằng phản hồi giả lập trong test; việc lọc owner được chạy qua API với PostgreSQL thật.

Migration SQL giữ các CHECK, expression index và FK ghép. schema.prisma dùng cho Prisma Client; các CHECK vẫn được PostgreSQL thực thi. Khi sửa model, tạo migration mới, xem SQL để giữ các ràng buộc và áp trên DB riêng trước. Tránh sửa migration đã áp dụng. Sinh lại client bằng db:generate sau khi sửa schema. Field thời gian Postgres time được Prisma biểu diễn bằng Date có phần ngày quy ước. Xác suất/Decimal có thể được JSON serialize thành chuỗi; Flutter parse dạng num hoặc string theo hợp đồng endpoint.

Khi build, mã sinh Prisma nằm trong dist/generated và được dùng bởi `npm start`. Nếu chuẩn bị artifact triển khai, chạy db:generate rồi build trước khi cài runtime dependencies bằng npm ci --omit=dev.

## API Auth cho frontend

Đã có API Express đăng ký, đăng nhập, refresh, quên/đổi mật khẩu, đăng xuất và Google OAuth/PKCE. Xem [hợp đồng API và cấu hình cloud](../docs/AUTH_SETUP.md). Google, SMTP và callback cần cấu hình trước khi kiểm thử đầy đủ. Frontend giữ nguyên.

## Hồ sơ, lịch chăm sóc và lịch sử thông báo

Màn hình Hồ sơ: [API và dữ liệu frontend cần](../docs/PROFILE_API.md). GET /me và GET /me/stats có thêm thống kê tưới/bón phân/điều trị từ nhật ký; PATCH /me cập nhật tên/múi giờ, đăng xuất dùng POST /auth/logout.

Xem [hợp đồng API và phần chờ module khác](../docs/BACKEND_FEATURES_1_2_5.md). Sau khi cài dependencies và db:generate, mở terminal riêng chạy `npm run reminders:watch` để tự tạo việc và hộp thư nhắc theo lịch/thời tiết. `npm run reminders:run` chạy một lượt. Push tới điện thoại chưa tích hợp.

Kiểm thử PostgreSQL an toàn trên máy: `npm run test:db:isolated`. Script tạo cluster tạm riêng rồi tự dọn, không dùng Supabase chung.

## Gemini bổ sung dữ liệu chăm sóc

Xem [cấu hình, API đề xuất/duyệt và cách nối với module AI](../docs/CARE_DATA_AI.md). `CARE_AI_MODE=auto` dùng demo có nhãn khi chưa có key. Thêm `GEMINI_API_KEY`, `GEMINI_MODEL`; cấp quyền duyệt bằng `CARE_REVIEWER_IDS` (UUID Auth). `npm run care:check` thử provider mà không ghi DB. Gemini thật được lưu vào dữ liệu loài và dùng lập lịch ngay với trạng thái ai_suggested; không cần màn hình duyệt. Chu kỳ null không được tự suy đoán; demo không dùng làm lịch thật. Áp migration 202611180001_auto_ai_care trước khi chạy bản mới.
