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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdfhawk/interface/dialogs/color_wheel_dialog.dart';
import 'package:pdfhawk/data/gen/setting.dart';
import 'package:pdfhawk/data/res/theme.dart';
import 'package:pdfhawk/logic/helpers/hive_box_handler.dart';
import 'package:pdfhawk/logic/services/folder_storage_service.dart';
import 'package:pdfhawk/logic/services/storage_service.dart';
import 'package:pdfhawk/main.dart';
import 'package:pdfhawk/data/res/constants.dart';
import 'package:pdfhawk/data/res/utils.dart';
import 'package:pdfhawk/data/res/variables.dart';
import 'package:permission_handler/permission_handler.dart';
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

class _SettingsPageState extends State<SettingsPage>
    with WidgetsBindingObserver {
  final hive = HiveBoxHandler.getConfigBox();
  int ti = 0;
  String? _customPdfSaveDir;
  String? _customHawkSaveDir;
  bool _cameraPermissionGranted = false;
  bool _storagePermissionGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateTiFromThemeNotifier();
    themeNotifier.addListener(_onThemeNotifierChanged);
    if (hive.isNotEmpty) {
      final box = hive.getAt(0);
      if (box != null) {
        final colorIdx = box.kcolor.clamp(0, AppPrimaryColor.values.length - 1);
        appPrimaryClr = AppPrimaryColor.values[colorIdx];
      }
    }
    _loadCustomSaveDirectories();
    _checkPermissions();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    try {
      final camStatus = await Permission.camera.status;
      final bool camGranted = camStatus.isGranted || camStatus.isLimited;
      final bool storageGranted =
          await FolderStorageService.isStoragePermissionGranted();
      if (mounted) {
        setState(() {
          _cameraPermissionGranted = camGranted;
          _storagePermissionGranted = storageGranted;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleCameraPermission(bool value) async {
    if (value) {
      final status = await Permission.camera.request();
      if (status.isPermanentlyDenied) {
        plainToast(msg: "Please grant Camera permission in Device Settings");
        await openAppSettings();
      }
    } else {
      plainToast(msg: "To disable permissions, please open Device Settings");
      await openAppSettings();
    }
    await _checkPermissions();
  }

  Future<void> _toggleStoragePermission(bool value) async {
    if (value) {
      final granted = await FolderStorageService.ensureStoragePermission();
      if (!granted && Platform.isAndroid) {
        plainToast(msg: "Please grant All Files Access in Device Settings");
      }
    } else {
      plainToast(msg: "To disable permissions, please open Device Settings");
      await openAppSettings();
    }
    await _checkPermissions();
  }

  Future<void> _selectPrimaryColor(
    AppPrimaryColor mode, {
    Color? customColor,
  }) async {
    setState(() {
      appPrimaryClr = mode;
      if (customColor != null) {
        customPrimaryColor = customColor;
      }
    });

    updatePrimaryColor(mode, customColor: customColor);

    if (customColor != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('custom_primary_color_value', customColor.toARGB32());
    }

    if (hive.isNotEmpty) {
      final box = hive.getAt(0);
      if (box != null) {
        box.kcolor = mode.index;
        box.save();
      }
    } else {
      hive.add(
        SettingBox()
          ..theme = ti
          ..kcolor = mode.index,
      );
    }
    plainToast(msg: 'Primary theme color updated!');
  }

  Future<void> _openCustomColorPicker() async {
    final pickedColor = await ColorWheelDialog.show(
      context,
      initialColor: customPrimaryColor,
    );
    if (pickedColor != null) {
      await _selectPrimaryColor(
        AppPrimaryColor.custom,
        customColor: pickedColor,
      );
    }
  }

  Widget _buildColorChip({
    required AppPrimaryColor mode,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final bool isSelected = appPrimaryClr == mode;
    final bool isMonotone = mode == AppPrimaryColor.monotone;

    return InkWell(
      borderRadius: allradius(24.r),
      onTap: onTap,
      child: Container(
        height: 42.r,
        width: 42.r,
        margin: EdgeInsets.only(right: 12.w),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(
                  color: isMonotone
                      ? (isDark ? Colors.white70 : Colors.black54)
                      : (isDark ? Colors.white : Colors.black87),
                  width: 2.5,
                )
              : (isMonotone
                    ? Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.2),
                        width: 1.2,
                      )
                    : null),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isSelected
            ? Center(
                child: Icon(
                  Icons.check_rounded,
                  size: 20.sp,
                  color: isMonotone
                      ? (isDark ? Colors.black : Colors.white)
                      : (ThemeData.estimateBrightnessForColor(color) ==
                                Brightness.dark
                            ? Colors.white
                            : Colors.black87),
                ),
              )
            : const SizedBox(),
      ),
    );
  }

  Widget _buildCustomColorChip(bool isDark) {
    final bool isSelected = appPrimaryClr == AppPrimaryColor.custom;
    final Color color = customPrimaryColor;

    return InkWell(
      borderRadius: allradius(24.r),
      onTap: () {
        if (isSelected) {
          _openCustomColorPicker();
        } else {
          _selectPrimaryColor(AppPrimaryColor.custom);
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 42.r,
            width: 42.r,
            margin: EdgeInsets.only(right: 12.w),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(
                      color: isDark ? Colors.white : Colors.black87,
                      width: 2.5,
                    )
                  : Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.25)
                          : Colors.black.withValues(alpha: 0.15),
                      width: 1.2,
                    ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isSelected
                ? Center(
                    child: Icon(
                      Icons.check_rounded,
                      size: 20.sp,
                      color:
                          ThemeData.estimateBrightnessForColor(color) ==
                              Brightness.dark
                          ? Colors.white
                          : Colors.black87,
                    ),
                  )
                : null,
          ),
          // Edit Overlay badge
          Positioned(
            right: 8.w,
            bottom: -2.h,
            child: GestureDetector(
              onTap: _openCustomColorPicker,
              child: Container(
                padding: EdgeInsets.all(3.r),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C34) : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.edit_rounded,
                  size: 10.sp,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
    WidgetsBinding.instance.removeObserver(this);
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
              borderRadius: allradius(25.r),
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
                    // Section: Set Primary Color
                    Padding(
                      padding: EdgeInsets.only(bottom: 16.h),
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
                          Gap(12.h),
                          Row(
                            children: [
                              _buildColorChip(
                                mode: AppPrimaryColor.monotone,
                                color: isDark ? Colors.white : Colors.black,
                                isDark: isDark,
                                onTap: () => _selectPrimaryColor(
                                  AppPrimaryColor.monotone,
                                ),
                              ),
                              _buildColorChip(
                                mode: AppPrimaryColor.red,
                                color: brightred,
                                isDark: isDark,
                                onTap: () =>
                                    _selectPrimaryColor(AppPrimaryColor.red),
                              ),
                              _buildColorChip(
                                mode: AppPrimaryColor.blue,
                                color: royalblue,
                                isDark: isDark,
                                onTap: () =>
                                    _selectPrimaryColor(AppPrimaryColor.blue),
                              ),
                              _buildCustomColorChip(isDark),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Card 1: Modified PDFs Save Location
                    _buildSaveLocationTile(
                      title: "Export Files To",
                      customPath: _customPdfSaveDir,
                      defaultPathLabel: "Default: Documents/PDFHawk",
                      onChoose: _pickCustomPdfDirectory,
                      onReset: _resetCustomPdfDirectory,
                      isDark: isDark,
                      theme: theme,
                    ),

                    // Card 2: Hawk Documents Save Location
                    _buildSaveLocationTile(
                      title: "Default Auto-save",
                      customPath: _customHawkSaveDir,
                      defaultPathLabel:
                          "Default: Documents/PDFHawk/HawkDocuments",
                      onChoose: _pickCustomHawkDirectory,
                      onReset: _resetCustomHawkDirectory,
                      isDark: isDark,
                      theme: theme,
                    ),

                    Gap(10.h),

                    // Section: App Permissions
                    Padding(
                      padding: EdgeInsets.only(top: 6.h, bottom: 4.h),
                      child: Text(
                        'App Permissions',
                        style: GoogleFonts.instrumentSans(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _buildPermissionSwitchTile(
                      title: "Camera Access",
                      subtitle: "Scan paper documents, notes, and receipts",
                      icon: Icons.camera_alt_outlined,
                      value: _cameraPermissionGranted,
                      onChanged: _toggleCameraPermission,
                      isDark: isDark,
                      theme: theme,
                    ),
                    _buildPermissionSwitchTile(
                      title: "Files & Storage Access",
                      subtitle: "Read, modify, import photos, and save PDFs",
                      icon: Icons.folder_shared_outlined,
                      value: _storagePermissionGranted,
                      onChanged: _toggleStoragePermission,
                      isDark: isDark,
                      theme: theme,
                    ),
                    Gap(8.h),

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
                                    color: isDark
                                        ? signalwhite
                                        : Colors.black87,
                                  ),
                                  Gap(6.w),
                                  Flexible(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                                ? signalwhite.withValues(
                                                    alpha: 0.7,
                                                  )
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

  Widget _buildPermissionSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
    required ThemeData theme,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20.sp,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          Gap(12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.instrumentSans(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Gap(2.h),
                Text(
                  subtitle,
                  style: GoogleFonts.instrumentSans(
                    fontSize: 11.5.sp,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Gap(8.w),
          Switch.adaptive(
            value: value,
            activeTrackColor: theme.primaryColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSaveLocationTile({
    required String title,
    required String? customPath,
    required String defaultPathLabel,
    required VoidCallback onChoose,
    required VoidCallback onReset,
    required bool isDark,
    required ThemeData theme,
  }) {
    final bool isCustom = customPath != null && customPath.isNotEmpty;
    final displayPath = isCustom ? customPath : defaultPathLabel;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: GoogleFonts.instrumentSans(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Gap(10.h),
          InkWell(
            onTap: onChoose,
            borderRadius: allradius(10.r),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF141418)
                    : const Color(0xFFF3F4F6),
                borderRadius: allradius(10.r),
                border: Border.all(
                  color: isCustom
                      ? theme.primaryColor.withValues(
                          alpha: isDark ? 0.45 : 0.35,
                        )
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.12)),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isCustom
                        ? Icons.folder_special_rounded
                        : Icons.folder_outlined,
                    size: 17.sp,
                    color: isCustom
                        ? theme.primaryColor
                        : (isDark ? Colors.grey.shade300 : Colors.black87),
                  ),
                  Gap(8.w),
                  Expanded(
                    child: Text(
                      displayPath,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.instrumentSans(
                        fontSize: 12.sp,
                        fontWeight: isCustom
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: isCustom
                            ? (isDark
                                  ? const Color(0xFF90CAF9)
                                  : (theme.primaryColor == Colors.black
                                        ? Colors.black87
                                        : theme.primaryColor))
                            : (isDark ? Colors.grey.shade200 : Colors.black87),
                      ),
                    ),
                  ),
                  if (isCustom) ...[
                    Gap(8.w),
                    GestureDetector(
                      onTap: onReset,
                      child: Container(
                        padding: EdgeInsets.all(5.r),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.15)
                              : Colors.black.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.restart_alt_rounded,
                          size: 15.sp,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
