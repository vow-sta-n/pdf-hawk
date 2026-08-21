/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_reorderable_grid_view/widgets/widgets.dart';
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
import 'package:pdfhawk/interface/pages/photo_editor_page.dart';
import 'package:pdfhawk/interface/widgets/bubble_button.dart';
import 'package:pdfhawk/interface/widgets/tutorial_card_widget.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:pdfhawk/logic/helpers/pdf_helper.dart';
import 'package:pdfhawk/interface/widgets/pdf_page_renderer.dart';

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

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  @override
  void dispose() {
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
            builder: (context) => PhotoEditorPage(
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

  // --- LONG-PRESS CONTEXT MENU ---
  void _showPageContextMenu(int pageIndex) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final page = _session!.pages[pageIndex];
    final isImagePage =
        page.newImageFilePath != null || page.cachedImagePath != null;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
            child: Wrap(
              children: [
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: Text(
                    "Page ${pageIndex + 1} Options",
                    style: GoogleFonts.outfit(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.playlist_add_rounded,
                    color: Colors.blueAccent,
                  ),
                  title: Text(
                    "Add Page Before (Previous)",
                    style: GoogleFonts.instrumentSans(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showAddPageTypeSheet(pageIndex);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.post_add_rounded,
                    color: Colors.green,
                  ),
                  title: Text(
                    "Add Page After (Next)",
                    style: GoogleFonts.instrumentSans(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showAddPageTypeSheet(pageIndex + 1);
                  },
                ),
                if (isImagePage)
                  ListTile(
                    leading: const Icon(
                      Icons.auto_fix_high_rounded,
                      color: Colors.purpleAccent,
                    ),
                    title: Text(
                      "Edit Image Page (Crop, Rotate, Effects)",
                      style: GoogleFonts.instrumentSans(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      String? imgPath =
                          page.newImageFilePath ?? page.cachedImagePath;
                      if (imgPath == null &&
                          page.originalPageIndex != null &&
                          _session != null) {
                        final sourceFile =
                            page.sourcePdfFile ?? _session!.originalFile;
                        final bytes =
                            await PdfPageImageRenderer.renderPageBytes(
                              pdfPath: sourceFile.path,
                              pageNumber: page.originalPageIndex!,
                              scale: 2.0,
                            );
                        if (bytes != null) {
                          final tempDir = await getTemporaryDirectory();
                          final tempFile = File(
                            '${tempDir.path}/edit_page_${page.originalPageIndex}_${DateTime.now().millisecondsSinceEpoch}.png',
                          );
                          await tempFile.writeAsBytes(bytes);
                          page.cachedImagePath = tempFile.path;
                          imgPath = tempFile.path;
                        }
                      }
                      if (imgPath != null && mounted) {
                        await Navigator.push(
                          this.context,
                          MaterialPageRoute(
                            builder: (context) => PhotoEditorPage(
                              imagePath: imgPath!,
                              onSave: (newPath) {
                                setState(() {
                                  page.newImageFilePath = newPath;
                                });
                              },
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ListTile(
                  leading: Icon(Icons.delete_outline_rounded, color: red),
                  title: Text(
                    "Delete Page ${pageIndex + 1}",
                    style: GoogleFonts.instrumentSans(
                      fontWeight: FontWeight.w600,
                      color: red,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _deletePage(pageIndex);
                  },
                ),
              ],
            ),
          ),
        );
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
  Future<void> _combinePdf() async {
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
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
    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: theme.colorScheme.primary),
              SizedBox(height: 16.h),
              Text(_statusText, style: GoogleFonts.instrumentSans()),
            ],
          ),
        ),
      );
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
            child: ListView(
              children: [
                // Top Navigation Row
                Row(
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
                Gap(15),

                // Header Title Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Re-Arrange PDF",
                            style: GoogleFonts.outfit(
                              height: 1,
                              fontSize: 38.sp,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Gap(5),
                          Text(
                            "${pages.length} Pages • Long-press & drag to rearrange",
                            style: GoogleFonts.instrumentSans(
                              height: 1,
                              fontSize: 16.sp,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Gap(5),

                Padding(
                  key: _keyGrid,
                  padding: EdgeInsets.all(16.r),
                  child: ReorderableBuilder<PdfPageModel>.builder(
                    itemCount: pages.length,
                    onReorder:
                        (
                          ReorderedListFunction<PdfPageModel>
                          reorderedListFunction,
                        ) {
                          setState(() {
                            final updatedPages = reorderedListFunction(
                              _session!.pages,
                            );
                            _session!.pages.clear();
                            _session!.pages.addAll(updatedPages);
                          });
                        },
                    childBuilder: (itemBuilder) {
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:
                              MediaQuery.of(context).size.width > 600 ? 4 : 3,
                          crossAxisSpacing: 12.w,
                          mainAxisSpacing: 12.h,
                          childAspectRatio: 0.72,
                        ),
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: pages.length,
                        itemBuilder: (context, index) {
                          final page = pages[index];
                          final isSelected = _selectedPageIndex == index;

                          return itemBuilder(
                            Container(
                              key: ValueKey<String>(page.id),
                              child: _buildGridPageCard(
                                page: page,
                                index: index,
                                isSelected: isSelected,
                                isDark: isDark,
                                theme: theme,
                              ),
                            ),
                            index,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          //bottom-nav-bar
          bottomToolBar(isDark, theme),
        ],
      ),
    );
  }

  Container bottomToolBar(bool isDark, ThemeData theme) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF16151B).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildToolbarActionButton(
              key: _keyCombine,
              icon: PDFHawkIcons.docs,
              label: "Combine",
              tooltipTitle: "Combine PDF",
              tooltipDesc:
                  "Merge external PDF files into your current document.",
              onTap: _combinePdf,
            ),
            _buildToolbarActionButton(
              key: _keyImage,
              icon: Icons.add_photo_alternate_outlined,
              label: "Image",
              tooltipTitle: "Add Images",
              tooltipDesc: "Append image pages to the end of the PDF document.",
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

  Widget _buildGridPageCard({
    required PdfPageModel page,
    required int index,
    required bool isSelected,
    required bool isDark,
    required ThemeData theme,
    bool isDragging = false,
    bool isDropTarget = false,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPageIndex = index;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: allradius(6.r),
          border: Border.all(
            color: isDropTarget
                ? theme.colorScheme.primary
                : (isSelected
                      ? theme.colorScheme.primary
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.12))),
            width: (isSelected || isDropTarget || isDragging) ? 2.5 : 1.0,
          ),
          boxShadow: isDragging
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: ClipRRect(
          borderRadius: allradius(6.r),
          child: Stack(
            children: [
              // Page Thumbnail Preview
              Positioned.fill(child: _buildThumbnailImage(page)),

              // Gradient overlays for text readability
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.3, 0.65, 1.0],
                      colors: [
                        Colors.black.withValues(alpha: 0.55),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.65),
                      ],
                    ),
                  ),
                ),
              ),

              // Page Number Badge (Top Left - Static page number)
              Positioned(
                top: 6.r,
                left: 6.r,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : Colors.black.withValues(alpha: 0.75),
                    borderRadius: allradius(6.r),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.4,
                          ),
                          blurRadius: 6,
                        ),
                    ],
                  ),
                  child: Text(
                    "${page.originalPageIndex ?? (index + 1)}",
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.sp,
                    ),
                  ),
                ),
              ),

              // Options Context Menu Button (Top Right)
              Positioned(
                top: 4.r,
                right: 4.r,
                child: GestureDetector(
                  key: index == 0 ? _keyPageMenu : null,
                  onTap: () => _showPageContextMenu(index),
                  child: Container(
                    padding: EdgeInsets.all(5.r),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.more_vert_rounded,
                      size: 16.r,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              // Drag handle indicator (Bottom Right)
              Positioned(
                bottom: 6.r,
                right: 6.r,
                child: Container(
                  padding: EdgeInsets.all(4.r),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: allradius(2.r),
                  ),
                  child: Icon(
                    page.newImageFilePath != null
                        ? Icons.image
                        : PDFHawkIcons.pdf,
                    size: 14.r,
                    color: Colors.white70,
                  ),
                ),
              ),

              // Drop Target Highlight visual overlay
              if (isDropTarget)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.swap_horiz_rounded,
                          color: Colors.white,
                          size: 22.r,
                        ),
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

  Widget _buildThumbnailImage(PdfPageModel page) {
    if (page.newImageFilePath != null) {
      return Image.file(
        File(page.newImageFilePath!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image_rounded),
      );
    } else if (page.cachedImagePath != null &&
        File(page.cachedImagePath!).existsSync()) {
      return Image.file(
        File(page.cachedImagePath!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.picture_as_pdf_rounded),
      );
    } else if (page.originalPageIndex != null && _session != null) {
      return PdfPageImageWidget(
        pdfFile: page.sourcePdfFile ?? _session!.originalFile,
        pageNumber: page.originalPageIndex!,
        fit: BoxFit.cover,
        scale: 0.5,
      );
    } else {
      return Container(
        color: Colors.white,
        child: Center(
          child: Text(
            "Blank A4",
            style: GoogleFonts.instrumentSans(
              color: Colors.black54,
              fontWeight: FontWeight.bold,
              fontSize: 12.sp,
            ),
          ),
        ),
      );
    }
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
        borderRadius: BorderRadius.circular(14.r),
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
        borderRadius: BorderRadius.circular(16.r),
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
