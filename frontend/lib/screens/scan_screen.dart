import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  // Trạng thái tĩnh (bước 1)
  bool _isDiseaseMode = true; // true: Chẩn đoán bệnh, false: Nhận diện loài
  bool _isFlashOn = false;
  String _zoomLevel = '1x';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Nền đen cho khu vực camera
      body: Stack(
        children: [
          // 1. Lớp dưới cùng: Camera Preview (Tạm dùng giả lập tĩnh)
          _buildMockCameraPreview(),

          // 2. Lớp giữa: Khung căn chỉnh (Focus Frame)
          _buildFocusFrame(),

          // 3. Lớp trên cùng: Các nút điều khiển (Top, Bottom)
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTopControls(),
                _buildBottomControls(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 1. Camera Preview giả lập ---
  Widget _buildMockCameraPreview() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFC8E6C9), // Xanh lá pastel giả lập lá cây
          image: const DecorationImage(
            image: AssetImage('assets/images/leaf_placeholder.png'), // Comment asset thật
            fit: BoxFit.cover,
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.eco_rounded,
            size: 200,
            color: Color(0x332E5A36), // Icon lá mờ mờ ở giữa
          ),
        ),
      ),
    );
  }

  // --- 2. Khung căn chỉnh ở giữa màn hình ---
  Widget _buildFocusFrame() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 280,
            height: 280,
            child: Stack(
              children: [
                // 4 góc bo viền sáng nổi bật (Góc trên trái)
                Positioned(top: 0, left: 0, child: _buildCorner(isTop: true, isLeft: true)),
                // Góc trên phải
                Positioned(top: 0, right: 0, child: _buildCorner(isTop: true, isLeft: false)),
                // Góc dưới trái
                Positioned(bottom: 0, left: 0, child: _buildCorner(isTop: false, isLeft: true)),
                // Góc dưới phải
                Positioned(bottom: 0, right: 0, child: _buildCorner(isTop: false, isLeft: false)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Text hướng dẫn
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Đưa lá cây vào giữa khung hình',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // Helper tạo 4 góc sáng cho khung Focus
  Widget _buildCorner({required bool isTop, required bool isLeft}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        border: Border(
          top: isTop ? const BorderSide(color: Colors.white, width: 4) : BorderSide.none,
          bottom: !isTop ? const BorderSide(color: Colors.white, width: 4) : BorderSide.none,
          left: isLeft ? const BorderSide(color: Colors.white, width: 4) : BorderSide.none,
          right: !isLeft ? const BorderSide(color: Colors.white, width: 4) : BorderSide.none,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isTop && isLeft ? 24 : 0),
          topRight: Radius.circular(isTop && !isLeft ? 24 : 0),
          bottomLeft: Radius.circular(!isTop && isLeft ? 24 : 0),
          bottomRight: Radius.circular(!isTop && !isLeft ? 24 : 0),
        ),
      ),
    );
  }

  // --- 3. Thanh điều khiển phía trên ---
  Widget _buildTopControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Nút Quay lại (Vùng chạm 48)
          _buildCircleButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context),
          ),
          
          // Nút chuyển chế độ (Nhận diện loài / Chẩn đoán bệnh)
          Container(
            height: 48,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModeButton('Nhận diện loài', !_isDiseaseMode),
                _buildModeButton('Chẩn đoán bệnh', _isDiseaseMode),
              ],
            ),
          ),

          // Các nút tiện ích (Flash & Flip)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCircleButton(
                icon: _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                onTap: () {},
              ),
              const SizedBox(width: 8),
              _buildCircleButton(
                icon: Icons.cameraswitch_rounded,
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(String title, bool isSelected) {
    return InkWell(
      onTap: () {}, // Sẽ xử lý ở Bước 2
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.subTextColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // --- 4. Thanh điều khiển phía dưới ---
  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Trình chọn Zoom
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: ['1x', '2x'].map((zoom) {
                final isSelected = _zoomLevel == zoom;
                return InkWell(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      zoom,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppTheme.titleTextColor : AppTheme.subTextColor,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Hàng nút chụp ảnh
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Nút Thư viện ảnh (Gallery)
              InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white, width: 2),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/gallery_thumb.png'), // Placeholder
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.photo_library_rounded, color: AppTheme.subTextColor),
                  ),
                ),
              ),

              // Nút Chụp ảnh (Capture) khổng lồ
              InkWell(
                onTap: () {}, // Sẽ kích hoạt giả lập API quét ở Bước 2
                borderRadius: BorderRadius.circular(40),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ),

              // Spacer để cân bằng bố cục đối xứng với nút Gallery
              const SizedBox(width: 56),
            ],
          ),
        ],
      ),
    );
  }

  // Nút tròn dùng chung cho Back, Flash, Switch Camera
  Widget _buildCircleButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppTheme.primaryColor, size: 22),
      ),
    );
  }
}