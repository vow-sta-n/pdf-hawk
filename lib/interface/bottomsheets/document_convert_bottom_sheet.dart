/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:io';
import 'package:community_material_icon/community_material_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfhawk/logic/helpers/document_converter.dart';
import 'package:pdfhawk/data/res/constants.dart';

class DocumentConvertBottomSheet extends StatefulWidget {
  final File file;
  final String fileName;
  final String extension;
  final String fileSize;
  final Function(File outputPdfFile) onConversionSuccess;

  const DocumentConvertBottomSheet({
    super.key,
    required this.file,
    required this.fileName,
    required this.extension,
    required this.fileSize,
    required this.onConversionSuccess,
  });

  @override
  State<DocumentConvertBottomSheet> createState() =>
      _DocumentConvertBottomSheetState();
}

class _DocumentConvertBottomSheetState
    extends State<DocumentConvertBottomSheet> {
  bool _isConverting = false;

  IconData _getFileIcon() {
    switch (widget.extension) {
      case 'docx':
        return CommunityMaterialIcons.file_word_outline;
      case 'pptx':
        return CommunityMaterialIcons.file_powerpoint_outline;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  Color _getFileColor() {
    switch (widget.extension) {
      case 'docx':
        return Colors.blue;
      case 'pptx':
        return Colors.orange;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Colors.teal;
      default:
        return Colors.blueGrey;
    }
  }

  Future<void> _convert() async {
    setState(() {
      _isConverting = true;
    });

    try {
      final outputFile = await DocumentConverter.convertToPdf(widget.file);
      if (mounted) {
        Navigator.pop(context); // Close bottomsheet
        widget.onConversionSuccess(outputFile);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConverting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Conversion failed: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.r),
          topRight: Radius.circular(24.r),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag handle indicator
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: allradius(2.r),
            ),
          ),
          Gap(24.h),

          // File Icon Preview
          CircleAvatar(
            radius: 40.r,
            backgroundColor: _getFileColor().withValues(alpha: 0.15),
            child: Icon(_getFileIcon(), size: 44.r, color: _getFileColor()),
          ),
          Gap(16.h),

          // File Name
          Text(
            widget.fileName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          Gap(6.h),

          // File Details (Format, size)
          Text(
            "${widget.extension.toUpperCase()} Format • ${widget.fileSize}",
            style: GoogleFonts.instrumentSans(
              fontSize: 13.sp,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          Gap(28.h),

          // Actions
          if (_isConverting) ...[
            const CircularProgressIndicator(),
            Gap(12.h),
            Text(
              "Converting file to PDF locally...",
              style: TextStyle(
                fontSize: 12.sp,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: ElevatedButton.icon(
                onPressed: _convert,
                icon: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Colors.white,
                ),
                label: Text(
                  "Convert to PDF",
                  style: GoogleFonts.outfit(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: allradius(14.r),
                  ),
                ),
              ),
            ),
            Gap(12.h),
            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: allradius(14.r),
                  ),
                ),
                child: Text(
                  "Cancel",
                  style: GoogleFonts.outfit(
                    fontSize: 15.sp,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
