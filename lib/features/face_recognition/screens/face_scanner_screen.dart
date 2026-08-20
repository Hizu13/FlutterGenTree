import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import '../../../config/app_color.dart';
import '../../family/models/family_model.dart';
import '../../family/services/family_api_service.dart';
import '../../tree/screens/tree_screen.dart';
import '../models/face_match_model.dart';
import '../services/face_recognition_service.dart';
import '../widgets/multi_face_picker_sheet.dart';

class FaceScannerScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const FaceScannerScreen({super.key, this.onBack});

  @override
  FaceScannerScreenState createState() => FaceScannerScreenState();
}

class FaceScannerScreenState extends State<FaceScannerScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;
  bool _isFlashOn = false;
  bool _showInstruction = true;

  FamilyModel? _currentFamily;
  final ImagePicker _picker = ImagePicker();

  // Trạng thái nhận diện
  bool _isScanning = false;
  double _scanProgress = 0.0;
  Timer? _progressTimer;
  Timer? _dotTimer;
  int _dotIndex = 0;
  String _scanStatusText = 'Đang nhận diện...';

  // Kết quả nhận diện
  FaceSearchResult? _latestResult;
  FaceMemberMatch? _matchedMember;
  String? _capturedImagePath;
  String? _errorMessage;
  bool _noMatchFound = false;

  @override
  void initState() {
    super.initState();
    _loadFamily();
    _initCamera();
    _startDotAnimation();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _progressTimer?.cancel();
    _dotTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadFamily() async {
    final fam = await FamilyApiService.getCurrentFamily();
    if (mounted && fam != null) {
      setState(() {
        _currentFamily = fam;
      });
      // Tự động nạp và cập nhật chỉ mục khuôn mặt từ Avatar thành viên trong nền
      FaceRecognitionApiService.reindexFamily(fam.id ?? 1);
    }
  }

  void _startDotAnimation() {
    _dotTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (mounted && _isScanning) {
        setState(() {
          _dotIndex = (_dotIndex + 1) % 6;
        });
      }
    });
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        await _setupCameraController(_cameras[_selectedCameraIndex]);
      }
    } catch (e) {
      debugPrint('[FaceScanner] Camera init error: $e');
    }
  }

  Future<void> _setupCameraController(CameraDescription cameraDescription) async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }

    _cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('[FaceScanner] Setup camera controller error: $e');
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_isCameraInitialized) return;
    try {
      final newFlash = !_isFlashOn;
      await _cameraController!.setFlashMode(
        newFlash ? FlashMode.torch : FlashMode.off,
      );
      setState(() {
        _isFlashOn = newFlash;
      });
    } catch (e) {
      debugPrint('[FaceScanner] Flash toggle error: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _setupCameraController(_cameras[_selectedCameraIndex]);
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 90,
      );
      if (picked != null) {
        _processImage(File(picked.path));
      }
    } catch (e) {
      debugPrint('[FaceScanner] Gallery pick error: $e');
    }
  }

  Future<void> captureAndScan() async {
    if (_isScanning) return;

    File? imageFile;
    if (_cameraController != null && _isCameraInitialized) {
      try {
        final xFile = await _cameraController!.takePicture();
        imageFile = File(xFile.path);
      } catch (e) {
        debugPrint('[FaceScanner] Take picture error: $e');
      }
    }

    // Fallback: Nếu không có camera phần cứng (giả lập), dùng ImagePicker
    if (imageFile == null) {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 90,
      );
      if (picked != null) {
        imageFile = File(picked.path);
      }
    }

    if (imageFile != null) {
      _processImage(imageFile);
    }
  }

  void _resetToLiveCamera() {
    setState(() {
      _capturedImagePath = null;
      _matchedMember = null;
      _noMatchFound = false;
      _latestResult = null;
      _errorMessage = null;
      _scanStatusText = 'Sẵn sàng nhận diện';
      _scanProgress = 0.0;
    });
  }

  void _processImage(File imageFile) async {
    setState(() {
      _isScanning = true;
      _scanProgress = 0.15;
      _scanStatusText = 'Đang phân tích ảnh vừa chụp...';
      _capturedImagePath = imageFile.path;
      _errorMessage = null;
      _matchedMember = null;
      _noMatchFound = false;
      _latestResult = null;
    });

    // Tạo hiệu ứng thanh tiến trình mượt mà
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 120), (timer) {
      if (mounted && _isScanning) {
        setState(() {
          if (_scanProgress < 0.85) {
            _scanProgress += 0.08;
          }
        });
      }
    });

    final familyId = _currentFamily?.id ?? 1;

    try {
      // 1. Kiểm tra phát hiện khuôn mặt và xem có nhiều người không
      final candidates = await FaceRecognitionApiService.detectCandidates(imageFile);

      if (candidates.length > 1) {
        _progressTimer?.cancel();
        setState(() {
          _isScanning = false;
          _scanProgress = 0.0;
        });

        if (mounted) {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (ctx) => MultiFacePickerSheet(
              candidates: candidates,
              onSelected: (selectedCand) {
                _performSearchWithCandidate(imageFile, familyId, selectedCand);
              },
            ),
          );
        }
        return;
      }

      // 2. Chạy tìm kiếm khuôn mặt trên Backend
      final results = await FaceRecognitionApiService.searchFace(
        familyId: familyId,
        imageFile: imageFile,
        threshold: 0.93,
      );

      _progressTimer?.cancel();

      if (mounted) {
        setState(() {
          _isScanning = false;
          _scanProgress = 1.0;
          if (results.isNotEmpty && results.first.matches.isNotEmpty) {
            _latestResult = results.first;
            _matchedMember = results.first.matches.first;
            _noMatchFound = false;
            _scanStatusText = 'Đã nhận diện thành công!';
          } else {
            _latestResult = results.isNotEmpty ? results.first : null;
            _matchedMember = null;
            _noMatchFound = true;
            _scanStatusText = 'Không tìm thấy trong gia phả';
          }
        });
      }
    } catch (e) {
      _progressTimer?.cancel();
      if (mounted) {
        setState(() {
          _isScanning = false;
          _scanProgress = 0.0;
          _errorMessage = 'Lỗi kết nối máy chủ AI: $e';
          _scanStatusText = 'Lỗi nhận diện';
        });
      }
    }
  }

  void _performSearchWithCandidate(
    File imageFile,
    int familyId,
    FaceCandidate candidate,
  ) async {
    setState(() {
      _isScanning = true;
      _scanProgress = 0.5;
      _scanStatusText = 'Đang nhận diện Người ${candidate.faceIndex + 1}...';
      _noMatchFound = false;
      _matchedMember = null;
    });

    final results = await FaceRecognitionApiService.searchFace(
      familyId: familyId,
      imageFile: imageFile,
      threshold: 0.93,
    );

    if (mounted) {
      setState(() {
        _isScanning = false;
        _scanProgress = 1.0;
        if (results.isNotEmpty) {
          final matched = results.firstWhere(
            (r) => r.faceIndex == candidate.faceIndex,
            orElse: () => results.first,
          );
          _latestResult = matched;
          if (matched.matches.isNotEmpty) {
            _matchedMember = matched.matches.first;
            _noMatchFound = false;
            _scanStatusText = 'Đã nhận diện thành công!';
          } else {
            _matchedMember = null;
            _noMatchFound = true;
            _scanStatusText = 'Không tìm thấy trong gia phả';
          }
        } else {
          _noMatchFound = true;
          _scanStatusText = 'Không tìm thấy trong gia phả';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F6F0),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // 1. Header màu nâu đậm chủ đạo
            _buildTopAppBar(),

            // 2. Nội dung cuộn chính
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    // Banner Hướng dẫn
                    if (_showInstruction) _buildInstructionBanner(),
                    if (_showInstruction) const SizedBox(height: 12),

                    // Khung Camera Viewfinder
                    _buildCameraViewfinder(),
                    const SizedBox(height: 14),

                    // Cụm Điều Khiển & Trạng thái nhận diện
                    _buildControlsAndStatusRow(),
                    const SizedBox(height: 16),

                    // Tiêu đề Kết quả / Lịch sử nhận diện
                    _buildSectionHeader(),
                    const SizedBox(height: 8),

                    // Card Kết quả phân tích / Nhận diện thành viên
                    _buildAnalysisResultCard(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. TOP APP BAR
  // ===========================================================================
  Widget _buildTopAppBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 14,
        left: 12,
        right: 12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.primaryExtraDark,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (widget.onBack != null) {
                widget.onBack!();
              } else if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          Expanded(
            child: Column(
              children: [
                const Text(
                  'Nhận diện AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _currentFamily != null
                      ? 'Xác thực thành viên ${_currentFamily!.name}'
                      : 'Xác thực thành viên dòng họ',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Đồng bộ Avatar dòng họ',
            onPressed: _handleReindexFamily,
            icon: const Icon(
              Icons.cloud_sync_rounded,
              color: Color(0xFFFFD580),
              size: 22,
            ),
          ),
          IconButton(
            onPressed: _showHelpDialog,
            icon: Icon(
              Icons.help_outline_rounded,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleReindexFamily() async {
    final familyId = _currentFamily?.id ?? 1;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.primaryExtraDark,
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFD580)),
            ),
            SizedBox(width: 12),
            Text('Đang nạp dữ liệu Avatar thành viên vào AI...', style: TextStyle(fontSize: 13)),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    final res = await FaceRecognitionApiService.reindexFamily(familyId);
    if (!mounted) return;

    final msg = res['message'] ?? 'Đã hoàn tất đồng bộ khuôn mặt';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: res['success'] == true ? const Color(0xFF2E7D32) : AppColors.error,
        content: Text('✅ $msg', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ===========================================================================
  // 2. BANNER HƯỚNG DẪN
  // ===========================================================================
  Widget _buildInstructionBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEADBCE), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: Color(0xFFFFD580),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hướng dẫn',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Đưa khuôn mặt vào khung hình, giữ yên và nhìn thẳng vào camera để AI nhận diện tốt nhất.',
                  style: TextStyle(
                    color: AppColors.textSecondary.withOpacity(0.9),
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _showInstruction = false;
              });
            },
            child: const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. KHUNG CAMERA VIEWFINDER (CHUẨN TỶ LỆ - KHÔNG BỊ NÓP MÉO)
  // ===========================================================================
  Widget _buildCameraViewfinder() {
    final screenWidth = MediaQuery.of(context).size.width - 32;
    final boxHeight = (screenWidth * 0.75).clamp(230.0, 310.0);

    return GestureDetector(
      onTap: captureAndScan,
      child: Container(
        width: double.infinity,
        height: boxHeight,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Live Camera Feed hoặc Ảnh vừa chụp (Tự động cân đối tỷ lệ cảm biến không bị méo)
              Positioned.fill(
                child: _capturedImagePath != null
                    ? Image.file(
                        File(_capturedImagePath!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.black87,
                          child: const Center(
                            child: Icon(Icons.broken_image_rounded, color: Colors.white70, size: 48),
                          ),
                        ),
                      )
                    : _buildLiveCameraPreview(),
              ),

              // Top Status Badge: Live Camera hoặc Ảnh vừa chụp
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.25),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: _capturedImagePath != null
                              ? const Color(0xFFFFB74D) // Cam vàng
                              : const Color(0xFF4CAF50), // Xanh lá
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        _capturedImagePath != null
                            ? (_isScanning ? 'Đang phân tích ảnh...' : 'Ảnh vừa chụp')
                            : 'Hãy nhìn thẳng vào camera',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Nút Bật lại Camera (khi đang hiển thị ảnh vừa chụp)
              if (_capturedImagePath != null)
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: _resetToLiveCamera,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.videocam_rounded, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Bật Camera',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Face Target Frame (4 Góc bo trắng)
              Center(
                child: CustomPaint(
                  size: Size(screenWidth * 0.58, screenWidth * 0.58),
                  painter: RoundedTargetFramePainter(
                    color: Colors.white.withOpacity(0.9),
                    strokeWidth: 3.0,
                    cornerLength: 24.0,
                    radius: 16.0,
                  ),
                ),
              ),

              // Nút Thư viện ảnh ở góc dưới phải camera
              Positioned(
                bottom: 10,
                right: 10,
                child: GestureDetector(
                  onTap: _pickImageFromGallery,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: const Icon(
                      Icons.photo_library_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Hiển thị luồng Camera trực tiếp chuẩn tỷ lệ cảm biến (không bị méo hay giãn hình)
  Widget _buildLiveCameraPreview() {
    if (!_isCameraInitialized || _cameraController == null) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2C241E), Color(0xFF1E1712)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.camera_alt_outlined,
            size: 56,
            color: Colors.white.withOpacity(0.2),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Tỷ lệ khung hình thực của Camera (chiều rộng / chiều cao ở chế độ dọc)
        double sensorAspect = _cameraController!.value.aspectRatio;
        if (sensorAspect > 1.0) {
          sensorAspect = 1.0 / sensorAspect;
        }

        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            alignment: Alignment.center,
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxWidth / sensorAspect,
              child: CameraPreview(_cameraController!),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // 4. CỤM ĐIỀU KHIỂN & TRẠNG THÁI (KÈM NÚT CHỤP ẢNH LỚN)
  // ===========================================================================
  Widget _buildControlsAndStatusRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEADBCE), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Nút Đèn Flash
          _buildCircleActionButton(
            icon: _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
            label: 'Đèn flash',
            isActive: _isFlashOn,
            onTap: _toggleFlash,
          ),

          // Cụm Trạng Thái Nhận Diện ở giữa (Không còn nút chụp ở giữa)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _scanStatusText,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),

                // Animated Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(7, (index) {
                    final isHighlighted = index == _dotIndex && _isScanning;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      width: isHighlighted ? 6.5 : 4.5,
                      height: isHighlighted ? 6.5 : 4.5,
                      decoration: BoxDecoration(
                        color: isHighlighted
                            ? AppColors.primary
                            : (_isScanning
                                ? const Color(0xFFD4B89C)
                                : const Color(0xFFD4B89C).withOpacity(0.6)),
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 5),
                Text(
                  _isScanning
                      ? 'Vui lòng giữ yên trong giây lát'
                      : 'Bấm nút chụp bên dưới để nhận diện',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Nút Đổi Camera
          _buildCircleActionButton(
            icon: Icons.sync_rounded,
            label: 'Đổi camera',
            isActive: false,
            onTap: _switchCamera,
          ),
        ],
      ),
    );
  }

  Widget _buildCircleActionButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primaryGold.withOpacity(0.15)
                  : const Color(0xFFF3ECE4),
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? AppColors.primaryGold : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? AppColors.primaryGold : AppColors.textPrimary,
              size: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 5. TIÊU ĐỀ KẾT QUẢ / LỊCH SỬ
  // ===========================================================================
  Widget _buildSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(
              Icons.crop_free_rounded,
              size: 18,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              'Kết quả nhận diện',
              style: AppTextStyles.h3.copyWith(
                fontSize: 14.5,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: _showHistoryBottomSheet,
          child: Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                'Lịch sử nhận diện',
                style: AppTextStyles.bodySecondary.copyWith(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 6. CARD KẾT QUẢ PHÂN TÍCH
  // ===========================================================================
  Widget _buildAnalysisResultCard() {
    // Trường hợp 1: Đã nhận diện thành công thành viên
    if (_matchedMember != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEADBCE), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar thành viên
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.surfaceMuted,
                      backgroundImage: _matchedMember!.avatarUrl != null &&
                              _matchedMember!.avatarUrl!.isNotEmpty
                          ? NetworkImage(_matchedMember!.avatarUrl!)
                          : null,
                      child: _matchedMember!.avatarUrl == null ||
                              _matchedMember!.avatarUrl!.isEmpty
                          ? const Icon(Icons.person, size: 32, color: AppColors.textSecondary)
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: Color(0xFF28A745),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),

                // Thông tin thành viên
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              _matchedMember!.fullName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF81C784)),
                            ),
                            child: Text(
                              _matchedMember!.matchPercent,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildMiniBadge('Đời thứ ${_matchedMember!.generation}'),
                          const SizedBox(width: 6),
                          _buildMiniBadge(_matchedMember!.branchName),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Cha: ${_matchedMember!.fatherName} • Mẹ: ${_matchedMember!.motherName}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Nút Thao tác: Xem trên cây gia phả & Quét lại
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: OutlinedButton(
                      onPressed: _resetToLiveCamera,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.refresh_rounded, size: 16),
                            SizedBox(width: 4),
                            Text('Quét lại', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TreeScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.account_tree_rounded, size: 16),
                            SizedBox(width: 6),
                            Text('Xem cây phả hệ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Trường hợp 2: Không tìm thấy người trong gia phả hiện tại
    if (_noMatchFound) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEADBCE), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFFB74D), width: 1.5),
                  ),
                  child: const Icon(
                    Icons.person_search_rounded,
                    size: 28,
                    color: Color(0xFFE65100),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Không tìm thấy trong gia phả',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Khuôn mặt này chưa có trong dữ liệu thành viên ${_currentFamily?.name ?? "dòng họ"}.',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: OutlinedButton(
                      onPressed: _resetToLiveCamera,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.refresh_rounded, size: 16),
                            SizedBox(width: 4),
                            Text('Chụp lại', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: ElevatedButton(
                      onPressed: _handleReindexFamily,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGold,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_sync_rounded, size: 16),
                            SizedBox(width: 6),
                            Text('Đồng bộ Avatar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Trường hợp 3: Đang phân tích / Quét khuôn mặt (Đúng y hệt hình mẫu)
    final progressPercent = (_scanProgress * 100).toInt();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEADBCE), width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar Placeholder hình người màu be
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFFF3ECE4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  size: 34,
                  color: Color(0xFFD4B89C),
                ),
              ),
              const SizedBox(width: 14),

              // Text phân tích khuôn mặt
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isScanning
                          ? 'Đang phân tích khuôn mặt...'
                          : 'Sẵn sàng nhận diện',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _errorMessage != null
                          ? _errorMessage!
                          : 'Hệ thống AI đang đối chiếu với dữ liệu thành viên trong gia phả.',
                      style: TextStyle(
                        fontSize: 11,
                        color: _errorMessage != null
                            ? AppColors.error
                            : AppColors.textSecondary,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Thanh tiến trình phân tích % (như trong ảnh mẫu)
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _isScanning ? _scanProgress : 0.0,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFF0E6DC),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
              ),
              if (_isScanning) ...[
                const SizedBox(width: 10),
                Text(
                  '$progressPercent%',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 14),

          // Nút Chụp / Quét khuôn mặt lớn nổi bật
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _isScanning ? null : captureAndScan,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isScanning
                        ? Icons.hourglass_top_rounded
                        : Icons.camera_alt_rounded,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isScanning ? 'Đang phân tích...' : 'Chụp & Nhận diện ngay',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
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

  Widget _buildMiniBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF3ECE4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10.5,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lightbulb_outline_rounded, color: AppColors.primaryGold),
            SizedBox(width: 8),
            Text('Mẹo nhận diện AI', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: const Text(
          '1. Giữ điện thoại ngang tầm mắt, cách 30-50cm.\n'
          '2. Tránh ngược sáng mạnh hoặc bóng đổ trên mặt.\n'
          '3. Nếu chụp ảnh nhóm, hệ thống sẽ cho bạn chạm chọn người cần tìm.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đã hiểu', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _showHistoryBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.history_rounded, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'Lịch sử nhận diện gần đây',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_latestResult != null && _latestResult!.matches.isNotEmpty) ...[
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _latestResult!.matches.length,
                itemBuilder: (ctx, i) {
                  final m = _latestResult!.matches[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.surfaceMuted,
                      backgroundImage: m.avatarUrl != null && m.avatarUrl!.isNotEmpty
                          ? NetworkImage(m.avatarUrl!)
                          : null,
                      child: m.avatarUrl == null || m.avatarUrl!.isEmpty
                          ? const Icon(Icons.person, color: AppColors.textSecondary)
                          : null,
                    ),
                    title: Text(
                      m.fullName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text('Đời thứ ${m.generation} • ${m.branchName}', style: const TextStyle(fontSize: 12)),
                    trailing: Text(
                      m.matchPercent,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  );
                },
              ),
            ] else ...[
              const Text(
                'Chưa có lịch sử nhận diện nào trước đó.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

/// CustomPainter vẽ 4 góc bo trắng (Target Brackets) định vị khuôn mặt
class RoundedTargetFramePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double cornerLength;
  final double radius;

  RoundedTargetFramePainter({
    required this.color,
    required this.strokeWidth,
    required this.cornerLength,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final r = radius;
    final cl = cornerLength;

    // 1. Góc trên - trái
    final pathTopLeft = Path()
      ..moveTo(0, cl)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(cl, 0);
    canvas.drawPath(pathTopLeft, paint);

    // 2. Góc trên - phải
    final pathTopRight = Path()
      ..moveTo(w - cl, 0)
      ..lineTo(w - r, 0)
      ..quadraticBezierTo(w, 0, w, r)
      ..lineTo(w, cl);
    canvas.drawPath(pathTopRight, paint);

    // 3. Góc dưới - trái
    final pathBottomLeft = Path()
      ..moveTo(0, h - cl)
      ..lineTo(0, h - r)
      ..quadraticBezierTo(0, h, r, h)
      ..lineTo(cl, h);
    canvas.drawPath(pathBottomLeft, paint);

    // 4. Góc dưới - phải
    final pathBottomRight = Path()
      ..moveTo(w - cl, h)
      ..lineTo(w - r, h)
      ..quadraticBezierTo(w, h, w, h - r)
      ..lineTo(w, h - cl);
    canvas.drawPath(pathBottomRight, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
