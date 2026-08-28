/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfhawk/data/res/constants.dart';
import 'package:pdfhawk/data/res/theme.dart';
import 'package:pdfhawk/data/res/utils.dart';
import 'package:pdfhawk/interface/home_page.dart';
import 'package:pdfhawk/logic/services/folder_storage_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class OnboardingPage extends StatefulWidget {
  final bool isReviewMode;
  const OnboardingPage({super.key, this.isReviewMode = false});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 4;
  // Permission states
  bool _hasCameraPermission = false;
  bool _hasStoragePermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionStatuses();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissionStatuses() async {
    try {
      final cameraStatus = await Permission.camera.status;
      final bool cameraGranted =
          cameraStatus.isGranted || cameraStatus.isLimited;

      final bool storageGranted =
          await FolderStorageService.isStoragePermissionGranted();

      if (mounted) {
        setState(() {
          _hasCameraPermission = cameraGranted;
          _hasStoragePermission = storageGranted;
        });
      }
    } catch (_) {}
  }

  Future<void> _requestCameraPermission() async {
    try {
      final res = await Permission.camera.request();
      if (mounted) {
        setState(() {
          _hasCameraPermission = res.isGranted || res.isLimited;
        });
      }
      if (res.isPermanentlyDenied) {
        plainToast(msg: "Please grant Camera permission in Device Settings");
        await openAppSettings();
      }
    } catch (_) {}
    await _checkPermissionStatuses();
  }

  Future<void> _requestStoragePermission() async {
    try {
      final granted = await FolderStorageService.ensureStoragePermission();
      if (Platform.isAndroid || Platform.isIOS) {
        try {
          await Permission.photos.request();
          await PhotoManager.requestPermissionExtend();
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _hasStoragePermission = granted;
        });
      }
      if (!granted && Platform.isAndroid) {
        plainToast(msg: "Please grant All Files Access to manage PDFs");
      }
    } catch (_) {}
    await _checkPermissionStatuses();
  }

  Future<void> _requestAllPermissionsAndFinish() async {
    // Trigger all remaining permission requests sequentially if needed
    if (!_hasCameraPermission) {
      await _requestCameraPermission();
    }
    if (!_hasStoragePermission) {
      await _requestStoragePermission();
    }

    // Save completion flag in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_onboarding', true);

    if (!mounted) return;

    if (widget.isReviewMode) {
      Navigator.pop(context);
      plainToast(msg: "Permissions updated!");
    } else {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const HomePage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _requestAllPermissionsAndFinish();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse('https://novaturients.in/community/pdfhawk/policy');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      plainToast(msg: "Unable to open link");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F10) : white,
      appBar: AppBar(
        toolbarHeight: 0,
        elevation: 0,
        backgroundColor: Colors.transparent,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Main PageView Slides
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                  if (index == _totalPages - 1) {
                    _checkPermissionStatuses();
                  }
                },
                children: [
                  _buildWelcomeSlide(isDark, primaryColor),
                  _buildReaderAndWriterSlide(isDark, primaryColor),
                  _buildScannerAndToolsSlide(isDark, primaryColor),
                  _buildPermissionsSlide(isDark, primaryColor),
                ],
              ),
            ),
            // if (_currentPage != _totalPages - 1)
            // Bottom Action & Dots Bar
            _buildBottomControls(isDark, primaryColor),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // SLIDE 1: Welcome & Value Proposition
  // ==========================================
  Widget _buildWelcomeSlide(bool isDark, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(),
          // Hero Illustration Card
          SizedBox(
            height: 360.h,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: allradius(28.r),
              child: SvgPicture.asset(
                'assets/illustration/illt_0.svg',
                fit: BoxFit.contain,
              ),
            ),
          ),

          // Key Highlights Chips Grid
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 2,
                runSpacing: 5,
                alignment: WrapAlignment.start,
                children: [
                  _buildFeatureChip("📄 PDF Reader", isDark),
                  _buildFeatureChip("✍️ Writing", isDark),
                  _buildFeatureChip("📸 Scanner", isDark),
                  _buildFeatureChip("⚡ Split", isDark),
                  _buildFeatureChip("⚡ Merge", isDark),
                  _buildFeatureChip("⚡ Compress", isDark),
                  _buildFeatureChip("⚡ Convert", isDark),
                ],
              ),
              const Gap(10),
              // Title & Subtitle
              Text(
                "Everything You\nMight Need!",
                textAlign: TextAlign.left,
                style: GoogleFonts.alata(
                  fontSize: 32.sp,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                  height: 1.15,
                  letterSpacing: -0.5,
                ),
              ),
              Gap(5),
              Text(
                "Read, write, edit, scan, convert, split, and merge PDFs with total privacy. All processing runs directly on your device processor.",
                textAlign: TextAlign.left,
                style: GoogleFonts.instrumentSans(
                  fontSize: 12.sp,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SLIDE 2: Reader, Writer & Studio
  // ==========================================
  Widget _buildReaderAndWriterSlide(bool isDark, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(),
          // Studio Preview Card
          // Hero Illustration Card
          SizedBox(
            width: double.infinity,
            height: 360.h,

            child: ClipRRect(
              borderRadius: allradius(28.r),
              child: SvgPicture.asset(
                'assets/illustration/illt_1.svg',
                fit: BoxFit.contain,
              ),
            ),
          ),

          // Key Highlights Chips Grid
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 2,
                runSpacing: 5,
                alignment: WrapAlignment.start,
                children: [
                  _buildFeatureChip("✍️ Rich Text", isDark),
                  _buildFeatureChip("✏️ Handwriting", isDark),
                  _buildFeatureChip("🎨 Stylus & Shapes", isDark),
                  _buildFeatureChip("🖋️ Signatures", isDark),
                  _buildFeatureChip("🔒 .hawk Drafts", isDark),
                  _buildFeatureChip("🌓 Dark Mode", isDark),
                ],
              ),
              const Gap(10),
              // Title & Subtitle
              Text(
                "Read, Write &\nAnnotate PDFs",
                textAlign: TextAlign.left,
                style: GoogleFonts.alata(
                  fontSize: 32.sp,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                  height: 1.15,
                  letterSpacing: -0.5,
                ),
              ),
              Gap(5),
              Text(
                "Enjoy ultra-smooth PDF reading with dark mode inversion, or create brand-new documents with rich text, signatures, and custom watermarks.",
                textAlign: TextAlign.left,
                style: GoogleFonts.instrumentSans(
                  fontSize: 12.sp,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SLIDE 3: Scanner & Swiss-Army Tools
  // ==========================================
  Widget _buildScannerAndToolsSlide(bool isDark, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(),
          // Hero Illustration Card
          SizedBox(
            width: double.infinity,
            height: 360.h,
            child: ClipRRect(
              borderRadius: allradius(28.r),
              child: SvgPicture.asset(
                'assets/illustration/illt_2.svg',
                fit: BoxFit.contain,
              ),
            ),
          ),

          // Key Highlights Chips Grid
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 2,
                runSpacing: 5,
                alignment: WrapAlignment.start,
                children: [
                  _buildFeatureChip("📐 Level Assist", isDark),
                  _buildFeatureChip("🖼️ Image to PDF", isDark),
                  _buildFeatureChip("📑 PDF to Image", isDark),
                  _buildFeatureChip("✂️ Split Pages", isDark),
                  _buildFeatureChip("🔗 Merge Multiple", isDark),
                  _buildFeatureChip("🔄 Reorder", isDark),
                ],
              ),
              const Gap(10),
              // Title & Subtitle
              Text(
                "Precision Scanner\nAnd Converter",
                textAlign: TextAlign.left,
                style: GoogleFonts.alata(
                  fontSize: 32.sp,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                  height: 1.15,
                  letterSpacing: -0.5,
                ),
              ),
              Gap(5),
              Text(
                "Scan paper documents with real-time tilt assistance, convert gallery photos to PDFs, split multi-page documents, and merge multiple files in seconds.",
                textAlign: TextAlign.left,
                style: GoogleFonts.instrumentSans(
                  fontSize: 12.sp,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SLIDE 4: Interactive Permissions Setup
  // ==========================================
  Widget _buildPermissionsSlide(bool isDark, Color primaryColor) {
    double h = getHeight(context);
    double w = getWidth(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            top: 0,
            child: SizedBox(
              height: 350,
              child: Image.asset('assets/src/logo.png'),
            ),
          ),

          SizedBox(
            height: h / 2.1,
            width: w,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Just one last step,\nSetup App Permissions",
                      textAlign: TextAlign.left,
                      style: GoogleFonts.alata(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        fontSize: 25.sp,
                        height: 1.15,
                      ),
                    ),
                    Gap(5),
                    Text(
                      "To enable all features, PDF Hawk requires the following permissions. Your files never leave this device.",
                      textAlign: TextAlign.left,
                      style: GoogleFonts.instrumentSans(
                        fontSize: 12.sp,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                        height: 1.45,
                      ),
                    ),
                    Gap(8),
                    InkWell(
                      onTap: _openPrivacyPolicy,
                      child: Text(
                        "Read Terms of Service & Privacy Policy ↗",
                        style: GoogleFonts.instrumentSans(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: primaryColor,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                Gap(30),
                // Permission Tile 1: Camera
                Column(
                  children: [
                    _buildPermissionActionCard(
                      title: "Camera Access",
                      description:
                          "Required to capture and scan physical documents, notes, and receipts.",
                      icon: Icons.camera_alt_outlined,
                      isGranted: _hasCameraPermission,
                      onGrant: _requestCameraPermission,
                      isDark: isDark,
                      primaryColor: primaryColor,
                    ),
                    Gap(10.h),
                    // Permission Tile 2: Files & Storage Management
                    _buildPermissionActionCard(
                      title: "Files & Storage Access",
                      description:
                          "Required to open, organize, import photos, and save PDFs across your folders.",
                      icon: Icons.folder_shared_outlined,
                      isGranted: _hasStoragePermission,
                      onGrant: _requestStoragePermission,
                      isDark: isDark,
                      primaryColor: primaryColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // HELPER WIDGETS
  // ==========================================

  Widget _buildPermissionActionCard({
    required String title,
    required String description,
    required IconData icon,
    required bool isGranted,
    required VoidCallback onGrant,
    required bool isDark,
    required Color primaryColor,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Container
          SizedBox.square(
            dimension: 42,
            child: Center(
              child: Icon(icon, color: primaryColor, size: 30.sp),
            ),
          ),
          Gap(12.w),
          // Texts
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.instrumentSans(
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Gap(2.h),
                Text(
                  description,
                  style: GoogleFonts.instrumentSans(
                    fontSize: 10.8.sp,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          Gap(8.w),
          // Action Button / Status Badge
          if (isGranted)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: allradius(6),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_rounded, color: Colors.green, size: 14.sp),
                  Gap(4.w),
                  Text(
                    "Granted",
                    style: GoogleFonts.instrumentSans(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            )
          else
            ElevatedButton(
              onPressed: onGrant,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: isDark ? Colors.black : Colors.white,
                elevation: 0,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                shape: RoundedRectangleBorder(borderRadius: allradius(6)),
              ),
              child: Text(
                "Grant",
                style: GoogleFonts.instrumentSans(
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(String label, bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF0F2F5),
        borderRadius: allradius(14.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.instrumentSans(
          fontSize: 10.sp,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
        ),
      ),
    );
  }

  // ==========================================
  // BOTTOM BAR: Dots & Action Buttons
  // ==========================================
  Widget _buildBottomControls(bool isDark, Color primaryColor) {
    final bool isLastPage = _currentPage == _totalPages - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Dots Indicator
          Row(
            children: List.generate(
              _totalPages,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: EdgeInsets.only(right: 6.w),
                width: _currentPage == index ? 24.w : 7.w,
                height: 7.h,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? primaryColor
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.2)
                            : Colors.black.withValues(alpha: 0.15)),
                  borderRadius: allradius(4.r),
                ),
              ),
            ),
          ),

          // Action Button (Next or Get Started)
          Row(
            children: [
              if (_currentPage != 0) ...[
                InkWell(
                  onTap: _prevPage,
                  borderRadius: allradius(100),
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_back,
                      size: 22.sp,
                      color: isDark ? Colors.black : Colors.white,
                    ),
                  ),
                ),
                Gap(10),
              ],

              InkWell(
                onTap: _nextPage,
                borderRadius: allradius(100),
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isLastPage ? Icons.check : Icons.arrow_forward_rounded,
                    size: 22.sp,
                    color: isDark ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
