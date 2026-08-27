/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pdf_types;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfhawk/data/class/p_d_f_hawk_icons_icons.dart';
import 'package:pdfhawk/data/res/constants.dart';
import 'package:pdfhawk/data/res/theme.dart';
import 'package:pdfhawk/interface/pages/pdf_reader_page.dart';
import 'package:pdfhawk/interface/pages/images_editor_page.dart';
import 'package:pdfhawk/interface/widgets/bubble_button.dart';
import 'package:pdfhawk/interface/widgets/tutorial_card_widget.dart';
import 'package:pdfhawk/logic/helpers/pdf_helper.dart';
import 'package:pdfhawk/interface/widgets/pdf_page_renderer.dart';
import 'package:pdfhawk/interface/widgets/reorderable_grid.dart';

class ReArrangePDFPage extends StatefulWidget {
  final File? pdfFile;
  final List<String>? initialImagePaths;
  final String? safDirectoryUri;

  const ReArrangePDFPage({
    super.key,
    this.pdfFile,
    this.initialImagePaths,
    this.safDirectoryUri,
  });

  @override
  State<ReArrangePDFPage> createState() => _ReArrangePDFPageState();
}

class _ReArrangePDFPageState extends State<ReArrangePDFPage> {
  final GlobalKey _keyHelp = GlobalKey();
  final GlobalKey _keyGrid = GlobalKey();
  final GlobalKey _keyPageMenu = GlobalKey();
  final GlobalKey _keyCombine = GlobalKey();
  final GlobalKey _keyImage = GlobalKey();
  final GlobalKey _keyExport = GlobalKey();

  PdfEditSession? _session;
  bool _isLoading = true;
  // ignore: unused_field
  bool _isSaving = false;
  double _saveProgress = 0.0;
  String _statusText = "Loading PDF document...";
  int? _selectedPageIndex;
  final ScrollController _gridScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  @override
  void dispose() {
    _gridScrollController.dispose();
    if (_session != null) {
      PdfPageImageRenderer.closeDocument(_session!.originalFile.path);
    }
    super.dispose();
  }

  Future<void> _loadSession() async {
    try {
      File fileToLoad;
      if (widget.pdfFile != null) {
        fileToLoad = widget.pdfFile!;
      } else if (widget.initialImagePaths != null &&
          widget.initialImagePaths!.isNotEmpty) {
        setState(() {
          _statusText = "Creating PDF from captured photos...";
        });
        final pdf = pw.Document();
        for (final path in widget.initialImagePaths!) {
          final imgFile = File(path);
          if (imgFile.existsSync()) {
            final imageBytes = await imgFile.readAsBytes();
            final image = pw.MemoryImage(imageBytes);
            pdf.addPage(
              pw.Page(
                pageFormat: pdf_types.PdfPageFormat.a4,
                margin: const pw.EdgeInsets.all(0),
                build: (pw.Context context) {
                  return pw.Center(
                    child: pw.Image(image, fit: pw.BoxFit.contain),
                  );
                },
              ),
            );
          }
        }
        final tempDir = await getTemporaryDirectory();
        fileToLoad = File(
          "${tempDir.path}/Scanned_${DateTime.now().millisecondsSinceEpoch}.pdf",
        );
        await fileToLoad.writeAsBytes(await pdf.save());
      } else {
        throw Exception("No PDF file or image paths provided.");
      }

      final session = await PdfHelper.startEditSession(fileToLoad);
      setState(() {
        _session = session;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _statusText = "Failed to load PDF: $e";
        _isLoading = false;
      });
    }
  }

  // --- PAGE INSERTION & DELETION ---
  void _addBlankPage(int insertIndex) {
    if (_session == null) return;
    setState(() {
      _session!.pages.insert(
        insertIndex,
        PdfPageModel(
          originalPageIndex: _session!.pages.length + 1,
          drawings: [],
          width: 595.0,
          height: 842.0,
        ),
      );
    });
  }

