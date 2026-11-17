import 'package:flutter/material.dart';
import '../../models/plant_model.dart';
import '../../theme/app_theme.dart';

class AiResultScreen extends StatelessWidget {
  final PlantModel plant;

  const AiResultScreen({super.key, required this.plant});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kết quả phân tích')),
      body: Center(
        child: Text(
          'Giao diện Kết quả AI (Đang xây dựng)\nCây: ${plant.commonName}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.subTextColor),
        ),
      ),
    );
  }
}