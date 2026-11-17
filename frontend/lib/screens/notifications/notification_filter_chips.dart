import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class NotificationFilterChips extends StatelessWidget {
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;

  const NotificationFilterChips({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final filters = ['Tất cả', 'Chưa đọc', 'Kết quả AI'];

    return Container(
      color: AppTheme.appBarColor,
      width: double.infinity,
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 24),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((filter) {
            final isActive = filter == selectedFilter;
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: InkWell(
                onTap: () => onFilterChanged(filter),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isActive ? AppTheme.primaryColor : AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: isActive
                        ? []
                        : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: Text(
                    filter,
                    style: TextStyle(
                      color: isActive ? Colors.white : AppTheme.subTextColor,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
