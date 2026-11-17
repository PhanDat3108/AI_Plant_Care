import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/task_model.dart';
import '../services/mock_data_service.dart';

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
    // Gọi mạng giả lập ngay khi khởi tạo màn hình
    _loadTasks();
  }

  // Tách riêng logic lấy dữ liệu
  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _dataService.getTodayTasks();
      setState(() {
        _tasks = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  // Xử lý logic tick hoàn thành công việc
  void _toggleTaskCompletion(String taskId, bool? newValue) {
    if (newValue == null) return;
    
    setState(() {
      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        // Dùng copyWith để tuân thủ tính bất biến của Model
        _tasks[index] = _tasks[index].copyWith(isCompleted: newValue);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          _buildFilterAndProgress(),
          Expanded(
            child: _buildBodyContent(), // Trả về 1 trong 4 trạng thái
          ),
        ],
      ),
    );
  }

  // Bộ định tuyến Trạng thái (Loading / Error / Empty / Data) 
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
              const Icon(Icons.wifi_off_rounded, size: 64, color: AppTheme.sickBadgeText),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.subTextColor, fontSize: 16),
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
//khi ko có nhiệm vụ nào
    if (_tasks.isEmpty) {
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
      itemBuilder: (context, index) {
        return _buildTaskCard(_tasks[index]);
      },
    );
  }

// Header
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 24),
      decoration: const BoxDecoration(
        color: AppTheme.appBarColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'Việc cần làm\nhôm nay',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 28,
                height: 1.2,
              ),
            ),
          ),
          const CircleAvatar(
            radius: 32,
            backgroundColor: AppTheme.healthyBadgeBg,
            child: Icon(Icons.water_drop_rounded, size: 32, color: AppTheme.primaryColor),
          ),
        ],
      ),
    );
  }

// tìm kiếm và tiến trình
  Widget _buildFilterAndProgress() {
    // Tính toán linh hoạt số task đã xong
    final completedCount = _tasks.where((t) => t.isCompleted).length;
    final totalCount = _tasks.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Icon(Icons.search, color: AppTheme.subTextColor, size: 28),
          if (totalCount > 0) // Chỉ hiện badge nếu có task
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: completedCount == totalCount ? AppTheme.primaryColor : AppTheme.healthyBadgeBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$completedCount/$totalCount xong',
                style: TextStyle(
                  color: completedCount == totalCount ? Colors.white : AppTheme.healthyBadgeText,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

// thẻ nhiệm vụ
  Widget _buildTaskCard(TaskModel task) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppTheme.scaffoldBackgroundColor,
              child: Icon(Icons.eco_rounded, color: AppTheme.primaryColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.plantNickname,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                      color: task.isCompleted ? AppTheme.subTextColor : AppTheme.titleTextColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  _buildTaskTag(task.type, task.isCompleted),
                ],
              ),
            ),
            SizedBox(
              width: 48,
              height: 48,
              child: Transform.scale(
                scale: 1.3,
                child: Checkbox(
                  value: task.isCompleted,
                  onChanged: (value) => _toggleTaskCompletion(task.id, value),
                  activeColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  side: const BorderSide(color: AppTheme.subTextColor, width: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

// tag công việc
  Widget _buildTaskTag(TaskType type, bool isCompleted) {
    if (isCompleted) {
      // Làm mờ tag đi khi task đã hoàn thành
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('Đã xong', style: TextStyle(color: AppTheme.subTextColor, fontSize: 12, fontWeight: FontWeight.bold)),
      );
    }

    Color bgColor;
    Color textColor;
    IconData icon;
    String label;

    switch (type) {
      case TaskType.water:
        bgColor = const Color(0xFFE3F2FD);
        textColor = const Color(0xFF1565C0);
        icon = Icons.water_drop;
        label = 'Tưới nước';
        break;
      case TaskType.fertilize:
        bgColor = const Color(0xFFFFF3E0);
        textColor = const Color(0xFFE65100);
        icon = Icons.science;
        label = 'Bón phân';
        break;
      case TaskType.spray:
        bgColor = const Color(0xFFF3E5F5);
        textColor = const Color(0xFF6A1B9A);
        icon = Icons.sanitizer;
        label = 'Phun thuốc';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}