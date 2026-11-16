# Frontend AI Plant Care

Ứng dụng Flutter cho Android/iOS. Điểm bắt đầu: `lib/main.dart`. Hiện là khung Flutter mặc định, chưa tích hợp backend hoặc Supabase Auth.

## Cài và chạy

Cài Flutter SDK với Dart tương thích `pubspec.yaml` (hiện `^3.13.4`), Android SDK/emulator hoặc thiết bị thật. Chạy iOS cần macOS và Xcode.

Từ thư mục frontend:

```sh
flutter doctor
flutter pub get
flutter run
```

Sửa các yêu cầu công cụ còn thiếu mà `flutter doctor` báo cho nền tảng muốn chạy. Chạy kiểm tra khi sửa code:

```sh
flutter analyze
flutter test
```

## Kiểm thử cùng backend

Làm UI độc lập chưa cần file `.env` backend. Muốn chạy API trên máy mình, nhận `.env` riêng từ Đạt, đặt vào `backend/.env` và làm theo [README backend](../backend/README.md). Không đưa mật khẩu DB hoặc file `.env` backend vào Flutter.

Khi triển khai lớp gọi API, dùng base URL theo thiết bị:

| Thiết bị | Base URL |
| --- | --- |
| Android Emulator chuẩn | `http://10.0.2.2:3100/api/v1` |
| iOS Simulator trên máy Mac chạy backend | `http://localhost:3100/api/v1` |
| Điện thoại thật | `http://<IP-LAN-máy-backend>:3100/api/v1` |

Điện thoại thật và máy backend cần cùng mạng, firewall cho phép cổng 3100. Kiểm tra đường dẫn `/ready` trước khi thử nghiệp vụ. Cấu hình base URL, quyền mạng/HTTP development và Supabase Auth trong Flutter chưa được triển khai; bảng trên là hướng dẫn cho lúc tích hợp.

API cần đăng nhập sẽ yêu cầu header `Authorization: Bearer <access_token>`. Token lấy từ Supabase Auth sau đăng nhập; publishable key không thay thế access token của người dùng. Cấu hình và kiểm thử luồng đăng nhập đang được hoàn thiện.

## Cấu trúc thư mục & Quy ước phát triển UI

### Các thành phần nền tảng đã dựng sẵn
- `lib/theme/app_theme.dart`: Bảng màu chuẩn toàn app (nền kem `#FAF7F0`, xanh lá đậm `#2E5A36`), bo góc 16dp và cấu hình Material 3.
- `lib/models/`: Các class dữ liệu (`PlantModel`, `TaskModel`, `NotificationModel`...).
- `lib/screens/navigation_bottombar.dart`: Thanh điều hướng BottomBar 5 mục đối xứng (Vườn cây, Việc cần làm, nút nổi Quét AI ở giữa, Thông báo, Hồ sơ) kèm các màn hình khung tạm thời để app chạy được ngay.

