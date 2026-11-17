import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Khung màn hình dùng chung: phần header xanh nhạt ở trên,
/// phía dưới là tấm nền kem bo tròn hai góc trên đè lên header.
/// Dùng cho Vườn của tôi, Hồ sơ... (và các màn khác nếu muốn đồng nhất).
class HeaderSheetScaffold extends StatelessWidget {
  const HeaderSheetScaffold({
    super.key,
    required this.header,
    required this.body,
  });

  final Widget header;
  final Widget body;

  static const double _sheetRadius = 28;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.appBarColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            header,
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(_sheetRadius),
                ),
                child: ColoredBox(
                  color: AppTheme.scaffoldBackgroundColor,
                  child: SizedBox.expand(child: body),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
