import 'package:flutter/material.dart';
import '../models/mock_data.dart';
import '../models/user_model.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../widgets/header_sheet_scaffold.dart';
import '../widgets/stat_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // TODO: thay bằng dữ liệu từ GET /me khi nối backend.
  UserModel get _user => mockUser;

  @override
  Widget build(BuildContext context) {
    final user = _user;

    return HeaderSheetScaffold(
      header: _ProfileHeader(user: user),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: StatCard(
                  icon: Icons.local_florist_rounded,
                  value: user.totalPlants,
                  label: 'Cây đang chăm',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  icon: Icons.camera_alt_rounded,
                  value: user.totalAiScans,
                  label: 'Lần quét AI',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _SettingsCard(),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Hồ sơ cá nhân',
              style: TextStyle(
                color: AppTheme.titleTextColor,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _UserAvatar(avatarUrl: user.avatarUrl),
          const SizedBox(height: 12),
          Text(
            user.fullName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.titleTextColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            user.email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.titleTextColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ảnh đại diện tròn viền trắng.
/// Có avatarUrl (ví dụ ảnh Google) -> hiện ảnh; không có / lỗi -> ảnh mặc định.
class _UserAvatar extends StatelessWidget {
  const _UserAvatar({this.avatarUrl});

  final String? avatarUrl;

  static const double _size = 104;

  @override
  Widget build(BuildContext context) {
    const defaultAvatar = Icon(
      Icons.person_rounded,
      size: 60,
      color: AppTheme.primaryColor,
    );

    final url = avatarUrl;
    final Widget content = (url == null || url.isEmpty)
        ? defaultAvatar
        : Image.network(
            url,
            width: _size,
            height: _size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => defaultAvatar,
          );

    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFDDE9DE),
        border: Border.all(color: Colors.white, width: 4),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: content,
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard();

  static const TextStyle _tileTitleStyle = TextStyle(
    color: AppTheme.titleTextColor,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  @override
  Widget build(BuildContext context) {
    const divider = Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: Color(0xFFE5E5E5),
    );

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Chế độ Tối
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.themeMode,
            builder: (context, mode, _) {
              return ListTile(
                leading: const Icon(
                  Icons.nightlight_round,
                  color: AppTheme.subTextColor,
                ),
                title: const Text('Chế độ Tối', style: _tileTitleStyle),
                trailing: Switch(
                  value: mode == ThemeMode.dark,
                  onChanged: ThemeController.setDark,
                ),
                onTap: () => ThemeController.setDark(mode != ThemeMode.dark),
              );
            },
          ),
          divider,

          // Thông tin ứng dụng
          ListTile(
            leading: const Icon(
              Icons.info_outline_rounded,
              color: AppTheme.subTextColor,
            ),
            title: const Text('Thông tin ứng dụng', style: _tileTitleStyle),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.subTextColor,
            ),
            onTap: () => _showAbout(context),
          ),
          divider,

          // Đăng xuất (nền đỏ nhạt, chữ đỏ để gây chú ý)
          ListTile(
            tileColor: AppTheme.sickBadgeBg,
            leading: const Icon(
              Icons.logout_rounded,
              color: AppTheme.sickBadgeText,
            ),
            title: const Text(
              'Đăng xuất',
              style: TextStyle(
                color: AppTheme.sickBadgeText,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () => _confirmLogout(context),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'AI Plant Care',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(
        Icons.local_florist_rounded,
        color: AppTheme.primaryColor,
        size: 40,
      ),
      children: const [
        Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text('Ứng dụng chăm sóc cây trồng với trợ lý AI.'),
        ),
      ],
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất khỏi AI Plant Care?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Đăng xuất',
              style: TextStyle(color: AppTheme.sickBadgeText),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      // TODO: gọi POST /auth/logout, xóa token trên máy rồi chuyển về màn Đăng nhập
      // (làm khi hoàn thành phần Đăng nhập/Đăng ký).
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã đăng xuất (chưa nối backend).')),
      );
    }
  }
}
