import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Ô nhập dạng "viên thuốc" cho các màn Đăng nhập / Đăng ký:
/// có icon bên trái, và nút con mắt ẩn/hiện khi là ô mật khẩu.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.isPassword = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onFieldSubmitted,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final bool enabled;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _obscure = true;

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: widget.isPassword && _obscure,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      onFieldSubmitted: widget.onFieldSubmitted,
      autocorrect: false,
      enableSuggestions: !widget.isPassword,
      style: const TextStyle(color: AppTheme.titleTextColor, fontSize: 16),
      decoration: InputDecoration(
        hintText: widget.hint,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        prefixIcon: Icon(widget.icon, color: AppTheme.subTextColor),
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppTheme.subTextColor,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
        border: _border(const Color(0xFFE5E5E5)),
        enabledBorder: _border(const Color(0xFFE5E5E5)),
        disabledBorder: _border(const Color(0xFFE5E5E5)),
        focusedBorder: _border(AppTheme.primaryColor, width: 2),
        errorBorder: _border(AppTheme.sickBadgeText),
        focusedErrorBorder: _border(AppTheme.sickBadgeText, width: 2),
        errorStyle: const TextStyle(color: AppTheme.sickBadgeText),
      ),
    );
  }
}
