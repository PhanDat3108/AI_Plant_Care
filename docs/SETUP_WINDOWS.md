# Windows và Android

1. Cài [Git for Windows](https://git-scm.com/downloads/win) và Node 24 LTS bản Windows từ [Node.js](https://nodejs.org/en/download). Mở PowerShell mới. Chạy `git --version`, `node -v`, `npm.cmd -v`. Nếu PowerShell chặn npm.ps1, dùng npm.cmd cho các lệnh npm.
2. Tải Flutter 3.47.5 stable từ [Flutter SDK archive](https://docs.flutter.dev/install/archive), giải nén vào thư mục người dùng có quyền ghi và thêm thư mục bin vào User PATH. Mở lại PowerShell và VS Code. Chạy `flutter --version`.
3. Cài Android Studio. SDK Manager → cài Android SDK Platform 37, Build Tools, Platform Tools, Emulator, Command-line Tools (latest). Dùng JDK bundled. Device Manager → Create Virtual Device → chọn Pixel, chọn system image phù hợp CPU → Finish → Play. Bật virtualization trong BIOS/UEFI nếu emulator yêu cầu. Trong PowerShell chạy `flutter doctor -v`, `flutter doctor --android-licenses`, `flutter devices`. Android demo không yêu cầu Xcode hoặc bộ công cụ Visual Studio cho Windows desktop.
4. Cài VS Code và extension Flutter/Dart. Mở repo cho terminal backend, mở riêng apps/mobile để chọn emulator và nhấn F5. Nếu gặp lỗi symlink plugin, bật Developer Mode trong Windows Settings.
5. Docker Desktop (WSL2) chỉ cần khi dùng Postgres trên máy. Khi dùng Supabase chung, điền DATABASE_URL và DIRECT_URL trong file .env rồi bỏ bước Compose. GitHub CLI tùy chọn: cài từ [GitHub CLI](https://cli.github.com/), chạy `gh auth login` rồi `gh auth status`.

Từ gốc repo mới clone, terminal backend:

```powershell
Copy-Item apps/api/.env.example apps/api/.env
npm.cmd ci
npm.cmd run db:generate
docker compose -f infra/docker-compose.yml up -d --wait
npm.cmd run db:migrate
npm.cmd run db:seed
npm.cmd run dev
```

Terminal mobile:

```powershell
Set-Location apps/mobile
flutter pub get
flutter analyze
flutter test
flutter run
```

Kiểm tra API trên host bằng `Invoke-RestMethod http://localhost:3100/api/v1/health`. Xem [README](../README.md) để kết nối emulator hoặc điện thoại qua LAN.
