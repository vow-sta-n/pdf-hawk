/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfhawk/data/res/theme.dart';
import 'package:pdfhawk/logic/helpers/pdf_helper.dart';

/// An overlay widget that renders an invisible, selectable text layer over a PDF page
/// matching exact text coordinates and font sizes.
class PdfSelectableTextLayer extends StatefulWidget {
  final File? pdfFile;
  final int pageNumber;
  final double pageWidth;
  final double pageHeight;
  final double scaleX;
  final double scaleY;
  final bool isSelectionEnabled;

  const PdfSelectableTextLayer({
    super.key,
    required this.pdfFile,
    required this.pageNumber,
    required this.pageWidth,
    required this.pageHeight,
    required this.scaleX,
    required this.scaleY,
    required this.isSelectionEnabled,
  });

  @override
  State<PdfSelectableTextLayer> createState() => _PdfSelectableTextLayerState();
}

class _PdfSelectableTextLayerState extends State<PdfSelectableTextLayer> {
  List<PdfTextLineModel>? _textLines;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTextLines();
  }

  @override
  void didUpdateWidget(covariant PdfSelectableTextLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pdfFile?.path != widget.pdfFile?.path ||
        oldWidget.pageNumber != widget.pageNumber) {
      _loadTextLines();
    }
  }

  Future<void> _loadTextLines() async {
    if (widget.pdfFile == null) {
      if (mounted) setState(() => _textLines = []);
      return;
    }

    if (_isLoading) return;
    _isLoading = true;

    try {
      final lines = await PdfHelper.extractPageTextLines(
        pdfFile: widget.pdfFile!,
        pageNumber: widget.pageNumber,
      );
      if (mounted) {
        setState(() {
          _textLines = lines;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _textLines = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_textLines == null || _textLines!.isEmpty) {
      return const SizedBox.shrink();
    }

    final sx = widget.scaleX;
    final sy = widget.scaleY;

    final content = Stack(
      clipBehavior: Clip.none,
      children: [
        for (final line in _textLines!)
          Positioned(
            left: line.bounds.left * sx,
            top: line.bounds.top * sy,
            width: (line.bounds.width * sx).clamp(1.0, double.infinity),
            height: (line.bounds.height * sy).clamp(1.0, double.infinity),
            child: FittedBox(
              fit: BoxFit.fill,
              alignment: Alignment.centerLeft,
              child: Text(
                line.text,
                style: TextStyle(
                  fontSize: line.fontSize * sy > 0 ? line.fontSize * sy : 14.0,
                  color: Colors.transparent,
                  height: 1.0,
                ),
              ),
            ),
          ),
      ],
    );

    return IgnorePointer(
      ignoring: !widget.isSelectionEnabled,
      child: DefaultSelectionStyle(
        selectionColor: royalblue.withValues(alpha: 0.35),
        cursorColor: royalblue,
        child: SelectionArea(
          child: content,
        ),
      ),
    );
  }
}
