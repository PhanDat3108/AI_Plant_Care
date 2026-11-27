import 'package:flutter/material.dart';

import '../core/api_exception.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/token_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/header_sheet_scaffold.dart';
import '../widgets/stat_card.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _user;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(showSpinner: false); // _loading đã là true từ đầu
  }

  /// GET /me. [showSpinner] = false khi kéo để làm mới (giữ nguyên nội dung cũ).
  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final user = await ProfileService.getMe();
      if (!mounted) return;
      setState(() {
        _user = user;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        // Đã thử làm mới token mà vẫn 401: yêu cầu đăng nhập lại.
        await TokenStorage.clear();
        if (!mounted) return;
        _goToLogin();
        return;
      }
      if (_user != null) {
        // Đang có dữ liệu cũ: giữ nguyên, chỉ báo lỗi nhỏ.
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      } else {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    }
  }

  void _goToLogin() {
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _editProfile() async {
    final user = _user;
    if (user == null) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EditProfileDialog(user: user),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Đã cập nhật hồ sơ.')));
      await _load(showSpinner: false); // PATCH xong thì gọi lại GET /me
    }
  }

  @override
  Widget build(BuildContext context) {
    return HeaderSheetScaffold(
      header: _ProfileHeader(user: _user),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final user = _user;

    if (user == null) {
      if (_loading) {
        return const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        );
      }
      return _ErrorState(
        message: _error ?? 'Không tải được hồ sơ.',
        onRetry: _load,
      );
    }

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: () => _load(showSpinner: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
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
          _SettingsCard(onEditProfile: _editProfile),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  /// null khi đang tải lần đầu.
  final UserModel? user;

  @override
  Widget build(BuildContext context) {
    final name = (user == null)
        ? ''
        : (user!.fullName.isNotEmpty ? user!.fullName : user!.email);

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
          _UserAvatar(avatarUrl: user?.avatarUrl),
          const SizedBox(height: 12),
          Text(
            name.isEmpty ? ' ' : name,
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
            user?.email ?? ' ',
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
            errorBuilder: (_, _, _) => defaultAvatar,
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 56,
              color: AppTheme.subTextColor,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.subTextColor,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(160, 48),
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.onEditProfile});

  final VoidCallback onEditProfile;

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
          // Chỉnh sửa hồ sơ (PATCH /me)
          ListTile(
            leading: const Icon(
              Icons.edit_outlined,
              color: AppTheme.subTextColor,
            ),
            title: const Text('Chỉnh sửa hồ sơ', style: _tileTitleStyle),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.subTextColor,
            ),
            onTap: onEditProfile,
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
      // POST /auth/logout + xóa token trên máy (kể cả khi mất mạng).
      final pushRemoved = await AuthService.logout();
      if (!context.mounted) return;
      if (!pushRemoved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Đã đăng xuất. Thiết bị vẫn có thể nhận lời nhắc vì chưa gỡ được trên máy chủ.',
            ),
          ),
        );
      }
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }
}

/// Hộp thoại sửa tên hiển thị và múi giờ (PATCH /me).
class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({required this.user});

  final UserModel user;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  static const List<String> _commonTimezones = [
    'Asia/Ho_Chi_Minh',
    'Asia/Bangkok',
    'Asia/Singapore',
    'Asia/Tokyo',
    'Asia/Seoul',
    'Europe/London',
    'America/New_York',
    'UTC',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final List<String> _options;
  late String _timezone;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.fullName);
    _timezone = widget.user.timezone;
    _options = [..._commonTimezones];
    if (!_options.contains(_timezone)) _options.insert(0, _timezone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Vui lòng nhập tên';
    if (v.length > 100) return 'Tên tối đa 100 ký tự';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ProfileService.updateMe(
        displayName: _nameController.text.trim(),
        timezone: _timezone,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Chỉnh sửa hồ sơ'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                enabled: !_saving,
                textInputAction: TextInputAction.done,
                validator: _validateName,
                decoration: const InputDecoration(
                  labelText: 'Tên hiển thị',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _timezone,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Múi giờ',
                  prefixIcon: Icon(Icons.public_rounded),
                ),
                items: [
                  for (final tz in _options)
                    DropdownMenuItem(value: tz, child: Text(tz)),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value != null) setState(() => _timezone = value);
                      },
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: AppTheme.sickBadgeText),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Hủy'),
        ),
        TextButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Lưu'),
        ),
      ],
    );
  }
}
