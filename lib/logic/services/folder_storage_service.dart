/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:pdfhawk/data/models/folder_model.dart';
import 'package:permission_handler/permission_handler.dart';

class FolderStorageService {
  /// Internal system and database file extensions that should never be shown in document lists
  static const Set<String> _ignoredExtensions = {
    'hive',
    'lock',
    'db',
    'sqlite',
    'sqlite3',
    'tmp',
    'temp',
    'dat',
    'bak',
    'bin',
    'properties',
    'class',
    'dex',
    'apk',
    'aab',
    'so',
  };

  /// Normalizes path from file picker / URI
  static String normalizePath(String rawPath) {
    String clean = rawPath.trim();
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

  /// Checks if a file is a valid user-facing document and not an internal database or hidden system file
  static bool isUserVisibleDocument(String filePath) {
    final base = p.basename(filePath);
    if (base.startsWith('.')) return false;
    final ext = p.extension(filePath).toLowerCase().replaceAll('.', '');
    if (_ignoredExtensions.contains(ext)) return false;
    return true;
  }

  /// Request all-files / storage access permission on Android
  static Future<bool> ensureStoragePermission() async {
    if (!Platform.isAndroid) return true;

    try {
      // 1. Android 11+ (API 30+) Manage External Storage
      final manageStatus = await Permission.manageExternalStorage.status;
      if (manageStatus.isGranted) return true;

      final reqManage = await Permission.manageExternalStorage.request();
      if (reqManage.isGranted) return true;

      // 2. Standard storage permission (Android 10 and below)
      final storageStatus = await Permission.storage.status;
      if (storageStatus.isGranted) return true;

      final reqStorage = await Permission.storage.request();
      if (reqStorage.isGranted) return true;

      // 3. Media permissions
      await Permission.photos.request();
      await Permission.videos.request();
      await Permission.audio.request();
    } catch (e) {
      debugPrint("FolderStorageService.ensureStoragePermission error: $e");
    }

    return await isStoragePermissionGranted();
  }

  /// Check whether storage permission is granted
  static Future<bool> isStoragePermissionGranted() async {
    if (!Platform.isAndroid) return true;
    try {
      if (await Permission.manageExternalStorage.isGranted) return true;
      if (await Permission.storage.isGranted) return true;
    } catch (_) {}
    return false;
  }

  /// Scans and returns all user-facing document files in the given folder
  /// Uses direct directory listing and subfolder recursive scanning.
  static Future<List<File>> getFolderFiles(
    FolderModel folder, {
    bool recursive = true,
  }) async {
    final List<File> result = [];
    final Set<String> seenPaths = {};

    final targetPath = folder.normalizedPath;

    // 1. Try standard filesystem listing on normalized path
    try {
      var dir = Directory(targetPath);
      if (!await dir.exists()) {
        dir = Directory(folder.path);
      }

      if (await dir.exists()) {
        final entities = await dir
            .list(followLinks: false, recursive: false)
            .toList();
        for (var entity in entities) {
          if (entity is File) {
            if (isUserVisibleDocument(entity.path) && !seenPaths.contains(entity.path)) {
              seenPaths.add(entity.path);
              result.add(entity);
            }
          }
        }

        // If direct listing had no files, search subfolders if recursive is enabled
        if (result.isEmpty && recursive) {
          final subEntities = await dir
              .list(followLinks: false, recursive: true)
              .toList();
          for (var entity in subEntities) {
            if (entity is File) {
              if (isUserVisibleDocument(entity.path) && !seenPaths.contains(entity.path)) {
                seenPaths.add(entity.path);
                result.add(entity);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Directory listing failed: $e");
    }

    return result;
  }

  /// Synchronously or quickly get cached/direct file count
  static int getFolderFileCount(FolderModel folder) {
    try {
      final targetPath = folder.normalizedPath;
      var dir = Directory(targetPath);
      if (!dir.existsSync()) {
        dir = Directory(folder.path);
      }
      if (dir.existsSync()) {
        final list = dir.listSync(followLinks: false, recursive: false);
        final count = list.where((e) => e is File && isUserVisibleDocument(e.path)).length;
        if (count > 0) return count;
      }
    } catch (_) {}
    return folder.cachedFileCount ?? 0;
  }
}
