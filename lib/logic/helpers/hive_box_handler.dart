/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'package:hive_flutter/hive_flutter.dart';
import 'package:pdfhawk/data/gen/setting.dart';

class HiveBoxHandler {
  static Box<SettingBox> getConfigBox() => Hive.box<SettingBox>('configs');
}
