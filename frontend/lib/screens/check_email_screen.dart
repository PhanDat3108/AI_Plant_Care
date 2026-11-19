import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api_exception.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_header.dart';
import '../widgets/header_sheet_scaffold.dart';
import '../widgets/primary_button.dart';
import 'login_screen.dart';

/// Màn "Chờ xác nhận email" sau khi đăng ký thành công.
/// Nút Gửi lại: POST /auth/resend-confirmation, có đếm ngược 60 giây.
class CheckEmailScreen extends StatefulWidget {
  const CheckEmailScreen({super.key, required this.email});

  final String email;

  @override
  State<CheckEmailScreen> createState() => _CheckEmailScreenState();
}

class _CheckEmailScreenState extends State<CheckEmailScreen> {
  static const int _cooldownSeconds = 60;

  Timer? _timer;
  int _secondsLeft = 0;
  bool _sending = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _cooldownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _resend() async {
    setState(() => _sending = true);
    try {
      await AuthService.resendConfirmation(widget.email);
      if (!mounted) return;
      _showMessage('Đã gửi lại email xác nhận.');
      _startCooldown();
    } on ApiException catch (e) {
      if (mounted) _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _backToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _secondsLeft <= 0 && !_sending;

    return HeaderSheetScaffold(
      header: const AuthHeader(title: 'Kiểm tra email', logoSize: 64),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.mark_email_read_outlined,
              size: 72,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 20),
            const Text(
              'Chúng tôi đã gửi email xác nhận tới',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.subTextColor, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              widget.email,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.titleTextColor,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Hãy mở email và bấm vào liên kết để kích hoạt tài khoản, '
              'sau đó quay lại đăng nhập.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.subTextColor,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            PrimaryButton(
              label: _secondsLeft > 0
                  ? 'Gửi lại email (${_secondsLeft}s)'
                  : 'Gửi lại email',
              loading: _sending,
              onPressed: canResend ? _resend : null,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _backToLogin,
              child: const Text(
                'Về đăng nhập',
                style: TextStyle(
                  color: AppTheme.titleTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
