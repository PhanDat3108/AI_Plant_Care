# Backend Auth — bàn giao cho frontend

Chỉ backend được thay đổi. Supabase quản lý mật khẩu, email và phiên; Express cung cấp API cho frontend. Google OAuth/SMTP chưa được cấu hình trên tài khoản cloud nên chưa kiểm thử toàn luồng thật.

## Chạy

Tại backend: `npm ci`, `npm run db:generate`, `npm run dev`. Giữ DATABASE_URL/SSL, SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY trong `.env`. Giữ DEV_AUTH_BYPASS=false. Thêm `AUTH_REDIRECT_URL` là URL callback do nhóm frontend thống nhất (ví dụ `vn.aiplantcare.app://auth/callback`); thêm chính xác URL đó vào Supabase Authentication → URL Configuration → Redirect URLs. Nếu biến này để trống, các API cần callback sẽ trả 503 cho đến khi cấu hình.

Không gửi file `.env` backend cho app sử dụng. Frontend chỉ cần base URL API và hợp đồng callback. Trên Android Emulator base URL thường là http://10.0.2.2:3100/api/v1; máy thật dùng IP LAN, production dùng HTTPS.

## API

Mọi đường dẫn bên dưới bắt đầu bằng `/api/v1`. Body JSON, response dạng `{success,data,error,message}`. Các response Auth có Cache-Control no-store. Không log/lưu mật khẩu, token vào console.

Code Auth chia theo luồng `src/routes/auth.ts` → `src/controllers/auth.ts` → `src/services/auth.ts`: routes gắn URL/middleware; controller kiểm tra input và trả HTTP response; service gọi Supabase và xử lý kết quả xác thực, không phụ thuộc Express req/res. `src/middlewares/auth.ts` xác minh token, `src/middlewares/auth-no-store.ts` đặt chính sách không cache. Việc tách file không thay đổi hợp đồng API dưới đây.

| Method/path | Body | Kết quả |
| --- | --- | --- |
| POST /auth/register | email, password (8–256 ký tự), full_name | confirmation_required, session (null khi cần xác nhận email) |
| POST /auth/login | email, password | access_token, refresh_token, expires_in, token_type, user |
| POST /auth/refresh | refresh_token | Bộ token mới; frontend phải thay cả refresh token cũ |
| POST /auth/forgot-password | email | Thông báo trung tính, Supabase gửi link nếu hợp lệ |
| POST /auth/resend-confirmation | email | Gửi lại email xác nhận |
| POST /auth/google | code_challenge | URL đăng nhập Google để mở trong trình duyệt hệ thống |
| POST /auth/exchange-code | auth_code, code_verifier | Bộ token sau Google PKCE |
| POST /auth/reset-password | password | Cập nhật mật khẩu, yêu cầu Bearer token hợp lệ |
| POST /auth/logout | Không cần body | Thu hồi refresh token của phiên hiện tại, yêu cầu Bearer token |
| GET /me | Không có | Lấy/tạo hồ sơ của người đã xác thực |
| PATCH /me | display_name và/hoặc timezone | Cập nhật hồ sơ của chính mình |

Các API bảo vệ cần `Authorization: Bearer <Supabase access_token>`. Không dùng Google access token thay thế. API reset-password cũng phục vụ đổi mật khẩu khi đã đăng nhập. Không có API tự đặt lại mật khẩu chỉ bằng email.

Lỗi: 400 INVALID_INPUT/AUTH_FAILED, 401 UNAUTHORIZED cho API bảo vệ, 429 AUTH_RATE_LIMITED, 503 AUTH_UNAVAILABLE hoặc AUTH_REDIRECT_NOT_CONFIGURED. Không trả nguyên lỗi nội bộ Supabase. Supabase áp dụng rate limits; trước khi public backend cần bổ sung giới hạn request tại gateway theo IP, không chỉ dựa vào giao diện.

## Callback frontend cần xử lý

Google dùng PKCE: frontend sinh code_verifier ngẫu nhiên đủ mạnh (43–128 ký tự theo chuẩn PKCE), lưu tạm an toàn trên thiết bị; code_challenge = base64url(SHA256(verifier)) không padding. Gửi challenge tới /auth/google, mở URL trả về. Khi app nhận callback có `code`, gửi code đó dưới tên `auth_code` cùng verifier tới /auth/exchange-code. Xóa verifier sau hoàn tất. Backend chỉ chấp nhận callback cấu hình cố định, không nhận redirect tùy ý từ request.

