import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfhawk/data/class/p_d_f_hawk_icons_icons.dart';
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
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
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
                      style: GoogleFonts.outfit(
                        fontSize: 24.sp,
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
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
                                        color: isDark ? Colors.white : Colors.black87,
                                        width: 2.5,
                                        style: BorderStyle.solid,
                                      )
                                    : null,
                                child: isSelected
                                    ? Center(
                                        child: Icon(
                                          Icons.check_rounded,
                                          size: 20.sp,
                                          color: ThemeData.estimateBrightnessForColor(
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
                Gap(10.h),
                // Rate App on Play Store button
                settingsButton(
                  title: 'Rate App on Play Store',
                  icon: Icons.star_rate_rounded,
                  onTap: _rateApp,
                  isDark: isDark,
                ),
                Gap(10.h),
                // Contribute on GitHub button
                settingsButton(
                  title: 'Contribute on GitHub',
                  icon: PDFHawkIcons.github_circled,
                  onTap: contribute,
                  isDark: isDark,
                ),
                Gap(20.h),
                // Privacy Policy link
                Padding(
                  padding: EdgeInsets.only(bottom: 10.h),
                  child: InkWell(
                    onTap: () => _showPolicyDialog(
                      context,
                      title: "Privacy Policy",
                      content:
                          "PDF Hawk respects your privacy. All document processing, editing, and storage occurs locally on your device. PDF Hawk does not collect or transmit personal information or document data.",
                      isDark: isDark,
                    ),
                    child: Text(
                      'Privacy Policy',
                      style: GoogleFonts.inter(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                        decorationColor: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
                // Terms & Conditions link
                InkWell(
                  onTap: () => _showPolicyDialog(
                    context,
                    title: "Terms & Conditions",
                    content:
                        "By using PDF Hawk, you agree to use the app for lawful PDF document handling. PDF Hawk is free software provided under the MIT Open Source License without warranties of any kind.",
                    isDark: isDark,
                  ),
                  child: Text(
                    'Terms & Conditions',
                    style: GoogleFonts.inter(
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                      decorationColor: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                    ),
                  ),
                ),
                Gap(12.h),
                // MIT Open Source License Footer
                Center(
                  child: Text(
                    'Licensed under MIT Open Source License',
                    style: GoogleFonts.instrumentSans(
                      fontSize: 11.sp,
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                    ),
                  ),
                ),
                Gap(6.h),
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

  Future<void> _rateApp() async {
    final Uri url = Uri.parse(
      "https://play.google.com/store/apps/details?id=com.novaturient.pdfhawk",
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      plainToast(msg: "Could not launch Play Store rating link");
    }
  }

  Future<void> contribute() async {
    final Uri url = Uri.parse("https://github.com/vow-sta-n/pdf-hawk");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      plainToast(msg: "Could not launch GitHub link");
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

  void _showPolicyDialog(
    BuildContext context, {
    required String title,
    required String content,
    required bool isDark,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Text(
          title,
          style: GoogleFonts.outfit(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          content,
          style: GoogleFonts.instrumentSans(
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
            fontSize: 14.sp,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.instrumentSans(
                color: kprimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

