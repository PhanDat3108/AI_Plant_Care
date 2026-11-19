import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/plant_model.dart';
import '../../services/mock_data_service.dart';
import 'plant_detail_header.dart';
import 'plant_detail_cards.dart';

class PlantDetailScreen extends StatefulWidget {
  final String plantId;

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
    _loadPlantData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _loadPlantData() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final data = await _dataService.getPlantDetail(widget.plantId);
      if (!mounted) return;
      setState(() { _plant = data; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _errorMessage = e.toString().replaceAll('Exception: ', ''); _isLoading = false; });
    }
  }

  void _showEditNicknameDialog() {
    if (_plant == null) return;
    _nicknameController.text = _plant!.nickname;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Đổi biệt danh', style: TextStyle(color: AppTheme.titleTextColor)),
        content: TextField(controller: _nicknameController, decoration: const InputDecoration(hintText: 'Nhập tên gọi mới cho cây...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy', style: TextStyle(color: AppTheme.subTextColor))),
          ElevatedButton(
            onPressed: () {
              if (_nicknameController.text.trim().isNotEmpty) {
                setState(() { _plant = _plant!.copyWith(nickname: _nicknameController.text.trim()); });
                Navigator.pop(context);
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePlant() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xóa cây?', style: TextStyle(color: AppTheme.sickBadgeText)),
        content: Text('Bạn có chắc chắn muốn xóa "${_plant?.nickname}" khỏi Vườn của mình không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy', style: TextStyle(color: AppTheme.subTextColor))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.sickBadgeText),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa cây khỏi vườn!')));
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.appBarColor,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.titleTextColor), onPressed: () => Navigator.pop(context)),
        title: const Text('Chi tiết cây'),
      ),
      body: _buildBodyContent(),
    );
  }

  Widget _buildBodyContent() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 64, color: AppTheme.sickBadgeText),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.subTextColor, fontSize: 16)),
              const SizedBox(height: 24),
              ElevatedButton.icon(onPressed: _loadPlantData, icon: const Icon(Icons.refresh_rounded), label: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }

    if (_plant == null) return const Center(child: Text('Không tìm thấy thông tin cây.'));

    return Column(
      children: [
        PlantDetailHeader(plant: _plant!, onEditNickname: _showEditNicknameDialog),
        Container(
          color: AppTheme.scaffoldBackgroundColor,
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: AppTheme.subTextColor,
            indicatorColor: AppTheme.primaryColor,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [Tab(text: 'HƯỚNG DẪN'), Tab(text: 'LỊCH NHẮC'), Tab(text: 'NHẬT KÝ')],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildInstructionTab(), _buildReminderTab(), _buildHistoryTab()],
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        InfoCard(icon: Icons.wb_sunny_rounded, iconColor: Colors.orange, title: 'Ánh sáng', subtitle: _plant!.sunlightInfo),
        InfoCard(icon: Icons.water_drop_rounded, iconColor: Colors.blue, title: 'Lượng nước', subtitle: _plant!.waterInfo),
        InfoCard(icon: Icons.eco_rounded, iconColor: Colors.brown, title: 'Loại đất', subtitle: _plant!.temperatureInfo),
        _buildDeleteButton(),
      ],
    );
  }

  Widget _buildReminderTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        ToggleReminderCard(icon: Icons.water_drop_rounded, iconColor: Colors.blue, title: 'Tưới nước', subtitle: 'Mỗi ${_plant!.wateringFrequencyDays} ngày, lúc ${_plant!.reminderTime}', value: _plant!.isWateringReminderOn, onChanged: (val) => setState(() => _plant = _plant!.copyWith(isWateringReminderOn: val))),
        ToggleReminderCard(icon: Icons.science_rounded, iconColor: Colors.orange, title: 'Bón phân', subtitle: 'Mỗi ${_plant!.fertilizingFrequencyDays} ngày, lúc ${_plant!.reminderTime}', value: _plant!.isFertilizingReminderOn, onChanged: (val) => setState(() => _plant = _plant!.copyWith(isFertilizingReminderOn: val))),
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
          if (log.actionType.contains('tưới'))      { iconColor = Colors.blue;   iconData = Icons.water_drop_rounded; }
          else if (log.actionType.contains('bón'))   { iconColor = Colors.orange; iconData = Icons.science_rounded; }
          else if (log.actionType.contains('chẩn'))  { iconColor = AppTheme.primaryColor; iconData = Icons.document_scanner_rounded; }

          return LogCard(
            icon: iconData, iconColor: iconColor,
            action: log.actionType,
            date: '${log.actionDate.day}/${log.actionDate.month}/${log.actionDate.year}',
            note: log.note,
          );
        }),
        _buildDeleteButton(),
      ],
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
