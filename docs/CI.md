# CI Flutter cho nhóm

Workflow `.github/workflows/flutter-ci.yml` tự chạy khi push lên nhánh có file workflow, mở/cập nhật PR, hoặc chạy thủ công khi workflow có trên nhánh mặc định. Không lọc đường dẫn: cả commit chỉ sửa backend cũng chạy kiểm tra Flutter.

Máy GitHub dùng Ubuntu, Flutter **3.47.5 stable / Dart 3.13.4**, tương ứng SDK đã kiểm thử tại máy phát triển. Các bước: lấy code → `flutter pub get` → `flutter analyze --no-pub` → `flutter test --no-pub`, trong thư mục frontend. Nếu analyze lỗi, bước test vẫn chạy để cung cấp kết quả riêng; toàn workflow vẫn thất bại. Không bỏ qua lỗi, không cần secrets hoặc file .env, không truy cập Supabase/Gemini.

## Thành viên cần làm

1. Nhận thay đổi CI cùng code nhóm. Merge PR chứa workflow vào main rồi các nhánh thành viên cập nhật main để có cùng cấu hình/test.
2. Trước khi push, chạy từ frontend:

```sh
flutter pub get
flutter analyze
flutter test
```

3. Sau push, mở GitHub repository → **Actions → Flutter CI** → chọn lượt chạy của commit/nhánh mình. Xanh là đạt; đỏ thì mở job **Flutter analyze and test**, xem bước lỗi rồi sửa và push lại. PR cũng hiển thị kết quả ở phần Checks.
4. Viết test cùng chức năng mới: logic dữ liệu, form nhập, trạng thái tải/lỗi/rỗng và thao tác chính. Dùng dữ liệu/API giả lập để test không phụ thuộc DB/key thật. Không xóa test hoặc dùng continue-on-error chỉ để báo xanh.

## Phạm vi hiện tại

Đã thay test bộ đếm Flutter mẫu bằng hai widget tests: chuyển các tab và mở Quét AI rồi quay về đúng tab trước đó. Đây là kiểm thử điều hướng của khung hiện có, chưa kiểm thử nhận diện ảnh, đăng nhập hay chăm sóc hoàn chỉnh. Cần bổ sung test khi từng chức năng hoàn thành; chưa đủ yêu cầu 15 test Flutter của mức Xuất sắc trong rubric.

CI không tự sửa code, không triển khai app, không áp migration, không ký APK. Muốn bắt buộc CI đạt trước khi merge, quản trị repo cần cấu hình branch protection/ruleset yêu cầu check `Flutter analyze and test`; workflow tự nó chưa chặn merge. Không cần cài GitHub Actions trên máy thành viên.

Nếu thay Flutter SDK, cập nhật phiên bản trong workflow và chạy lại kiểm tra; không tự lấy phiên bản mới nhất mỗi lần chạy.

Tham khảo cấu hình action: https://github.com/subosito/flutter-action
