# Frontend AI Plant Care

Flutter đã tích hợp backend, Supabase Auth qua API, quét ảnh, vườn cây, lịch chăm sóc và push Android. Điểm vào: `lib/main.dart`.

## Chuẩn bị

1. Flutter 3.47.5 / Dart 3.13.4 (khớp CI), Android SDK, JDK 17 trở lên tương thích Android Gradle Plugin; chạy `flutter doctor` để kiểm tra.
2. Mở emulator hoặc kết nối Android và bật USB debugging; kiểm tra `flutter devices`.
3. Repo đã có `android/app/google-services.json` cho project hiện tại (cấu hình client). Nếu dùng project riêng, thay bằng cấu hình cùng project FCM của backend, package `vn.aiplantcare.ai_plant_care`. Không dùng Firebase Admin JSON trong frontend.
4. Đăng nhập Google hiện dùng trình duyệt OAuth/PKCE qua Supabase, không dùng Google Sign-In native: kiểm tra Supabase redirect theo [GOOGLE_MOBILE_SETUP](../docs/GOOGLE_MOBILE_SETUP.md). Không bắt buộc đăng ký SHA release cho luồng này.

## Chạy

Từ thư mục `frontend`:

```sh
flutter pub get
flutter run
```

Mặc định API là `https://ai-plant-care.onrender.com/api/v1`, cấu hình trong `lib/core/api_config.dart`. Không cần `.env` backend để dùng bản triển khai. Đăng ký tài khoản và xác nhận email trước khi đăng nhập; không có tài khoản/mật khẩu dùng chung trong repo.

Đổi sang backend riêng khi chạy:

```sh
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3100/api/v1
```

Địa chỉ trên dành cho Android Emulator. Điện thoại thật dùng IP LAN máy backend, cùng mạng, cổng 3100 được phép truy cập. Dùng HTTPS cho bản phân phối. Backend phải đáp ứng `/api/v1/ready`; chỉ HTTP 200 từ health chưa chứng minh DB hoạt động.

## Cấu trúc

- `lib/screens/`, `lib/widgets/`: màn hình và thành phần giao diện.
- `lib/services/`: API, xác thực, token và push.
- `lib/models/`: dữ liệu ứng dụng.
- `lib/core/`: URL API, lỗi, validation, chọn URL ảnh.
- `lib/theme/`: theme sáng.
- `test/`: unit và widget test, không cần gọi backend thật.

## Kiểm tra và đóng gói

```sh
flutter analyze
flutter test
```

[Hướng dẫn ký APK release](../docs/RELEASE.md). CI tự chạy analyze/test khi push/PR; xem [CI](../docs/CI.md).

## Demo AI không có khóa nhà cung cấp

Người chạy backend đặt `CARE_AI_MODE=demo` rồi khởi động lại backend; app trỏ tới backend đó. Backend vẫn cần database, Auth và Storage được cấu hình. Kết quả AI khi này là dữ liệu minh họa, không dùng làm bằng chứng độ chính xác. Không bật demo trên backend dùng chung mà chưa thông báo cho nhóm.

## Dữ liệu, AI và giới hạn

Xem [README gốc](../README.md#dữ-liệu-và-quyền-riêng-tư) về nơi lưu dữ liệu và [hồ sơ dùng AI](../docs/ai/README.md). Android là nền tảng kiểm thử chính. Chưa có dark mode, offline hoặc giao diện hai ngôn ngữ. Push hiện chỉ triển khai Android; khi app mở chỉ hiện thông báo trong app.
