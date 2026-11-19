import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Thanh điều khiển phía trên: nút Back + toggle chế độ + nút Flash
class ScanTopControls extends StatelessWidget {
  final bool isDiseaseMode;
  final bool isFlashOn;
  final VoidCallback onBack;
  final VoidCallback onToggleFlash;
  final ValueChanged<bool> onToggleMode; // true = Chẩn đoán, false = Nhận diện

  const ScanTopControls({
    super.key,
    required this.isDiseaseMode,
    required this.isFlashOn,
    required this.onBack,
    required this.onToggleFlash,
    required this.onToggleMode,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ScanCircleButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: onBack,
          ),
          Container(
            height: 48,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ScanModeButton(
                  title: 'Nhận diện loài',
                  isSelected: !isDiseaseMode,
                  onTap: () => onToggleMode(false),
                ),
                _ScanModeButton(
                  title: 'Chẩn đoán bệnh',
                  isSelected: isDiseaseMode,
                  onTap: () => onToggleMode(true),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ScanCircleButton(
                icon: isFlashOn
                    ? Icons.flash_on_rounded
                    : Icons.flash_off_rounded,
                onTap: onToggleFlash,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Cụm điều khiển phía dưới: zoom + nút thư viện + nút chụp
class ScanBottomControls extends StatelessWidget {
  final String zoomLevel;
  final bool isAnalyzing;
  final VoidCallback onCapture;
  final ValueChanged<String> onZoomChanged;

  const ScanBottomControls({
    super.key,
    required this.zoomLevel,
    required this.isAnalyzing,
    required this.onCapture,
    required this.onZoomChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Thanh zoom
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: ['1x', '2x'].map((zoom) {
                final isSelected = zoomLevel == zoom;
                return InkWell(
                  onTap: () => onZoomChanged(zoom),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      zoom,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? AppTheme.titleTextColor
                            : AppTheme.subTextColor,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // Hàng nút: Thư viện + Chụp
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
                    child: Icon(
                      Icons.photo_library_rounded,
                      color: AppTheme.subTextColor,
                    ),
                  ),
                ),
              ),
              // Nút CHỤP ẢNH
              InkWell(
                onTap: onCapture,
                borderRadius: BorderRadius.circular(40),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isAnalyzing ? 64 : 72,
                  height: isAnalyzing ? 64 : 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isAnalyzing ? Colors.grey : Colors.white,
                      width: 4,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: isAnalyzing
                            ? Colors.grey
                            : AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
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
}

/// Lớp phủ loading khi AI đang phân tích
class ScanAnalyzingOverlay extends StatelessWidget {
  const ScanAnalyzingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
    );
  }
}

/// Nút tròn chung (Back / Flash)
class _ScanCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ScanCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppTheme.primaryColor, size: 22),
      ),
    );
  }
}

/// Nút toggle chế độ (Nhận diện / Chẩn đoán)
class _ScanModeButton extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _ScanModeButton({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
}