  Future<void> _addImagePage(int insertIndex, {bool editFirst = true}) async {
    if (_session == null) return;
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      String imagePath = result.files.single.path!;

      if (editFirst && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ImagesEditorPage(
              imagePath: imagePath,
              onSave: (newPath) {
                imagePath = newPath;
              },
            ),
          ),
        );
      }

      final decodedImage = await decodeImageFromList(
        await File(imagePath).readAsBytes(),
      );

      setState(() {
        _session!.pages.insert(
          insertIndex,
          PdfPageModel(
            originalPageIndex: _session!.pages.length + 1,
            newImageFilePath: imagePath,
            drawings: [],
            width: decodedImage.width.toDouble(),
            height: decodedImage.height.toDouble(),
          ),
        );
      });
    }
  }

  void _deletePage(int index) {
    if (_session == null || _session!.pages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cannot delete the only page in PDF")),
      );
      return;
    }
    setState(() {
      _session!.pages.removeAt(index);
    });
  }

  void _editPageInImageEditor(PdfPageModel page) async {
    await PdfReorderableGrid.openPageInEditor(
      context: context,
      page: page,
      fallbackPdfFile: _session?.originalFile,
      onSaved: (newPath) {
        setState(() {
          page.newImageFilePath = newPath;
        });
      },
    );
  }

  void _showAddPageTypeSheet(int targetIndex) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(
                Icons.note_add_outlined,
                color: isDark ? Colors.white : Colors.black87,
              ),
              title: Text(
                "Add Blank A4 Page",
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              ),
              onTap: () {
                Navigator.pop(context);
                _addBlankPage(targetIndex);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.image_outlined,
                color: isDark ? Colors.white : Colors.black87,
              ),
              title: Text(
                "Add Page from Image",
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              ),
              onTap: () {
                Navigator.pop(context);
                _addImagePage(targetIndex);
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- TOOLBAR ACTIONS ---

  // 1. Combine PDF
  Future<void> _addPdf() async {
    if (_session == null) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      final selectedFile = File(result.files.single.path!);
      try {
        final newSession = await PdfHelper.startEditSession(selectedFile);
        setState(() {
          _session!.pages.addAll(newSession.pages);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Merged ${newSession.pages.length} pages into document.",
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Failed to combine PDF: $e")));
        }
      }
    }
  }

  // 2. Add Images to PDF (at end)
  Future<void> _addImagesToEnd() async {
    if (_session == null) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );

    if (result != null) {
      for (final file in result.files) {
        if (file.path != null) {
          final decoded = await decodeImageFromList(
            await File(file.path!).readAsBytes(),
          );
          setState(() {
            _session!.pages.add(
              PdfPageModel(
                originalPageIndex: _session!.pages.length + 1,
                newImageFilePath: file.path!,
                drawings: [],
                width: decoded.width.toDouble(),
                height: decoded.height.toDouble(),
              ),
            );
          });
        }
      }
    }
  }

  // 4. Export & Save PDF with Progress Bar & Completion Prompt
  Future<void> _exportAndSavePdf() async {
    if (_session == null) return;
    final theme = Theme.of(context);

    final originalFileName =
        _session?.originalFile.path.split('/').last.replaceAll('.pdf', '') ??
        'scanned_document';
    final nameController = TextEditingController(
      text: "edited_$originalFileName",
    );

    final shouldExport = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: allradius(20.r)),
        title: Text(
          "Export & Save PDF",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Enter custom filename:",
              style: GoogleFonts.instrumentSans(fontSize: 12.sp),
            ),
            SizedBox(height: 8.h),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                suffixText: ".pdf",
                border: OutlineInputBorder(borderRadius: allradius(12.r)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: allradius(12.r)),
            ),
            child: const Text("Export"),
          ),
        ],
      ),
    );

    if (shouldExport != true) return;

    // Show Progress Bar Dialog
    setState(() {
      _isSaving = true;
      _saveProgress = 0.1;
    });

    _showProgressDialog();

    try {
      // Simulate stepped progress during assembly
      for (double p = 0.2; p <= 0.8; p += 0.2) {
        await Future.delayed(const Duration(milliseconds: 150));
        if (mounted) setState(() => _saveProgress = p);
      }

      final filename = nameController.text.trim().endsWith(".pdf")
          ? nameController.text.trim()
          : "${nameController.text.trim()}.pdf";

      final compiledFile = await PdfHelper.saveSession(
        session: _session!,
        safDirectoryUri: widget.safDirectoryUri,
        outputName: filename,
      );

      final bytes = await compiledFile.readAsBytes();
      final savePath = await FilePicker.platform.saveFile(
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: bytes,
      );

      File finalSavedFile = compiledFile;
      if (savePath != null) {
        finalSavedFile = File(savePath);
        await finalSavedFile.writeAsBytes(bytes);
      }

      setState(() {
        _saveProgress = 1.0;
        _isSaving = false;
      });

      if (mounted) {
        Navigator.pop(context); // Dismiss progress dialog
        _showCompletionDialog(finalSavedFile);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        Navigator.pop(context); // Dismiss progress dialog
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error exporting PDF: $e")));
      }
    }
  }

  void _showProgressDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: allradius(20.r)),
        content: Padding(
          padding: EdgeInsets.symmetric(vertical: 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                value: _saveProgress > 0 ? _saveProgress : null,
                color: theme.colorScheme.primary,
              ),
              SizedBox(height: 20.h),
              Text(
                "Saving & Exporting PDF...",
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 16.sp,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                "${(_saveProgress * 100).toInt()}% completed",
                style: GoogleFonts.instrumentSans(
                  fontSize: 12.sp,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCompletionDialog(File savedFile) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: allradius(20.r)),
        title: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.green,
              size: 28,
            ),
            SizedBox(width: 8.w),
            Text(
              "PDF Export Complete!",
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 18.sp,
              ),
            ),
          ],
        ),
        content: Text(
          "Your edited PDF has been saved successfully.",
          style: GoogleFonts.instrumentSans(fontSize: 14.sp),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text("View in Reader"),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => PDFReaderPage(pdfFile: savedFile),
                ),
              );
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.share_rounded),
            label: const Text("Done"),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: allradius(12.r)),
            ),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen(ThemeData theme, bool isDark) {
    final hasError = !_isLoading && _session == null;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 10,
        automaticallyImplyActions: false,
        automaticallyImplyLeading: false,
        backgroundColor: theme.appBarTheme.backgroundColor,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: BubbleButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: Center(
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 20.w),
                    padding: EdgeInsets.symmetric(
                      horizontal: 24.w,
                      vertical: 32.h,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E1E24)
                          : const Color(0xFFF7F7FA),
                      borderRadius: allradius(24.r),
                      border: Border.all(
                        color: isDark
                            ? Colors.white12
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.3 : 0.05,
                          ),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 76.r,
                          height: 76.r,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hasError
                                ? red.withValues(alpha: 0.12)
                                : royalblue.withValues(alpha: 0.12),
                            border: Border.all(
                              color: hasError
                                  ? red.withValues(alpha: 0.35)
                                  : royalblue.withValues(alpha: 0.35),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              hasError
                                  ? Icons.error_outline_rounded
                                  : PDFHawkIcons.add_document,
                              size: 32.sp,
                              color: hasError ? red : royalblue,
                            ),
                          ),
                        ),
                        Gap(22.h),
                        if (!hasError) ...[
                          SizedBox(
                            width: 28.r,
                            height: 28.r,
                            child: const CircularProgressIndicator(
                              color: royalblue,
                              strokeWidth: 3.0,
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                          Gap(16.h),
                        ],
                        Text(
                          hasError
                              ? "Unable to Load PDF"
                              : "Loading PDF Document",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Gap(8.h),
                        Text(
                          _statusText,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.instrumentSans(
                            fontSize: 13.5.sp,
                            color: isDark ? Colors.white60 : Colors.black54,
                            height: 1.35,
                          ),
                        ),
                        if (hasError) ...[
                          Gap(20.h),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: royalblue,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: 20.w,
                                vertical: 10.h,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: allradius(12.r),
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                _isLoading = true;
                                _statusText = "Loading PDF document...";
                              });
                              _loadSession();
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: Text(
                              "Try Again",
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- BUILD METHOD ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    double h = getHeight(context);
    double w = getWidth(context);
    if (_isLoading || _session == null) {
      return _buildLoadingScreen(theme, isDark);
    }

    final pages = _session?.pages ?? [];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 10,
        automaticallyImplyActions: false,
        automaticallyImplyLeading: false,
        backgroundColor: theme.appBarTheme.backgroundColor,
      ),
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          SizedBox(
            height: h,
            width: w,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Navigation Row
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      BubbleButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                      BubbleButton(
                        icon: Icons.help_outline_outlined,
                        onTap: _showTutorial,
                      ),
                    ],
                  ),
                ),
                Gap(20),

                // Header Title Section
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Re-Arrange PDF",
                        style: GoogleFonts.outfit(
                          height: 1,
                          fontSize: 34.sp,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Gap(4),
                      Text(
                        "${pages.length} Pages • Long-press & drag to rearrange",
                        style: GoogleFonts.instrumentSans(
                          height: 1,
                          fontSize: 14.sp,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                Gap(25),

                // Virtualized Lazy Reorderable Grid
                Expanded(
                  child: Padding(
                    key: _keyGrid,
                    padding: EdgeInsets.symmetric(horizontal: 14.w),
                    child: PdfReorderableGrid(
                      pages: pages,
                      fallbackPdfFile: _session?.originalFile,
                      scrollController: _gridScrollController,
                      selectedPageIndex: _selectedPageIndex,
                      firstItemMenuKey: _keyPageMenu,
                      crossAxisCount: MediaQuery.of(context).size.width > 600
                          ? 4
                          : 4,
                      onPageSelected: (index) {
                        setState(() {
                          _selectedPageIndex = index;
                        });
                      },
                      onAddBefore: (index) => _showAddPageTypeSheet(index),
                      onAddAfter: (index) => _showAddPageTypeSheet(index + 1),
                      onEditImage: (index, page) =>
                          _editPageInImageEditor(page),
                      onDeletePage: (index) => _deletePage(index),
                      onReorder: (updatedPages) {
                        setState(() {
                          _session!.pages.clear();
                          _session!.pages.addAll(updatedPages);
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Floating Glass Bottom Navbar
          Positioned(
            left: 20.w,
            right: 20.w,
            bottom: 20.h,
            child: bottomToolBar(isDark, theme),
          ),
        ],
      ),
    );
  }

  Widget bottomToolBar(bool isDark, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF16151B).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: allradius(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.0),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: allradius(16.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 8.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildToolbarActionButton(
                  key: _keyCombine,
                  icon: PDFHawkIcons.docs,
                  label: "Add PDF",
                  tooltipTitle: "Add PDF",
                  tooltipDesc:
                      "Import and append external PDF files into your current document.",
                  onTap: _addPdf,
                ),
                _buildToolbarActionButton(
                  key: _keyImage,
                  icon: Icons.add_photo_alternate_outlined,
                  label: "Image",
                  tooltipTitle: "Add Images",
                  tooltipDesc:
                      "Append image pages to the end of the PDF document.",
                  onTap: _addImagesToEnd,
                ),
                _buildToolbarActionButton(
                  key: _keyExport,
                  icon: Icons.save_alt_outlined,
                  label: "Save",
                  tooltipTitle: "Save & Export PDF",
                  tooltipDesc:
                      "Save and export the edited PDF to your chosen directory.",
                  onTap: _exportAndSavePdf,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTutorial() {
    showAppTutorial(
      context: context,
      steps: [
        TutorialStep(
          identify: "help",
          keyTarget: _keyHelp,
          shape: ShapeLightFocus.Circle,
          align: ContentAlign.bottom,
          title: "Help & Overview",
          description:
              "Tap this Help icon anytime to replay this interactive tutorial for PDF Editor.",
          icon: Icons.help_outline_outlined,
        ),
        TutorialStep(
          identify: "grid",
          targetPosition: TargetPosition(
            Size(
              MediaQuery.of(context).size.width - 32.w,
              MediaQuery.of(context).size.height * 0.42,
            ),
            Offset(16.w, 90.h),
          ),
          shape: ShapeLightFocus.RRect,
          radius: 16.r,
          align: ContentAlign.bottom,
          title: "Rearrange & Edit Pages",
          description:
              "Long-press & drag page thumbnails to reorder. Tap a page to select it for options to rotate, replace, filter, or delete.",
          icon: Icons.grid_view_rounded,
        ),
        TutorialStep(
          identify: "pageMenu",
          keyTarget: _keyPageMenu,
          shape: ShapeLightFocus.Circle,
          align: ContentAlign.bottom,
          title: "Page Options Menu",
          description:
              "Tap the 3 vertical dots icon on any page thumbnail to rotate, replace, apply photo filters, or delete that specific page.",
          icon: Icons.more_vert_rounded,
        ),
        TutorialStep(
          identify: "combine",
          keyTarget: _keyCombine,
          shape: ShapeLightFocus.RRect,
          radius: 14.r,
          align: ContentAlign.top,
          title: "Combine PDFs",
          description:
              "Import external PDF files from your storage and merge their pages into your current document.",
          icon: Icons.merge_type_rounded,
        ),
        TutorialStep(
          identify: "image",
          keyTarget: _keyImage,
          shape: ShapeLightFocus.RRect,
          radius: 14.r,
          align: ContentAlign.top,
          title: "Add Photo Images",
          description:
              "Pick photo images from your gallery and append them as new pages to the PDF document.",
          icon: Icons.add_photo_alternate_rounded,
        ),
        TutorialStep(
          identify: "export",
          keyTarget: _keyExport,
          shape: ShapeLightFocus.RRect,
          radius: 14.r,
          align: ContentAlign.top,
          title: "Export & Save PDF",
          description:
              "Render all changes and save your finished PDF file to local storage or open directly in Reader.",
          icon: Icons.ios_share_rounded,
        ),
      ],
    );
  }

  Widget _buildToolbarActionButton({
    Key? key,
    required IconData icon,
    required String label,
    required String tooltipTitle,
    required String tooltipDesc,
    required VoidCallback onTap,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveColor = color ?? (isDark ? Colors.white : Colors.black87);

    return Tooltip(
      key: key,
      triggerMode: TooltipTriggerMode.longPress,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF23222A) : const Color(0xFF1E1E24),
        borderRadius: allradius(14.r),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10),
        ],
      ),
      richMessage: TextSpan(
        children: [
          TextSpan(
            text: "$tooltipTitle\n",
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 13.sp,
              color: Colors.white,
            ),
          ),
          TextSpan(
            text: tooltipDesc,
            style: GoogleFonts.inter(fontSize: 10.sp, color: Colors.white70),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: allradius(16.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w),

          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: effectiveColor, size: 22.r),
              SizedBox(height: 4.h),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                  color: effectiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
