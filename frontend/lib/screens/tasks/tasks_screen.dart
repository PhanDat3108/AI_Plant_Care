import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../models/task_model.dart';
import '../../services/mock_data_service.dart';
import 'tasks_header.dart';
import 'task_progress_bar.dart';
import 'task_card.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final MockDataService _dataService = MockDataService();

  List<TaskModel> _tasks = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await _dataService.getTodayTasks();
      if (!mounted) return;
      setState(() {
        _tasks = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _toggleTaskCompletion(String taskId, bool? newValue) {
    if (newValue == null) return;
    setState(() {
      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        _tasks[index] = _tasks[index].copyWith(isCompleted: newValue);
      }
    });
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
                onPressed: _loadTasks,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    final isAllCompleted =
        _tasks.isNotEmpty && _tasks.every((t) => t.isCompleted);
    if (_tasks.isEmpty || isAllCompleted) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt_rounded, size: 64, color: AppTheme.appBarColor),
            SizedBox(height: 16),
            Text(
              'Tuyệt vời!\nBạn đã hoàn thành mọi việc hôm nay.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.subTextColor, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: _tasks.length,
      itemBuilder: (context, index) => TaskCard(
        task: _tasks[index],
        onToggle: (val) => _toggleTaskCompletion(_tasks[index].id, val),
      ),
    );
  }
}
