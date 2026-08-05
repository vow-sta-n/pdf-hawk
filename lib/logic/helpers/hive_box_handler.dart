import 'package:hive_flutter/hive_flutter.dart';
import 'package:pdfhawk/data/gen/setting.dart';

class HiveBoxHandler {
  static Box<SettingBox> getConfigBox() => Hive.box<SettingBox>('configs');
}
