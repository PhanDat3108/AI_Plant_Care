import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class TasksHeader extends StatelessWidget {
  const TasksHeader({super.key});

  @override
  Widget build(BuildContext context) {
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
}
