# AI Plant Care

## Frontend

Ứng dụng Flutter cho Android và iOS. Điểm bắt đầu là `frontend/lib/main.dart`. Sau khi clone, mở emulator hoặc kết nối điện thoại, rồi chạy:

```sh
cd frontend
flutter pub get
flutter run
```

## Backend


| Thư mục | Dùng để |
| --- | --- |
| `backend/src/routes/` | Khai báo đường dẫn API |
| `backend/src/controllers/` | Nhận request và trả response |
| `backend/src/services/` | Xử lý nghiệp vụ |
| `backend/src/middlewares/` | Xử lý chung giữa các request |
| `backend/src/config/` | Đọc cấu hình ứng dụng |
| `backend/tests/` | Viết kiểm thử backend |

## Kiểm tra tự động

Workflow **Flutter CI** chạy analyze và test khi push/PR. Xem [hướng dẫn CI](docs/CI.md). Thành viên cập nhật workflow qua nhánh main sau khi PR được merge.
