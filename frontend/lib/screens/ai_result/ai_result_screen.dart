import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../models/plant_model.dart';
import '../../services/plant_care_service.dart';
import '../../theme/app_theme.dart';
import '../plant_detail/plant_detail_screen.dart';
import 'ai_result_cards.dart';
import 'ai_result_header.dart';

class AiResultScreen extends StatefulWidget {
  final PlantModel plant;
  final double? confidence;

  const AiResultScreen({
    super.key,
    required this.plant,
    this.confidence,
  });

  @override
  State<AiResultScreen> createState() => _AiResultScreenState();
}

class _AiResultScreenState extends State<AiResultScreen> {
  bool _isAdding = false;

  String _formatError(Object e) {
    if (e is ApiException) return e.message;
    return e.toString().replaceAll('Exception: ', '');
  }

  Future<({String nickname, String environment})?> _showSavePlantDialog() async {
    final defaultName = widget.plant.nickname.trim().isNotEmpty
        ? widget.plant.nickname.trim()
        : widget.plant.commonName.trim();

    final nameController = TextEditingController(text: defaultName);
    var selectedEnvironment = widget.plant.environment;
    String? errorText;

    final result = await showDialog<({String nickname, String environment})>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Thêm vào Vườn của tôi',
                style: TextStyle(color: AppTheme.titleTextColor),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Biệt danh cho cây',
                      hintText: 'Ví dụ: Trầu bà phòng khách',
                      errorText: errorText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Vị trí đặt cây',
                    style: TextStyle(
                      color: AppTheme.subTextColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Trong nhà'),
                        selected: selectedEnvironment == 'indoor',
                        onSelected: (_) =>
                            setDialogState(() => selectedEnvironment = 'indoor'),
                      ),
                      ChoiceChip(
                        label: const Text('Ngoài trời'),
                        selected: selectedEnvironment == 'outdoor',
                        onSelected: (_) =>
                            setDialogState(() => selectedEnvironment = 'outdoor'),
                      ),
                      ChoiceChip(
                        label: const Text('Chưa rõ'),
                        selected: selectedEnvironment == 'unknown',
                        onSelected: (_) =>
                            setDialogState(() => selectedEnvironment = 'unknown'),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Hủy',
                    style: TextStyle(color: AppTheme.subTextColor),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final nickname = nameController.text.trim();
                    if (nickname.isEmpty) {
                      setDialogState(() {
                        errorText = 'Vui lòng nhập tên gọi cho cây.';
                      });
                      return;
                    }
                    Navigator.pop(
                      dialogContext,
                      (nickname: nickname, environment: selectedEnvironment),
                    );
                  },
                  child: const Text('Lưu cây'),
                ),
              ],
            );
          },
        );
      },
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      nameController.dispose();
    });
    return result;
  }

  Future<void> _addToGarden() async {
    if (_isAdding) return;

    final input = await _showSavePlantDialog();
    if (input == null || !mounted) return;

    setState(() => _isAdding = true);

    try {
      final created = await PlantCareService.saveScannedPlant(
        nickname: input.nickname,
        speciesId: widget.plant.speciesId,
        coverImageKey: widget.plant.imageUrl.trim().isNotEmpty
            ? widget.plant.imageUrl.trim()
            : null,
        environment: input.environment,
      );

      final newPlantId = created['id']?.toString();

      if (newPlantId != null && newPlantId.isNotEmpty) {
        // Đồng bộ kế hoạch chăm sóc sau khi transaction lưu cây đã commit
        try {
          await PlantCareService.syncCarePlan(newPlantId);
        } catch (_) {
          // Không chặn luồng lưu cây nếu loài chưa có dữ liệu duyệt/thời tiết
        }

        // Bổ sung dữ liệu chăm sóc AI ở request riêng để không giữ màn hình chờ Gemini
        if (widget.plant.speciesId != null &&
            widget.plant.speciesId!.trim().isNotEmpty) {
          unawaited(
            PlantCareService.enrichCareData(newPlantId).catchError(
              (_) => const PlantCareDataResult(),
            ),
          );
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã thêm cây vào Vườn của bạn!'),
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (newPlantId != null && newPlantId.isNotEmpty) {
        final updatedPlant = widget.plant.copyWith(
          nickname: input.nickname,
          environment: input.environment,
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PlantDetailScreen(
              plantId: newPlantId,
              initialPlant: updatedPlant,
            ),
          ),
        );
      } else {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAdding = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_formatError(e)),
          backgroundColor: AppTheme.sickBadgeText,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppTheme.titleTextColor,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Kết quả phân tích'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          children: [
            AiResultHeader(
              plant: widget.plant,
              isSick: isSick,
              confidence: widget.confidence,
            ),
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