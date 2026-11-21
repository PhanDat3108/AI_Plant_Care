import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_exception.dart';
import '../../services/scan_service.dart';
import '../../theme/app_theme.dart';
import '../ai_result/ai_result_screen.dart';
import 'scan_controls.dart';
import 'scan_viewfinder.dart';

class ScanScreen extends StatefulWidget {
  final String? plantId;
  final bool initialDiseaseMode;

  const ScanScreen({
    super.key,
    this.plantId,
    this.initialDiseaseMode = false,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final ImagePicker _picker = ImagePicker();

  CameraController? _cameraController;
  String? _cameraError;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;

  late bool _isDiseaseMode;
  bool _isFlashOn = false;
  String _zoomLevel = '1x';

  bool _isAnalyzing = false;
  String? _selectedImagePath;

  @override
  void initState() {
    super.initState();
    _isDiseaseMode = widget.plantId != null ? true : widget.initialDiseaseMode;
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() => _cameraError = 'Không tìm thấy camera trên thiết bị.');
        }
        return;
      }

      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();

      try {
        _minZoom = await controller.getMinZoomLevel();
        _maxZoom = await controller.getMaxZoomLevel();
      } catch (_) {
        _minZoom = 1.0;
        _maxZoom = 1.0;
      }

      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {}

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _cameraError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraError = 'Không mở được camera. Bạn vẫn có thể chọn ảnh từ thư viện.';
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  void _toggleMode(bool isDisease) {
    if (_isAnalyzing) return;
    setState(() => _isDiseaseMode = isDisease);
  }

  Future<void> _toggleFlash() async {
    if (_isAnalyzing) return;
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    final nextState = !_isFlashOn;
    try {
      await controller.setFlashMode(
        nextState ? FlashMode.torch : FlashMode.off,
      );
      if (!mounted) return;
      setState(() => _isFlashOn = nextState);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thiết bị hoặc máy ảo này không hỗ trợ bật đèn flash.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _setZoom(String zoom) async {
    if (_isAnalyzing) return;
    setState(() => _zoomLevel = zoom);

    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    final target = zoom == '2x' ? 2.0 : 1.0;
    final clamped = target.clamp(_minZoom, _maxZoom);
    try {
      await controller.setZoomLevel(clamped);
    } catch (_) {}
  }

  Future<void> _capturePhoto() async {
    if (_isAnalyzing) return;
    final controller = _cameraController;

    if (controller != null && controller.value.isInitialized) {
      if (controller.value.isTakingPicture) return;
      try {
        final photo = await controller.takePicture();
        await _analyzeImage(photo);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể chụp ảnh: $e'),
            backgroundColor: AppTheme.sickBadgeText,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      // Dự phòng nếu camera lồng không khởi tạo được
      await _pickFromSource(ImageSource.camera);
    }
  }

  Future<void> _pickFromSource(ImageSource source) async {
    if (_isAnalyzing) return;

    XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể mở thư viện ảnh: $e'),
          backgroundColor: AppTheme.sickBadgeText,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (picked == null || !mounted) return;
    await _analyzeImage(picked);
  }

  Future<void> _analyzeImage(XFile file) async {
    if (!mounted) return;

    setState(() {
      _selectedImagePath = file.path;
      _isAnalyzing = true;
    });

    try {
      final bytes = await file.readAsBytes();
      final mode = widget.plantId != null
          ? 'diagnose'
          : (_isDiseaseMode ? 'both' : 'identify');

      final scanResult = await ScanService.createScan(
        imageBytes: bytes,
        fileName: file.name,
        mode: mode,
        plantId: widget.plantId,
      );

      if (_isFlashOn) {
        try {
          await _cameraController?.setFlashMode(FlashMode.off);
        } catch (_) {}
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AiResultScreen(
            plant: scanResult.toPlantModel(),
            confidence: scanResult.displayConfidence,
            localImagePath: file.path,
            coverImageKey: scanResult.imageKey,
            healthStatusRaw: scanResult.healthStatus,
            isMock: scanResult.isMock,
            existingPlantId: widget.plantId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _selectedImagePath = null);
      final message = e is ApiException
          ? e.message
          : e.toString().replaceAll('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
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
          ScanCameraPreview(
            cameraController: _cameraController,
            previewImagePath: _selectedImagePath,
            cameraError: _cameraError,
          ),
          ScanViewfinder(isAnalyzing: _isAnalyzing),
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
                  onCapture: _capturePhoto,
                  onPickGallery: () => _pickFromSource(ImageSource.gallery),
                  onZoomChanged: _setZoom,
                ),
              ],
            ),
          ),
          if (_isAnalyzing) const ScanAnalyzingOverlay(),
        ],
      ),
    );
  }
}