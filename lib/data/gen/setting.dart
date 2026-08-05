import 'package:hive_flutter/hive_flutter.dart';
part 'setting.g.dart';

@HiveType(typeId: 3)
class SettingBox extends HiveObject {
  @HiveField(0)
  late int theme;
  @HiveField(1)
  late int kcolor;
}
