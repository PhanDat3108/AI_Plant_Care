import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../services/mock_data_service.dart';
import '../ai_result/ai_result_screen.dart';
import 'scan_viewfinder.dart';
import 'scan_controls.dart';

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
          // Lớp 1: Nền camera giả lập
          const ScanCameraPreview(),

          // Lớp 2: Khung ngắm 4 góc + hướng dẫn
          ScanViewfinder(isAnalyzing: _isAnalyzing),

          // Lớp 3: Các nút điều khiển (trên & dưới)
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ScanTopControls(
                  isDiseaseMode: _isDiseaseMode,
                  isFlashOn: _isFlashOn,
                  onBack: () => Navigator.pop(context),
                  onToggleFlash: _toggleFlash,
                  onToggleMode: _toggleMode,
                ),
                ScanBottomControls(
                  zoomLevel: _zoomLevel,
                  isAnalyzing: _isAnalyzing,
                  onCapture: _captureAndAnalyze,
                  onZoomChanged: _setZoom,
                ),
              ],
            ),
          ),

          // Lớp 4: Overlay loading khi AI đang phân tích
          if (_isAnalyzing) const ScanAnalyzingOverlay(),
        ],
      ),
    );
  }
}