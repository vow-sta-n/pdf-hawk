import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfhawk/res/constants.dart';

const Color kprimary = Color(0xFFEDB61F);
const Color darkbg = Color(0xff121212);
const Color red = Color.fromARGB(255, 167, 42, 10);
const Color white = Color(0xFFFFFFFF);
const Color black = Color(0xFF000000);
const Color grey = Colors.grey;
const Color silver = Color(0xfff2f5fc);
const Color transparent = Color.fromARGB(0, 255, 255, 255);
const Color arsenic = Color.fromARGB(255, 44, 44, 44);
const Color offgrey = Color(0xff808080);
const Color ongrey = Color(0xff666666);
const Color coral = Color(0xfff17239);
const Color signalwhite = Color(0xfff4f8f4);

class AppThemes {
  static final lightTheme = ThemeData(
    brightness: Brightness.light,
    focusColor: white,
    primaryColor: white,
    appBarTheme: AppBarTheme(
      elevation: 0,
      backgroundColor: transparent,
      shadowColor: transparent,
      scrolledUnderElevation: 0,
      surfaceTintColor: transparent,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: transparent,
        statusBarBrightness: Brightness.dark,
        systemStatusBarContrastEnforced: true,
        statusBarIconBrightness: Brightness.dark,
      ),
      titleTextStyle: GoogleFonts.lato(
        textStyle: const TextStyle(
          fontSize: 35,
          color: black,
          fontWeight: FontWeight.w500,
        ),
      ),
      centerTitle: false,
      titleSpacing: 0,
      foregroundColor: black,
    ),
    inputDecorationTheme: const InputDecorationTheme(focusColor: transparent),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: allradius(20)),
    ),
    colorScheme: const ColorScheme.light(primary: white),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      iconSize: 25,
      backgroundColor: white,
      foregroundColor: white,
      shape: RoundedRectangleBorder(borderRadius: allradius(15)),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: white,
      actionTextColor: black,
    ),
    scaffoldBackgroundColor: white,
    tabBarTheme: TabBarThemeData(indicatorColor: white),
  );
}
