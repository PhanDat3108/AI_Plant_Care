import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/plant_model.dart';
import '../services/mock_data_service.dart';

class PlantDetailScreen extends StatefulWidget {
  final String plantId;

  // Bắt buộc truyền ID cây để gọi data
  const PlantDetailScreen({super.key, required this.plantId});

  @override
  State<PlantDetailScreen> createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends State<PlantDetailScreen> with SingleTickerProviderStateMixin {
  final MockDataService _dataService = MockDataService();
  
  late TabController _tabController;
  late TextEditingController _nicknameController;

  PlantModel? _plant;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _nicknameController = TextEditingController();
    _loadPlantData(); // Khởi chạy gọi mạng giả lập
  }

  @override
  void dispose() {
    // giải phóng mọi Controller khi rời màn hình
    _tabController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  // --- Xử lý Dữ liệu ---
  Future<void> _loadPlantData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _dataService.getPlantDetail(widget.plantId);
      setState(() {
        _plant = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  // --- Tương tác Popup ---
  void _showEditNicknameDialog() {
    if (_plant == null) return;
    _nicknameController.text = _plant!.nickname;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Đổi biệt danh', style: TextStyle(color: AppTheme.titleTextColor)),
          content: TextField(
            controller: _nicknameController,
            decoration: const InputDecoration(
              hintText: 'Nhập tên gọi mới cho cây...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy', style: TextStyle(color: AppTheme.subTextColor)),
            ),
            ElevatedButton(
              onPressed: () {
                if (_nicknameController.text.trim().isNotEmpty) {
                  setState(() {
                    _plant = _plant!.copyWith(nickname: _nicknameController.text.trim());
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeletePlant() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Xóa cây?', style: TextStyle(color: AppTheme.sickBadgeText)),
          content: Text('Bạn có chắc chắn muốn xóa "${_plant?.nickname}" khỏi Vườn của mình không?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy', style: TextStyle(color: AppTheme.subTextColor)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.sickBadgeText),
              onPressed: () {
                Navigator.pop(context); // Đóng Dialog
                Navigator.pop(context); // Thoát khỏi màn hình chi tiết (quay về Vườn)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã xóa cây khỏi vườn!')),
                );
              },
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.appBarColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.titleTextColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Chi tiết cây'),
      ),
      body: _buildBodyContent(),
    );
  }

  // --- Bộ định tuyến 3 Trạng thái ---
  Widget _buildBodyContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 64, color: AppTheme.sickBadgeText),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.subTextColor, fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadPlantData,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (_plant == null) {
      return const Center(child: Text('Không tìm thấy thông tin cây.'));
    }

    return Column(
      children: [
        _buildHeaderSection(),
        Container(
          color: AppTheme.scaffoldBackgroundColor,
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: AppTheme.subTextColor,
            indicatorColor: AppTheme.primaryColor,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [
              Tab(text: 'HƯỚNG DẪN'),
              Tab(text: 'LỊCH NHẮC'),
              Tab(text: 'NHẬT KÝ'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildInstructionTab(),
              _buildReminderTab(),
              _buildHistoryTab(),
            ],
          ),
        ),
      ],
    );
  }

  // --- 1. Header Section ---
  Widget _buildHeaderSection() {
    final bool isSick = _plant!.healthStatus == HealthStatus.sick;

    return Stack(
      children: [
        Container(
          height: 80,
          decoration: const BoxDecoration(
            color: AppTheme.appBarColor,
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
          ),
        ),
        Card(
          margin: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(color: AppTheme.scaffoldBackgroundColor, shape: BoxShape.circle),
                  child: Center(
                    child: Icon(Icons.park_rounded, size: 60, color: isSick ? AppTheme.sickBadgeText.withOpacity(0.5) : AppTheme.primaryColor),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        _plant!.nickname,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.titleTextColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _showEditNicknameDialog,
                      child: const Icon(Icons.edit_rounded, size: 20, color: AppTheme.subTextColor),
                    ),
                  ],
                ),
                Text(
                  _plant!.scientificName,
                  style: const TextStyle(color: AppTheme.subTextColor, fontStyle: FontStyle.italic, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSick ? AppTheme.sickBadgeBg : AppTheme.healthyBadgeBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isSick ? 'Phát hiện bệnh' : 'Khỏe mạnh',
                    style: TextStyle(color: isSick ? AppTheme.sickBadgeText : AppTheme.healthyBadgeText, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- 2. Các Tab Content ---
  Widget _buildInstructionTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        _buildInfoCard(Icons.wb_sunny_rounded, Colors.orange, 'Ánh sáng', _plant!.sunlightInfo),
        _buildInfoCard(Icons.water_drop_rounded, Colors.blue, 'Lượng nước', _plant!.waterInfo),
        _buildInfoCard(Icons.eco_rounded, Colors.brown, 'Loại đất', _plant!.temperatureInfo),
        _buildDeleteButton(),
      ],
    );
  }

  Widget _buildReminderTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        _buildToggleCard(
          Icons.water_drop_rounded, Colors.blue, 'Tưới nước', 
          'Mỗi ${_plant!.wateringFrequencyDays} ngày, lúc ${_plant!.reminderTime}', 
          _plant!.isWateringReminderOn, 
          (val) => setState(() => _plant = _plant!.copyWith(isWateringReminderOn: val))
        ),
        _buildToggleCard(
          Icons.science_rounded, Colors.orange, 'Bón phân', 
          'Mỗi ${_plant!.fertilizingFrequencyDays} ngày, lúc ${_plant!.reminderTime}', 
          _plant!.isFertilizingReminderOn, 
          (val) => setState(() => _plant = _plant!.copyWith(isFertilizingReminderOn: val))
        ),
        _buildDeleteButton(),
      ],
    );
  }

  Widget _buildHistoryTab() {
    if (_plant!.logs.isEmpty) {
      return Column(
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.history_rounded, size: 48, color: AppTheme.appBarColor),
          const SizedBox(height: 16),
          const Text('Chưa có ghi chép chăm sóc nào.', style: TextStyle(color: AppTheme.subTextColor)),
          _buildDeleteButton(),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        ..._plant!.logs.map((log) {
          Color iconColor = AppTheme.primaryColor;
          IconData iconData = Icons.info_outline_rounded;
          if (log.actionType.contains('tưới')) {
            iconColor = Colors.blue; iconData = Icons.water_drop_rounded;
          } else if (log.actionType.contains('bón')) {
            iconColor = Colors.orange; iconData = Icons.science_rounded;
          } else if (log.actionType.contains('chẩn đoán')) {
            iconColor = AppTheme.primaryColor; iconData = Icons.document_scanner_rounded;
          }
          
          final dateStr = "${log.actionDate.day}/${log.actionDate.month}/${log.actionDate.year}";
          
          return _buildLogCard(iconData, iconColor, log.actionType, dateStr, log.note);
        }),
        _buildDeleteButton(),
      ],
    );
  }

  // --- Helper Widgets ---
  Widget _buildInfoCard(IconData icon, Color iconColor, String title, String subtitle) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 24)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.titleTextColor)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppTheme.subTextColor, fontSize: 13)),
      ),
    );
  }

  Widget _buildToggleCard(IconData icon, Color iconColor, String title, String subtitle, bool value, Function(bool) onChanged) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 24)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.titleTextColor)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: AppTheme.subTextColor, fontSize: 13))])),
            Switch(value: value, onChanged: onChanged, activeColor: AppTheme.primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(IconData icon, Color iconColor, String action, String date, String note) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 24)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(action, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.titleTextColor)), Text(date, style: const TextStyle(color: AppTheme.subTextColor, fontSize: 11))]), const SizedBox(height: 4), Text(note, style: const TextStyle(color: AppTheme.subTextColor, fontSize: 13))])),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: OutlinedButton.icon(
        onPressed: _confirmDeletePlant,
        icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.sickBadgeText),
        label: const Text('Xóa cây khỏi vườn', style: TextStyle(color: AppTheme.sickBadgeText)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: AppTheme.sickBadgeText),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}