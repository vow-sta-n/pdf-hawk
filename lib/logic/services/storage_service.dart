/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:pdfhawk/logic/services/folder_storage_service.dart';

/// Central storage management service for PDF Hawk.
/// Handles resolving, creating, and saving exported files to the dedicated PDFHawk folder or user-configured custom folders.
class StorageService {
  static const String appFolderName = 'PDFHawk';
  static const String keyCustomPdfSaveDir = 'custom_pdf_save_dir';
  static const String keyCustomHawkSaveDir = 'custom_hawk_save_dir';

  /// Get custom PDF save directory path from storage (null if default)
  static Future<String?> getCustomPdfSaveDirectory() async {
    try {
      final box = Hive.box('pdfhawk_box');
      return box.get(keyCustomPdfSaveDir) as String?;
    } catch (_) {
      return null;
    }
  }

  /// Set or reset custom PDF save directory path (pass null to reset to default)
  static Future<void> setCustomPdfSaveDirectory(String? path) async {
    try {
      final box = Hive.box('pdfhawk_box');
      if (path == null || path.isEmpty) {
        await box.delete(keyCustomPdfSaveDir);
      } else {
        final clean = FolderStorageService.normalizePath(path);
        await box.put(keyCustomPdfSaveDir, clean);
      }
    } catch (e) {
      debugPrint("Failed to set custom PDF save directory: $e");
    }
  }

  /// Get custom Hawk (.hawk) documents save directory path from storage (null if default)
  static Future<String?> getCustomHawkSaveDirectory() async {
    try {
      final box = Hive.box('pdfhawk_box');
      return box.get(keyCustomHawkSaveDir) as String?;
    } catch (_) {
      return null;
    }
  }

  /// Set or reset custom Hawk (.hawk) documents save directory path (pass null to reset to default)
  static Future<void> setCustomHawkSaveDirectory(String? path) async {
    try {
      final box = Hive.box('pdfhawk_box');
      if (path == null || path.isEmpty) {
        await box.delete(keyCustomHawkSaveDir);
      } else {
        final clean = FolderStorageService.normalizePath(path);
        await box.put(keyCustomHawkSaveDir, clean);
      }
    } catch (e) {
      debugPrint("Failed to set custom Hawk save directory: $e");
    }
  }

  /// Resolves the effective directory for saving modified/exported PDFs
  static Future<Directory> getEffectivePdfSaveDirectory() async {
    final customPath = await getCustomPdfSaveDirectory();
    if (customPath != null && customPath.isNotEmpty) {
      final customDir = Directory(customPath);
      try {
        if (!await customDir.exists()) {
          await customDir.create(recursive: true);
        }
        return customDir;
      } catch (e) {
        debugPrint("Custom PDF directory unavailable ($e), falling back to default");
      }
    }
    return await getPDFHawkDirectory();
  }

  /// Resolves the effective directory for saving created/auto-saved .hawk documents
  static Future<Directory> getEffectiveHawkSaveDirectory() async {
    final customPath = await getCustomHawkSaveDirectory();
    if (customPath != null && customPath.isNotEmpty) {
      final customDir = Directory(customPath);
      try {
        if (!await customDir.exists()) {
          await customDir.create(recursive: true);
        }
        return customDir;
      } catch (e) {
        debugPrint("Custom Hawk directory unavailable ($e), falling back to default");
      }
    }
    return await getPDFHawkDirectory(subFolder: 'HawkDocuments');
  }

  /// Resolves and ensures the primary PDFHawk folder in device storage exists.
  ///
  /// Storage resolution order:
  /// - Android: User-visible Documents folder (`/storage/emulated/0/Documents/PDFHawk`)
  ///   with automatic fallback to app-specific external storage (`/Android/data/.../files/PDFHawk`)
  /// - iOS: Application Documents folder (`.../Documents/PDFHawk`)
  /// - Desktop: Downloads directory (`.../Downloads/PDFHawk`)
  static Future<Directory> getPDFHawkDirectory({String? subFolder}) async {
    Directory targetDir;

    if (Platform.isAndroid) {
      // 1. Try public user-visible Documents/PDFHawk directory
      final publicDocsDir = Directory(
        '/storage/emulated/0/Documents/$appFolderName',
      );
      try {
        if (!await publicDocsDir.exists()) {
          await publicDocsDir.create(recursive: true);
        }
        targetDir = publicDocsDir;
      } catch (e) {
        debugPrint(
          "Public Documents access restricted, falling back to app external storage: $e",
        );
        // 2. Fallback to App External Storage
        final extDir = await getExternalStorageDirectory();
        final basePath =
            extDir?.path ?? (await getApplicationDocumentsDirectory()).path;
        targetDir = Directory(p.join(basePath, appFolderName));
      }
    } else if (Platform.isIOS) {
      final appDocs = await getApplicationDocumentsDirectory();
      targetDir = Directory(p.join(appDocs.path, appFolderName));
    } else {
      final baseDir =
          await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      targetDir = Directory(p.join(baseDir.path, appFolderName));
    }

    if (subFolder != null && subFolder.isNotEmpty) {
      targetDir = Directory(p.join(targetDir.path, subFolder));
    }

    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    return targetDir;
  }

  /// Saves exported byte data (PDF, Hawk document, image, etc.) into the appropriate directory.
  static Future<File> saveExportedFile({
    required String fileName,
    required List<int> bytes,
    String? subFolder,
    String? customDirectoryPath,
  }) async {
    Directory dir;
    if (customDirectoryPath != null && customDirectoryPath.isNotEmpty) {
      dir = Directory(customDirectoryPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } else if (subFolder == 'HawkDocuments') {
      dir = await getEffectiveHawkSaveDirectory();
    } else if (subFolder == null || subFolder.isEmpty) {
      dir = await getEffectivePdfSaveDirectory();
    } else {
      dir = await getPDFHawkDirectory(subFolder: subFolder);
    }

    final sanitizedName = fileName
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .trim();
    final filePath = p.join(dir.path, sanitizedName);
    final file = File(filePath);

    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Lists all exported files with a specific extension from the PDFHawk directory or custom PDF save directory.
  static Future<List<File>> getExportedFiles({
    String? subFolder,
    String extension = '.pdf',
  }) async {
    try {
      final dir = subFolder == null || subFolder.isEmpty
          ? await getEffectivePdfSaveDirectory()
          : await getPDFHawkDirectory(subFolder: subFolder);
      final entities = await dir.list().toList();
      final files = entities
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith(extension.toLowerCase()))
          .toList();

      files.sort(
        (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
      );
      return files;
    } catch (e) {
      debugPrint("Failed to fetch exported files: $e");
      return [];
    }
  }
}
