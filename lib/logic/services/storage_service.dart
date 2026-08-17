/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Central storage management service for PDF Hawk.
/// Handles resolving, creating, and saving exported files to the dedicated PDFHawk folder.
class StorageService {
  static const String appFolderName = 'PDFHawk';

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

  /// Saves exported byte data (PDF, Hawk document, image, etc.) into the PDFHawk directory.
  static Future<File> saveExportedFile({
    required String fileName,
    required List<int> bytes,
    String? subFolder,
  }) async {
    final dir = await getPDFHawkDirectory(subFolder: subFolder);
    final sanitizedName = fileName
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .trim();
    final filePath = p.join(dir.path, sanitizedName);
    final file = File(filePath);

    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Lists all exported files with a specific extension from the PDFHawk directory.
  static Future<List<File>> getExportedFiles({
    String? subFolder,
    String extension = '.pdf',
  }) async {
    try {
      final dir = await getPDFHawkDirectory(subFolder: subFolder);
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
      debugPrint("Failed to fetch exported files from PDFHawk directory: $e");
      return [];
    }
  }
}
