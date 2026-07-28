import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfhawk/logic/helpers/pdf_helper.dart';
import 'package:pdfhawk/interface/pages/ReadWrite/pdf_reader_page.dart';
import 'package:pdfhawk/interface/pages/Scan/scan_edit_page.dart';
import 'package:pdfhawk/res/theme.dart';

class MasterPdfEditorPage extends StatefulWidget {
  final File pdfFile;
  final String? safDirectoryUri;

  const MasterPdfEditorPage({
    super.key,
    required this.pdfFile,
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

  // --- REORDERING ---
  void _reorderPages(int oldIndex, int newIndex) {
    if (_session == null) return;
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _session!.pages.removeAt(oldIndex);
      _session!.pages.insert(newIndex, item);
    });
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
    final isImagePage = page.newImageFilePath != null || page.cachedImagePath != null;

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
                  leading: const Icon(Icons.playlist_add_rounded, color: Colors.blueAccent),
                  title: Text(
                    "Add Page Before (Previous)",
                    style: GoogleFonts.instrumentSans(fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showAddPageTypeSheet(pageIndex);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.post_add_rounded, color: Colors.green),
                  title: Text(
                    "Add Page After (Next)",
                    style: GoogleFonts.instrumentSans(fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showAddPageTypeSheet(pageIndex + 1);
                  },
                ),
                if (isImagePage)
                  ListTile(
                    leading: const Icon(Icons.auto_fix_high_rounded, color: Colors.purpleAccent),
                    title: Text(
                      "Edit Image Page (Crop, Rotate, Effects)",
                      style: GoogleFonts.instrumentSans(fontWeight: FontWeight.w600),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      final imgPath = page.newImageFilePath ?? page.cachedImagePath;
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
              leading: Icon(Icons.note_add_outlined, color: isDark ? Colors.white : Colors.black87),
              title: Text("Add Blank A4 Page", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
              onTap: () {
                Navigator.pop(context);
                _addBlankPage(targetIndex);
              },
            ),
            ListTile(
              leading: Icon(Icons.image_outlined, color: isDark ? Colors.white : Colors.black87),
              title: Text("Add Page from Image", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
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
              content: Text("Merged ${newSession.pages.length} pages into document."),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to combine PDF: $e")),
          );
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
          final decoded = await decodeImageFromList(await File(file.path!).readAsBytes());
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
      text: "edited_${widget.pdfFile.path.split('/').last.replaceAll('.pdf', '')}",
    );

    final shouldExport = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error exporting PDF: $e")),
        );
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
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
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16.sp),
              ),
              SizedBox(height: 8.h),
              Text(
                "${(_saveProgress * 100).toInt()}% completed",
                style: GoogleFonts.instrumentSans(fontSize: 12.sp, color: Colors.grey),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
            SizedBox(width: 8.w),
            Text(
              "PDF Export Complete!",
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18.sp),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
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
              "${pages.length} Pages • Tap & drag to reorder",
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
          : ReorderableListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
              itemCount: pages.length,
// ignore: deprecated_member_use
              onReorder: _reorderPages,
              itemBuilder: (context, index) {
                final page = pages[index];
                final isSelected = _selectedPageIndex == index;

                return KeyedSubtree(
                  key: ValueKey(page),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedPageIndex = index;
                      });
                    },
                    onLongPress: () => _showPageContextMenu(index),
                    child: Container(
                      margin: EdgeInsets.only(bottom: 14.h),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : (isDark ? Colors.white12 : Colors.black12),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Page number & drag handle
                          Container(
                            width: 48.w,
                            height: 100.h,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primary.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.horizontal(
                                left: Radius.circular(16.r),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "${index + 1}",
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16.sp,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                Icon(
                                  Icons.drag_indicator_rounded,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                  size: 20.r,
                                ),
                              ],
                            ),
                          ),

                          // Thumbnail Preview
                          Expanded(
                            child: Container(
                              height: 100.h,
                              padding: EdgeInsets.all(8.r),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10.r),
                                child: _buildThumbnailImage(page),
                              ),
                            ),
                          ),

                          // Page info / context action trigger
                          IconButton(
                            icon: const Icon(Icons.more_vert_rounded),
                            onPressed: () => _showPageContextMenu(index),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
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
                tooltipDesc: "Merge external PDF files into your current document.",
                onTap: _combinePdf,
              ),
              _buildToolbarActionButton(
                icon: Icons.add_photo_alternate_rounded,
                label: "Add Images",
                tooltipTitle: "Add Images",
                tooltipDesc: "Append image pages to the end of the PDF document.",
                onTap: _addImagesToEnd,
              ),
              _buildToolbarActionButton(
                icon: Icons.draw_rounded,
                label: "Sign PDF",
                tooltipTitle: "Sign PDF",
                tooltipDesc: "Draw a custom signature and place it on a PDF page.",
                onTap: _openSignPdfDialog,
              ),
              _buildToolbarActionButton(
                icon: Icons.ios_share_rounded,
                label: "Export",
                tooltipTitle: "Export PDF",
                tooltipDesc: "Save and export the edited PDF to your chosen directory.",
                onTap: _exportAndSavePdf,
                color: theme.colorScheme.primary,
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
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image_rounded),
      );
    } else if (page.cachedImagePath != null) {
      return Image.file(
        File(page.cachedImagePath!),
        fit: BoxFit.contain,
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
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
          ),
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
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18.sp),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
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
