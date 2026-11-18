import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// Nền camera giả lập (Positioned.fill)
class ScanCameraPreview extends StatelessWidget {
  const ScanCameraPreview({super.key});

  @override
  Widget build(BuildContext context) {
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
}

/// Khung ngắm 4 góc + chú thích hướng dẫn
class ScanViewfinder extends StatelessWidget {
  final bool isAnalyzing;

  const ScanViewfinder({super.key, required this.isAnalyzing});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 280,
            height: 280,
            child: Stack(
              children: [
                Positioned(top: 0, left: 0, child: _ScanCorner(isTop: true, isLeft: true)),
                Positioned(top: 0, right: 0, child: _ScanCorner(isTop: true, isLeft: false)),
                Positioned(bottom: 0, left: 0, child: _ScanCorner(isTop: false, isLeft: true)),
                Positioned(bottom: 0, right: 0, child: _ScanCorner(isTop: false, isLeft: false)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AnimatedOpacity(
            opacity: isAnalyzing ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.85),
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
}

/// 1 góc khung ngắm (widget nội bộ)
class _ScanCorner extends StatelessWidget {
  final bool isTop;
  final bool isLeft;

  const _ScanCorner({required this.isTop, required this.isLeft});

  @override
  Widget build(BuildContext context) {
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
}
