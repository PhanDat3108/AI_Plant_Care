import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'navigation_bottombar.dart';

/// Cổng vào app: đã có phiên đăng nhập thì vào thẳng màn chính,
/// chưa có thì hiện màn Đăng nhập.
/// Dùng trong main.dart:  home: const AuthGate(),
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<bool> _sessionFuture = AuthService.hasSession();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
          );
        }
        return snapshot.data == true
            ? const NavigationBottomBar()
            : const LoginScreen();
      },
    );
  }
}
