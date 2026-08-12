/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'package:pdfhawk/data/models/writer_element.dart';

class WriterDocumentModel {
  final String quillDeltaJson;
  final List<WriterElement> overlays;
  final double? pageWidth;
  final double? pageHeight;
  final double? marginTop;
  final double? marginBottom;
  final double? marginLeft;
  final double? marginRight;

  WriterDocumentModel({
    required this.quillDeltaJson,
    required this.overlays,
    this.pageWidth,
    this.pageHeight,
    this.marginTop,
    this.marginBottom,
    this.marginLeft,
    this.marginRight,
  });

  Map<String, dynamic> toJson() => {
    'quillDeltaJson': quillDeltaJson,
    'overlays': overlays.map((e) => e.toJson()).toList(),
    'pageWidth': pageWidth,
    'pageHeight': pageHeight,
    'marginTop': marginTop,
    'marginBottom': marginBottom,
    'marginLeft': marginLeft,
    'marginRight': marginRight,
  };

  factory WriterDocumentModel.fromJson(Map<String, dynamic> json) {
    return WriterDocumentModel(
      quillDeltaJson: json['quillDeltaJson'] as String? ?? "[]",
      overlays: (json['overlays'] as List? ?? [])
          .map((e) => WriterElement.fromJson(e as Map<String, dynamic>))
          .toList(),
      pageWidth: (json['pageWidth'] as num?)?.toDouble(),
      pageHeight: (json['pageHeight'] as num?)?.toDouble(),
      marginTop: (json['marginTop'] as num?)?.toDouble(),
      marginBottom: (json['marginBottom'] as num?)?.toDouble(),
      marginLeft: (json['marginLeft'] as num?)?.toDouble(),
      marginRight: (json['marginRight'] as num?)?.toDouble(),
    );
  }
}
