import { randomUUID } from "node:crypto";
import type { RequestHandler } from "express";

// Local backend diagnostic page, not a frontend application or a session store.
export const authCallback: RequestHandler = (_req, res) => {
  const nonce = randomUUID();
  res.setHeader("Cache-Control", "no-store");
  res.setHeader("Referrer-Policy", "no-referrer");
  res.setHeader("X-Content-Type-Options", "nosniff");
  res.setHeader(
    "Content-Security-Policy",
    `default-src 'none'; script-src 'nonce-${nonce}'; connect-src 'self'; base-uri 'none'; frame-ancestors 'none'; form-action 'none'`,
  );
  res.type("html")
    .send(`<!doctype html><html lang="vi"><meta charset="utf-8"><title>Kiểm thử Auth backend</title>
<h1>Kiểm thử Auth backend</h1><p id="status">Đang đọc callback…</p>
<button id="google" type="button" hidden>Thử đăng nhập Google</button><p id="instructions"></p><button id="copy" hidden>Sao chép thông tin phiên để test Postman</button>
<section id="recovery" hidden>
<p>Nhập email thử và mật khẩu mới. Trang sẽ gọi API đổi mật khẩu, đăng nhập lại để kiểm tra rồi đăng xuất phiên kiểm thử.</p>
<label>Email <input id="email" type="email" autocomplete="username"></label>
<label>Mật khẩu mới <input id="password" type="password" minlength="8" maxlength="256" autocomplete="new-password"></label>
<button id="reset" type="button">Đổi mật khẩu và kiểm tra đăng nhập</button>
</section>
<script nonce="${nonce}">
(async () => {
 const query = new URLSearchParams(location.search);
 const fragment = new URLSearchParams(location.hash.slice(1));
 history.replaceState(null, '', location.pathname);
 const status = document.getElementById('status');
 const instructions = document.getElementById('instructions');
 const copy = document.getElementById('copy');
 const error = query.get('error') || fragment.get('error');
 if (error) { sessionStorage.removeItem('auth-test-verifier'); status.textContent = 'Liên kết không hợp lệ, đã hết hạn hoặc đăng nhập bị hủy. Hãy yêu cầu lại.'; return; }
 const code = query.get('code');
 let payload;
 if (code) {
   status.textContent = 'Đã nhận mã Google OAuth. Chưa đổi mã lấy phiên đăng nhập.';
   instructions.textContent = 'POST /api/v1/auth/exchange-code với auth_code này và code_verifier đã tạo trước khi đăng nhập. Mã chỉ dùng một lần.';
   const verifier = sessionStorage.getItem('auth-test-verifier');
   sessionStorage.removeItem('auth-test-verifier');
   if (verifier) {
     try {
       const r = await fetch('/api/v1/auth/exchange-code', {method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({auth_code:code,code_verifier:verifier})});
       const result = await r.json();
       if (!r.ok) {status.textContent='Không đổi được mã Google. Hãy bắt đầu lại luồng đăng nhập.';return;}
       payload=result.data;
       const me=await fetch('/api/v1/me',{headers:{Authorization:'Bearer '+payload.access_token},cache:'no-store'});
       status.textContent=me.ok ? 'Đăng nhập Google, đổi mã lấy token và lấy hồ sơ: thành công.' : 'Google trả phiên thành công nhưng chưa lấy được hồ sơ backend.';
       instructions.textContent='Đây là kết quả kiểm thử backend. Không chia sẻ token.';
     } catch {status.textContent='Không kết nối được backend. Hãy bắt đầu lại luồng Google.';return;}
   } else {payload = {auth_code: code};}
 } else {
   const token = fragment.get('access_token');
   if (!token) {
     status.textContent = 'Callback đã sẵn sàng. Hãy mở liên kết email hoặc thử Google bên dưới.';
     const google = document.getElementById('google'); google.hidden=false;
     google.onclick = async () => {
       google.disabled=true;
       try {
         const bytes=crypto.getRandomValues(new Uint8Array(32));
         const encode=(bytes)=>btoa(String.fromCharCode(...bytes)).replaceAll('+','-').replaceAll('/','_').replaceAll('=','');
         const verifier=encode(bytes);
         const challenge=encode(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(verifier))));
         const r=await fetch('/api/v1/auth/google',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({code_challenge:challenge})});
         const result=await r.json();
         if(!r.ok){status.textContent='Chưa tạo được URL Google. Kiểm tra cấu hình callback.';return;}
         sessionStorage.setItem('auth-test-verifier',verifier);
         location.assign(result.data.url);
       } catch {status.textContent='Chưa bắt đầu được đăng nhập Google.';}
       finally {google.disabled=false;}
     };return;
   }
   try {
     const r = await fetch('/api/v1/me', {headers:{Authorization:'Bearer '+token},cache:'no-store'});
     if (!r.ok) { status.textContent = 'Đã nhận phiên nhưng backend chưa xác minh được. Kiểm tra trạng thái dịch vụ hoặc yêu cầu link mới.'; return; }
     status.textContent = fragment.get('type') === 'recovery' ? 'Phiên khôi phục hợp lệ. Có thể đặt mật khẩu mới.' : 'Phiên đăng nhập hợp lệ. Backend đã đọc/tạo hồ sơ thành công.';
     instructions.textContent = fragment.get('type') === 'recovery' ? 'Dùng access_token làm Bearer token, POST /api/v1/auth/reset-password với body {"password":"mật khẩu mới"}. Không chia sẻ token.' : 'Dùng access_token làm Bearer token để kiểm thử API. Không chia sẻ token.';
     payload = {access_token: token,refresh_token:fragment.get('refresh_token'),token_type:'bearer'};
   } catch { status.textContent = 'Không kết nối được backend. Hãy thử lại luồng xác thực.'; return; }
 }
 if (fragment.get('type') === 'recovery' && payload.access_token) {
   document.getElementById('recovery').hidden = false;
   instructions.textContent = 'Dùng biểu mẫu bên dưới. Không gửi mật khẩu hoặc token vào chat.';
   const reset = document.getElementById('reset');
   reset.onclick = async () => {
     const emailField = document.getElementById('email');
     const passwordField = document.getElementById('password');
     const password = passwordField.value;
     if (!emailField.value || !emailField.checkValidity() || password.length < 8 || password.length > 256) { status.textContent = 'Điền đúng email và mật khẩu từ 8 đến 256 ký tự.'; return; }
     reset.disabled = true;
     try {
       const changed = await fetch('/api/v1/auth/reset-password', {method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer '+payload.access_token},body:JSON.stringify({password})});
       if (!changed.ok) {status.textContent='Không đổi được mật khẩu. Kiểm tra link còn hạn và chính sách mật khẩu.'; return;}
       const login = await fetch('/api/v1/auth/login', {method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:emailField.value.trim(),password})});
       passwordField.value='';
       if (!login.ok) {status.textContent='Đã đổi mật khẩu nhưng đăng nhập lại chưa thành công. Kiểm tra email đã nhập.';return;}
       const result=await login.json();
       const logout=await fetch('/api/v1/auth/logout',{method:'POST',headers:{Authorization:'Bearer '+result.data.access_token}});
       status.textContent=logout.ok ? 'Đổi mật khẩu, đăng nhập bằng mật khẩu mới và đăng xuất: thành công.' : 'Đổi mật khẩu và đăng nhập mới thành công; chưa đăng xuất được phiên thử.';
       document.getElementById('recovery').hidden=true;
     } catch {status.textContent='Lỗi kết nối. Mật khẩu có thể đã đổi; kiểm tra bằng đăng nhập trước khi thử lại.';}
     finally {reset.disabled=false;}
   };
   return;
 }
 copy.hidden = false;
 copy.onclick = async () => { try { await navigator.clipboard.writeText(JSON.stringify(payload));copy.textContent='Đã sao chép. Không gửi nội dung này vào chat.'; } catch {copy.textContent='Trình duyệt chưa cho phép sao chép.';} };
})();
</script></html>`);
};
