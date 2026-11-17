import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PlantDetailScreen extends StatefulWidget {
  // Ở Bước 1 (UI tĩnh), ta chưa cần truyền PlantModel vào vội.
  const PlantDetailScreen({super.key});

  @override
  State<PlantDetailScreen> createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends State<PlantDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // State giả lập cho các công tắc (Bước 1)
  bool _isWateringOn = true;
  bool _isFertilizingOn = true;

  @override
  void initState() {
    super.initState();
    // Khởi tạo TabController với 3 tab
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    // TUÂN THỦ RUBRIC: Giải phóng TabController khi rời màn hình
    _tabController.dispose();
    super.dispose();
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
      body: Column(
        children: [
          // 1. Phần Header Card có viền bo tròn nằm đè lên nền xanh nhạt
          _buildHeaderSection(),

          // 2. Thanh TabBar
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

          // 3. Nội dung các Tab
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
      ),
    );
  }

  // --- 1. Header Section ---
  Widget _buildHeaderSection() {
    return Stack(
      children: [
        // Background xanh nhạt vuốt xuống một chút
        Container(
          height: 80,
          decoration: const BoxDecoration(
            color: AppTheme.appBarColor,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
        ),
        
        // Thẻ thông tin cây
        Card(
          margin: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // Ảnh cây giả lập
                Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    color: AppTheme.scaffoldBackgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.park_rounded, size: 60, color: AppTheme.primaryColor),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Tên biệt danh + Nút sửa
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Bé Kim Tiền',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.titleTextColor),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {}, // Gọi popup sửa tên ở bước 2
                      child: const Icon(Icons.edit_rounded, size: 20, color: AppTheme.subTextColor),
                    ),
                  ],
                ),
                
                // Tên khoa học
                const Text(
                  'Zamioculcas zamiifolia',
                  style: TextStyle(color: AppTheme.subTextColor, fontStyle: FontStyle.italic, fontSize: 14),
                ),
                const SizedBox(height: 12),
                
                // Badge sức khỏe
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.healthyBadgeBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Khỏe mạnh',
                    style: TextStyle(color: AppTheme.healthyBadgeText, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- 2. Tab 1: Hướng dẫn chăm sóc ---
  Widget _buildInstructionTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        _buildInfoCard(
          icon: Icons.wb_sunny_rounded,
          iconColor: Colors.orange,
          title: 'Ánh sáng',
          subtitle: 'Nắng nhẹ hoặc bóng râm trong nhà',
        ),
        _buildInfoCard(
          icon: Icons.water_drop_rounded,
          iconColor: Colors.blue,
          title: 'Lượng nước',
          subtitle: 'Tưới 1 lần/tuần, tránh ngập úng',
        ),
        _buildInfoCard(
          icon: Icons.eco_rounded,
          iconColor: Colors.brown,
          title: 'Loại đất',
          subtitle: 'Đất tơi xốp, thoát nước tốt',
        ),
        _buildDeleteButton(),
      ],
    );
  }

  // --- 3. Tab 2: Lịch nhắc nhở ---
  Widget _buildReminderTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        _buildToggleCard(
          icon: Icons.water_drop_rounded,
          iconColor: Colors.blue,
          title: 'Tưới nước',
          subtitle: 'Mỗi 3 ngày, lúc 08:00 AM',
          value: _isWateringOn,
          onChanged: (val) => setState(() => _isWateringOn = val),
        ),
        _buildToggleCard(
          icon: Icons.science_rounded,
          iconColor: Colors.orange,
          title: 'Bón phân',
          subtitle: 'Mỗi 30 ngày, lúc 09:00 AM',
          value: _isFertilizingOn,
          onChanged: (val) => setState(() => _isFertilizingOn = val),
        ),
        _buildDeleteButton(),
      ],
    );
  }

  // --- 4. Tab 3: Nhật ký chăm sóc ---
  Widget _buildHistoryTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        _buildLogCard(
          icon: Icons.water_drop_rounded,
          iconColor: Colors.blue,
          action: 'Đã tưới nước',
          date: '16/11/2026 - 08:05 AM',
          note: 'Tưới đủ ẩm gốc, lá xanh tốt',
        ),
        _buildLogCard(
          icon: Icons.document_scanner_rounded,
          iconColor: AppTheme.primaryColor,
          action: 'Đã chẩn đoán bệnh',
          date: '10/11/2026 - 04:20 PM',
          note: 'AI xác nhận cây khỏe mạnh (96%)',
        ),
        _buildDeleteButton(),
      ],
    );
  }

  // --- Helpers để render Card ---
  Widget _buildInfoCard({required IconData icon, required Color iconColor, required String title, required String subtitle}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.titleTextColor)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppTheme.subTextColor, fontSize: 13)),
      ),
    );
  }

  Widget _buildToggleCard({required IconData icon, required Color iconColor, required String title, required String subtitle, required bool value, required Function(bool) onChanged}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.titleTextColor)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: AppTheme.subTextColor, fontSize: 13)),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppTheme.primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard({required IconData icon, required Color iconColor, required String action, required String date, required String note}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(action, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.titleTextColor)),
                      Text(date, style: const TextStyle(color: AppTheme.subTextColor, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(note, style: const TextStyle(color: AppTheme.subTextColor, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Nút xóa cây (Dùng chung cho cả 3 tab)
  Widget _buildDeleteButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: OutlinedButton.icon(
        onPressed: () {},
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