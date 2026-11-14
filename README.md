# AI Plant Care

## Frontend

Ứng dụng Flutter cho Android và iOS. Điểm bắt đầu là `frontend/lib/main.dart`. Sau khi clone, mở emulator hoặc kết nối điện thoại, rồi chạy:

```sh
cd frontend
flutter pub get
flutter run
```

## Backend

Nền Express + TypeScript + Prisma và PostgreSQL đã có migration, seed demo, xác thực Supabase và API đọc vườn cây. Xem [cách cài và chạy backend](backend/README.md).

| Thư mục | Dùng để |
| --- | --- |
| `backend/src/routes/` | Khai báo đường dẫn API |
| `backend/src/controllers/` | Nhận request và trả response |
| `backend/src/services/` | Xử lý nghiệp vụ |
| `backend/src/middlewares/` | Xử lý chung giữa các request |
| `backend/src/config/` | Đọc cấu hình ứng dụng |
| `backend/tests/` | Viết kiểm thử backend |

Thiết kế PostgreSQL, sơ đồ quan hệ và hướng dẫn tạo bảng nằm trong [backend/database](backend/database/README.md).
