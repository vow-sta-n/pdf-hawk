import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfhawk/data/setting.dart';
import 'package:pdfhawk/logic/helpers/hive_box_handler.dart';
import 'package:pdfhawk/main.dart';
import 'package:pdfhawk/res/constants.dart';
import 'package:pdfhawk/res/theme.dart';
import 'package:pdfhawk/res/utils.dart';
import 'package:pdfhawk/res/variables.dart';

class KThemedBox extends StatelessWidget {
  final double? height;
  final double? width;
  final double? elevation;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final BoxShape shape;
  final BoxBorder? border;
  final Widget? child;

  const KThemedBox({
    super.key,
    this.height,
    this.width,
    this.elevation,
    this.margin,
    this.color,
    this.shape = BoxShape.rectangle,
    this.border,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      margin: margin,
      decoration: BoxDecoration(
        color: color,
        shape: shape,
        border: border,
        boxShadow: elevation != null && elevation! > 0
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: elevation!,
                  spreadRadius: elevation! / 2,
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

class MenuSheet extends StatefulWidget {
  final dynamic onRefresh;
  final dynamic all;
  final dynamic selected;
  final bool isFactory;
  final bool comp;
  final Function(int hj, bool cls)? onUpdateCompare;
  final BuildContext? ctx;
  const MenuSheet({
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
  State<MenuSheet> createState() => _MenuSheetState();
}

class _MenuSheetState extends State<MenuSheet> {
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
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          FloatingActionButton(
            onPressed: () => Navigator.pop(context),
            backgroundColor: dullblack,
            shape: const CircleBorder(),
            child: Icon(Icons.keyboard_arrow_down_rounded, size: 30.sp, color: white),
          ),
          Container(
            width: w,
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: dullblack,
              borderRadius: allradius(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: w, child: Center(child: uihandle())),
                Text(
                  '🗂️ Hello there,',
                  style: GoogleFonts.instrumentSans(
                    fontSize: 32.sp,
                    color: white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Gap(20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        // theme
                        InkWell(
                          onTap: () {
                            if (ti == 0) {
                              updateThemeMode(ThemeMode.light);
                              setState(() {
                                ti = 1;
                              });
                            } else if (ti == 1) {
                              updateThemeMode(ThemeMode.dark);
                              setState(() {
                                ti = 2;
                              });
                            } else {
                              updateThemeMode(ThemeMode.system);
                              setState(() {
                                ti = 0;
                              });
                            }
                            if (hive.isNotEmpty) {
                              final box = hive.getAt(0);
                              if (box != null) {
                                box.theme = ti;
                                box.save();
                              }
                            } else {
                              hive.add(SettingBox()..theme = ti..kcolor = ci);
                            }
                          },
                          child: Container(
                            height: 45,
                            width: w - 40,
                            padding: const EdgeInsets.only(left: 10, right: 10),
                            decoration: BoxDecoration(
                              borderRadius: allradius(5),
                              color: white,
                              border: Border.all(color: white, width: 2),
                            ),
                            child: Center(
                              child: Row(
                                children: [
                                  Icon(
                                    ti == 0
                                        ? Icons.lightbulb_circle_outlined
                                        : ti == 1
                                            ? Icons.light_mode
                                            : Icons.dark_mode,
                                    size: 22.sp,
                                    color: black,
                                  ),
                                  const Gap(15),
                                  Text(
                                    them[ti],
                                    style: GoogleFonts.instrumentSans(
                                      height: 1,
                                      color: black,
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Gap(30),
                // color
                Padding(
                  padding: const EdgeInsets.only(left: 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // title
                      Text(
                        'Set Primary Color',
                        style: GoogleFonts.instrumentSans(
                          height: 1,
                          color: white,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Gap(7),
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
                              if (hive.isNotEmpty) {
                                final box = hive.getAt(0);
                                if (box != null) {
                                  box.kcolor = ci;
                                  box.save();
                                }
                              } else {
                                hive.add(SettingBox()..theme = ti..kcolor = ci);
                              }
                              plainToast(
                                msg:
                                    'Your preference will be active from the next restart of PDF Hawk!',
                              );
                            },
                            child: KThemedBox(
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
