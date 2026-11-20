# Google login trên Flutter mobile

Backend có POST /api/v1/auth/google (body code_challenge) và POST /api/v1/auth/exchange-code (body auth_code, code_verifier). Response token dùng như email login. Client không truyền redirect_to; backend quyết định callback từ cấu hình.

## Backend của mỗi thành viên

Thêm vào backend/.env:

```env
GOOGLE_AUTH_REDIRECT_URL=vn.aiplantcare.app://auth/callback
```

Giữ AUTH_REDIRECT_URL hiện có cho đăng ký/xác nhận email và khôi phục mật khẩu. Nếu biến Google thiếu hoặc rỗng, backend dùng AUTH_REDIRECT_URL để tương thích cấu hình cũ. Không cần migration hay package mới. Khởi động lại backend sau khi sửa .env.

## Cấu hình Supabase (người quản lý project làm một lần)

Authentication → URL Configuration → Redirect URLs: thêm chính xác `vn.aiplantcare.app://auth/callback`, lưu. Giữ URL callback email đang sử dụng.

Google provider vẫn cần được bật với Client ID/Secret đã cấu hình. Trong Google Cloud, Authorized redirect URI vẫn là callback HTTPS của Supabase (copy từ màn hình provider); không thay bằng deep link mobile. Nếu ứng dụng OAuth đang Testing, tài khoản thử cần có trong danh sách Test users khi cấu hình Google yêu cầu.

## Frontend

1. Thêm crypto, url_launcher, app_links. Dùng flutter_secure_storage đã có để lưu verifier tạm.
2. Khởi tạo listener app_links sớm ở cấp app, nhận cả lần mở app từ trạng thái tắt và khi đang chạy; kiểm tra scheme/host/path, xử lý lỗi callback, chống callback trùng và phối hợp AuthGate.
3. Bấm Google: tạo verifier bằng Random.secure (32 byte → base64url bỏ padding), challenge = base64url(SHA256(verifier)) bỏ padding. Lưu verifier/thời điểm tạo, chỉ giữ một lượt đăng nhập đang chờ.
4. POST /auth/google với code_challenge, auth:false. DioClient hiện trả phần data trực tiếp; lấy result['url']. Mở bằng trình duyệt hệ thống.
5. Đăng ký custom URL scheme vn.aiplantcare.app trên iOS và intent filter Android (VIEW/DEFAULT/BROWSABLE, scheme vn.aiplantcare.app, host auth, path /callback), theo hướng dẫn app_links và tắt cơ chế deep link mặc định của Flutter nếu plugin yêu cầu.
6. Khi nhận vn.aiplantcare.app://auth/callback?code=...: lấy query code và verifier của lượt đang chờ, POST /auth/exchange-code với auth_code/code_verifier, auth:false. Không tạo verifier mới ở bước này. Không ghi log URL callback/code/token.
7. Lưu access_token/refresh_token qua TokenStorage.save, dọn verifier, gọi ProfileService.getMe rồi vào NavigationBottomBar. Hủy/thất bại phải cho thử lại; thiếu verifier thì bắt đầu lại Google login.

Không cần Google Client Secret trong app. Luồng hiện tại là trình duyệt OAuth/PKCE, không dùng token từ google_sign_in để gửi vào exchange-code.

## Kiểm thử

- Kiểm tra deep link mở được app trước, rồi mới thử Google.
- Đăng nhập trên simulator/điện thoại, hủy đăng nhập, callback trùng, đóng app giữa luồng, mở lại app sau thành công.
- API base URL: Android emulator 10.0.2.2:3100; iOS simulator localhost:3100; máy thật dùng IP LAN/server HTTPS.
- Trang localhost:3100/auth/callback vẫn dùng cho email. Nút Google trên trang kiểm thử web sẽ chuyển về mobile khi biến Google đã được cấu hình; muốn test Google trên web thì dùng backend riêng với biến Google trống.

Tài liệu: https://supabase.com/docs/guides/auth/native-mobile-deep-linking và https://pub.dev/packages/app_links
