# APK release Android

## Khóa ký riêng

Cấu hình release không còn dùng debug key. Người quản lý giữ và sao lưu an toàn `frontend/android/release.jks` và `frontend/android/key.properties`. Cả hai bị Git ignore; không gửi cùng APK hoặc ghi mật khẩu vào tài liệu. Mất khóa có thể không cập nhật được app đã phát hành.

Nếu máy chưa có khóa, nhận lại khóa của nhóm qua kênh riêng. Chỉ lần đầu dự án mới tạo khóa:

```sh
python3 frontend/tool/create_release_key.py
```

Script không ghi đè khóa có sẵn. Yêu cầu Python 3 và JDK/keytool trên PATH. Nếu đổi máy, giữ nguyên khóa; không tạo khóa khác để cập nhật bản đã phát hành.

## Build

Tại `frontend`:

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release --dart-define=API_BASE_URL=https://ai-plant-care.onrender.com/api/v1
```

APK: `frontend/build/app/outputs/flutter-apk/app-release.apk`. Đây là APK dùng được cho nhiều kiến trúc Android theo cấu hình Flutter mặc định. Chia sẻ APK và checksum, không chia sẻ key.properties/release.jks. Khi phát hành bản cập nhật tăng version/build number trong pubspec.yaml.

## Kiểm tra trước khi chia sẻ

- Google login hiện dùng trình duyệt OAuth/PKCE qua Supabase, không bắt buộc SHA release. Giữ callback Supabase và deep link đúng theo GOOGLE_MOBILE_SETUP.md. Chỉ cần đăng ký SHA nếu chuyển sang native Google Sign-In hoặc dịch vụ yêu cầu chứng chỉ Android.
- Cài thử trên máy riêng, đăng nhập email/Google, quét ảnh, lưu cây, chỉnh lịch và nhận push ở nền.
- Bản debug cũ và APK này khác chữ ký: Android không cho cập nhật chồng. Không tự gỡ app khi chưa kiểm tra dữ liệu; việc gỡ xóa phiên và dữ liệu cục bộ. Dữ liệu server vẫn thuộc tài khoản đã đăng nhập.
- Máy có thể yêu cầu cho phép cài ứng dụng từ nguồn đang mở APK.
- Nếu dùng apksigner (Android SDK build-tools), chạy `apksigner verify --print-certs <APK>` để xác nhận chữ ký; chạy `shasum -a 256 <APK>` để ghi checksum.

Build thành công chưa chứng minh đăng nhập Google/FCM với chứng chỉ mới hoạt động. Không tuyên bố đã phát hành hoặc đã được người dùng thử chỉ dựa vào build.

## Bản build ngày 27/11/2026

Build thành công, APK khoảng 57,7 MB, `apksigner verify --print-certs` đạt. Certificate DN: `CN=AI Plant Care, O=AI Plant Care, C=VN`.

Dấu vân tay công khai của chứng chỉ release (có thể đăng ký Firebase/Google khi dịch vụ cần; không bắt buộc cho OAuth trình duyệt hiện tại):

- SHA-1: `66:7E:19:65:6A:AC:4A:C6:8B:61:38:34:F5:45:62:35:A7:A0:7B:5E`
- SHA-256: `B4:CA:27:B9:04:20:BB:D2:E0:C1:9C:3A:F7:B5:14:EE:6A:81:CE:42:CF:9C:71:94:29:C1:BB:F2:CB:E7:2D:B5`

Checksum SHA-256 của file APK (khác fingerprint chứng chỉ):
`a1bdbcfb87c1f31de1dec4788ff441ed55644470bd457e01bab00209746a923c`

Gradle có cảnh báo camera_android_camerax dùng Kotlin Gradle Plugin sẽ cần migration khi nâng Flutter tương lai; bản SDK hiện tại build thành công. Chưa đăng ký fingerprint mới trên console hoặc kiểm thử bản APK này trên máy thật trong lượt build.
