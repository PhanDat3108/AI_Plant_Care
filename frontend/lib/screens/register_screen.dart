import 'package:flutter/material.dart';

import '../core/api_exception.dart';
import '../core/validators.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/header_sheet_scaffold.dart';
import '../widgets/primary_button.dart';
import 'check_email_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
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

    final email = _emailController.text.trim();

    setState(() => _loading = true);
    try {
      await AuthService.register(
        fullName: _fullNameController.text.trim(),
        email: email,
        password: _passwordController.text, // ô nhập lại KHÔNG gửi lên backend
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => CheckEmailScreen(email: email)),
      );
    } on ApiException catch (e) {
      if (mounted) _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HeaderSheetScaffold(
      header: const AuthHeader(
        title: 'Đăng ký tài khoản',
        showBack: true,
        logoSize: 64,
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthTextField(
                controller: _fullNameController,
                hint: 'Họ và Tên',
                icon: Icons.person_outline_rounded,
                textInputAction: TextInputAction.next,
                validator: Validators.fullName,
                enabled: !_loading,
              ),
              const SizedBox(height: 16),
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
                hint: 'Mật khẩu (từ 8 ký tự)',
                icon: Icons.lock_outline_rounded,
                isPassword: true,
                textInputAction: TextInputAction.next,
                validator: Validators.newPassword,
                enabled: !_loading,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                controller: _confirmController,
                hint: 'Nhập lại mật khẩu',
                icon: Icons.lock_outline_rounded,
                isPassword: true,
                textInputAction: TextInputAction.done,
                validator:
                    Validators.confirmPassword(() => _passwordController.text),
                onFieldSubmitted: (_) => _submit(),
                enabled: !_loading,
              ),
              const SizedBox(height: 28),
              PrimaryButton(
                label: 'Đăng ký',
                loading: _loading,
                onPressed: _submit,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Đã có tài khoản? ',
                    style: TextStyle(color: AppTheme.titleTextColor),
                  ),
                  GestureDetector(
                    onTap: _loading ? null : () => Navigator.maybePop(context),
                    child: const Text(
                      'Đăng nhập',
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
