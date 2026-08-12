/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfhawk/interface/painters/signature_painter.dart';
import 'package:pdfhawk/logic/helpers/pdf_helper.dart';

class SignaturePadDialog extends StatefulWidget {
  final Function(List<DrawingPath>) onConfirm;

  const SignaturePadDialog({super.key, required this.onConfirm});

  @override
  State<SignaturePadDialog> createState() => _SignaturePadDialogState();
}

class _SignaturePadDialogState extends State<SignaturePadDialog> {
  final List<Offset> _currentPoints = [];
  final List<DrawingPath> _paths = [];

  void _clear() {
    setState(() {
      _currentPoints.clear();
      _paths.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Draw Signature",
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 18.sp,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: "Clear Signature",
            onPressed: _clear,
          ),
        ],
      ),
      content: SizedBox(
        width: 320.w,
        height: 200.h,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E24) : Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: isDark ? Colors.white24 : Colors.black12,
              width: 1.5,
            ),
          ),
          child: GestureDetector(
            onPanStart: (details) {
              setState(() {
                _currentPoints.clear();
                _currentPoints.add(details.localPosition);
              });
            },
            onPanUpdate: (details) {
              setState(() {
                _currentPoints.add(details.localPosition);
              });
            },
            onPanEnd: (_) {
              if (_currentPoints.isNotEmpty) {
                setState(() {
                  _paths.add(
                    DrawingPath(
                      points: List.from(_currentPoints),
                      color: isDark ? Colors.white : Colors.black,
                      strokeWidth: 3.0,
                      isHighlighter: false,
                    ),
                  );
                  _currentPoints.clear();
                });
              }
            },
            child: CustomPaint(
              painter: SignaturePainter(
                paths: _paths,
                currentPoints: _currentPoints,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _paths.isEmpty && _currentPoints.isEmpty
              ? null
              : () {
                  Navigator.pop(context);
                  widget.onConfirm(_paths);
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
          child: const Text("Apply Signature"),
        ),
      ],
    );
  }
}
