/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'package:flutter/material.dart';
import 'package:pdfhawk/interface/pages/photo_editor_page.dart';

enum AppPrimaryColor { blue, red, monotone, custom }

AppPrimaryColor appPrimaryClr = AppPrimaryColor.blue;
Color customPrimaryColor = const Color(0xFF8E24AA);

typedef ScanEditPage = PhotoEditorPage;

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier<ThemeMode>(
  ThemeMode.system,
);

final ValueNotifier<AppPrimaryColor> appPrimaryClrNotifier =
    ValueNotifier<AppPrimaryColor>(AppPrimaryColor.blue);

final ValueNotifier<Color> primaryColorNotifier = ValueNotifier<Color>(
  const Color(0xff256ef1),
);
