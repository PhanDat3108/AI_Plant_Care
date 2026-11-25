import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/api_exception.dart';
import '../../models/task_model.dart';
import '../../services/care_log_service.dart';
import '../../services/care_task_service.dart';
import '../../services/plant_care_service.dart';
import '../../theme/app_theme.dart';
import 'task_card.dart';
import 'task_progress_bar.dart';
import 'tasks_header.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => TasksScreenState();
}

class TasksScreenState extends State<TasksScreen> {
  List<TaskModel> _tasks = [];
  final Set<String> _updatingTaskIds = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    loadTasks();
  }

  String _formatError(Object e) {
    if (e is ApiException) return e.message;
    return e.toString().replaceAll('Exception: ', '');
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.sickBadgeText : AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _taskTypeToKind(TaskType type) {
    switch (type) {
      case TaskType.water:
        return 'water';
      case TaskType.fertilize:
        return 'fertilize';
      case TaskType.spray:
        return 'treat';
    }
  }

  Future<void> loadTasks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final page = await CareTaskService.getTodayTasks();
      if (!mounted) return;
      setState(() {
        _tasks = page.items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _formatError(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleTaskCompletion(TaskModel task, bool? newValue) async {
    if (newValue == null || _updatingTaskIds.contains(task.id)) return;
    if (task.plantId.isEmpty) {
      _showMessage('Không xác định được cây của nhiệm vụ này.', isError: true);
      return;
    }

    setState(() => _updatingTaskIds.add(task.id));

    try {
      if (newValue) {
        final requestId = const Uuid().v4();
        await CareLogService.createCareLog(
          plantId: task.plantId,
          kind: _taskTypeToKind(task.type),
          taskId: task.id,
          requestId: requestId,
        );

        try {
          await PlantCareService.syncCarePlan(task.plantId);
        } catch (_) {
          // Không chặn trạng thái hoàn thành nếu sync thời tiết lỗi tạm thời
        }

        if (!mounted) return;
        setState(() {
          final index = _tasks.indexWhere((t) => t.id == task.id);
          if (index != -1) {
            _tasks[index] = _tasks[index].copyWith(
              isCompleted: true,
              state: 'done',
            );
          }
        });
        _showMessage('Đã ghi nhận hoàn thành "${task.plantNickname}".');
      } else {
        final logs = await CareLogService.listByPlant(task.plantId, limit: 100);
        final matched = logs.where((l) => l.taskId == task.id).toList();
        if (matched.isEmpty) {
          _showMessage(
            'Không tìm thấy nhật ký gắn với nhiệm vụ này để hoàn tác.',
            isError: true,
          );
          return;
        }

        await CareLogService.deleteCareLog(matched.first.id);

        try {
          await PlantCareService.syncCarePlan(task.plantId);
        } catch (_) {}

        if (!mounted) return;
        setState(() {
          final index = _tasks.indexWhere((t) => t.id == task.id);
          if (index != -1) {
            _tasks[index] = _tasks[index].copyWith(
              isCompleted: false,
              state: 'pending',
            );
          }
        });
        _showMessage('Đã hoàn tác nhiệm vụ về trạng thái chờ.');
      }
    } catch (e) {
      _showMessage(_formatError(e), isError: true);
    } finally {
      if (mounted) {
        setState(() => _updatingTaskIds.remove(task.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const TasksHeader(),
          TaskProgressBar(tasks: _tasks),
          Expanded(child: _buildBodyContent()),
        ],
      ),
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
                Icons.wifi_off_rounded,
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
                onPressed: loadTasks,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (_tasks.isEmpty) {
      return RefreshIndicator(
        onRefresh: loadTasks,
        color: AppTheme.primaryColor,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.22),
            const Icon(
              Icons.task_alt_rounded,
              size: 64,
              color: AppTheme.appBarColor,
            ),
            const SizedBox(height: 16),
            const Text(
              'Hôm nay chưa có việc chăm sóc nào.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.subTextColor, fontSize: 16),
            ),
          ],
        ),
      );
    }

    final isAllCompleted = _tasks.every((t) => t.isCompleted);

    return RefreshIndicator(
      onRefresh: loadTasks,
      color: AppTheme.primaryColor,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 80),
        itemCount: _tasks.length + (isAllCompleted ? 1 : 0),
        itemBuilder: (context, index) {
          if (isAllCompleted && index == 0) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.healthyBadgeBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.task_alt_rounded, color: AppTheme.primaryColor),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tuyệt vời! Bạn đã hoàn thành mọi việc chăm sóc hôm nay.',
                      style: TextStyle(
                        color: AppTheme.healthyBadgeText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final task = _tasks[isAllCompleted ? index - 1 : index];
          final isUpdating = _updatingTaskIds.contains(task.id);

          return TaskCard(
            task: task,
            onToggle: isUpdating
                ? null
                : (val) => _toggleTaskCompletion(task, val),
          );
        },
      ),
    );
  }

  void reload() {}
}