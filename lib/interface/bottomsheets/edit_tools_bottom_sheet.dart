/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:io';
import 'package:community_material_icon/community_material_icon.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:pdfhawk/data/class/p_d_f_hawk_icons_icons.dart';
import 'package:pdfhawk/data/res/constants.dart';
import 'package:pdfhawk/data/res/theme.dart';
import 'package:pdfhawk/data/res/utils.dart';
import 'package:pdfhawk/interface/bottomsheets/document_convert_bottom_sheet.dart';
import 'package:pdfhawk/interface/bottomsheets/images_convert_bottom_sheet.dart';
import 'package:pdfhawk/interface/dialogs/split_pdf_dialog.dart';
import 'package:pdfhawk/interface/pages/PDFTools/merge_pdfs_page.dart';
import 'package:pdfhawk/interface/pages/FileViewers/pdf_reader_page.dart';
import 'package:pdfhawk/interface/pages/PDFTools/rearrange_pdf_page.dart';
import 'package:pdfhawk/interface/widgets/bubble_button.dart';
import 'package:pdfhawk/interface/widgets/glass_grid_tile_button.dart';
import 'package:pdfhawk/logic/helpers/pdf_helper.dart';

class EditToolsBottomSheet extends StatefulWidget {
  final ThemeData theme;
  final bool isDark;
  final File? pdf;
  const EditToolsBottomSheet({
    super.key,
    required this.theme,
    required this.isDark,
    this.pdf,
  });

  @override
  State<EditToolsBottomSheet> createState() => _EditToolsBottomSheetState();
}

