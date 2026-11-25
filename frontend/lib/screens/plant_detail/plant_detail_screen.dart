import '../../core/plant_image_url.dart';

import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../models/plant_model.dart';
import '../../models/task_model.dart';
import '../../services/care_log_service.dart';
import '../../services/plant_care_service.dart';
import '../../theme/app_theme.dart';
import '../ai_scan/scan_screen.dart';
import 'plant_detail_dialogs.dart';
import 'plant_detail_header.dart';
import 'plant_detail_tabs.dart';

class PlantDetailScreen extends StatefulWidget {
  final String plantId;
  final PlantModel? initialPlant;

  const PlantDetailScreen({
    super.key,
    required this.plantId,
    this.initialPlant,
  });

  @override
  State<PlantDetailScreen> createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends State<PlantDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  PlantModel? _plant;
  bool _isLoading = true;
  bool _isSavingSchedule = false;
  bool _isSyncingPlan = false;
  bool _isEnrichingCare = false;
  bool _isMutatingPlant = false;
  bool _isMutatingLog = false;
  String? _errorMessage;
  String? _careDataNotice;
  List<String> _syncWarnings = [];
  List<TaskModel> _scheduledTasks = [];
  String? _syncSummary;
  bool _hasWaterSchedule = false;
  bool _hasFertilizeSchedule = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _plant = widget.initialPlant;
    _loadPlantData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatError(Object e) {
    if (e is ApiException) return e.message;
    return e.toString().replaceAll('Exception: ', '');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // --- Tải dữ liệu tổng hợp của cây ---

  Future<void> _loadPlantData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _careDataNotice = null;
    });

    Map<String, dynamic>? gardenPlant;
    CareSchedulesResult? schedules;
    PlantCareDataResult? careData;
    List<CareLog> careLogs = widget.initialPlant?.logs ?? const [];
    String? careDataNotice;
    Object? fatalError;

    try {
      schedules = await PlantCareService.getSchedules(widget.plantId);
    } catch (e) {
      fatalError = e;
    }

    try {
      gardenPlant = await PlantCareService.getGardenPlantById(widget.plantId);
    } catch (e) {
      if (widget.initialPlant == null && schedules == null) {
        fatalError ??= e;
      }
    }

    try {
      careData = await PlantCareService.getCareData(widget.plantId);
    } on ApiException catch (e) {
      careDataNotice = e.message;
    } catch (e) {
      careDataNotice = _formatError(e);
    }

    try {
      careLogs = await CareLogService.listByPlant(widget.plantId, limit: 100);
    } catch (_) {}

    if (!mounted) return;

    if (gardenPlant == null &&
        schedules == null &&
        widget.initialPlant == null) {
      setState(() {
        _errorMessage = fatalError != null
            ? _formatError(fatalError)
            : 'Không tìm thấy thông tin cây.';
        _isLoading = false;
      });
      return;
    }

    final base = widget.initialPlant;
    final waterSchedule = schedules?.findByKind('water');
    final fertilizeSchedule = schedules?.findByKind('fertilize');

    final nickname = gardenPlant?['nickname']?.toString().trim();
    final coverUrl = gardenPlant == null
        ? base?.imageUrl ?? ''
        : plantImageUrl(gardenPlant);
    final speciesId = gardenPlant?['species_id']?.toString().trim();
    final environment = gardenPlant?['environment']?.toString().trim();

    final waterTime =
        waterSchedule?.localTime ?? base?.effectiveWaterTime ?? '08:00';
    final fertilizeTime =
        fertilizeSchedule?.localTime ?? base?.effectiveFertilizeTime ?? '08:00';

    setState(() {
      _plant = PlantModel(
        id: widget.plantId,
        speciesId: speciesId ?? base?.speciesId,
        environment: environment ?? base?.environment ?? 'unknown',
        nickname: (nickname != null && nickname.isNotEmpty)
            ? nickname
            : (base?.nickname ?? careData?.commonName ?? 'Cây của tôi'),
        scientificName: careData?.scientificName ?? base?.scientificName ?? '',
        commonName: careData?.commonName ?? base?.commonName ?? '',
        imageUrl: coverUrl,
        healthStatus: base?.healthStatus ?? HealthStatus.healthy,
        diseaseName: base?.diseaseName,
        symptoms: base?.symptoms,
        treatmentSteps: base?.treatmentSteps,
        sunlightInfo:
            careData?.lightGuide ??
            base?.sunlightInfo ??
            'Chưa có hướng dẫn ánh sáng.',
        waterInfo:
            careData?.waterGuide ??
            base?.waterInfo ??
            'Chưa có hướng dẫn tưới nước.',
        temperatureInfo:
            careData?.temperatureGuide ??
            base?.temperatureInfo ??
            'Chưa có hướng dẫn nhiệt độ.',
        soilInfo: careData?.soilGuide ?? base?.soilInfo,
        fertilizerInfo: careData?.fertilizerGuide ?? base?.fertilizerInfo,
        careStatus: careData?.careStatus ?? base?.careStatus,
        wateringFrequencyDays:
            waterSchedule?.intervalDays ??
            careData?.wateringDays ??
            base?.wateringFrequencyDays ??
            3,
        fertilizingFrequencyDays:
            fertilizeSchedule?.intervalDays ??
            careData?.fertilizingDays ??
            base?.fertilizingFrequencyDays ??
            14,
        reminderTime: waterTime,
        waterReminderTime: waterTime,
        fertilizeReminderTime: fertilizeTime,
        isWateringReminderOn:
            waterSchedule?.enabled ??
            (schedules == null ? base?.isWateringReminderOn ?? false : false),
        isFertilizingReminderOn:
            fertilizeSchedule?.enabled ??
            (schedules == null
                ? base?.isFertilizingReminderOn ?? false
                : false),
        logs: careLogs,
      );
      _scheduledTasks = schedules?.tasks ?? [];
      _hasWaterSchedule = waterSchedule != null;
      _hasFertilizeSchedule = fertilizeSchedule != null;
      _syncSummary = null;
      _syncWarnings = [];
      _careDataNotice = careDataNotice;
      _isLoading = false;
    });
  }

  // --- Hành động: Dữ liệu chăm sóc AI ---

  Future<void> _enrichCareData() async {
    if (_isEnrichingCare) return;
    setState(() => _isEnrichingCare = true);

    try {
      final careData = await PlantCareService.enrichCareData(widget.plantId);
      if (!mounted) return;

      if (careData.draftStatus == 'generating') {
        _showMessage(
          'AI đang tạo hướng dẫn chăm sóc, vui lòng tải lại sau vài giây.',
        );
      } else {
        setState(() {
          _careDataNotice = null;
          if (_plant != null) {
            _plant = _plant!.copyWith(
              scientificName: careData.scientificName ?? _plant!.scientificName,
              commonName: careData.commonName ?? _plant!.commonName,
              sunlightInfo: careData.lightGuide ?? _plant!.sunlightInfo,
              waterInfo: careData.waterGuide ?? _plant!.waterInfo,
              temperatureInfo:
                  careData.temperatureGuide ?? _plant!.temperatureInfo,
              soilInfo: careData.soilGuide ?? _plant!.soilInfo,
              fertilizerInfo:
                  careData.fertilizerGuide ?? _plant!.fertilizerInfo,
              careStatus: careData.careStatus ?? _plant!.careStatus,
            );
          }
        });
        _showMessage(
          careData.isMockDraft
              ? 'Đã tải bản hướng dẫn mẫu (Demo).'
              : 'Đã cập nhật hướng dẫn chăm sóc từ AI!',
        );
      }
    } catch (e) {
      _showMessage(_formatError(e));
    } finally {
      if (mounted) setState(() => _isEnrichingCare = false);
    }
  }

  // --- Hành động: Lịch nhắc & Thời tiết ---

  Future<void> _saveSchedule({
    required bool isWater,
    required int intervalDays,
    required String localTime,
    required bool enabled,
  }) async {
    if (_isSavingSchedule || _isSyncingPlan || _plant == null) return;
    setState(() => _isSavingSchedule = true);

    try {
      final updated = isWater
          ? await PlantCareService.updateWaterSchedule(
              widget.plantId,
              intervalDays: intervalDays,
              localTime: localTime,
              enabled: enabled,
            )
          : await PlantCareService.updateFertilizeSchedule(
              widget.plantId,
              intervalDays: intervalDays,
              localTime: localTime,
              enabled: enabled,
            );

      CarePlanSyncResult? syncResult;
      try {
        syncResult = await PlantCareService.syncCarePlan(widget.plantId);
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _plant = isWater
            ? _plant!.copyWith(
                wateringFrequencyDays: updated.intervalDays,
                reminderTime: updated.localTime,
                waterReminderTime: updated.localTime,
                isWateringReminderOn: updated.enabled,
              )
            : _plant!.copyWith(
                fertilizingFrequencyDays: updated.intervalDays,
                fertilizeReminderTime: updated.localTime,
                isFertilizingReminderOn: updated.enabled,
              );
        if (isWater) {
          _hasWaterSchedule = true;
        } else {
          _hasFertilizeSchedule = true;
        }
        _scheduledTasks = syncResult?.tasks ?? [];
        _syncWarnings = syncResult?.warnings ?? [];
        _syncSummary = syncResult == null
            ? 'Đã lưu lịch, nhưng chưa tính được ngày nhắc tiếp theo. Hãy bấm đồng bộ để thử lại.'
            : _describeSync(syncResult);
      });
      _showMessage(
        isWater ? 'Đã lưu lịch tưới nước!' : 'Đã lưu lịch bón phân!',
      );
    } catch (e) {
      _showMessage(_formatError(e));
    } finally {
      if (mounted) setState(() => _isSavingSchedule = false);
    }
  }

  Future<void> _handleEditSchedule({required bool isWater}) async {
    if (_plant == null) return;
    final result = await showEditScheduleDialog(
      context,
      isWater: isWater,
      currentDays: isWater
          ? _plant!.wateringFrequencyDays
          : _plant!.fertilizingFrequencyDays,
      currentTime: isWater
          ? _plant!.effectiveWaterTime
          : _plant!.effectiveFertilizeTime,
      currentEnabled: isWater
          ? _plant!.isWateringReminderOn
          : _plant!.isFertilizingReminderOn,
    );
    if (result == null || !mounted) return;

    await _saveSchedule(
      isWater: isWater,
      intervalDays: result.intervalDays,
      localTime: result.localTime,
      enabled: result.enabled,
    );
  }

  Future<void> _syncCarePlanManually() async {
    if (_isSyncingPlan || _isSavingSchedule) return;
    setState(() => _isSyncingPlan = true);

    try {
      final result = await PlantCareService.syncCarePlan(widget.plantId);
      final latest = await PlantCareService.getSchedules(widget.plantId);
      if (!mounted) return;

      final water = latest.findByKind('water');
      final fertilize = latest.findByKind('fertilize');

      setState(() {
        _syncWarnings = result.warnings;
        _scheduledTasks = result.tasks;
        _hasWaterSchedule = water != null;
        _hasFertilizeSchedule = fertilize != null;
        _syncSummary = _describeSync(result);
        if (_plant != null) {
          _plant = _plant!.copyWith(
            wateringFrequencyDays:
                water?.intervalDays ?? _plant!.wateringFrequencyDays,
            waterReminderTime: water?.localTime ?? _plant!.waterReminderTime,
            isWateringReminderOn: water?.enabled ?? false,
            fertilizingFrequencyDays:
                fertilize?.intervalDays ?? _plant!.fertilizingFrequencyDays,
            fertilizeReminderTime:
                fertilize?.localTime ?? _plant!.fertilizeReminderTime,
            isFertilizingReminderOn: fertilize?.enabled ?? false,
          );
        }
      });
      _showMessage(_syncSummary!);
    } catch (e) {
      _showMessage(_formatError(e));
    } finally {
      if (mounted) setState(() => _isSyncingPlan = false);
    }
  }

  String _describeSync(CarePlanSyncResult result) {
    if (result.warnings.isNotEmpty) {
      return 'Đã kiểm tra lịch; còn lưu ý cần xem bên dưới.';
    }
    if (result.tasks.isEmpty) {
      return 'Không có lịch nhắc đang hoạt động. Hãy tạo hoặc bật lịch.';
    }
    if (result.tasks.any((t) => t.adjustmentReason != null)) {
      return 'Lịch nhắc đang được điều chỉnh theo thời tiết. Xem ngày nhắc và lý do bên dưới.';
    }
    if (result.weatherSource != null) {
      return 'Đã kiểm tra thời tiết; lịch nhắc hiện giữ theo chu kỳ đã đặt.';
    }
    return 'Đã tính lịch theo chu kỳ đã đặt; không áp dụng điều chỉnh thời tiết.';
  }

  // --- Hành động: Nhật ký chăm sóc ---

  Future<void> _reloadCareLogs() async {
    try {
      final logs = await CareLogService.listByPlant(widget.plantId, limit: 100);
      if (!mounted || _plant == null) return;
      setState(() => _plant = _plant!.copyWith(logs: logs));
    } catch (e) {
      _showMessage(_formatError(e));
    }
  }

  Future<void> _handleSaveCareLog({CareLog? existingLog}) async {
    if (_isMutatingLog) return;
    final input = await showCareLogDialog(context, existingLog: existingLog);
    if (input == null || !mounted) return;

    setState(() => _isMutatingLog = true);
    try {
      if (existingLog != null) {
        await CareLogService.updateCareLog(
          existingLog.id,
          kind: input.kind,
          note: input.note,
        );
        _showMessage('Đã cập nhật nhật ký chăm sóc!');
      } else {
        final kind = input.kind ?? 'water';
        await CareLogService.createCareLog(
          plantId: widget.plantId,
          kind: kind,
          note: input.note,
        );
        if (kind == 'water' || kind == 'fertilize') {
          try {
            await PlantCareService.syncCarePlan(widget.plantId);
          } catch (_) {}
        }
        _showMessage('Đã thêm nhật ký chăm sóc!');
      }
      await _reloadCareLogs();
    } catch (e) {
      _showMessage(_formatError(e));
    } finally {
      if (mounted) setState(() => _isMutatingLog = false);
    }
  }

  Future<void> _handleDeleteCareLog(CareLog log) async {
    if (_isMutatingLog) return;
    final confirmed = await showDeleteCareLogDialog(
      context,
      isLinkedToTask: log.taskId != null,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isMutatingLog = true);
    try {
      await CareLogService.deleteCareLog(log.id);
      if (log.taskId != null) {
        try {
          await PlantCareService.syncCarePlan(widget.plantId);
        } catch (_) {}
      }
      await _reloadCareLogs();
      _showMessage('Đã xóa mục nhật ký!');
    } catch (e) {
      _showMessage(_formatError(e));
    } finally {
      if (mounted) setState(() => _isMutatingLog = false);
    }
  }

  // --- Hành động: Đổi tên & Xóa cây ---

  Future<void> _handleEditNickname() async {
    if (_plant == null || _isMutatingPlant) return;
    final newName = await showEditNicknameDialog(
      context,
      currentNickname: _plant!.nickname,
    );
    if (newName == null || !mounted) return;

    setState(() => _isMutatingPlant = true);
    try {
      await PlantCareService.updatePlantNickname(widget.plantId, newName);
      if (!mounted) return;
      setState(() => _plant = _plant!.copyWith(nickname: newName));
      _showMessage('Đã cập nhật biệt danh cây!');
    } catch (e) {
      _showMessage(_formatError(e));
    } finally {
      if (mounted) setState(() => _isMutatingPlant = false);
    }
  }

  Future<void> _handleDeletePlant() async {
    if (_plant == null || _isMutatingPlant) return;
    final confirmed = await showDeletePlantDialog(
      context,
      plantNickname: _plant!.nickname,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isMutatingPlant = true);
    try {
      await PlantCareService.deletePlant(widget.plantId);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã xóa cây khỏi vườn!')));
    } catch (e) {
      if (mounted) setState(() => _isMutatingPlant = false);
      _showMessage(_formatError(e));
    }
  }

  // --- Giao diện ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.appBarColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppTheme.titleTextColor,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Chi tiết cây'),
        actions: [
          IconButton(
            tooltip: 'Quét bệnh cho cây này',
            icon: const Icon(Icons.document_scanner_outlined),
            onPressed: _isLoading
                ? null
                : () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ScanScreen(
                          plantId: widget.plantId,
                          initialDiseaseMode: true,
                        ),
                      ),
                    );
                    if (mounted) await _loadPlantData();
                  },
          ),
        ],
      ),
      body: _buildBodyContent(),
    );
  }

  Widget _buildBodyContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: AppTheme.sickBadgeText,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.subTextColor,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadPlantData,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (_plant == null) {
      return const Center(child: Text('Không tìm thấy thông tin cây.'));
    }

    final plant = _plant!;
    return Column(
      children: [
        PlantDetailHeader(plant: plant, onEditNickname: _handleEditNickname),
        Container(
          color: AppTheme.scaffoldBackgroundColor,
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: AppTheme.subTextColor,
            indicatorColor: AppTheme.primaryColor,
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            tabs: const [
              Tab(text: 'HƯỚNG DẪN'),
              Tab(text: 'LỊCH NHẮC'),
              Tab(text: 'NHẬT KÝ'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              PlantInstructionTab(
                plant: plant,
                careDataNotice: _careDataNotice,
                isEnrichingCare: _isEnrichingCare,
                isMutatingPlant: _isMutatingPlant,
                onRefresh: _loadPlantData,
                onEnrichCare: _enrichCareData,
                onDeletePlant: _handleDeletePlant,
              ),
              PlantReminderTab(
                plant: plant,
                isSavingSchedule: _isSavingSchedule,
                isSyncingPlan: _isSyncingPlan,
                isMutatingPlant: _isMutatingPlant,
                syncWarnings: _syncWarnings,
                tasks: _scheduledTasks,
                syncSummary: _syncSummary,
                hasWaterSchedule: _hasWaterSchedule,
                hasFertilizeSchedule: _hasFertilizeSchedule,
                onRefresh: _loadPlantData,
                onToggleWater: (val) => _saveSchedule(
                  isWater: true,
                  intervalDays: plant.wateringFrequencyDays,
                  localTime: plant.effectiveWaterTime,
                  enabled: val,
                ),
                onToggleFertilize: (val) => _saveSchedule(
                  isWater: false,
                  intervalDays: plant.fertilizingFrequencyDays,
                  localTime: plant.effectiveFertilizeTime,
                  enabled: val,
                ),
                onEditWater: () => _handleEditSchedule(isWater: true),
                onEditFertilize: () => _handleEditSchedule(isWater: false),
                onSyncPlan: _syncCarePlanManually,
                onDeletePlant: _handleDeletePlant,
              ),
              PlantHistoryTab(
                logs: plant.logs,
                isMutatingLog: _isMutatingLog,
                isMutatingPlant: _isMutatingPlant,
                onRefresh: _reloadCareLogs,
                onAddLog: () => _handleSaveCareLog(),
                onEditLog: (log) => _handleSaveCareLog(existingLog: log),
                onDeleteLog: _handleDeleteCareLog,
                onDeletePlant: _handleDeletePlant,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
