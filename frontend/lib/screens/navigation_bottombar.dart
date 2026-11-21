import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

import 'my_garden_screen.dart';
import 'tasks/tasks_screen.dart';
import 'notifications/notification_screen.dart';
import 'profile_screen.dart';
import 'ai_scan/scan_screen.dart';

class NavigationBottomBar extends StatefulWidget {
  const NavigationBottomBar({super.key});

  @override
  State<NavigationBottomBar> createState() => _NavigationBottomBarState();
}

class _NavigationBottomBarState extends State<NavigationBottomBar> {
  final GlobalKey<MyGardenScreenState> _gardenKey = GlobalKey<MyGardenScreenState>();
  final GlobalKey<TasksScreenState> _tasksKey = GlobalKey<TasksScreenState>();
  final GlobalKey<NotificationScreenState> _notificationKey = GlobalKey<NotificationScreenState>();
  int _selectedIndex = 0;
  bool _hasUnreadNotification = false;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      MyGardenScreen(key: _gardenKey),
      TasksScreen(key: _tasksKey),
      NotificationScreen(
        key: _notificationKey,
        onUnreadChanged: (hasUnread) {
          setState(() {
            _hasUnreadNotification = hasUnread;
          });
        },
      ),
      const ProfileScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 0) _gardenKey.currentState?.reload();
    if (index == 1) _tasksKey.currentState?.loadTasks();
    if (index == 2) _notificationKey.currentState?.loadNotifications();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),

      floatingActionButton: Transform.translate(
        //điều chỉnh nút chụp theo phương Oy
        offset: const Offset(0, 15),
        child: FloatingActionButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ScanScreen()),
            );
            _gardenKey.currentState?.reload();
          },
          backgroundColor: AppTheme.primaryColor,
          shape: const CircleBorder(),
          elevation: 4,
          child: const Icon(
            Icons.camera_alt_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
      
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
        color: AppTheme.cardColor,
        shape: const CircularNotchedRectangle(),
        //điều chỉnh vết lõm
        notchMargin: 12.0,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(
                icon: Icons.local_florist_rounded,
                label: 'Vườn cây',
                index: 0,
              ),
              _navItem(
                icon: Icons.check_circle_outline_rounded,
                label: 'Nhiệm vụ',
                index: 1,
              ),
              const SizedBox(width: 48),
              _navItem(
                icon: Icons.notifications_none_rounded,
                label: 'Thông báo',
                index: 2,
                hasBadge: _hasUnreadNotification,
              ),
              _navItem(
                icon: Icons.person_outline_rounded,
                label: 'Hồ sơ',
                index: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // nút bấm trên thanh điều hướng
  Widget _navItem({
    required IconData icon,
    required String label,
    required int index,
    bool hasBadge = false,
  }) {
    final isSelected = _selectedIndex == index;
    final color = isSelected ? AppTheme.primaryColor : AppTheme.subTextColor;

    Widget iconWidget = Icon(icon, color: color, size: 26);

    // Thêm chấm đỏ Badge cho tab Thông báo khi có thông báo chưa đọc
    if (hasBadge) {
      iconWidget = Badge(
        backgroundColor: AppTheme.sickBadgeText,
        smallSize: 10,
        child: iconWidget,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onItemTapped(index),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 65,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              iconWidget,
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
