/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'package:community_material_icon/community_material_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfhawk/data/gen/setting.dart';
import 'package:pdfhawk/data/res/theme.dart';
import 'package:pdfhawk/interface/widgets/circular_color_chip.dart';
import 'package:pdfhawk/logic/helpers/hive_box_handler.dart';
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
                        fontSize: 32.sp,
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Gap(16.h),
                // Theme Mode 3-Chip Selector (System, Light, Dark)
                Row(
                  children: [
                    Expanded(
                      child: _buildThemeChip(
                        index: 0,
                        label: "System",
                        icon: Icons.brightness_auto_rounded,
                        isDark: isDark,
                      ),
                    ),
                    Gap(8.w),
                    Expanded(
                      child: _buildThemeChip(
                        index: 1,
                        label: "Light",
                        icon: Icons.light_mode_rounded,
                        isDark: isDark,
                      ),
                    ),
                    Gap(8.w),
                    Expanded(
                      child: _buildThemeChip(
                        index: 2,
                        label: "Dark",
                        icon: Icons.dark_mode_rounded,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                Gap(20.h),
                // Set Primary Color section
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
                          fontWeight: FontWeight.w600,
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
                    Gap(8.w),
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
                          'https://www.novaturients.in/community/pdfhawk/privacy_policy',
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
                          'https://www.novaturients.in/community/pdfhawk/privacy_policy',
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

  Widget _buildThemeChip({
    required int index,
    required String label,
    required IconData icon,
    required bool isDark,
  }) {
    final bool isSelected = ti == index;
    return InkWell(
      borderRadius: allradius(10.r),
      onTap: () {
        setState(() {
          ti = index;
        });
        if (index == 0) {
          updateThemeMode(ThemeMode.system);
        } else if (index == 1) {
          updateThemeMode(ThemeMode.light);
        } else if (index == 2) {
          updateThemeMode(ThemeMode.dark);
        }
        if (hive.isNotEmpty) {
          final box = hive.getAt(0);
          if (box != null) {
            box.theme = ti;
            box.save();
          }
        } else {
          hive.add(
            SettingBox()
              ..theme = ti
              ..kcolor = ci,
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 44.h,
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white : const Color(0xFF1E1E1E))
              : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.04)),
          borderRadius: allradius(10.r),
          border: Border.all(
            color: isSelected
                ? (isDark ? Colors.white : const Color(0xFF1E1E1E))
                : (isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.1)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18.sp,
              color: isSelected
                  ? (isDark ? Colors.black : Colors.white)
                  : (isDark ? Colors.white70 : Colors.black87),
            ),
            Gap(6.w),
            Text(
              label,
              style: GoogleFonts.instrumentSans(
                color: isSelected
                    ? (isDark ? Colors.black : Colors.white)
                    : (isDark ? Colors.white70 : Colors.black87),
                fontSize: 13.sp,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
