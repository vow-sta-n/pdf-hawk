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
    final currentMode = themeNotifier.value;
    if (currentMode == ThemeMode.system) {
      ti = 0;
    } else if (currentMode == ThemeMode.light) {
      ti = 1;
    } else if (currentMode == ThemeMode.dark) {
      ti = 2;
    }
    if (hive.isNotEmpty) {
      final box = hive.getAt(0);
      if (box != null) {
        ci = box.kcolor;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    double w = getWidth(context);
    return Material(
      color: transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: EdgeInsetsGeometry.only(right: 15),
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(25.r),
              child: Container(
                width: 50.r,
                height: 50.r,
                decoration: BoxDecoration(
                  color: dullblack,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(Icons.close, color: Colors.white, size: 26.sp),
                ),
              ),
            ),
          ),
          Container(
            width: w,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: dullblack,
              borderRadius: allradius(12),
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
                        fontSize: 26.sp,
                        color: white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Gap(15),
                // Theme Mode 3-Chip Selector (System, Light, Dark)
                Row(
                  children: [
                    Expanded(
                      child: _buildThemeChip(
                        index: 0,
                        label: "System",
                        icon: Icons.brightness_auto_rounded,
                      ),
                    ),
                    const Gap(8),
                    Expanded(
                      child: _buildThemeChip(
                        index: 1,
                        label: "Light",
                        icon: Icons.light_mode_rounded,
                      ),
                    ),
                    const Gap(8),
                    Expanded(
                      child: _buildThemeChip(
                        index: 2,
                        label: "Dark",
                        icon: Icons.dark_mode_rounded,
                      ),
                    ),
                  ],
                ),
                const Gap(20),
                // color
                Padding(
                  padding: const EdgeInsets.only(left: 5, bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        'Set Primary Color',
                        style: GoogleFonts.instrumentSans(
                          height: 1,
                          color: white,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Gap(10),
                      // body
                      SizedBox(
                        height: 45,
                        width: w,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: color.length,
                          padding: EdgeInsets.zero,
                          itemBuilder: (context, index) => InkWell(
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
                              height: 40,
                              elevation: 1.2,
                              width: 40,
                              margin: const EdgeInsets.only(right: 7),
                              color: color[index],
                              shape: BoxShape.circle,
                              border: ci == index
                                  ? Border.all(
                                      color: isDark ? white : white,
                                      width: 2,
                                      style: BorderStyle.solid,
                                    )
                                  : null,
                              child: const SizedBox(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(5),
                // Share App button
                settingsButton(
                  title: 'Share App',
                  icon: Icons.share_rounded,
                  onTap: _shareApp,
                ),
                const Gap(12),
                // Rate App on Play Store button
                settingsButton(
                  title: 'Rate App on Play Store',
                  icon: Icons.star_rate_rounded,
                  onTap: _rateApp,
                ),
                const Gap(12),
                // Contribute on GitHub button
                settingsButton(
                  title: 'Contribute on GitHub',
                  icon: PDFHawkIcons.github_circled,
                  onTap: contribute,
                ),
                const Gap(20),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () => _showPolicyDialog(
                      context,
                      title: "Privacy Policy",
                      content:
                          "PDF Hawk respects your privacy. All document processing, editing, and storage occurs locally on your device. PDF Hawk does not collect or transmit personal information or document data.",
                    ),
                    child: Text(
                      'Privacy Policy',
                      style: GoogleFonts.inter(
                        color: Colors.grey.shade400,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.grey.shade400,
                      ),
                    ),
                  ),
                ),

                InkWell(
                  onTap: () => _showPolicyDialog(
                    context,
                    title: "Terms & Conditions",
                    content:
                        "By using PDF Hawk, you agree to use the app for lawful PDF document handling. PDF Hawk is free software provided under the MIT Open Source License without warranties of any kind.",
                  ),
                  child: Text(
                    'Terms & Conditions',
                    style: GoogleFonts.inter(
                      color: Colors.grey.shade400,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.grey.shade400,
                    ),
                  ),
                ),
                const Gap(8),
                // MIT Open Source License Footer
                Center(
                  child: Text(
                    'Licensed under MIT Open Source License',
                    style: GoogleFonts.instrumentSans(
                      fontSize: 11.sp,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
                const Gap(10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InkWell settingsButton({
    required Function onTap,
    required String title,
    required IconData icon,
  }) {
    double w = getWidth(context);
    return InkWell(
      onTap: () => onTap(),
      child: Container(
        height: 45,
        width: w - 44,
        padding: EdgeInsets.symmetric(horizontal: 8.r),
        decoration: BoxDecoration(
          border: Border.all(color: white, width: 2),
          borderRadius: allradius(6),
        ),
        child: Center(
          child: Row(
            children: [
              Icon(icon, size: 22.sp, color: white),
              const Gap(15),
              Text(
                title,
                style: GoogleFonts.instrumentSans(
                  color: white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _shareApp() {
    SharePlus.instance.share(
      ShareParams(
        text:
            "Check out PDF Hawk - The ultimate PDF Reader, Editor & Scanner app! Download now: https://play.google.com/store/apps/details?id=com.pdfhawk.app",
      ),
    );
  }

  Future<void> _rateApp() async {
    final Uri url = Uri.parse(
      "https://play.google.com/store/apps/details?id=com.pdfhawk.app",
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
  }) {
    final bool isSelected = ti == index;
    return InkWell(
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
          color: isSelected ? white : Colors.white.withValues(alpha: 0.08),
          borderRadius: allradius(8),
          border: Border.all(
            color: isSelected ? white : Colors.white12,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18.sp, color: isSelected ? black : white),
            Gap(6.w),
            Text(
              label,
              style: GoogleFonts.instrumentSans(
                color: isSelected ? black : white,
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
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dullblack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Text(
          title,
          style: GoogleFonts.outfit(
            color: white,
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          content,
          style: GoogleFonts.instrumentSans(
            color: Colors.grey.shade300,
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
