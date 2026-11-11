# macOS và Apple Silicon

1. Kiểm tra `git --version`, `node -v`, `npm -v`, `flutter --version`, `flutter doctor -v`, `gh --version`. Dùng Git từ Xcode Command Line Tools hoặc Homebrew. Nếu thiếu Git, mở Terminal chạy `xcode-select --install` rồi làm theo trình cài.
2. Cài Node 24 LTS bản macOS ARM64 từ [Node.js](https://nodejs.org/en/download). Nếu có nvm, từ gốc repo chạy `nvm install` và `nvm use`. Kiểm tra node hiển thị v24.
3. Tải Flutter 3.47.5 stable dành cho macOS ARM64 từ [Flutter SDK archive](https://docs.flutter.dev/install/archive), giải nén vào thư mục cá nhân, thêm thư mục bin của SDK vào PATH trong cấu hình shell, mở lại Terminal.
4. Cài Android Studio bản Apple Silicon. Trong SDK Manager cài Android SDK Platform 36 và 37, Build Tools, Platform Tools, Emulator và Android SDK Command-line Tools (latest). Dùng JDK đi kèm Android Studio. Trong Device Manager tạo máy Pixel với system image ARM64, nhấn Play. Chạy `flutter doctor --android-licenses`, tự xem và chấp nhận điều khoản nếu đồng ý.
5. Trong VS Code cài extension Flutter (kèm Dart). Mở thư mục repo, mở terminal chạy backend theo README. Mở frontend trong cửa sổ thứ hai, chọn emulator ở thanh trạng thái, nhấn F5.
6. Docker Desktop bản Apple Silicon là tùy chọn khi cần DB riêng. Nếu dùng Supabase chung thì lấy thông tin kết nối từ trưởng nhóm qua kênh riêng. Để tạo repo bằng CLI, cài [GitHub CLI](https://cli.github.com/), chạy `gh auth login`, rồi `gh auth status`.

`flutter doctor -v` liệt kê từng toolchain. Nếu thiếu cmdline-tools, bổ sung trong SDK Manager. Nếu chưa thấy máy, kiểm tra `flutter emulators` và `flutter devices`. Đóng mở lại VS Code sau khi đổi PATH. Xcode và iOS simulator chỉ cần cho iOS: cài Xcode, mở một lần để hoàn tất setup, cài iOS runtime trong Settings → Components, mở Simulator và chọn thiết bị. Cài CocoaPods nếu doctor yêu cầu cho plugin native. Giữ đủ dung lượng cho Gradle, NDK và simulator.

Tiếp tục với [lệnh chạy backend và mobile](../README.md).
