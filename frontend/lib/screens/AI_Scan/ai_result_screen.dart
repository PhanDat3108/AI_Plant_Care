import 'package:flutter/material.dart';
import '../../models/plant_model.dart';
import '../../theme/app_theme.dart';

class AiResultScreen extends StatefulWidget {
  final PlantModel plant;

  const AiResultScreen({super.key, required this.plant});

  @override
  State<AiResultScreen> createState() => _AiResultScreenState();
}

class _AiResultScreenState extends State<AiResultScreen> {
  bool _isAdding = false;

  // Giả lập luồng lưu cây vào CSDL
  Future<void> _addToGarden() async {
    setState(() {
      _isAdding = true;
    });

    // Mô phỏng delay mạng
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    setState(() {
      _isAdding = false;
    });

    // Báo thành công
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã thêm cây vào Vườn của bạn!'),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Quay về màn hình chính (hoặc có thể điều hướng thẳng sang PlantDetail)
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final bool isSick = widget.plant.healthStatus == HealthStatus.sick;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.titleTextColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Kết quả phân tích'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100), // Chừa không gian cho nút bấm nổi
        child: Column(
          children: [
            _buildMainImageCard(isSick),
            _buildCareSummaryChips(),
            if (isSick) _buildDiseaseInfoCard(),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildAddButton(),
    );
  }

  // Thẻ Ảnh & Tên chính
  Widget _buildMainImageCard(bool isSick) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Cụm Ảnh & Điểm chính xác
            Stack(
              children: [
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    // Dummy ảnh bằng Icon
                    child: Icon(
                      Icons.park_rounded,
                      size: 100,
                      color: isSick ? AppTheme.sickBadgeText.withOpacity(0.5) : AppTheme.primaryColor.withOpacity(0.5),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.appBarColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '94% chính xác',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Tên cây
            Text(
              widget.plant.commonName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24),
            ),
            Text(
              widget.plant.scientificName,
              style: const TextStyle(
                color: AppTheme.subTextColor,
                fontStyle: FontStyle.italic,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            
            // Badge Trạng thái
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSick ? AppTheme.sickBadgeBg : AppTheme.healthyBadgeBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isSick ? 'Phát hiện bệnh: ${widget.plant.diseaseName}' : 'Khỏe mạnh',
                style: TextStyle(
                  color: isSick ? AppTheme.sickBadgeText : AppTheme.healthyBadgeText,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Bộ thông số chăm sóc 
  Widget _buildCareSummaryChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildChip(Icons.wb_sunny_rounded, Colors.orange, widget.plant.sunlightInfo),
          _buildChip(Icons.water_drop_rounded, Colors.blue, widget.plant.waterInfo),
          _buildChip(Icons.thermostat_rounded, Colors.redAccent, widget.plant.temperatureInfo),
        ],
      ),
    );
  }

  Widget _buildChip(IconData icon, Color iconColor, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.titleTextColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // Thẻ Triệu chứng & Cách xử lý (Chỉ hiện khi bị bệnh) 
  Widget _buildDiseaseInfoCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Triệu chứng & Cách xử lý',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            
            if (widget.plant.symptoms != null)
              ...widget.plant.symptoms!.map((symptom) => _buildBulletPoint(symptom)),
              
            if (widget.plant.treatmentSteps != null)
              ...widget.plant.treatmentSteps!.map((step) => _buildBulletPoint(step)),
          ],
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6, right: 8),
            child: Icon(Icons.circle, size: 8, color: AppTheme.primaryColor),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppTheme.titleTextColor, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. Nút Thêm vào vườn nổi ---
  Widget _buildAddButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ElevatedButton(
        onPressed: _isAdding ? null : _addToGarden,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), 
        ),
        child: _isAdding
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Thêm vào Vườn của tôi', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 8),
                  Icon(Icons.eco_rounded, size: 20),
                ],
              ),
      ),
    );
  }
}