class _EditToolsBottomSheetState extends State<EditToolsBottomSheet> {
  Future<void> _pickAndSplitPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => SplitPdfDialog(pdfFile: file),
        );
      }
    }
  }

  Future<void> _pickAndMergePdfs() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );

    if (result != null && result.paths.isNotEmpty) {
      final pdfFiles = result.paths
          .whereType<String>()
          .map((p) => File(p))
          .toList();

      if (pdfFiles.isNotEmpty && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MergePdfsPage(initialPdfFiles: pdfFiles),
          ),
        );
      }
    }
  }

  Future<void> _pickAndRearrangePdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReArrangePDFPage(pdfFile: file),
          ),
        );
      }
    }
  }

  Future<void> _pickAndConvertFile() async {
    const supportedExts = [
      'docx',
      'pptx',
      'txt',
      'jpg',
      'jpeg',
      'png',
      'webp',
      'bmp',
    ];
    final imageExts = {'jpg', 'jpeg', 'png', 'webp', 'bmp'};

    // 1. Show convertable file extensions in a toast message before opening device storage
    plainToast(
      msg: "Select convertible file (DOCX, PPTX, TXT, JPG, PNG, WEBP, BMP)",
      toastLength: Toast.LENGTH_LONG,
    );

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: supportedExts,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return;

      final validFiles = <File>[];
      final invalidFileNames = <String>[];

      for (var f in result.files) {
        if (f.path != null) {
          final ext = p.extension(f.path!).toLowerCase().replaceAll('.', '');
          if (supportedExts.contains(ext)) {
            validFiles.add(File(f.path!));
          } else {
            invalidFileNames.add(f.name);
          }
        }
      }

      if (invalidFileNames.isNotEmpty) {
        plainToast(
          msg:
              "Cannot convert unsupported files: ${invalidFileNames.join(', ')}",
          toastLength: Toast.LENGTH_LONG,
        );
        if (validFiles.isEmpty) return;
      }

      if (!mounted || validFiles.isEmpty) return;

      // If all selected files are images
      final allImages = validFiles.every((f) {
        final ext = p.extension(f.path).toLowerCase().replaceAll('.', '');
        return imageExts.contains(ext);
      });

      if (allImages) {
        int totalBytes = 0;
        for (var file in validFiles) {
          totalBytes += file.lengthSync();
        }
        final fileSizeString = "${(totalBytes / 1024).toStringAsFixed(1)} KB";

        if (!mounted) return;
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) {
            return ImagesConvertBottomSheet(
              files: validFiles,
              fileSize: fileSizeString,
              onConversionSuccess: (outputPdfFile) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PDFReaderPage(pdfFile: outputPdfFile),
                  ),
                );
              },
            );
          },
        );
      } else {
        // Document (DOCX, PPTX, TXT)
        final firstFile = validFiles.first;
        final fileName = p.basename(firstFile.path);
        final extension = p
            .extension(firstFile.path)
            .toLowerCase()
            .replaceAll('.', '');
        final bytesCount = firstFile.lengthSync();
        final fileSizeString = "${(bytesCount / 1024).toStringAsFixed(1)} KB";

        if (!mounted) return;
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) {
            return DocumentConvertBottomSheet(
              file: firstFile,
              fileName: fileName,
              extension: extension,
              fileSize: fileSizeString,
              onConversionSuccess: (outputPdfFile) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PDFReaderPage(pdfFile: outputPdfFile),
                  ),
                );
              },
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        plainToast(msg: "Error picking file for conversion!");
      }
      debugPrint(e.toString());
    }
  }

  Future<void> _pickAndCompressFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      if (!mounted) return;

      final isDark = Theme.of(context).brightness == Brightness.dark;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: allradius(16.r)),
          content: Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: Row(
              children: [
                const CircularProgressIndicator(color: royalblue),
                Gap(16.w),
                Expanded(
                  child: Text(
                    "Compressing file...",
                    style: GoogleFonts.instrumentSans(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final originalSize = await file.length();
      final compressedFile = await PdfHelper.compressPdfOrImageFile(
        inputFile: file,
      );

      if (mounted) Navigator.pop(context);

      if (compressedFile != null && compressedFile.existsSync()) {
        final newSize = await compressedFile.length();
        final savedBytes = originalSize > newSize ? originalSize - newSize : 0;
        final savedPercentage = originalSize > 0
            ? ((savedBytes / originalSize) * 100).toStringAsFixed(1)
            : "0";

        final originalFormatted = (originalSize / (1024 * 1024))
            .toStringAsFixed(2);
        final newFormatted = (newSize / (1024 * 1024)).toStringAsFixed(2);

        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: allradius(18.r)),
              title: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.greenAccent,
                  ),
                  Gap(10.w),
                  Text(
                    "Compressed!",
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Original: $originalFormatted MB",
                    style: GoogleFonts.instrumentSans(
                      fontSize: 14.sp,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  Gap(4.h),
                  Text(
                    "Compressed: $newFormatted MB",
                    style: GoogleFonts.instrumentSans(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: royalblue,
                    ),
                  ),
                  Gap(4.h),
                  Text(
                    "Saved $savedPercentage% of file size",
                    style: GoogleFonts.instrumentSans(
                      fontSize: 13.sp,
                      color: Colors.greenAccent,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Done"),
                ),
                if (compressedFile.path.endsWith('.pdf'))
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: royalblue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: allradius(10.r),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PDFReaderPage(pdfFile: compressedFile),
                        ),
                      );
                    },
                    child: const Text("Open File"),
                  ),
              ],
            ),
          );
        }
      } else {
        if (mounted) {
          plainToast(msg: "Failed to compress file.");
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.isDark ? const Color(0xFF161616) : Colors.white,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(16.r),
        topRight: Radius.circular(16.r),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Gap(15.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  BubbleButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
              Gap(20.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Tools & Options",
                      style: GoogleFonts.outfit(
                        height: 1,
                        fontSize: 32.sp,
                        fontWeight: FontWeight.bold,
                        color: widget.isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Gap(6.h),
                    Text(
                      "Select an edit tool to manage and transform your PDFs",
                      style: GoogleFonts.instrumentSans(
                        fontSize: 14.sp,
                        color: widget.isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Gap(26.h),

              // 2x2 Grid of Edit Options
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                padding: EdgeInsets.symmetric(horizontal: 10.w),
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12.w,
                mainAxisSpacing: 12.h,
                childAspectRatio: 1.45,
                children: [
                  GlassGridTileButton(
                    icon: PDFHawkIcons.file_word,
                    title: "Convert",
                    description: "Images or DOCX to PDF",
                    onTap: _pickAndConvertFile,
                    theme: widget.theme,
                    isDark: widget.isDark,
                  ),
                  GlassGridTileButton(
                    icon: PDFHawkIcons.split,
                    title: "Split",
                    description: "Divide PDF into parts",
                    onTap: _pickAndSplitPdf,
                    theme: widget.theme,
                    isDark: widget.isDark,
                  ),
                  GlassGridTileButton(
                    icon: PDFHawkIcons.merge,
                    title: "Merge",
                    description: "Combine multiple PDFs",
                    onTap: _pickAndMergePdfs,
                    theme: widget.theme,
                    isDark: widget.isDark,
                  ),
                  GlassGridTileButton(
                    icon: Icons.grid_view_rounded,
                    title: "Rearrange",
                    description: "Reorder & edit pages",
                    onTap: _pickAndRearrangePdf,
                    theme: widget.theme,
                    isDark: widget.isDark,
                  ),
                  GlassGridTileButton(
                    icon: Icons.compress_outlined,
                    title: "Compress",
                    description: "Compress Images or PDF",
                    onTap: _pickAndCompressFile,
                    theme: widget.theme,
                    isDark: widget.isDark,
                  ),
                  GlassGridTileButton(
                    icon: CommunityMaterialIcons.text_recognition,
                    title: "Extract Text",
                    description: "Extract text from PDF",
                    onTap: () {},
                    theme: widget.theme,
                    isDark: widget.isDark,
                  ),
                ],
              ),
              Gap(12.h),

              // // Extract Text Tile Button
              // if (widget.onExtractTextTap != null)
              //   Padding(
              //     padding: EdgeInsets.symmetric(horizontal: 10.w),
              //     child: GestureDetector(
              //       onTap: widget.onExtractTextTap,
              //       child: Container(
              //         padding: EdgeInsets.symmetric(
              //           horizontal: 16.w,
              //           vertical: 14.h,
              //         ),
              //         decoration: BoxDecoration(
              //           color: widget.isDark
              //               ? Colors.white.withValues(alpha: 0.02)
              //               : Colors.black.withValues(alpha: 0.02),
              //           borderRadius: allradius(22.r),
              //           border: Border.all(
              //             color: widget.isDark
              //                 ? Colors.white.withValues(alpha: 0.12)
              //                 : Colors.black.withValues(alpha: 0.12),
              //             width: 1.5,
              //           ),
              //         ),
              //         child: Row(
              //           children: [
              //             Container(
              //               padding: EdgeInsets.all(10.r),
              //               decoration: BoxDecoration(
              //                 color: royalblue.withValues(alpha: 0.15),
              //                 borderRadius: allradius(12.r),
              //               ),
              //               child: Icon(
              //                 Icons.text_snippet_rounded,
              //                 color: royalblue,
              //                 size: 22.r,
              //               ),
              //             ),
              //             Gap(14.w),
              //             Expanded(
              //               child: Column(
              //                 crossAxisAlignment: CrossAxisAlignment.start,
              //                 children: [
              //                   Text(
              //                     "Extract Text",
              //                     style: GoogleFonts.outfit(
              //                       fontSize: 16.sp,
              //                       fontWeight: FontWeight.bold,
              //                       color: widget.isDark
              //                           ? Colors.white
              //                           : Colors.black87,
              //                     ),
              //                   ),
              //                   Gap(2.h),
              //                   Text(
              //                     "Extract, search, copy & share document text",
              //                     style: GoogleFonts.instrumentSans(
              //                       fontSize: 12.5.sp,
              //                       color: widget.isDark
              //                           ? Colors.grey.shade400
              //                           : Colors.grey.shade600,
              //                     ),
              //                   ),
              //                 ],
              //               ),
              //             ),
              //             Icon(
              //               Icons.arrow_forward_ios_rounded,
              //               size: 16.r,
              //               color: widget.isDark
              //                   ? Colors.white38
              //                   : Colors.black38,
              //             ),
              //           ],
              //         ),
              //       ),
              //     ),
              //   ),
            ],
          ),
        ),
      ),
    );
  }
}
