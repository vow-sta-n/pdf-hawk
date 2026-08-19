/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:io';
import 'package:path/path.dart' as p;

class FolderModel {
  final String id;
  final String name;
  final String path;
  final bool isDefault;
  final int? colorValue;
  final int? createdTimestamp;
  int? cachedFileCount;

  FolderModel({
    required this.id,
    required this.name,
    required this.path,
    this.isDefault = false,
    this.colorValue,
    this.createdTimestamp,
    this.cachedFileCount,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'path': path,
    'isDefault': isDefault,
    'colorValue': colorValue,
    'createdTimestamp': createdTimestamp ?? DateTime.now().millisecondsSinceEpoch,
    'cachedFileCount': cachedFileCount,
  };

  factory FolderModel.fromJson(Map<String, dynamic> json) {
    return FolderModel(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? 'Folder',
      path: json['path'] as String? ?? '',
      isDefault: json['isDefault'] as bool? ?? false,
      colorValue: json['colorValue'] as int?,
      createdTimestamp: json['createdTimestamp'] as int?,
      cachedFileCount: json['cachedFileCount'] as int?,
    );
  }

  /// Get normalized clean filesystem path
  String get normalizedPath {
    String clean = path.trim();
    if (clean.startsWith('file://')) {
      try {
        clean = Uri.parse(clean).toFilePath();
      } catch (_) {
        clean = clean.replaceFirst('file://', '');
      }
    }
    try {
      clean = Uri.decodeFull(clean);
    } catch (_) {}
    return clean;
  }

  /// Check if the folder directory actually exists on disk
  bool exists() {
    try {
      final targetPath = normalizedPath;
      var dir = Directory(targetPath);
      if (dir.existsSync()) return true;
      return Directory(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  /// Get the number of non-hidden files in this folder synchronously
  int getFileCountSync() {
    try {
      final targetPath = normalizedPath;
      var dir = Directory(targetPath);
      if (!dir.existsSync()) {
        dir = Directory(path);
      }
      if (dir.existsSync()) {
        final list = dir.listSync(followLinks: false, recursive: false);
        final count = list.where((entity) {
          if (entity is! File) return false;
          final base = p.basename(entity.path);
          if (base.startsWith('.')) return false;
          final ext = p.extension(entity.path).toLowerCase().replaceAll('.', '');
          return !const {
            'hive', 'lock', 'db', 'sqlite', 'sqlite3', 'tmp', 'temp', 'dat', 'bak', 'bin'
          }.contains(ext);
        }).length;
        if (count > 0) return count;
      }
    } catch (_) {}
    return cachedFileCount ?? 0;
  }
}
