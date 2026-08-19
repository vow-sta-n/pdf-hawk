/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:io';
import 'package:community_material_icon/community_material_icon.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfhawk/data/gen/setting.dart';
import 'package:pdfhawk/data/res/theme.dart';
import 'package:pdfhawk/interface/widgets/circular_color_chip.dart';
import 'package:pdfhawk/logic/helpers/hive_box_handler.dart';
import 'package:pdfhawk/logic/services/folder_storage_service.dart';
import 'package:pdfhawk/logic/services/storage_service.dart';
import 'package:pdfhawk/main.dart';
import 'package:pdfhawk/data/res/constants.dart';
import 'package:pdfhawk/data/res/utils.dart';
import 'package:pdfhawk/data/res/variables.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  final dynamic onRefresh;
  final dynamic all;
  final dynamic selected;
  final bool isFactory;
  final bool comp;
  final Function(int hj, bool cls)? onUpdateCompare;
  final BuildContext? ctx;
  const SettingsPage({
    super.key,
    this.onRefresh,
    this.comp = false,
    this.ctx,
    this.all,
    this.selected,
    this.isFactory = false,
    this.onUpdateCompare,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final hive = HiveBoxHandler.getConfigBox();
  bool kc = false;
  bool kl = false;
  int ti = 0;
  int ni = 0;
  List them = [
    'System Default(Theme)',
    'Enable Light Mode',
    'Enable Dark Mode',
  ];

  String? _customPdfSaveDir;
  String? _customHawkSaveDir;

  @override
  void initState() {
    super.initState();
    _updateTiFromThemeNotifier();
    themeNotifier.addListener(_onThemeNotifierChanged);
    if (hive.isNotEmpty) {
      final box = hive.getAt(0);
      if (box != null) {
        ci = box.kcolor;
      }
    }
    _loadCustomSaveDirectories();
  }

  Future<void> _loadCustomSaveDirectories() async {
    final pdfDir = await StorageService.getCustomPdfSaveDirectory();
    final hawkDir = await StorageService.getCustomHawkSaveDirectory();
    if (mounted) {
      setState(() {
        _customPdfSaveDir = pdfDir;
        _customHawkSaveDir = hawkDir;
      });
    }
  }

  Future<void> _pickCustomPdfDirectory() async {
    try {
      if (Platform.isAndroid) {
        await FolderStorageService.ensureStoragePermission();
      }
      final selectedPath = await FilePicker.platform.getDirectoryPath();
      if (selectedPath == null || selectedPath.isEmpty) return;

      await StorageService.setCustomPdfSaveDirectory(selectedPath);
      await _loadCustomSaveDirectories();
      plainToast(msg: "Modified PDFs save location updated!");
    } catch (e) {
      plainToast(msg: "Error selecting folder: $e");
    }
  }

  Future<void> _resetCustomPdfDirectory() async {
    await StorageService.setCustomPdfSaveDirectory(null);
    await _loadCustomSaveDirectories();
    plainToast(msg: "Reset to default PDF save location");
  }

  Future<void> _pickCustomHawkDirectory() async {
    try {
      if (Platform.isAndroid) {
        await FolderStorageService.ensureStoragePermission();
      }
      final selectedPath = await FilePicker.platform.getDirectoryPath();
      if (selectedPath == null || selectedPath.isEmpty) return;

      await StorageService.setCustomHawkSaveDirectory(selectedPath);
      await _loadCustomSaveDirectories();
      plainToast(msg: "Hawk documents save location updated!");
    } catch (e) {
      plainToast(msg: "Error selecting folder: $e");
    }
  }

  Future<void> _resetCustomHawkDirectory() async {
    await StorageService.setCustomHawkSaveDirectory(null);
    await _loadCustomSaveDirectories();
    plainToast(msg: "Reset to default Hawk save location");
  }

  void _updateTiFromThemeNotifier() {
    final currentMode = themeNotifier.value;
    if (currentMode == ThemeMode.system) {
      ti = 0;
    } else if (currentMode == ThemeMode.light) {
      ti = 1;
    } else if (currentMode == ThemeMode.dark) {
      ti = 2;
    }
  }

  void _onThemeNotifierChanged() {
    if (mounted) {
      setState(() {
        _updateTiFromThemeNotifier();
      });
    }
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeNotifierChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final double w = getWidth(context);

    return Material(
      color: transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: EdgeInsets.only(right: 15.w, bottom: 8.h),
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(25.r),
              child: Container(
                width: 46.r,
                height: 46.r,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.3 : 0.08,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.06),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.close_rounded,
                    color: isDark ? Colors.white : Colors.black87,
                    size: 24.sp,
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: w,
            padding: EdgeInsets.all(16.r),
            margin: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: allradius(16.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.80,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Settings',
                          style: GoogleFonts.instrumentSans(
                            fontSize: 30.sp,
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    Gap(18.h),

                    // Section: Save Locations
                    Text(
                      'Save Locations',
                      style: GoogleFonts.instrumentSans(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Gap(4.h),
                    Text(
                      'Choose custom folders for saving modified PDFs and auto-saved .hawk documents separately.',
                      style: GoogleFonts.instrumentSans(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        fontSize: 12.sp,
                      ),
                    ),
                    Gap(12.h),

                    // Card 1: Modified PDFs Save Location
                    _buildSaveLocationTile(
                      title: "Modified & Exported PDFs",
                      subtitle: "Where edited, converted, split, and merged PDFs are saved",
                      customPath: _customPdfSaveDir,
                      defaultPathLabel: "Default: Documents/PDFHawk",
                      icon: Icons.picture_as_pdf_rounded,
                      onChoose: _pickCustomPdfDirectory,
                      onReset: _resetCustomPdfDirectory,
                      isDark: isDark,
                      theme: theme,
                    ),

                    // Card 2: Hawk Documents Save Location
                    _buildSaveLocationTile(
                      title: "Auto-saved Documents (.hawk)",
                      subtitle: "Where created documents and workspace drafts (.hawk) are saved",
                      customPath: _customHawkSaveDir,
                      defaultPathLabel: "Default: Documents/PDFHawk/HawkDocuments",
                      icon: Icons.edit_document,
                      onChoose: _pickCustomHawkDirectory,
                      onReset: _resetCustomHawkDirectory,
                      isDark: isDark,
                      theme: theme,
                    ),

                    Gap(10.h),

                    // Section: Set Primary Color
                    Padding(
                      padding: EdgeInsets.only(left: 2.w, bottom: 16.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            'Set Primary Color',
                            style: GoogleFonts.instrumentSans(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Gap(10.h),
                          SizedBox(
                            height: 45.h,
                            width: w,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: color.length,
                              padding: EdgeInsets.zero,
                              itemBuilder: (context, index) {
                                final bool isSelected = ci == index;
                                return InkWell(
                                  borderRadius: BorderRadius.circular(20.r),
                                  onTap: () {
                                    setState(() {
                                      ci = index;
                                    });
                                    updatePrimaryColor(index);
                                    if (hive.isNotEmpty) {
                                      final box = hive.getAt(0);
                                      if (box != null) {
                                        box.kcolor = ci;
                                        box.save();
                                      }
                                    } else {
                                      hive.add(
                                        SettingBox()
                                          ..theme = ti
                                          ..kcolor = ci,
                                      );
                                    }
                                    plainToast(msg: 'Primary theme color updated!');
                                  },
                                  child: CircularColorChip(
                                    height: 40.r,
                                    elevation: 1.2,
                                    width: 40.r,
                                    margin: EdgeInsets.only(right: 8.w),
                                    color: color[index],
                                    shape: BoxShape.circle,
                                    border: isSelected
                                        ? Border.all(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                            width: 2.5,
                                            style: BorderStyle.solid,
                                          )
                                        : null,
                                    child: isSelected
                                        ? Center(
                                            child: Icon(
                                              Icons.check_rounded,
                                              size: 20.sp,
                                              color:
                                                  ThemeData.estimateBrightnessForColor(
                                                        color[index],
                                                      ) ==
                                                      Brightness.dark
                                                      ? Colors.white
                                                      : Colors.black87,
                                            ),
                                          )
                                        : const SizedBox(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    Gap(4.h),

                    // Share App button
                    settingsButton(
                      title: 'Share App',
                      icon: Icons.share_rounded,
                      onTap: _shareApp,
                      isDark: isDark,
                    ),
                    Gap(16.h),

                    // Footer Row: Know More, GitHub, PolyForm License
                    Row(
                      children: [
                        InkWell(
                          onTap: () => openExternalLink(
                            context,
                            'https://www.novaturients.in',
                          ),
                          borderRadius: allradius(30.r),
                          child: Container(
                            height: 38.h,
                            padding: EdgeInsets.symmetric(horizontal: 14.w),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E1E1E),
                              borderRadius: allradius(30.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Know More',
                                  style: GoogleFonts.lato(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.black : Colors.white,
                                  ),
                                ),
                                Gap(4.w),
                                Icon(
                                  Icons.arrow_outward_outlined,
                                  size: 14.sp,
                                  color: isDark ? Colors.black : Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Gap(10.w),
                        // GitHub Button
                        InkWell(
                          onTap: () => openExternalLink(
                            context,
                            'https://github.com/vow-sta-n/pdf-hawk',
                          ),
                          borderRadius: allradius(30.r),
                          child: Container(
                            height: 38.h,
                            padding: EdgeInsets.symmetric(horizontal: 14.w),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E1E1E),
                              borderRadius: allradius(30.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CommunityMaterialIcons.github,
                                  size: 19.sp,
                                  color: isDark ? Colors.black : Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Gap(8.w),
                        // PolyForm License & Owner Info
                        Expanded(
                          child: InkWell(
                            onTap: () => openExternalLink(
                              context,
                              'https://polyformproject.org/licenses/noncommercial/1.0.0/',
                            ),
                            borderRadius: allradius(30.r),
                            child: Container(
                              height: 38.h,
                              padding: EdgeInsets.symmetric(horizontal: 8.w),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.05),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.15)
                                      : Colors.black.withValues(alpha: 0.12),
                                ),
                                borderRadius: allradius(30.r),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    CommunityMaterialIcons.scale_balance,
                                    size: 16.sp,
                                    color: isDark ? signalwhite : Colors.black87,
                                  ),
                                  Gap(6.w),
                                  Flexible(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'PolyForm License',
                                          style: GoogleFonts.lato(
                                            fontSize: 10.5.sp,
                                            fontWeight: FontWeight.w700,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                            height: 1.1,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '© 2026 Novaturients',
                                          style: GoogleFonts.lato(
                                            fontSize: 8.sp,
                                            fontWeight: FontWeight.w400,
                                            color: isDark
                                                ? signalwhite.withValues(alpha: 0.7)
                                                : Colors.black54,
                                            height: 1.1,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: 16.h, bottom: 6.h),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          InkWell(
                            onTap: () => openExternalLink(
                              context,
                              'https://novaturients.in/community/pdfhawk/policy',
                            ),
                            child: Text(
                              'Terms & Conditions',
                              style: GoogleFonts.lato(
                                fontSize: 12.5.sp,
                                color: isDark
                                    ? signalwhite.withValues(alpha: 0.8)
                                    : Colors.black54,
                                decoration: TextDecoration.underline,
                                decorationColor: isDark
                                    ? signalwhite.withValues(alpha: 0.8)
                                    : Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12.w),
                            child: Text(
                              '•',
                              style: TextStyle(
                                color: isDark
                                    ? signalwhite.withValues(alpha: 0.5)
                                    : Colors.black38,
                                fontSize: 12.sp,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => openExternalLink(
                              context,
                              'https://novaturients.in/community/pdfhawk/policy',
                            ),
                            child: Text(
                              'Privacy Policy',
                              style: GoogleFonts.lato(
                                fontSize: 12.5.sp,
                                color: isDark
                                    ? signalwhite.withValues(alpha: 0.8)
                                    : Colors.black54,
                                decoration: TextDecoration.underline,
                                decorationColor: isDark
                                    ? signalwhite.withValues(alpha: 0.8)
                                    : Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveLocationTile({
    required String title,
    required String subtitle,
    required String? customPath,
    required String defaultPathLabel,
    required IconData icon,
    required VoidCallback onChoose,
    required VoidCallback onReset,
    required bool isDark,
    required ThemeData theme,
  }) {
    final bool isCustom = customPath != null && customPath.isNotEmpty;
    final displayPath = isCustom ? customPath : defaultPathLabel;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isCustom
              ? theme.primaryColor.withValues(alpha: 0.4)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.06)),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: isCustom
                      ? theme.primaryColor.withValues(alpha: 0.15)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 18.sp,
                  color: isCustom
                      ? theme.primaryColor
                      : (isDark ? Colors.white : Colors.black87),
                ),
              ),
              Gap(10.w),
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
                      subtitle,
                      style: GoogleFonts.instrumentSans(
                        fontSize: 11.sp,
                        color:
                            isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Gap(10.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  size: 15.sp,
                  color: isCustom
                      ? theme.primaryColor
                      : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                ),
                Gap(6.w),
                Expanded(
                  child: Text(
                    displayPath,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.instrumentSans(
                      fontSize: 11.sp,
                      color: isCustom
                          ? (isDark ? Colors.blue.shade200 : Colors.blue.shade800)
                          : (isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600),
                      fontWeight:
                          isCustom ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Gap(8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isCustom) ...[
                TextButton.icon(
                  onPressed: onReset,
                  icon: Icon(
                    Icons.refresh_rounded,
                    size: 14.sp,
                    color: Colors.grey.shade500,
                  ),
                  label: Text(
                    "Reset",
                    style: GoogleFonts.instrumentSans(
                      fontSize: 11.5.sp,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  ),
                ),
                Gap(6.w),
              ],
              InkWell(
                onTap: onChoose,
                borderRadius: BorderRadius.circular(8.r),
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_location_alt_rounded,
                        size: 14.sp,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      Gap(4.w),
                      Text(
                        isCustom ? "Change Folder" : "Choose Folder",
                        style: GoogleFonts.instrumentSans(
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget settingsButton({
    required Function onTap,
    required String title,
    required IconData icon,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () => onTap(),
      borderRadius: allradius(10.r),
      child: Container(
        height: 48.h,
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.03),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.1),
            width: 1,
          ),
          borderRadius: allradius(10.r),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20.sp,
              color: isDark ? Colors.white : Colors.black87,
            ),
            Gap(12.w),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.instrumentSans(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20.sp,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ],
        ),
      ),
    );
  }

  void _shareApp() {
    SharePlus.instance.share(
      ShareParams(
        text:
            "Check out PDF Hawk - The ultimate PDF Reader, Editor & Scanner app! Download now: https://play.google.com/store/apps/details?id=com.novaturient.pdfhawk",
      ),
    );
  }

  Future<void> openExternalLink(BuildContext context, String link) async {
    try {
      // Ensure scheme exists (http/https)
      if (!link.startsWith(RegExp(r'https?:\/\/'))) {
        link = 'https://$link';
      }

      final Uri uri = Uri.parse(link);

      // Quick sanity check
      if (uri.scheme != 'http' && uri.scheme != 'https') {
        plainToast(msg: 'Unsupported URL scheme: ${uri.scheme}');
        return;
      }

      // canLaunchUrl is recommended before launchUrl
      final bool canLaunch = await canLaunchUrl(uri);
      if (!canLaunch) {
        plainToast(msg: 'Unable to open link: $link');
        return;
      }

      // open in external browser
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        plainToast(msg: 'Failed to open link: $link');
      }
    } catch (e, st) {
      // Debug print and show friendly message
      debugPrint('openExternalLink error: $e\n$st');
      plainToast(msg: 'Error opening link');
    }
  }
}
