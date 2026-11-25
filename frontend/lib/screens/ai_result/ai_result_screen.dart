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
  final String? localImagePath;
  final String? coverImageKey;
  final String? healthStatusRaw;
  final bool isMock;
  final String? existingPlantId;

  const AiResultScreen({
    super.key,
    required this.plant,
    this.confidence,
    this.localImagePath,
    this.coverImageKey,
    this.healthStatusRaw,
    this.isMock = false,
    this.existingPlantId,
  });

  @override
  State<AiResultScreen> createState() => _AiResultScreenState();
}

class _AiResultScreenState extends State<AiResultScreen> {
  bool _isAdding = false;

  static const _cityCoords = <String, ({double lat, double lng})>{
    'Hà Nội': (lat: 21.0285, lng: 105.8542),
    'TP. Hồ Chí Minh': (lat: 10.8231, lng: 106.6297),
    'Đà Nẵng': (lat: 16.0544, lng: 108.2022),
    'Hải Phòng': (lat: 20.8449, lng: 106.6881),
    'Cần Thơ': (lat: 10.0452, lng: 105.7469),
  };

  String _formatError(Object e) {
    if (e is ApiException) return e.message;
    return e.toString().replaceAll('Exception: ', '');
  }

  Future<
    ({String nickname, String environment, double latitude, double longitude})?
  >
  _showSavePlantDialog() {
    var nicknameText = widget.plant.nickname.trim().isNotEmpty
        ? widget.plant.nickname.trim()
        : widget.plant.commonName.trim();
    var selectedEnvironment = widget.plant.environment;
    var selectedCity = 'Hà Nội';
    String? errorText;

    return showDialog<
      ({String nickname, String environment, double latitude, double longitude})
    >(
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
                  TextFormField(
                    initialValue: nicknameText,
                    onChanged: (val) => nicknameText = val,
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
                  const SizedBox(height: 16),
                  const Text(
                    'Khu vực (lấy thời tiết)',
                    style: TextStyle(
                      color: AppTheme.subTextColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: selectedCity,
                    items: _cityCoords.keys
                        .map(
                          (city) =>
                              DropdownMenuItem(value: city, child: Text(city)),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedCity = val);
                    },
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Trong nhà'),
                        selected: selectedEnvironment == 'indoor',
                        onSelected: (_) => setDialogState(
                          () => selectedEnvironment = 'indoor',
                        ),
                      ),
                      ChoiceChip(
                        label: const Text('Ngoài trời'),
                        selected: selectedEnvironment == 'outdoor',
                        onSelected: (_) => setDialogState(
                          () => selectedEnvironment = 'outdoor',
                        ),
                      ),
                      ChoiceChip(
                        label: const Text('Chưa rõ'),
                        selected: selectedEnvironment == 'unknown',
                        onSelected: (_) => setDialogState(
                          () => selectedEnvironment = 'unknown',
                        ),
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
                    final nickname = nicknameText.trim();
                    if (nickname.isEmpty) {
                      setDialogState(() {
                        errorText = 'Vui lòng nhập tên gọi cho cây.';
                      });
                      return;
                    }
                    final coords = _cityCoords[selectedCity]!;
                    Navigator.pop(dialogContext, (
                      nickname: nickname,
                      environment: selectedEnvironment,
                      latitude: coords.lat,
                      longitude: coords.lng,
                    ));
                  },
                  child: const Text('Lưu cây'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addToGarden() async {
    if (_isAdding) return;

    final input = await _showSavePlantDialog();
    if (input == null || !mounted) return;

    setState(() => _isAdding = true);

    try {
      final rawCoverKey = (widget.coverImageKey?.trim().isNotEmpty ?? false)
          ? widget.coverImageKey!.trim()
          : null;

      final created = await PlantCareService.saveScannedPlant(
        nickname: input.nickname,
        speciesId: widget.plant.speciesId,
        coverImageKey: rawCoverKey,
        environment: input.environment,
        latitude: input.latitude,
        longitude: input.longitude,
      );

      final newPlantId = created['id']?.toString();

      if (newPlantId != null && newPlantId.isNotEmpty) {
        try {
          await PlantCareService.syncCarePlan(newPlantId);
        } catch (_) {
          // Không chặn luồng lưu cây nếu loài chưa có dữ liệu duyệt/thời tiết
        }

        if (widget.plant.speciesId != null &&
            widget.plant.speciesId!.trim().isNotEmpty) {
          unawaited(
            PlantCareService.enrichCareData(newPlantId)
                .catchError((_) => const PlantCareDataResult()),
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
    final bool hasFindings =
        (widget.plant.symptoms?.isNotEmpty ?? false) ||
        (widget.plant.treatmentSteps?.isNotEmpty ?? false);

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
              localImagePath: widget.localImagePath,
              healthStatusRaw: widget.healthStatusRaw,
              isMock: widget.isMock,
            ),
            AiResultCareSummary(plant: widget.plant),
            if (isSick || hasFindings)
              AiResultDiseaseCard(plant: widget.plant, isSick: isSick),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: widget.existingPlantId == null
          ? AiResultAddButton(isAdding: _isAdding, onAdd: _addToGarden)
          : null,
    );
  }
}
