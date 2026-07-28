// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'setting.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SettingBoxAdapter extends TypeAdapter<SettingBox> {
  @override
  final int typeId = 3;

  @override
  SettingBox read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SettingBox()
      ..theme = (fields[0] as int?) ?? 0
      ..kcolor = (fields[1] as int?) ?? 0;
  }

  @override
  void write(BinaryWriter writer, SettingBox obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.theme)
      ..writeByte(1)
      ..write(obj.kcolor);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingBoxAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
