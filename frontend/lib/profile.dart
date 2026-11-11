import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'settings.dart';
import 'page.dart';
import 'resource.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});
  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final email = TextEditingController(), password = TextEditingController();
  String? message;
  bool busy = false;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> authenticate({
    bool register = false,
    bool logout = false,
  }) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final auth = Supabase.instance.client.auth;
      if (logout) {
        await auth.signOut();
      } else if (register) {
        await auth.signUp(email: email.text.trim(), password: password.text);
      } else {
        await auth.signInWithPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
      password.clear();
      if (mounted && register && auth.currentSession == null) {
        setState(() => message = 'Kiểm tra email để xác nhận tài khoản.');
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => message = e.message);
    } catch (_) {
      if (mounted) setState(() => message = 'Chưa kết nối được Supabase.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Settings.hasAuth
        ? Supabase.instance.client.auth.currentUser
        : null;
    return PlantPage('Tài khoản', [
      ListTile(
        leading: const Icon(Icons.person_outline),
        title: Text(
          user?.email ?? (Settings.hasAuth ? 'Chưa đăng nhập' : 'Chế độ demo'),
        ),
        subtitle: Text(
          Settings.hasAuth
              ? 'Supabase Auth'
              : 'Chưa cấu hình Supabase trên thiết bị.',
        ),
      ),
      Resource(
        '/health',
        (h) => ListTile(
          leading: const Icon(Icons.dns_outlined),
          title: const Text('Máy chủ đang hoạt động'),
          subtitle: Text(
            "${h['isMock'] ? 'API giả lập' : 'API thật'} • ${h['demoAuth'] ? 'Người dùng demo' : 'Xác thực Supabase'}",
          ),
        ),
      ),
      if (Settings.hasAuth && user == null) ...[
        TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        TextField(
          controller: password,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Mật khẩu'),
        ),
        FilledButton(
          onPressed: busy ? null : () => authenticate(),
          child: const Text('Đăng nhập'),
        ),
        TextButton(
          onPressed: busy ? null : () => authenticate(register: true),
          child: const Text('Tạo tài khoản'),
        ),
      ],
      if (user != null)
        OutlinedButton(
          onPressed: busy ? null : () => authenticate(logout: true),
          child: const Text('Đăng xuất'),
        ),
      if (message != null) Text(message!),
    ]);
  }
}
