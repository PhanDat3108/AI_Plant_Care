import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/task_model.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  // Dữ liệu tĩnh tạm thời (Bước 1: UI)
  final List<TaskModel> _mockTasks = [
    TaskModel(id: 't1', plantId: 'p1', plantNickname: 'Bé Kim Tiền', plantAvatar: 'assets/images/kim_tien.png', type: TaskType.water, isCompleted: false),
    TaskModel(id: 't2', plantId: 'p2', plantNickname: 'Trầu Bà Xanh', plantAvatar: 'assets/images/trau_ba.png', type: TaskType.fertilize, isCompleted: false),
    TaskModel(id: 't3', plantId: 'p3', plantNickname: 'Lưỡi Hổ', plantAvatar: 'assets/images/luoi_ho.png', type: TaskType.spray, isCompleted: true),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          _buildFilterAndProgress(),
          Expanded(
            child: ListView.builder(
              itemCount: _mockTasks.length,
              padding: const EdgeInsets.only(top: 8, bottom: 80), 
              itemBuilder: (context, index) {
                return _buildTaskCard(_mockTasks[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- 1. Header màu xanh nhạt ---
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
          // Thay ảnh minh họa bình tưới bằng Icon kết hợp CircleAvatar tạm thời
          const CircleAvatar(
            radius: 32,
            backgroundColor: AppTheme.healthyBadgeBg,
            child: Icon(Icons.water_drop_rounded, size: 32, color: AppTheme.primaryColor),
          ),
        ],
      ),
    );
  }

  // --- 2. Thanh Tìm kiếm & Tiến độ ---
  Widget _buildFilterAndProgress() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Icon(Icons.search, color: AppTheme.subTextColor, size: 28),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.healthyBadgeBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '1/3 xong',
              style: TextStyle(
                color: AppTheme.healthyBadgeText,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. Card Công việc ---
  Widget _buildTaskCard(TaskModel task) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Avatar cây
            CircleAvatar(
              radius: 28,
              backgroundColor: AppTheme.scaffoldBackgroundColor,
              child: Icon(Icons.eco_rounded, color: AppTheme.primaryColor, size: 28), // Dummy thay cho ảnh thật
            ),
            const SizedBox(width: 16),
            
            // Thông tin cây & Tag công việc
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.plantNickname,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  _buildTaskTag(task.type),
                ],
              ),
            ),
            
            SizedBox(
              width: 48,
              // height: 58,
              child: Transform.scale(
                scale: 1.5,
                child: Checkbox(
                  value: task.isCompleted,
                  onChanged: (value) {},
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

  // --- Helper: Render Tag màu sắc theo loại công việc ---
  Widget _buildTaskTag(TaskType type) {
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
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}