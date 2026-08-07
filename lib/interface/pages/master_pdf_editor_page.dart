import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_reorderable_grid_view/widgets/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pdf_types;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfhawk/data/res/theme.dart';
import 'package:pdfhawk/interface/pages/pdf_reader_page.dart';
import 'package:pdfhawk/interface/pages/scan_edit_page.dart';
import 'package:pdfhawk/logic/helpers/pdf_helper.dart';

class MasterPdfEditorPage extends StatefulWidget {
  final File? pdfFile;
  final List<String>? initialImagePaths;
  final String? safDirectoryUri;

  const MasterPdfEditorPage({
    super.key,
    this.pdfFile,
    this.initialImagePaths,
    this.safDirectoryUri,
  });


  @override
  State<MasterPdfEditorPage> createState() => _MasterPdfEditorPageState();
}

class _MasterPdfEditorPageState extends State<MasterPdfEditorPage> {
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

  Future<void> _loadSession() async {
    try {
      final session = await PdfHelper.startEditSession(widget.pdfFile);
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
          originalPageIndex: null,
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
            builder: (context) => ScanEditPage(
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
            originalPageIndex: null,
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
                      final imgPath =
                          page.newImageFilePath ?? page.cachedImagePath;
                      if (imgPath != null && mounted) {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ScanEditPage(
                              imagePath: imgPath,
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
                originalPageIndex: null,
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

  // 3. Sign PDF
  void _openSignPdfDialog() {
    if (_session == null || _session!.pages.isEmpty) return;
    final targetPageIdx = _selectedPageIndex ?? 0;

    showDialog(
      context: context,
      builder: (context) => _SignaturePadDialog(
        onConfirm: (signaturePaths) {
          setState(() {
            _session!.pages[targetPageIdx].drawings.addAll(signaturePaths);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Signature added to Page ${targetPageIdx + 1}"),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  // 4. Export & Save PDF with Progress Bar & Completion Prompt
  Future<void> _exportAndSavePdf() async {
    if (_session == null) return;
    final theme = Theme.of(context);

    final nameController = TextEditingController(
      text:
          "edited_${widget.pdfFile.path.split('/').last.replaceAll('.pdf', '')}",
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
        backgroundColor: theme.appBarTheme.backgroundColor,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Master PDF Editor",
              style: GoogleFonts.outfit(
                color: theme.appBarTheme.foregroundColor,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "${pages.length} Pages • Long-press & drag to rearrange",
              style: GoogleFonts.instrumentSans(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontSize: 12.sp,
              ),
            ),
          ],
        ),
        iconTheme: IconThemeData(color: theme.appBarTheme.iconTheme?.color),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_alt_rounded),
            tooltip: "Export PDF",
            onPressed: _exportAndSavePdf,
          ),
        ],
      ),
      body: pages.isEmpty
          ? Center(
              child: Text(
                "No pages in PDF document.",
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
            )
          : Padding(
              padding: EdgeInsets.all(16.r),
              child: ReorderableBuilder<PdfPageModel>.builder(
                itemCount: pages.length,
                onReorder:
                    (
                      ReorderedListFunction<PdfPageModel> reorderedListFunction,
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
                      crossAxisCount: MediaQuery.of(context).size.width > 600
                          ? 4
                          : 3,
                      crossAxisSpacing: 12.w,
                      mainAxisSpacing: 12.h,
                      childAspectRatio: 0.72,
                    ),
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

      // Bottom Toolbar like PDFReaderPage
      bottomNavigationBar: Container(
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
                icon: Icons.merge_type_rounded,
                label: "Combine PDF",
                tooltipTitle: "Combine PDF",
                tooltipDesc:
                    "Merge external PDF files into your current document.",
                onTap: _combinePdf,
              ),
              _buildToolbarActionButton(
                icon: Icons.add_photo_alternate_rounded,
                label: "Add Images",
                tooltipTitle: "Add Images",
                tooltipDesc:
                    "Append image pages to the end of the PDF document.",
                onTap: _addImagesToEnd,
              ),
              _buildToolbarActionButton(
                icon: Icons.draw_rounded,
                label: "Sign PDF",
                tooltipTitle: "Sign PDF",
                tooltipDesc:
                    "Draw a custom signature and place it on a PDF page.",
                onTap: _openSignPdfDialog,
              ),
              _buildToolbarActionButton(
                icon: Icons.ios_share_rounded,
                label: "Export",
                tooltipTitle: "Export PDF",
                tooltipDesc:
                    "Save and export the edited PDF to your chosen directory.",
                onTap: _exportAndSavePdf,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
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
          borderRadius: BorderRadius.circular(16.r),
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
          borderRadius: BorderRadius.circular(15.r),
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

              // Page Number Badge (Top Left)
              Positioned(
                top: 6.r,
                left: 6.r,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(8.r),
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
                    "${index + 1}",
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
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Icon(
                    Icons.drag_indicator_rounded,
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
                      borderRadius: BorderRadius.circular(15.r),
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
    } else if (page.cachedImagePath != null) {
      return Image.file(
        File(page.cachedImagePath!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.picture_as_pdf_rounded),
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
            style: GoogleFonts.instrumentSans(
              fontSize: 11.sp,
              color: Colors.white70,
            ),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: effectiveColor, size: 22.r),
              SizedBox(height: 4.h),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 11.sp,
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

// --- SIGNATURE PAD DIALOG ---

class _SignaturePadDialog extends StatefulWidget {
  final Function(List<DrawingPath>) onConfirm;

  const _SignaturePadDialog({required this.onConfirm});

  @override
  State<_SignaturePadDialog> createState() => _SignaturePadDialogState();
}

class _SignaturePadDialogState extends State<_SignaturePadDialog> {
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
              painter: _SignaturePainter(
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

class _SignaturePainter extends CustomPainter {
  final List<DrawingPath> paths;
  final List<Offset> currentPoints;
  final Color color;

  _SignaturePainter({
    required this.paths,
    required this.currentPoints,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final path in paths) {
      if (path.points.length < 2) continue;
      final p = Path();
      p.moveTo(path.points.first.dx, path.points.first.dy);
      for (int i = 1; i < path.points.length; i++) {
        p.lineTo(path.points[i].dx, path.points[i].dy);
      }
      canvas.drawPath(p, paint);
    }

    if (currentPoints.length > 1) {
      final p = Path();
      p.moveTo(currentPoints.first.dx, currentPoints.first.dy);
      for (int i = 1; i < currentPoints.length; i++) {
        p.lineTo(currentPoints[i].dx, currentPoints[i].dy);
      }
      canvas.drawPath(p, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
