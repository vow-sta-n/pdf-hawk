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

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier<ThemeMode>(
  ThemeMode.system,
);

final ValueNotifier<Color> primaryColorNotifier = ValueNotifier<Color>(
  color[ci],
);

Future<void> updateThemeMode(ThemeMode mode) async {
  themeNotifier.value = mode;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('theme_mode', mode.toString());
}

void updatePrimaryColor(int index) {
  if (index >= 0 && index < color.length) {
    ci = index;
    kprimary = color[ci];
    primaryColorNotifier.value = kprimary;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(SettingBoxAdapter());
  final configBox = await Hive.openBox<SettingBox>('configs');
  await Hive.openBox('pdfhawk_box');

  if (configBox.isNotEmpty) {
    final setting = configBox.getAt(0);
    if (setting != null) {
      ci = setting.kcolor.clamp(0, color.length - 1);
      kprimary = color[ci];
      primaryColorNotifier.value = kprimary;
    }
  }

  final prefs = await SharedPreferences.getInstance();
  final themeStr = prefs.getString('theme_mode');
  if (themeStr != null) {
    themeNotifier.value = ThemeMode.values.firstWhere(
      (e) => e.toString() == themeStr,
      orElse: () => ThemeMode.system,
    );
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
            return ValueListenableBuilder<Color>(
              valueListenable: primaryColorNotifier,
              builder: (context, currentPrimaryColor, _) {
                return MaterialApp(
                  title: 'PDF Hawk',
                  debugShowCheckedModeBanner: false,
                  theme: ThemeData(
                    useMaterial3: true,
                    brightness: Brightness.light,
                    primaryColor: currentPrimaryColor,
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: currentPrimaryColor,
                      brightness: Brightness.light,
                      primary: currentPrimaryColor,
                      surface: Colors.white,
                    ),
                    scaffoldBackgroundColor: Colors.white,
                    appBarTheme: const AppBarTheme(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      iconTheme: IconThemeData(color: Colors.black),
                    ),
                    textTheme: GoogleFonts.instrumentSansTextTheme(
                      ThemeData.light().textTheme,
                    ),
                  ),
                  darkTheme: ThemeData(
                    useMaterial3: true,
                    brightness: Brightness.dark,
                    primaryColor: currentPrimaryColor,
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: currentPrimaryColor,
                      brightness: Brightness.dark,
                      primary: currentPrimaryColor,
                      surface: Colors.black,
                    ),
                    scaffoldBackgroundColor: Colors.black,
                    appBarTheme: const AppBarTheme(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      iconTheme: IconThemeData(color: Colors.white),
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
                  home: const HomePage(),
                );
              },
            );
          },
        );
      },
    );
  }
}
