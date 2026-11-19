import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../models/task_model.dart';
import '../../services/care_task_service.dart';
import '../../theme/app_theme.dart';
import 'task_card.dart';
import 'task_progress_bar.dart';
import 'tasks_header.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List<TaskModel> _tasks = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  String _formatError(Object e) {
    if (e is ApiException) return e.message;
    return e.toString().replaceAll('Exception: ', '');
  }

  Future<void> _loadTasks() async {
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
      return RefreshIndicator(
        onRefresh: _loadTasks,
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
            Text(
              _tasks.isEmpty
                  ? 'Hôm nay chưa có việc chăm sóc nào.'
                  : 'Tuyệt vời!\nBạn đã hoàn thành mọi việc hôm nay.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.subTextColor,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTasks,
      color: AppTheme.primaryColor,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 80),
        itemCount: _tasks.length,
        itemBuilder: (context, index) => TaskCard(
          task: _tasks[index],
          // Chờ API Module 6 (đánh dấu hoàn thành + ghi care_log) nên giữ chỉ đọc
          onToggle: null,
        ),
      ),
    );
  }
}