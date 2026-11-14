-- Chỉ chạy khi project dùng Supabase Auth và các profile hiện tại đều có tài khoản tương ứng.
ALTER TABLE plantcare.profiles
    ADD CONSTRAINT profiles_auth_user_fk
    FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
