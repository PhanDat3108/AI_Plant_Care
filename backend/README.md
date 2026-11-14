# Backend AI Plant Care

Node.js 24, Express 5, TypeScript, Prisma 7.10.1 và PostgreSQL 16+. Nền hiện có kết nối DB, migration, seed demo, xác minh Supabase access token, kiểm tra quyền đọc cây, validation, logging và xử lý lỗi tập trung.

## Chạy lần đầu trên Windows hoặc macOS

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

Seed tạo tài khoản demo, hai loài, hai cây, hai lịch tưới và hai việc đến hạn. Chạy lại không nhân bản. Chu kỳ là dữ liệu minh họa để nhóm thử chức năng. Lệnh seed yêu cầu NODE_ENV=development và DEV_AUTH_BYPASS=true. Khi backend đã chạy, mở [health](http://127.0.0.1:3100/api/v1/health), [ready](http://127.0.0.1:3100/api/v1/ready), [vườn demo](http://127.0.0.1:3100/api/v1/plants) hoặc [hồ sơ demo](http://127.0.0.1:3100/api/v1/me).

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

1. Từ mục Connect của Supabase, đặt DATABASE_URL cho runtime và DIRECT_URL cho migration trong backend/.env. Session pooler phù hợp khi máy chỉ có IPv4; lấy hostname và port chính xác từ dashboard. Cấu hình TLS theo hướng dẫn của project.
2. Chạy `npm run db:migrate`. Schema nghiệp vụ plantcare dành cho Express; giữ ngoài danh sách schema public của Data API. Runtime nên dùng role DB riêng với USAGE trên schema và quyền dữ liệu cần thiết; role migration quản lý DDL. Hai URL local ban đầu dùng tài khoản phát triển riêng của dự án.
3. Đặt SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY và DEV_AUTH_BYPASS=false. Flutter đăng nhập Google/email qua Supabase, gửi token đến API. Middleware gọi Supabase Auth để xác minh token rồi lấy user.id. GET /me tạo profile cho lần đăng nhập đầu, từ đó plants.owner_id liên kết profile.
4. Có thể chạy database/002_supabase_auth_optional.sql trong Supabase SQL Editor để ràng buộc profiles.id với auth.users.id. Mọi profile hiện có cần tương ứng một tài khoản Auth trước khi áp dụng. Seed demo cố định phù hợp database local.
5. Khi triển khai dùng NODE_ENV=production. Bypass bật ở staging/production làm ứng dụng từ chối khởi động. Chuẩn bị bucket private cho ảnh khi nhóm viết chức năng upload; schema lưu object key và metadata ảnh tham khảo.

Tên key trong .env.example là cấu hình mẫu. `env:init` tạo mật khẩu local ngẫu nhiên và không ghi đè .env hiện có. API key nhà cung cấp AI sẽ được thêm khi triển khai adapter, lưu phía backend.

Nguồn kết nối [Supabase](https://supabase.com/docs/guides/database/connecting-to-postgres). Cấu hình Prisma 7 theo [tài liệu nâng cấp chính thức](https://www.prisma.io/docs/guides/upgrade-prisma-orm/v7).

## API nền hiện có

| Endpoint | Yêu cầu | Kết quả |
| --- | --- | --- |
| GET /api/v1/health | Công khai | Liveness của tiến trình và trạng thái demo auth |
| GET /api/v1/ready | Công khai | 200 khi đọc được bảng profiles; 503 khi DB/schema chưa sẵn sàng |
| GET /api/v1/me | Auth hoặc development demo | Hồ sơ và isDemo |
| GET /api/v1/plants?limit=20&offset=0 | Auth hoặc development demo | Cây của chủ đã xác minh, limit tối đa 100 |
| GET /api/v1/plants/:id | Auth hoặc development demo | Cây, loài và metadata ảnh bìa tham khảo nếu có |

Mọi response có success, data, error và message. Lỗi dùng mã INVALID_INPUT (400), UNAUTHORIZED (401), NOT_FOUND (404), AUTH_UNAVAILABLE/DATABASE_UNAVAILABLE (503), INTERNAL_ERROR (500). Header X-Request-ID dùng đối chiếu log. Log chỉ ghi method, path, status, thời gian và request ID.

Development bypass dùng UUID cố định trong src/config/demo.ts. Các chức năng CRUD ghi dữ liệu, upload/quét AI, thời tiết, tạo lịch tự động và gửi thông báo là phần nghiệp vụ hai bạn backend sẽ viết trên nền này.

## Cấu trúc để chia việc

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
