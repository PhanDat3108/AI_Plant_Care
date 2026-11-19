import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/task_model.dart';

class TaskCard extends StatelessWidget {
  final TaskModel task;
  final ValueChanged<bool?> onToggle;

  const TaskCard({super.key, required this.task, required this.onToggle});

  @override
  Widget build(BuildContext context) {
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
                  _TaskTag(type: task.type, isCompleted: task.isCompleted),
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
                  onChanged: onToggle,
                  activeColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  side: const BorderSide(color: AppTheme.subTextColor, width: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget nội bộ của TaskCard
class _TaskTag extends StatelessWidget {
  final TaskType type;
  final bool isCompleted;

  const _TaskTag({required this.type, required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    if (isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('Đã xong',
            style: TextStyle(color: AppTheme.subTextColor, fontSize: 12, fontWeight: FontWeight.bold)),
      );
    }

    final Map<TaskType, ({Color bg, Color text, IconData icon, String label})> styles = {
      TaskType.water:    (bg: const Color(0xFFE3F2FD), text: const Color(0xFF1565C0), icon: Icons.water_drop,  label: 'Tưới nước'),
      TaskType.fertilize:(bg: const Color(0xFFFFF3E0), text: const Color(0xFFE65100), icon: Icons.science,     label: 'Bón phân'),
      TaskType.spray:    (bg: const Color(0xFFF3E5F5), text: const Color(0xFF6A1B9A), icon: Icons.sanitizer,   label: 'Phun thuốc'),
    };

    final s = styles[type]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: 14, color: s.text),
          const SizedBox(width: 4),
          Text(s.label, style: TextStyle(color: s.text, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
