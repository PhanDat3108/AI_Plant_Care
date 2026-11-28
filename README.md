# AI Plant Care

Ứng dụng Flutter hỗ trợ quản lý vườn cây, nhận diện loài và tham khảo chẩn đoán bệnh từ ảnh. Backend Node.js giữ khóa dịch vụ AI, lưu dữ liệu qua Supabase và gửi nhắc chăm sóc qua Firebase Cloud Messaging.

## Chức năng

- Đăng ký, xác nhận email và đăng nhập email/Google. Backend có API khôi phục mật khẩu; callback recovery trên mobile cần hoàn thiện và nghiệm thu riêng.
- Nhận diện loài, chẩn đoán bệnh bằng camera hoặc ảnh thư viện; quét cho cây đã lưu.
- Thêm cây vào vườn, ảnh bìa, đổi tên và xóa cây.
- Hướng dẫn chăm sóc, nhật ký, sửa/bật/tắt lịch tưới và bón phân.
- Đồng bộ kế hoạch với thời tiết; giữ lịch hiện tại và báo lý do nếu nguồn thời tiết lỗi.
- Việc cần làm, đánh dấu hoàn tất, thông báo trong app và push Android.
- Hồ sơ và thống kê cá nhân. Hiện chỉ có giao diện sáng, tiếng Việt.

## Chạy nhanh Android

Xem [README frontend](frontend/README.md) để cài Flutter, cấu hình Firebase và chạy. Backend mặc định là Render; người thử app không cần mật khẩu database hoặc khóa AI. Muốn tự chạy backend, xem [README backend](backend/README.md) và `backend/.env.example`.

```sh
cd frontend
flutter pub get
flutter run
```

Cần thiết bị/emulator Android. Repo đã có Firebase client config cho project hiện tại; không cần khóa Firebase Admin để chạy Flutter. Backend Render và các dịch vụ cloud phải hoạt động.

## Kiến trúc

Flutter screens/widgets → services → REST API Express → services → Prisma/PostgreSQL. Supabase Auth xác minh người dùng; Supabase Storage lưu ảnh; PlantNet/Gemini xử lý AI qua backend; Open-Meteo cung cấp thời tiết, WeatherAPI dự phòng khi được cấu hình; cron gọi backend để tạo nhắc và gửi FCM.

Chi tiết: [kiến trúc backend](docs/BACKEND_ARCHITECTURE.md), [API frontend](docs/FRONTEND_API_SPEC.md), [push](docs/PUSH_NOTIFICATIONS.md).

## Kiểm thử

```sh
cd frontend
flutter analyze
flutter test
```

Tại thư mục `backend`: `npm ci`, `npm run db:generate`, `npm run typecheck`, `npm test`. Unit test không cần database production; test database dùng database riêng theo README backend. CI Flutter chạy analyze/test khi push và PR.

## Dữ liệu và quyền riêng tư

- Supabase Auth: tài khoản và phiên đăng nhập; mật khẩu được xử lý bởi dịch vụ Auth.
- PostgreSQL/Supabase: hồ sơ, cây, lịch, nhiệm vụ, nhật ký, kết quả quét, thông báo và đăng ký thiết bị push.
- Supabase Storage: ảnh tải lên; app nhận URL ảnh có thời hạn từ backend.
- Điện thoại: access/refresh token và thông tin đăng ký push qua secure storage. Không lưu database vườn để dùng offline.
- Ảnh quét được backend gửi tới PlantNet/Gemini theo chế độ. Vị trí dùng cho dự báo được gửi tới Open-Meteo hoặc WeatherAPI dự phòng khi áp dụng. Xem [cấu hình thời tiết](docs/WEATHER.md).
- Camera/thư viện dùng khi chọn hoặc chụp ảnh; quyền thông báo được xin sau khi bắt đầu phiên đăng nhập Android.
- Không đưa DATABASE_URL, secret Supabase, khóa AI, Firebase Admin JSON hoặc khóa ký APK vào app/Git. Firebase client config không thay thế quyền truy cập server.

## Dùng AI

Nhóm sử dụng ChatGPT/Codex hỗ trợ phân tích yêu cầu, viết/chỉnh code, tìm lỗi, thiết kế test và tài liệu. Các phần hỗ trợ và giới hạn xác minh được ghi trong [docs/ai](docs/ai/README.md). Đây không phải xác nhận thay cho việc mỗi thành viên tự chạy và giải thích phần mã phụ trách. Nếu có dùng công cụ AI khác, thành viên bổ sung đúng thực tế.

## Bản cài thử và hồ sơ nộp

- [Build và ký APK](docs/RELEASE.md).
- [Kịch bản demo, phản hồi người dùng và checklist nộp](docs/SUBMISSION.md).
- [Kết quả kiểm thử](docs/TEST_RESULTS.md).

## Hạn chế

App cần mạng cho dữ liệu nghiệp vụ và AI. Kết quả AI có thể sai, cần đối chiếu thực tế. Push Android phụ thuộc quyền thiết bị, FCM và cron; khi app đang mở hiện thông báo trong app, không có banner hệ thống riêng. iOS chưa xác nhận tương đương Android. Chưa hỗ trợ dark mode hoặc đa ngôn ngữ. Demo AI vẫn cần backend, database và storage; không phải chế độ offline.
