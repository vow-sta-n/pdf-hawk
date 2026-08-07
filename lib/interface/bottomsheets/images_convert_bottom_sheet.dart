import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfhawk/logic/helpers/document_converter.dart';

class ImagesConvertBottomSheet extends StatefulWidget {
  final List<File> files;
  final String fileSize;
  final Function(File outputPdfFile) onConversionSuccess;

  const ImagesConvertBottomSheet({
    super.key,
    required this.files,
    required this.fileSize,
    required this.onConversionSuccess,
  });

  @override
  State<ImagesConvertBottomSheet> createState() =>
      _ImagesConvertBottomSheetState();
}

class _ImagesConvertBottomSheetState extends State<ImagesConvertBottomSheet> {
  bool _isConverting = false;

  Future<void> _convert() async {
    setState(() {
      _isConverting = true;
    });

    try {
      final outputFile = await DocumentConverter.convertImagesToPdf(
        widget.files,
      );
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
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          Gap(24.h),

          // Horizontal list of images
          SizedBox(
            height: 120.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.files.length,
              separatorBuilder: (context, index) => Gap(12.w),
              itemBuilder: (context, index) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12.r),
                  child: Container(
                    width: 90.w,
                    height: 120.h,
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    child: Image.file(widget.files[index], fit: BoxFit.cover),
                  ),
                );
              },
            ),
          ),
          Gap(16.h),

          // File Name
          Text(
            widget.files.length == 1
                ? "Convert 1 Image"
                : "Convert ${widget.files.length} Images",
            maxLines: 1,
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
            "IMAGE Format • ${widget.fileSize}",
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
              "Converting images to PDF locally...",
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
                    borderRadius: BorderRadius.circular(14.r),
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
                    borderRadius: BorderRadius.circular(14.r),
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
