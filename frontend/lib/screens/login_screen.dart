import 'package:flutter/material.dart';

import '../core/api_exception.dart';
import '../core/validators.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/header_sheet_scaffold.dart';
import '../widgets/primary_button.dart';
import 'navigation_bottombar.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await AuthService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      // TODO: sau khi đăng nhập có thể gọi GET /me để nạp hồ sơ.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const NavigationBottomBar()),
      );
    } on ApiException catch (e) {
      if (mounted) _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onForgotPassword() {
    // TODO: mở màn Quên mật khẩu (POST /auth/forgot-password) khi làm xong.
    _showMessage('Tính năng quên mật khẩu sẽ sớm có.');
  }

  void _onGoogleLogin() {
    // TODO: đăng nhập Google (PKCE + deep link) khi có URL callback từ backend.
    _showMessage('Đăng nhập bằng Google sẽ sớm có.');
  }

  void _openRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return HeaderSheetScaffold(
      header: const AuthHeader(title: 'AI Plant Care'),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthTextField(
                controller: _emailController,
                hint: 'Email',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: Validators.email,
                enabled: !_loading,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                controller: _passwordController,
                hint: 'Mật khẩu',
                icon: Icons.lock_outline_rounded,
                isPassword: true,
                textInputAction: TextInputAction.done,
                validator: Validators.requiredPassword,
                onFieldSubmitted: (_) => _submit(),
                enabled: !_loading,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _loading ? null : _onForgotPassword,
                  child: const Text(
                    'Quên mật khẩu?',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      decoration: TextDecoration.underline,
                      decorationColor: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              PrimaryButton(
                label: 'Đăng nhập',
                loading: _loading,
                onPressed: _submit,
              ),
              const SizedBox(height: 20),
              const Row(
                children: [
                  Expanded(child: Divider(color: Color(0xFFD9D9D9))),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Hoặc',
                      style: TextStyle(color: AppTheme.subTextColor),
                    ),
                  ),
                  Expanded(child: Divider(color: Color(0xFFD9D9D9))),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _onGoogleLogin,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.titleTextColor,
                    side: const BorderSide(color: Color(0xFFE5E5E5)),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  // TODO: thay bằng logo Google thật khi có file ảnh.
                  icon: Image.asset(
                    'assets/images/google-color.png',
                    width: 24,
                    height: 24,
                  ),
                  label: const Text('Đăng nhập bằng Google'),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Chưa có tài khoản? ',
                    style: TextStyle(color: AppTheme.titleTextColor),
                  ),
                  GestureDetector(
                    onTap: _loading ? null : _openRegister,
                    child: const Text(
                      'Đăng ký ngay',
                      style: TextStyle(
                        color: AppTheme.titleTextColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
