import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Phần đầu (logo + tiêu đề) dùng chung cho Đăng nhập / Đăng ký / Chờ xác nhận.
/// Đặt vào tham số `header` của HeaderSheetScaffold.
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.title,
    this.showBack = false,
    this.logoSize = 76,
  });

  final String title;
  final bool showBack;
  final double logoSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      child: Column(
        children: [
          SizedBox(
            height: 40,
            child: Align(
              alignment: Alignment.centerLeft,
              child: showBack
                  ? IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: AppTheme.titleTextColor,
                      ),
                      onPressed: () => Navigator.maybePop(context),
                    )
                  : null,
            ),
          ),
          // TODO: thay bằng logo thật (Image.asset) khi có file ảnh.
          Container(
            width: logoSize,
            height: logoSize,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: Icon(
              Icons.local_florist_rounded,
              size: logoSize * 0.55,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.titleTextColor,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
