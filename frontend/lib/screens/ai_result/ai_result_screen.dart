import 'package:flutter/material.dart';
import '../../models/plant_model.dart';
import '../../theme/app_theme.dart';
import 'ai_result_header.dart';
import 'ai_result_cards.dart';

class AiResultScreen extends StatefulWidget {
  final PlantModel plant;

  const AiResultScreen({super.key, required this.plant});

  @override
  State<AiResultScreen> createState() => _AiResultScreenState();
}

class _AiResultScreenState extends State<AiResultScreen> {
  bool _isAdding = false;

  // Giả lập luồng lưu cây vào CSDL
  Future<void> _addToGarden() async {
    setState(() {
      _isAdding = true;
    });

    // Mô phỏng delay mạng
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    setState(() {
      _isAdding = false;
    });

    // Báo thành công
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã thêm cây vào Vườn của bạn!'),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Quay về màn hình chính (hoặc có thể điều hướng thẳng sang PlantDetail)
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final bool isSick = widget.plant.healthStatus == HealthStatus.sick;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.titleTextColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Kết quả phân tích'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100), // Chừa không gian cho nút bấm nổi
        child: Column(
          children: [
            AiResultHeader(plant: widget.plant, isSick: isSick),
            AiResultCareSummary(plant: widget.plant),
            if (isSick) AiResultDiseaseCard(plant: widget.plant),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: AiResultAddButton(
        isAdding: _isAdding,
        onAdd: _addToGarden,
      ),
    );
  }
}
