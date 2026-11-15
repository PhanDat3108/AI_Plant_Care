# AI Plant Care

Ứng dụng Flutter chăm sóc cây, backend Express + TypeScript + Prisma, database PostgreSQL trên Supabase.

## Nhận dự án

```sh
git clone https://github.com/PhanDat3108/AI_Plant_Care.git
cd AI_Plant_Care
```

Nếu đã clone, cập nhật nhánh làm việc theo quy trình của nhóm. Mỗi người phát triển trên nhánh riêng và mở pull request.

## Cần chạy phần nào?

| Công việc | Cần chuẩn bị |
| --- | --- |
| Làm giao diện Flutter | Flutter SDK, emulator/thiết bị; chưa cần `.env` backend |
| Làm backend | Node.js 24, file `.env` nhận riêng từ Đạt |
| Test Flutter với API trên máy mình | Chạy cả frontend và backend; đặt `.env` tại `backend/` |

File `.env` backend chứa quyền truy cập DB, chỉ gửi riêng cho thành viên cần chạy backend. Không đặt file này trong frontend hoặc commit lên GitHub. `.env.example` giữ giá trị mẫu; chứng chỉ CA trong `backend/certs/` được chia sẻ cùng repo. Đổi mật khẩu đã lộ trước khi chia sẻ cấu hình cho nhóm.

## Chạy backend với Supabase

Đặt file `.env` nhận riêng vào `backend/.env`, rồi chạy:

```sh
cd backend
npm ci
npm run db:generate
npm run dev
```

Mở http://localhost:3100/api/v1/ready, kiểm tra HTTP 200 và `data.status` là `ready`. Không cần Docker. DB chung đã tạo bảng: không chạy seed demo hay reset DB.

Xem [hướng dẫn backend](backend/README.md) để biết cấu hình SSL, API, xử lý lỗi và tùy chọn DB local.

## Chạy frontend

Mở terminal khác từ thư mục gốc dự án:

```sh
cd frontend
flutter doctor
flutter pub get
flutter run
```

Dùng Flutter SDK có Dart tương thích `frontend/pubspec.yaml` (hiện yêu cầu `^3.13.4`). Mở emulator hoặc kết nối thiết bị trước khi chạy. Xem [hướng dẫn frontend](frontend/README.md) để biết địa chỉ API khi kiểm thử.

## Trạng thái hiện tại

- Đã có nền backend, Prisma migration, 10 bảng nghiệp vụ và kết nối Supabase qua SSL.
- Đã có API health/ready, đọc hồ sơ và vườn cây, middleware xác minh Supabase token.
- Supabase Auth và đăng nhập Flutter chưa hoàn thiện/kiểm thử toàn luồng.
- Frontend hiện là khung Flutter mặc định, chưa tích hợp backend.
- CRUD ghi dữ liệu, quét AI, upload ảnh, lịch chăm sóc và thông báo là phần nhóm tiếp tục phát triển.

Thiết kế dữ liệu nằm trong [backend/database/README.md](backend/database/README.md).
