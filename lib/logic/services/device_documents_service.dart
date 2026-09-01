/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfhawk/logic/services/folder_storage_service.dart';
import 'package:pdfhawk/logic/services/storage_service.dart';

enum DocumentCategory {
  all,
  pdf,
  word,
  excel,
  ppt,
  text,
  hawk,
  other,
}

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

class DeviceDocumentsService {
  static final ValueNotifier<List<DeviceDocumentModel>> documentsNotifier =
      ValueNotifier<List<DeviceDocumentModel>>([]);
  static final ValueNotifier<bool> isScanningNotifier =
      ValueNotifier<bool>(false);

  static const String _cacheBoxKey = 'device_documents_cache';

  static const Set<String> _pdfExtensions = {'pdf'};
  static const Set<String> _wordExtensions = {'docx', 'doc', 'dot', 'dotx'};
  static const Set<String> _excelExtensions = {
    'xlsx',
    'xls',
    'csv',
    'xlt',
    'xltx',
  };
  static const Set<String> _pptExtensions = {
    'pptx',
    'ppt',
    'pps',
    'ppsx',
    'pot',
  };
  static const Set<String> _textExtensions = {'txt', 'md', 'rtf', 'log'};
  static const Set<String> _hawkExtensions = {'hawk'};
  static const Set<String> _otherExtensions = {'epub', 'odt', 'ods', 'odp'};

  /// Directory paths that should be skipped to prevent scanning system/app cache internals
  static const Set<String> _skippedDirNames = {
    'android',
    'node_modules',
    '.git',
    '.cache',
    '.thumbnails',
    '.trash',
    'cache',
    'temp',
    'tmp',
    '.system',
    '.gemini',
    '.gradle',
  };

  /// Determines document category based on extension
  static DocumentCategory getCategoryForExtension(String rawExt) {
    final ext = rawExt.toLowerCase().replaceAll('.', '');
    if (_pdfExtensions.contains(ext)) return DocumentCategory.pdf;
    if (_wordExtensions.contains(ext)) return DocumentCategory.word;
    if (_excelExtensions.contains(ext)) return DocumentCategory.excel;
    if (_pptExtensions.contains(ext)) return DocumentCategory.ppt;
    if (_textExtensions.contains(ext)) return DocumentCategory.text;
    if (_hawkExtensions.contains(ext)) return DocumentCategory.hawk;
    if (_otherExtensions.contains(ext)) return DocumentCategory.other;
    return DocumentCategory.other;
  }

  /// Checks whether an extension is a supported document
  static bool isSupportedDocument(String filePath) {
    final base = p.basename(filePath);
    if (base.startsWith('.')) return false;
    final ext = p.extension(filePath).toLowerCase().replaceAll('.', '');
    return _pdfExtensions.contains(ext) ||
        _wordExtensions.contains(ext) ||
        _excelExtensions.contains(ext) ||
        _pptExtensions.contains(ext) ||
        _textExtensions.contains(ext) ||
        _hawkExtensions.contains(ext) ||
        _otherExtensions.contains(ext);
  }

  /// Loads cached device documents from Hive instantly
  static List<DeviceDocumentModel> getCachedDocuments() {
    try {
      final box = Hive.box('pdfhawk_box');
      final rawList = box.get(_cacheBoxKey);
      if (rawList is List) {
        final List<DeviceDocumentModel> list = [];
        for (var item in rawList) {
          if (item is Map) {
            try {
              list.add(
                DeviceDocumentModel.fromJson(Map<String, dynamic>.from(item)),
              );
            } catch (_) {}
          }
        }
        if (list.isNotEmpty) {
          documentsNotifier.value = list;
          return list;
        }
      }
    } catch (e) {
      debugPrint("Error reading cached device documents: $e");
    }
    return documentsNotifier.value;
  }

