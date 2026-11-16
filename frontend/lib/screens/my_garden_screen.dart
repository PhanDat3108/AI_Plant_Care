import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MyGardenScreen extends StatelessWidget {
  const MyGardenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Giao diện Vườn cây', style: TextStyle(color: AppTheme.subTextColor))),
    );
  }
}