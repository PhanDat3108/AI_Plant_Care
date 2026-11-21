import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../models/task_model.dart';

class TaskProgressBar extends StatelessWidget {
  final List<TaskModel> tasks;

  const TaskProgressBar({super.key, required this.tasks});

  @override
  Widget build(BuildContext context) {
    final completedCount = tasks.where((t) => t.isCompleted).length;
    final totalCount = tasks.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: totalCount > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: completedCount == totalCount
                    ? AppTheme.primaryColor
                    : AppTheme.healthyBadgeBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$completedCount/$totalCount xong',
                style: TextStyle(
                  color: completedCount == totalCount
                      ? Colors.white
                      : AppTheme.healthyBadgeText,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
