import 'dart:io';
import 'package:pdfhawk/data/res/enum.dart';

class DeviceDocumentModel {
  final String path;
  final String name;
  final String extension;
  final int size;
  final DateTime lastModified;
  final DocumentCategory category;

  const DeviceDocumentModel({
    required this.path,
    required this.name,
    required this.extension,
    required this.size,
    required this.lastModified,
    required this.category,
  });

  Map<String, dynamic> toJson() => {
    'path': path,
    'name': name,
    'extension': extension,
    'size': size,
    'lastModified': lastModified.millisecondsSinceEpoch,
    'category': category.name,
  };

  factory DeviceDocumentModel.fromJson(Map<String, dynamic> json) {
    DocumentCategory cat = DocumentCategory.other;
    try {
      cat = DocumentCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => DocumentCategory.other,
      );
    } catch (_) {}

    return DeviceDocumentModel(
      path: json['path'] as String,
      name: json['name'] as String,
      extension: json['extension'] as String,
      size: json['size'] as int? ?? 0,
      lastModified: DateTime.fromMillisecondsSinceEpoch(
        json['lastModified'] as int? ?? 0,
      ),
      category: cat,
    );
  }

  File get file => File(path);

  bool get exists => File(path).existsSync();

  String get formattedSize {
    if (size < 1024) return "$size B";
    if (size < 1024 * 1024) {
      return "${(size / 1024).toStringAsFixed(1)} KB";
    }
    return "${(size / (1024 * 1024)).toStringAsFixed(2)} MB";
  }
}
