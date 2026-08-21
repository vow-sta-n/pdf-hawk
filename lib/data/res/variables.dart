/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'package:flutter/material.dart';
import 'package:pdfhawk/data/res/theme.dart';
import 'package:pdfhawk/interface/pages/photo_editor_page.dart';

//color
int ci = 0;

// Color pr = const Color(0xFFE52521);

List color = [
  const Color(0xFFE52521), // Red
  const Color(0xff9fa0c3),
  const Color(0xffC7D36F),
  const Color(0xffDDF3F5),
  const Color(0xffECE8D9),
  const Color(0xffCCA8E9),
  royalblue,
  coral,
];

typedef ScanEditPage = PhotoEditorPage;

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier<ThemeMode>(
  ThemeMode.system,
);

final ValueNotifier<Color> primaryColorNotifier = ValueNotifier<Color>(
  color[ci],
);