Đăng ký và recovery hiện dùng luồng email của Supabase không PKCE: callback có thể mang session trong URL fragment. Frontend phải xử lý trên thiết bị, không ghi log URL chứa token. Với `type=recovery`, hiển thị màn hình đặt mật khẩu, dùng access token recovery gọi /auth/reset-password. Với signup, lấy session rồi gọi /me. Không gửi token về một website callback không kiểm soát. Nếu nhóm muốn dùng SDK PKCE cho mọi email flow, cần đổi hợp đồng cùng frontend, không trộn lẫn hai cơ chế.

Đăng xuất: frontend xóa token khỏi bộ nhớ/lưu trữ và giao diện. Access token cũ có thể còn hiệu lực đến hết hạn; logout thu hồi refresh token, không hứa thu hồi tức thì mọi JWT đã phát hành.

## Supabase email / SMTP

Authentication → Sign In / Providers → Email: bật đăng ký và Confirm email. Authentication → Email → SMTP Settings: nhập sender và SMTP credentials từ nhà cung cấp email của nhóm, xác minh sender/domain theo yêu cầu nhà cung cấp. Giữ template dùng ConfirmationURL. SMTP mặc định chỉ gửi tới thành viên team và có giới hạn thấp. Chưa có SMTP riêng thì chưa nghiệm thu gửi email cho người dùng ngoài team.

Tạo một tài khoản thử đã xác nhận trong Dashboard để test login trước; không cần tắt Confirm email toàn project. Không gửi mật khẩu thử vào chat.

## Google

1. Google Cloud → Google Auth Platform: cấu hình Branding/Audience và Test users.
2. Clients → Create client → Web application (đang dùng OAuth qua trình duyệt).
3. Authorized redirect URIs: copy callback từ Supabase Google provider. Project hiện tại: `https://htocmxwdinqldyeorrai.supabase.co/auth/v1/callback`.
4. Supabase → Authentication → Sign In / Providers → Google: bật, điền Client ID/Secret, Save. Secret chỉ lưu tại Supabase.
5. Supabase Redirect URLs: thêm URL quay về app trùng AUTH_REDIRECT_URL.

Google → Supabase dùng callback HTTPS; Supabase → app dùng callback của frontend. Đây là hai URL khác nhau.

## Kiểm thử

`npm test`, `npm run typecheck`, `npm run lint`, `npm run build`. Unit tests dùng mock, không chứng minh SMTP/Google cloud hoạt động. Không chạy test:db trên DB Supabase chung (fixture dành cho DB local).

Nghiệm thu thật: đăng ký → email → xác nhận; login đúng/sai; refresh; quên mật khẩu → link recovery → mật khẩu mới; Google đồng ý/hủy; gọi /me hai lần không tạo trùng; PATCH /me không sửa ID/người khác; logout và đăng nhập lại. Cần thiết bị callback hoặc frontend do nhóm cung cấp để kiểm thử luồng email/Google đầy đủ.

Tài liệu: [Google](https://supabase.com/docs/guides/auth/social-sign-in/auth-google), [SMTP](https://supabase.com/docs/guides/auth/auth-smtp), [redirects](https://supabase.com/docs/guides/auth/redirect-urls).

## Callback kiểm thử backend local

Đã có `GET /auth/callback` chỉ khi NODE_ENV=development. Khi test trên máy, đặt AUTH_REDIRECT_URL=http://localhost:3100/auth/callback và thêm đúng URL đó vào Supabase Redirect URLs. Mở trang callback để bắt đầu Google: trang tạo PKCE verifier/challenge, giữ verifier tạm trong sessionStorage cùng tab và đổi mã qua API khi quay về. Với email recovery, trang cho nhập mật khẩu mới, gọi reset-password rồi kiểm tra login/logout. Không cần Flutter. Không gửi token, link chứa token hoặc mật khẩu vào chat.

Trang này không lưu token/mật khẩu, xóa query/fragment khỏi thanh địa chỉ và đặt no-store/CSP. Nó không được mở ở production; khi deploy phải dùng callback thực tế đã thống nhất với client.
