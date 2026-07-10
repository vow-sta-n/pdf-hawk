import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pdfhawk/interface/home_page.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

Future<void> updateThemeMode(ThemeMode mode) async {
  themeNotifier.value = mode;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('theme_mode', mode.toString());
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('pdfhawk_box');
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
            return MaterialApp(
              title: 'PDF Hawk',
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.light,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFFE52521),
                  brightness: Brightness.light,
                  primary: const Color(0xFFE52521),
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
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFFE52521),
                  brightness: Brightness.dark,
                  primary: const Color(0xFFE52521),
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
              home: const HomePage(),
            );
          },
        );
      },
    );
  }
}
