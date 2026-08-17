/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:pdfhawk/logic/services/storage_service.dart';

class HawkCryptoService {
  static const String _defaultKey = "PDFHAWK_SECRET_ENCRYPTION_KEY_2026_V1";
  static const String _headerMagic = "HAWKDOC1"; // 8 bytes magic header

  /// Encrypts JSON string content with hardcoded key into Uint8List with header
  static Uint8List encryptJson(String jsonString, {String? key}) {
    final secretKey = key ?? _defaultKey;
    final headerBytes = utf8.encode(_headerMagic);
    final contentBytes = utf8.encode(jsonString);
    final keyBytes = utf8.encode(secretKey);

    final encryptedBytes = Uint8List(contentBytes.length);
    for (int i = 0; i < contentBytes.length; i++) {
      encryptedBytes[i] = contentBytes[i] ^ keyBytes[i % keyBytes.length];
    }

    final result = Uint8List(headerBytes.length + encryptedBytes.length);
    result.setRange(0, headerBytes.length, headerBytes);
    result.setRange(headerBytes.length, result.length, encryptedBytes);
    return result;
  }

  /// Decrypts Uint8List bytes of a .hawk file into JSON string
  static String decryptHawkBytes(Uint8List bytes, {String? key}) {
    final secretKey = key ?? _defaultKey;
    final headerBytes = utf8.encode(_headerMagic);

    if (bytes.length < headerBytes.length) {
      throw FormatException("Invalid .hawk file: File too short.");
    }

    // Verify magic header
    for (int i = 0; i < headerBytes.length; i++) {
      if (bytes[i] != headerBytes[i]) {
        throw FormatException("Invalid .hawk file: Header signature mismatch.");
      }
    }

    final keyBytes = utf8.encode(secretKey);
    final payloadBytes = bytes.sublist(headerBytes.length);
    final decryptedBytes = Uint8List(payloadBytes.length);

    for (int i = 0; i < payloadBytes.length; i++) {
      decryptedBytes[i] = payloadBytes[i] ^ keyBytes[i % keyBytes.length];
    }

    return utf8.decode(decryptedBytes);
  }

  /// Decrypts a .hawk File from storage
  static Future<Map<String, dynamic>> readHawkFile(File file) async {
    final bytes = await file.readAsBytes();
    final jsonStr = decryptHawkBytes(bytes);
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }

  /// Saves document JSON to a .hawk file in app storage or given folder
  static Future<File> saveHawkFile(String docName, Map<String, dynamic> jsonMap, {String? folderPath}) async {
    final sanitizedName = docName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    final fileName = sanitizedName.endsWith('.hawk') ? sanitizedName : '$sanitizedName.hawk';

    String targetDir;
    if (folderPath != null && folderPath.isNotEmpty) {
      targetDir = folderPath;
    } else {
      final hawkDir = await StorageService.getPDFHawkDirectory(subFolder: 'HawkDocuments');
      targetDir = hawkDir.path;
    }

    final filePath = p.join(targetDir, fileName);
    final file = File(filePath);

    final jsonStr = jsonEncode(jsonMap);
    final encrypted = encryptJson(jsonStr);

    await file.writeAsBytes(encrypted, flush: true);
    return file;
  }

  /// Returns list of all saved .hawk files from default HawkDocuments storage directory
  static Future<List<File>> getSavedHawkFiles() async {
    try {
      final List<File> files = [];

      // 1. Primary PDFHawk/HawkDocuments storage directory
      final hawkDir = await StorageService.getPDFHawkDirectory(subFolder: 'HawkDocuments');
      if (await hawkDir.exists()) {
        final entities = await hawkDir.list().toList();
        files.addAll(
          entities.whereType<File>().where(
            (f) => f.path.toLowerCase().endsWith('.hawk'),
          ),
        );
      }

      // 2. Legacy app documents directory for backwards compatibility
      final appDir = await getApplicationDocumentsDirectory();
      final legacyHawkDir = Directory(p.join(appDir.path, 'HawkDocuments'));
      if (legacyHawkDir.path != hawkDir.path && await legacyHawkDir.exists()) {
        final legacyEntities = await legacyHawkDir.list().toList();
        for (final entity in legacyEntities.whereType<File>()) {
          if (entity.path.toLowerCase().endsWith('.hawk') &&
              !files.any((f) => p.basename(f.path) == p.basename(entity.path))) {
            files.add(entity);
          }
        }
      }

      // Sort by modified date descending (newest first)
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      return files;
    } catch (e) {
      debugPrint("Failed to fetch saved .hawk files: $e");
      return [];
    }
  }

  /// Deletes a saved .hawk file
  static Future<void> deleteHawkFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint("Failed to delete .hawk file: $e");
    }
  }
}