  /// Scans device directories in the background for all documents
  static Future<List<DeviceDocumentModel>> scanDeviceDocuments({
    bool force = false,
  }) async {
    // If already scanning and not forced, return current values
    if (isScanningNotifier.value && !force) {
      return documentsNotifier.value;
    }

    isScanningNotifier.value = true;

    try {
      // 1. Check/request permission
      final hasPermission =
          await FolderStorageService.isStoragePermissionGranted();
      if (!hasPermission && Platform.isAndroid) {
        // Attempt quick permission check without blocking UI
        FolderStorageService.ensureStoragePermission();
      }

      final Set<String> targetDirectories = {};

      // 2. Identify search roots
      if (Platform.isAndroid) {
        final primaryStorage = Directory('/storage/emulated/0');
        if (primaryStorage.existsSync()) {
          // Add common standard user folders
          final commonPaths = [
            '/storage/emulated/0/Download',
            '/storage/emulated/0/Documents',
            '/storage/emulated/0/PDFHawk',
            '/storage/emulated/0/DCIM',
            '/storage/emulated/0/Pictures',
            '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Documents',
            '/storage/emulated/0/WhatsApp/Media/WhatsApp Documents',
            '/storage/emulated/0/Telegram/Telegram Documents',
            '/storage/emulated/0/Download/Telegram',
          ];

          for (final path in commonPaths) {
            if (Directory(path).existsSync()) {
              targetDirectories.add(path);
            }
          }

          // Add top-level user directories under /storage/emulated/0
          try {
            final topEntities = primaryStorage.listSync(followLinks: false);
            for (final entity in topEntities) {
              if (entity is Directory) {
                final dirName = p.basename(entity.path).toLowerCase();
                if (!dirName.startsWith('.') &&
                    !_skippedDirNames.contains(dirName)) {
                  targetDirectories.add(entity.path);
                }
              }
            }
          } catch (_) {}
        }
      }

      // 3. Add PDFHawk internal directories and application docs
      try {
        final pdfHawkDir = await StorageService.getPDFHawkDirectory();
        if (pdfHawkDir.existsSync()) {
          targetDirectories.add(pdfHawkDir.path);
        }
      } catch (_) {}

      try {
        final appDocsDir = await getApplicationDocumentsDirectory();
        if (appDocsDir.existsSync()) {
          targetDirectories.add(appDocsDir.path);
        }
      } catch (_) {}

      try {
        final extStorageDir = await getExternalStorageDirectory();
        if (extStorageDir != null && extStorageDir.existsSync()) {
          targetDirectories.add(extStorageDir.path);
        }
      } catch (_) {}

      try {
        final downloadsDir = await getDownloadsDirectory();
        if (downloadsDir != null && downloadsDir.existsSync()) {
          targetDirectories.add(downloadsDir.path);
        }
      } catch (_) {}

      // 4. Scan all collected directories recursively
      final Map<String, DeviceDocumentModel> discoveredMap = {};

      for (final rootPath in targetDirectories) {
        await _scanDirectoryRecursively(
          Directory(rootPath),
          discoveredMap,
          maxDepth: 4,
          currentDepth: 0,
        );
      }

      final List<DeviceDocumentModel> discoveredList = discoveredMap.values
          .toList()
        ..sort((a, b) => b.lastModified.compareTo(a.lastModified));

      // 5. Update cache and notify UI listeners
      documentsNotifier.value = discoveredList;

      try {
        final box = Hive.box('pdfhawk_box');
        final rawList = discoveredList.map((d) => d.toJson()).toList();
        await box.put(_cacheBoxKey, rawList);
      } catch (e) {
        debugPrint("Error writing device documents cache: $e");
      }

      return discoveredList;
    } catch (e) {
      debugPrint("DeviceDocumentsService.scanDeviceDocuments error: $e");
      return documentsNotifier.value;
    } finally {
      isScanningNotifier.value = false;
    }
  }

  /// Helper to safely scan directories recursively with depth bounding
  static Future<void> _scanDirectoryRecursively(
    Directory dir,
    Map<String, DeviceDocumentModel> results, {
    required int maxDepth,
    required int currentDepth,
  }) async {
    if (currentDepth > maxDepth) return;

    try {
      if (!dir.existsSync()) return;

      final entities = dir.listSync(followLinks: false);
      for (final entity in entities) {
        if (entity is File) {
          final filePath = entity.path;
          if (isSupportedDocument(filePath) &&
              !results.containsKey(filePath)) {
            try {
              final stat = entity.statSync();
              final ext = p
                  .extension(filePath)
                  .toLowerCase()
                  .replaceAll('.', '');
              final cat = getCategoryForExtension(ext);

              results[filePath] = DeviceDocumentModel(
                path: filePath,
                name: p.basename(filePath),
                extension: ext,
                size: stat.size,
                lastModified: stat.modified,
                category: cat,
              );
            } catch (_) {}
          }
        } else if (entity is Directory) {
          final dirName = p.basename(entity.path).toLowerCase();
          if (!dirName.startsWith('.') && !_skippedDirNames.contains(dirName)) {
            await _scanDirectoryRecursively(
              entity,
              results,
              maxDepth: maxDepth,
              currentDepth: currentDepth + 1,
            );
          }
        }
      }
    } catch (_) {
      // Ignore permission denied on specific subfolders
    }
  }

  /// Filter documents by category
  static List<DeviceDocumentModel> filterByCategory(
    List<DeviceDocumentModel> docs,
    DocumentCategory category,
  ) {
    if (category == DocumentCategory.all) return docs;
    return docs.where((doc) => doc.category == category).toList();
  }

  /// Search documents by name query
  static List<DeviceDocumentModel> searchDocuments(
    List<DeviceDocumentModel> docs,
    String query,
  ) {
    if (query.trim().isEmpty) return docs;
    final lower = query.toLowerCase().trim();
    return docs.where((doc) => doc.name.toLowerCase().contains(lower)).toList();
  }
}
