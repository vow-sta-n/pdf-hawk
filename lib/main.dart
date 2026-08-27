/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:pdfhawk/data/gen/setting.dart';
import 'package:pdfhawk/interface/home_page.dart';
import 'package:pdfhawk/data/res/theme.dart';
import 'package:pdfhawk/data/res/variables.dart';
import 'package:pdfhawk/logic/services/intent_service.dart';

import 'package:pdfhawk/onboarding_page.dart';
import 'package:pdfhawk/data/res/constants.dart';

Future<void> updateThemeMode(ThemeMode mode) async {
  themeNotifier.value = mode;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('theme_mode', mode.toString());
}

void updatePrimaryColor(AppPrimaryColor colorMode, {Color? customColor}) {
  appPrimaryClr = colorMode;
  appPrimaryClrNotifier.value = colorMode;
  if (customColor != null) {
    customPrimaryColor = customColor;
  }
  kprimary = resolveAppPrimaryColor(appPrimaryClr, isDark: false);
  primaryColorNotifier.value = kprimary;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  IntentService.initialize();
  await Hive.initFlutter();
  Hive.registerAdapter(SettingBoxAdapter());
  final configBox = await Hive.openBox<SettingBox>('configs');
  await Hive.openBox('pdfhawk_box');

  final prefs = await SharedPreferences.getInstance();
  final customColorVal = prefs.getInt('custom_primary_color_value');
  if (customColorVal != null) {
    customPrimaryColor = Color(customColorVal);
  }

  if (configBox.isNotEmpty) {
    final setting = configBox.getAt(0);
    if (setting != null) {
      final int colorIdx = setting.kcolor.clamp(
        0,
        AppPrimaryColor.values.length - 1,
      );
      appPrimaryClr = AppPrimaryColor.values[colorIdx];
      appPrimaryClrNotifier.value = appPrimaryClr;
      kprimary = resolveAppPrimaryColor(appPrimaryClr, isDark: false);
      primaryColorNotifier.value = kprimary;
    }
  }

  final themeStr = prefs.getString('theme_mode');
  if (themeStr != null) {
    themeNotifier.value = ThemeMode.values.firstWhere(
      (e) => e.toString() == themeStr,
      orElse: () => ThemeMode.system,
    );
  }

  final bool hasCompletedOnboarding =
      prefs.getBool('has_completed_onboarding') ?? false;

  runApp(MyApp(hasCompletedOnboarding: hasCompletedOnboarding));
}

class MyApp extends StatelessWidget {
  final bool hasCompletedOnboarding;
  const MyApp({super.key, this.hasCompletedOnboarding = false});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: themeNotifier,
          builder: (context, currentThemeMode, _) {
            return ValueListenableBuilder<AppPrimaryColor>(
              valueListenable: appPrimaryClrNotifier,
              builder: (context, currentMode, _) {
                return ValueListenableBuilder<Color>(
                  valueListenable: primaryColorNotifier,
                  builder: (context, currentPrimaryColor, _) {
                    final bool isMonochromatic =
                        (currentMode == AppPrimaryColor.monotone);
                    final lightPrimary = resolveAppPrimaryColor(
                      currentMode,
                      isDark: false,
                      customClr: customPrimaryColor,
                    );
                    final darkPrimary = resolveAppPrimaryColor(
                      currentMode,
                      isDark: true,
                      customClr: customPrimaryColor,
                    );

                    return MaterialApp(
                      title: 'PDF Hawk',
                      debugShowCheckedModeBanner: false,
                      theme: ThemeData(
                        useMaterial3: true,
                        brightness: Brightness.light,
                        primaryColor: lightPrimary,
                        colorScheme: ColorScheme.fromSeed(
                          seedColor: isMonochromatic
                              ? const Color(0xFF1E1E1E)
                              : lightPrimary,
                          brightness: Brightness.light,
                          primary: lightPrimary,
                          onPrimary: Colors.white,
                          surface: Colors.white,
                          onSurface: Colors.black87,
                        ),
                        scaffoldBackgroundColor: Colors.white,
                        appBarTheme: const AppBarTheme(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          iconTheme: IconThemeData(color: Colors.black),
                        ),
                        popupMenuTheme: PopupMenuThemeData(
                          color: Colors.white,
                          surfaceTintColor: Colors.transparent,
                          elevation: 8,
                          shadowColor: Colors.black.withValues(alpha: 0.12),
                          shape: RoundedRectangleBorder(
                            borderRadius: allradius(16.r),
                            side: BorderSide(
                              color: Colors.black.withValues(alpha: 0.08),
                              width: 1,
                            ),
                          ),
                          textStyle: GoogleFonts.instrumentSans(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                          iconColor: Colors.black87,
                        ),
                        textTheme: GoogleFonts.instrumentSansTextTheme(
                          ThemeData.light().textTheme,
                        ),
                      ),
                      darkTheme: ThemeData(
                        useMaterial3: true,
                        brightness: Brightness.dark,
                        primaryColor: darkPrimary,
                        colorScheme: ColorScheme.fromSeed(
                          seedColor: isMonochromatic
                              ? const Color(0xFFE0E0E0)
                              : currentPrimaryColor,
                          brightness: Brightness.dark,
                          primary: darkPrimary,
                          onPrimary: Colors.black,
                          surface: Colors.black,
                          onSurface: Colors.white,
                        ),
                        scaffoldBackgroundColor: Colors.black,
                        appBarTheme: const AppBarTheme(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          iconTheme: IconThemeData(color: Colors.white),
                        ),
                        popupMenuTheme: PopupMenuThemeData(
                          color: const Color(0xFF1E1E1E),
                          surfaceTintColor: Colors.transparent,
                          elevation: 8,
                          shadowColor: Colors.black.withValues(alpha: 0.6),
                          shape: RoundedRectangleBorder(
                            borderRadius: allradius(16.r),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.12),
                              width: 1,
                            ),
                          ),
                          textStyle: GoogleFonts.instrumentSans(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                          iconColor: Colors.white,
                        ),
                        textTheme: GoogleFonts.instrumentSansTextTheme(
                          ThemeData.dark().textTheme,
                        ),
                      ),
                      themeMode: currentThemeMode,
                      localizationsDelegates: const [
                        GlobalMaterialLocalizations.delegate,
                        GlobalWidgetsLocalizations.delegate,
                        GlobalCupertinoLocalizations.delegate,
                        FlutterQuillLocalizations.delegate,
                      ],
                      supportedLocales: const [Locale('en', '')],
                      home: hasCompletedOnboarding
                          ? const HomePage()
                          : const OnboardingPage(),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
