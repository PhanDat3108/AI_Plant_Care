import 'package:flutter/material.dart';

import '../core/api_exception.dart';
import '../core/validators.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/header_sheet_scaffold.dart';
import '../widgets/primary_button.dart';

/// Màn Quên mật khẩu: nhập email, gọi POST /auth/forgot-password.
/// Backend luôn trả thông báo trung tính (không tiết lộ email có tồn tại hay không),
/// nên app cũng hiện cùng một thông báo cho mọi email hợp lệ.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController =
      TextEditingController(text: widget.initialEmail);
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
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
      await AuthService.forgotPassword(_emailController.text.trim());
      if (mounted) setState(() => _sent = true);
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
        title: 'Quên mật khẩu',
        showBack: true,
        logoSize: 64,
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: _sent ? _buildSent() : _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Nhập email đã đăng ký, chúng tôi sẽ gửi liên kết để bạn đặt lại mật khẩu.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.subTextColor,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          AuthTextField(
            controller: _emailController,
            hint: 'Email',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            validator: Validators.email,
            onFieldSubmitted: (_) => _submit(),
            enabled: !_loading,
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Gửi liên kết đặt lại',
            loading: _loading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  Widget _buildSent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.mark_email_read_outlined,
          size: 72,
          color: AppTheme.primaryColor,
        ),
        const SizedBox(height: 20),
        const Text(
          'Nếu email này đã đăng ký, bạn sẽ nhận được liên kết đặt lại mật khẩu. '
          'Hãy kiểm tra hộp thư (cả mục Spam), mở liên kết để đặt mật khẩu mới '
          'rồi quay lại đăng nhập.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.subTextColor,
            fontSize: 15,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),
        PrimaryButton(
          label: 'Về đăng nhập',
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => _sent = false),
          child: const Text(
            'Gửi lại cho email khác',
            style: TextStyle(
              color: AppTheme.titleTextColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
