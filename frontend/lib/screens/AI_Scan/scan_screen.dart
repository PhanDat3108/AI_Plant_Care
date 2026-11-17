import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../services/mock_data_service.dart';
import '../AI_Scan/ai_result_screen.dart'; 

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final MockDataService _dataService = MockDataService();

  // Các state tương tác
  bool _isDiseaseMode = true;
  bool _isFlashOn = false;
  String _zoomLevel = '1x';
  
  // State xử lý call API
  bool _isAnalyzing = false;

  // --- Logic Tương tác ---
  void _toggleMode(bool isDisease) {
    if (_isAnalyzing) return;
    setState(() => _isDiseaseMode = isDisease);
  }

  void _toggleFlash() {
    if (_isAnalyzing) return;
    setState(() => _isFlashOn = !_isFlashOn);
  }

  void _setZoom(String zoom) {
    if (_isAnalyzing) return;
    setState(() => _zoomLevel = zoom);
  }

  // Logic gọi AI phân tích ảnh
  Future<void> _captureAndAnalyze() async {
    if (_isAnalyzing) return;

    setState(() {
      _isAnalyzing = true;
    });

    try {
      // Gọi service quét AI giả lập
      final result = await _dataService.scanAndDiagnose('assets/images/leaf_placeholder.png');
      
      // Kiểm tra mounted trước khi dùng context theo chuẩn Flutter Lint
      if (!mounted) return;
      
      // Chuyển sang màn hình kết quả và truyền data qua
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => AiResultScreen(plant: result)),
      );
    } catch (e) {
      if (!mounted) return;
      
      // Trạng thái Lỗi: Hiển thị SnackBar thân thiện
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppTheme.sickBadgeText,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildMockCameraPreview(),
          _buildFocusFrame(),
          
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTopControls(),
                _buildBottomControls(),
              ],
            ),
          ),

          // Trạng thái Loading đè lên toàn màn hình khi đang quét AI
          if (_isAnalyzing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.7),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon quét đang quay
                    CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                      strokeWidth: 4,
                    ),
                    SizedBox(height: 24),
                    Text(
                      'AI đang phân tích ảnh...\nVui lòng giữ yên thiết bị.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMockCameraPreview() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFC8E6C9),
          image: const DecorationImage(
            image: AssetImage('assets/images/leaf_placeholder.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: const Center(
          child: Icon(Icons.eco_rounded, size: 200, color: Color(0x332E5A36)),
        ),
      ),
    );
  }

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
                Positioned(top: 0, left: 0, child: _buildCorner(isTop: true, isLeft: true)),
                Positioned(top: 0, right: 0, child: _buildCorner(isTop: true, isLeft: false)),
                Positioned(bottom: 0, left: 0, child: _buildCorner(isTop: false, isLeft: true)),
                Positioned(bottom: 0, right: 0, child: _buildCorner(isTop: false, isLeft: false)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AnimatedOpacity(
            opacity: _isAnalyzing ? 0.0 : 1.0, // Ẩn text khi đang quét
            duration: const Duration(milliseconds: 300),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Đưa lá cây vào giữa khung hình',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildTopControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildCircleButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context),
          ),
          Container(
            height: 48,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModeButton('Nhận diện loài', !_isDiseaseMode, () => _toggleMode(false)),
                _buildModeButton('Chẩn đoán bệnh', _isDiseaseMode, () => _toggleMode(true)),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCircleButton(
                icon: _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                onTap: _toggleFlash,
              ),
      
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(String title, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
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

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
                  onTap: () => _setZoom(zoom),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              InkWell(
                onTap: () {}, // Chọn ảnh từ thư viện
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Center(
                    child: Icon(Icons.photo_library_rounded, color: AppTheme.subTextColor),
                  ),
                ),
              ),
              
              // Nút CHỤP ẢNH
              InkWell(
                onTap: _captureAndAnalyze,
                borderRadius: BorderRadius.circular(40),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _isAnalyzing ? 64 : 72, // Thu nhỏ nhẹ khi đang quét
                  height: _isAnalyzing ? 64 : 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isAnalyzing ? Colors.grey : Colors.white, 
                      width: 4
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _isAnalyzing ? Colors.grey : AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 56), 
            ],
          ),
        ],
      ),
    );
  }

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