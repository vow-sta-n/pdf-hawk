/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:io';
import 'package:community_material_icon/community_material_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfhawk/data/res/constants.dart';
import 'package:pdfhawk/data/res/utils.dart';
import 'package:pdfhawk/interface/home_page.dart';
import 'package:pdfhawk/logic/services/folder_storage_service.dart';
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
      backgroundColor: isDark
          ? const Color(0xFF0F0F10)
          : const Color(0xFFFAFAFC),
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
          // Hero Illustration / Stylized Badge Card
          Container(
            width: double.infinity,
            height: 240.h,
            padding: EdgeInsets.all(20.r),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        primaryColor.withValues(alpha: 0.25),
                        const Color(0xFF1E1E24),
                        const Color(0xFF141416),
                      ]
                    : [
                        primaryColor.withValues(alpha: 0.18),
                        Colors.white,
                        const Color(0xFFF0F4FF),
                      ],
              ),
              borderRadius: allradius(28.r),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : primaryColor.withValues(alpha: 0.15),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Floating Decorative Badge 1: 100% Offline
                Positioned(
                  top: 10.h,
                  left: 8.w,
                  child: _buildFloatingBadge(
                    icon: Icons.cloud_off_rounded,
                    label: "100% Offline",
                    isDark: isDark,
                  ),
                ),
                // Floating Decorative Badge 2: Local Processing
                Positioned(
                  top: 18.h,
                  right: 8.w,
                  child: _buildFloatingBadge(
                    icon: Icons.shield_rounded,
                    label: "Zero Cloud Uploads",
                    isDark: isDark,
                  ),
                ),
                // Central App Logo & Hawk Emblem
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 88.r,
                      height: 88.r,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF222228) : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.4 : 0.1,
                            ),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          CommunityMaterialIcons.file_document_edit_outline,
                          size: 44.sp,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    Gap(12.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.15),
                        borderRadius: allradius(12.r),
                      ),
                      child: Text(
                        "PDF STUDIO SUITE",
                        style: GoogleFonts.instrumentSans(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w800,
                          color: primaryColor,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                // Floating Decorative Badge 3: Fast & Native
                Positioned(
                  bottom: 8.h,
                  child: _buildFloatingBadge(
                    icon: Icons.bolt_rounded,
                    label: "Blazing Fast Hardware Engine",
                    isDark: isDark,
                  ),
                ),
              ],
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
              Gap(20),
              // Title & Subtitle
              Text(
                "Your Complete Offline PDF Tools",
                textAlign: TextAlign.left,
                style: GoogleFonts.outfit(
                  fontSize: 36.sp,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                  height: 1.15,
                  letterSpacing: -0.5,
                ),
              ),
              Gap(10.h),
              Text(
                "Read, write, edit, scan, convert, split, and merge PDFs with total privacy. All processing runs directly on your device processor.",
                textAlign: TextAlign.left,
                style: GoogleFonts.instrumentSans(
                  fontSize: 13.5.sp,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  height: 1.45,
                ),
              ),
              Gap(40),
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
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A20) : Colors.white,
              borderRadius: allradius(24.r),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mock Document Canvas Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.edit_note_rounded,
                          color: primaryColor,
                          size: 20.sp,
                        ),
                        Gap(6.w),
                        Text(
                          "Document Studio (.hawk)",
                          style: GoogleFonts.instrumentSans(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 3.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: allradius(8.r),
                      ),
                      child: Text(
                        "Auto-Saved",
                        style: GoogleFonts.instrumentSans(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
                Gap(12.h),
                // Mock Document Features Showcase
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 12.h,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF121214)
                        : const Color(0xFFF7F8FA),
                    borderRadius: allradius(16.r),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStudioMockRow(
                        icon: Icons.format_bold_rounded,
                        title: "Rich Text Formatting",
                        subtitle:
                            "Headings, lists, colors, highlights & custom fonts",
                        isDark: isDark,
                      ),
                      Gap(10.h),
                      _buildStudioMockRow(
                        icon: Icons.draw_rounded,
                        title: "Stylus & Handwriting",
                        subtitle:
                            "Freehand drawing, shapes, watermarks & signatures",
                        isDark: isDark,
                      ),
                      Gap(10.h),
                      _buildStudioMockRow(
                        icon: Icons.lock_outline_rounded,
                        title: "Encrypted .hawk Drafts",
                        subtitle:
                            "Proprietary offline encrypted document storage",
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ],
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
              const Gap(20),
              // Title & Subtitle
              Text(
                "Read, Write & Annotate PDFs",
                textAlign: TextAlign.left,
                style: GoogleFonts.outfit(
                  fontSize: 36.sp,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                  height: 1.15,
                  letterSpacing: -0.5,
                ),
              ),
              Gap(10.h),
              Text(
                "Enjoy ultra-smooth PDF reading with dark mode inversion, or create brand-new documents with rich text, signatures, and custom watermarks.",
                textAlign: TextAlign.left,
                style: GoogleFonts.instrumentSans(
                  fontSize: 13.5.sp,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  height: 1.45,
                ),
              ),
              const Gap(40),
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
          // Tools Preview Grid Card
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A20) : Colors.white,
              borderRadius: allradius(24.r),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Swiss-Army PDF Toolkit",
                      style: GoogleFonts.instrumentSans(
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 3.h,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.15),
                        borderRadius: allradius(8.r),
                      ),
                      child: Text(
                        "Zero Quality Loss",
                        style: GoogleFonts.instrumentSans(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                Gap(12.h),
                Row(
                  children: [
                    Expanded(
                      child: _buildToolTile(
                        icon: Icons.document_scanner_rounded,
                        title: "Smart Scanner",
                        subtitle: "Level gauge assist",
                        isDark: isDark,
                        primaryColor: primaryColor,
                      ),
                    ),
                    Gap(10.w),
                    Expanded(
                      child: _buildToolTile(
                        icon: Icons.image_rounded,
                        title: "Image ↔ PDF",
                        subtitle: "Two-way convert",
                        isDark: isDark,
                        primaryColor: primaryColor,
                      ),
                    ),
                  ],
                ),
                Gap(10.h),
                Row(
                  children: [
                    Expanded(
                      child: _buildToolTile(
                        icon: Icons.call_split_rounded,
                        title: "Split PDF",
                        subtitle: "Extract pages",
                        isDark: isDark,
                        primaryColor: primaryColor,
                      ),
                    ),
                    Gap(10.w),
                    Expanded(
                      child: _buildToolTile(
                        icon: Icons.merge_type_rounded,
                        title: "Merge PDFs",
                        subtitle: "Combine multiple",
                        isDark: isDark,
                        primaryColor: primaryColor,
                      ),
                    ),
                  ],
                ),
              ],
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
              const Gap(20),
              // Title & Subtitle
              Text(
                "Precision Scanner & Converters",
                textAlign: TextAlign.left,
                style: GoogleFonts.outfit(
                  fontSize: 36.sp,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                  height: 1.15,
                  letterSpacing: -0.5,
                ),
              ),
              Gap(10.h),
              Text(
                "Scan paper documents with real-time tilt assistance, convert gallery photos to PDFs, split multi-page documents, and merge multiple files in seconds.",
                textAlign: TextAlign.left,
                style: GoogleFonts.instrumentSans(
                  fontSize: 13.5.sp,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  height: 1.45,
                ),
              ),
              const Gap(40),
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
                      style: GoogleFonts.outfit(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        fontSize: 25.sp,
                        height: 1.2,
                      ),
                    ),
                    Gap(10.h),
                    Text(
                      "To enable all features, PDF Hawk requires the following permissions. Your files never leave this device.",
                      textAlign: TextAlign.left,
                      style: GoogleFonts.instrumentSans(
                        fontSize: 13.sp,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                        height: 1.4,
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

  Widget _buildFloatingBadge({
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF22222A).withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: allradius(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13.sp,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
          Gap(5.w),
          Text(
            label,
            style: GoogleFonts.instrumentSans(
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
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

  Widget _buildStudioMockRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(6.r),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 16.sp,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        Gap(10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.instrumentSans(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.instrumentSans(
                  fontSize: 10.sp,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
    required Color primaryColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141416) : const Color(0xFFF7F8FA),
        borderRadius: allradius(14.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: primaryColor, size: 20.sp),
          Gap(8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.instrumentSans(
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.instrumentSans(
                    fontSize: 9.5.sp,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
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


 // Privacy Policy & Terms Acknowledgment Box
                // Padding(
                //   padding: const EdgeInsets.only(bottom: 30),
                //   child: Row(
                //     mainAxisSize: MainAxisSize.max,
                //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //     children: [
                //       InkWell(
                //         onTap: _prevPage,
                //         child: Container(
                //           height: 45,
                //           padding: EdgeInsets.symmetric(horizontal: 10),
                //           decoration: BoxDecoration(
                //             color: isDark ? white : black,
                //             border: Border.all(
                //               color: isDark ? white : black,
                //               width: 2,
                //             ),
                //             borderRadius: allradius(6),
                //           ),
                //           child: Center(
                //             child: Icon(
                //               Icons.arrow_back_ios_new_rounded,
                //               color: isDark ? black : white,
                //             ),
                //           ),
                //         ),
                //       ),
                //       InkWell(
                //         onTap: _nextPage,
                //         child: Container(
                //           height: 45,
                //           width: getWidth(context) / 1.3,
                //           decoration: BoxDecoration(
                //             color: isDark ? white : black,
                //             border: Border.all(
                //               color: isDark ? white : black,
                //               width: 2,
                //             ),
                //             borderRadius: allradius(6),
                //           ),
                //           child: Center(
                //             child: Text(
                //               'Continue',
                //               style: GoogleFonts.lato(
                //                 height: 1,
                //                 fontSize: 14.sp,
                //                 color: isDark ? black : white,
                //                 fontWeight: FontWeight.w600,
                //               ),
                //             ),
                //           ),
                //         ),
                //       ),
                //     ],
                //   ),
                // ),

 // InkWell(
              //   onTap: _prevPage,
              //   child: Container(
              //     height: 45,
              //     padding: EdgeInsets.symmetric(horizontal: 10),
              //     decoration: BoxDecoration(
              //       color: isDark ? white : black,
              //       border: Border.all(color: isDark ? white : black, width: 2),
              //       borderRadius: allradius(6),
              //     ),
              //     child: Center(
              //       child: Icon(
              //         Icons.arrow_back_ios_new_rounded,
              //         color: isDark ? black : white,
              //       ),
              //     ),
              //   ),
              // ),

              // InkWell(
              //   onTap: _nextPage,
              //   child: Container(
              //     height: 45,
              //     width: getWidth(context) / 1.3,
              //     decoration: BoxDecoration(
              //       color: isDark ? white : black,
              //       border: Border.all(color: isDark ? white : black, width: 2),
              //       borderRadius: allradius(6),
              //     ),
              //     child: Center(
              //       child: Text(
              //         'Continue',
              //         style: GoogleFonts.lato(
              //           height: 1,
              //           fontSize: 14.sp,
              //           color: isDark ? black : white,
              //           fontWeight: FontWeight.w600,
              //         ),
              //       ),
              //     ),
              //   ),
              // ),