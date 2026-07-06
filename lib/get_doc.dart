import 'package:flutter/material.dart';
import 'package:saf/saf.dart';

enum DocumentType {
  all,
  pdf,
  document,
  ppt,
  text,
}

Future<List<String>> fetchDocumentsFromStorage({
  required String directoryUri,
  DocumentType type = DocumentType.all,
}) async {
  try {
    // Get all files recursively
    List<String>? allFiles = await Saf.getFilesPathFor(
      directoryUri,
      fileType: "any",
    );

    if (allFiles == null || allFiles.isEmpty) return [];

    final List<String> filtered = [];

    for (final path in allFiles) {
      final name = path.split('/').last.toLowerCase();

      switch (type) {
        case DocumentType.pdf:
          if (name.endsWith(".pdf")) filtered.add(path);
          break;

        case DocumentType.document:
          if (name.endsWith(".doc") || name.endsWith(".docx")) {
            filtered.add(path);
          }
          break;

        case DocumentType.ppt:
          if (name.endsWith(".ppt") || name.endsWith(".pptx")) {
            filtered.add(path);
          }
          break;

        case DocumentType.text:
          if (name.endsWith(".txt")) filtered.add(path);
          break;

        case DocumentType.all:
          if (name.endsWith(".pdf") ||
              name.endsWith(".doc") ||
              name.endsWith(".docx") ||
              name.endsWith(".ppt") ||
              name.endsWith(".pptx") ||
              name.endsWith(".txt")) {
            filtered.add(path);
          }
          break;
      }
    }

    return filtered;
  } catch (e) {
    debugPrint("Document fetch failed: $e");
    return [];
  }
}
