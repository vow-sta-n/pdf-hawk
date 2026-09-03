/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:io';
import 'package:community_material_icon/community_material_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:share_plus/share_plus.dart';
import 'package:saf/src/storage_access_framework/api.dart';
import 'package:pdfhawk/data/class/editor_overlay_item.dart';
import 'package:pdfhawk/data/res/enum.dart';
import 'package:pdfhawk/data/res/utils.dart';
import 'package:pdfhawk/interface/dialogs/color_wheel_dialog.dart';
import 'package:pdfhawk/interface/widgets/pdf_page_renderer.dart';
import 'package:pdfhawk/interface/widgets/pdf_page_view_item.dart';
import 'package:pdfhawk/interface/painters/shape_painter.dart';
import 'package:pdfhawk/logic/helpers/pdf_helper.dart';
import 'package:pdfhawk/interface/pages/rearrange_pdf_page.dart';
import 'package:pdfhawk/interface/pages/merge_pdfs_page.dart';
import 'package:pdfhawk/interface/bottomsheets/edit_tools_bottom_sheet.dart';
import 'package:pdfhawk/interface/bottomsheets/extract_text_bottom_sheet.dart';
import 'package:pdfhawk/interface/bottomsheets/document_convert_bottom_sheet.dart';
import 'package:pdfhawk/interface/bottomsheets/images_convert_bottom_sheet.dart';
import 'package:pdfhawk/interface/dialogs/split_pdf_dialog.dart';
import 'package:pdfhawk/data/res/constants.dart';
import 'package:pdfhawk/data/res/theme.dart';

class PDFReaderPage extends StatefulWidget {
  final File pdfFile;
  final String? safDirectoryUri;

  const PDFReaderPage({super.key, required this.pdfFile, this.safDirectoryUri});

  @override
  State<PDFReaderPage> createState() => _PDFReaderPageState();
}

class _PDFReaderPageState extends State<PDFReaderPage>
    with SingleTickerProviderStateMixin {
  PageDisplayLayout _displayLayout = PageDisplayLayout.single;
  String _statusText = "Loading PDF file...";
  EditorTool _activeTool = EditorTool.view;
  Axis _scrollDirection = Axis.vertical;
  Color _selectedColor = royalblue;
  late PageController _pageController;
  late ScrollController _verticalScrollController;
  late TransformationController _transformationController;
  late AnimationController _zoomAnimationController;
  Animation<Matrix4>? _zoomAnimation;
  TapDownDetails? _doubleTapDetails;
  List<Offset> _currentPoints = [];
  bool _hasUnsavedChanges = false;
  bool _isAnnotatingMode = false;
  bool _isPageZoomed = false;
  bool _isAppBarVisible = true;
  int _activePointers = 0;
  bool _isPinching = false;
  double _dynamicRenderScale = 2.0;
  Timer? _zoomDebounceTimer;
  DrawingPath? _selectedAnnotation;
  EditorOverlayItem? _selectedOverlayItem;
  int _currentPageIndex = 0;
  PdfEditSession? _session;
  bool _isLoading = true;
  bool _isSaving = false;
  double _strokeWidth = 4.0;
  int _renderVersion = 0;
  final Map<int, List<DrawingPath>> _drawingRedoHistory = {};
  final Map<int, List<EditorOverlayItem>> _overlayRedoHistory = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPageIndex);
    _verticalScrollController = ScrollController();
    _transformationController = TransformationController();
    _zoomAnimationController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 260),
        )..addListener(() {
          if (_zoomAnimation != null) {
            _transformationController.value = _zoomAnimation!.value;
          }
        });
    _initSession();
  }

  @override
  void dispose() {
    PdfPageImageRenderer.closeDocument(widget.pdfFile.path);
    PdfPageImageRenderer.clearMemoryCache();
    PdfHelper.clearTextLinesCache();
    _zoomDebounceTimer?.cancel();
    _zoomAnimationController.dispose();
    _pageController.dispose();
    _verticalScrollController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _updateDynamicRenderScale() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final targetScale = currentScale >= 1.35 ? 4.5 : 2.0;

    if (targetScale != _dynamicRenderScale) {
      _zoomDebounceTimer?.cancel();
      _zoomDebounceTimer = Timer(const Duration(milliseconds: 100), () {
        if (mounted && targetScale != _dynamicRenderScale) {
          setState(() {
            _dynamicRenderScale = targetScale;
          });
        }
      });
    }
  }

  void _animateZoomTo(Matrix4 targetMatrix) {
    _zoomAnimation =
        Matrix4Tween(
          begin: _transformationController.value,
          end: targetMatrix,
        ).animate(
          CurvedAnimation(
            parent: _zoomAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _zoomAnimationController.forward(from: 0.0);
  }

  void _handleDoubleTap() {
    if (_activeTool != EditorTool.view) return;
    if (_transformationController.value != Matrix4.identity()) {
      _animateZoomTo(Matrix4.identity());
      setState(() {
        _isPageZoomed = false;
        _isAppBarVisible = true;
      });
    } else {
      final tapPos = _doubleTapDetails?.localPosition ?? Offset.zero;
      final x = -tapPos.dx * 1.25;
      final y = -tapPos.dy * 1.25;
      // ignore: deprecated_member_use
      final targetMatrix = Matrix4.identity()
        // ignore: deprecated_member_use
        ..translate(x, y)
        // ignore: deprecated_member_use
        ..scale(2.25);

      _animateZoomTo(targetMatrix);
      setState(() {
        _isPageZoomed = true;
        _isAppBarVisible = false;
      });
    }
  }

  void _toggleScrollDirection(Axis direction) {
    if (_scrollDirection == direction) return;
    setState(() {
      _scrollDirection = direction;
      _isAppBarVisible = true;
      _transformationController.value = Matrix4.identity();
      _isPageZoomed = false;
      _pageController.dispose();
      _pageController = PageController(initialPage: _currentPageIndex);
    });
  }

  void _enterAnnotationMode() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isAnnotatingMode = true;
      _activeTool = EditorTool.pen;
      _isAppBarVisible = true;
    });
  }

  void _updateUnsavedChangesState() {
    if (_session == null) {
      if (_hasUnsavedChanges) {
        setState(() {
          _hasUnsavedChanges = false;
        });
      }
      return;
    }

    bool hasAnyEdits = false;
    for (final page in _session!.pages) {
      if (page.drawings.isNotEmpty || page.overlays.isNotEmpty) {
        hasAnyEdits = true;
        break;
      }
    }

    if (_hasUnsavedChanges != hasAnyEdits) {
      setState(() {
        _hasUnsavedChanges = hasAnyEdits;
      });
    }
  }

  void _exitAnnotationMode() {
    setState(() {
      _isAnnotatingMode = false;
      _selectedAnnotation = null;
      _activeTool = EditorTool.view;
      _isAppBarVisible = true;
    });
    _updateUnsavedChangesState();
  }

  Future<void> _sharePdf() async {
    try {
      if (!widget.pdfFile.existsSync()) {
        plainToast(msg: "PDF file does not exist.");
        return;
      }
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(widget.pdfFile.path)],
          text: p.basename(widget.pdfFile.path),
        ),
      );
    } catch (e) {
      plainToast(msg: "Error sharing PDF: $e");
    }
  }

  void _onSelectAnnotation(PdfPageModel pageModel, DrawingPath? annotation) {
    setState(() {
      _selectedAnnotation = annotation;
      if (annotation != null) {
        _selectedOverlayItem = null;
      }
    });
  }

  void _onDeleteAnnotation(PdfPageModel pageModel, DrawingPath annotation) {
    HapticFeedback.mediumImpact();
    setState(() {
      pageModel.drawings.remove(annotation);
      _selectedAnnotation = null;
    });
    _updateUnsavedChangesState();
    plainToast(msg: "Annotation deleted");
  }

  void _onUpdateAnnotationColor(DrawingPath annotation, Color newColor) {
    HapticFeedback.selectionClick();
    setState(() {
      annotation.color = newColor;
    });
    _updateUnsavedChangesState();
  }

  void _onAnnotationMoved() {
    _updateUnsavedChangesState();
  }

  void _undoAnnotation(PdfPageModel pageModel) {
    bool undone = false;
    if (pageModel.drawings.isNotEmpty) {
      final removed = pageModel.drawings.removeLast();
      _drawingRedoHistory.putIfAbsent(_currentPageIndex, () => []).add(removed);
      undone = true;
    } else if (pageModel.overlays.isNotEmpty) {
      final removed = pageModel.overlays.removeLast();
      _overlayRedoHistory.putIfAbsent(_currentPageIndex, () => []).add(removed);
      undone = true;
    }

    if (undone) {
      setState(() {
        _selectedAnnotation = null;
      });
      _updateUnsavedChangesState();
      plainToast(msg: "Undone");
    } else {
      plainToast(msg: "Nothing to undo");
    }
  }

  void _redoAnnotation(PdfPageModel pageModel) {
    bool redone = false;
    final pageRedoDrawings = _drawingRedoHistory[_currentPageIndex];
    final pageRedoOverlays = _overlayRedoHistory[_currentPageIndex];

    if (pageRedoDrawings != null && pageRedoDrawings.isNotEmpty) {
      final restored = pageRedoDrawings.removeLast();
      pageModel.drawings.add(restored);
      redone = true;
    } else if (pageRedoOverlays != null && pageRedoOverlays.isNotEmpty) {
      final restored = pageRedoOverlays.removeLast();
      pageModel.overlays.add(restored);
      redone = true;
    }

    if (redone) {
      setState(() {});
      _updateUnsavedChangesState();
      plainToast(msg: "Redone");
    } else {
      plainToast(msg: "Nothing to redo");
    }
  }

  void _deleteSelectedAnnotation(PdfPageModel pageModel) {
    if (_selectedOverlayItem != null &&
        pageModel.overlays.contains(_selectedOverlayItem)) {
      setState(() {
        pageModel.overlays.remove(_selectedOverlayItem);
        _overlayRedoHistory
            .putIfAbsent(_currentPageIndex, () => [])
            .add(_selectedOverlayItem!);
        _selectedOverlayItem = null;
      });
      _updateUnsavedChangesState();
      plainToast(msg: "Element deleted");
    } else if (_selectedAnnotation != null &&
        pageModel.drawings.contains(_selectedAnnotation)) {
      setState(() {
        pageModel.drawings.remove(_selectedAnnotation);
        _drawingRedoHistory
            .putIfAbsent(_currentPageIndex, () => [])
            .add(_selectedAnnotation!);
        _selectedAnnotation = null;
      });
      _updateUnsavedChangesState();
      plainToast(msg: "Annotation deleted");
    } else if (pageModel.overlays.isNotEmpty) {
      setState(() {
        final removed = pageModel.overlays.removeLast();
        _overlayRedoHistory
            .putIfAbsent(_currentPageIndex, () => [])
            .add(removed);
      });
      _updateUnsavedChangesState();
      plainToast(msg: "Element deleted");
    } else if (pageModel.drawings.isNotEmpty) {
      setState(() {
        final removed = pageModel.drawings.removeLast();
        _drawingRedoHistory
            .putIfAbsent(_currentPageIndex, () => [])
            .add(removed);
      });
      _updateUnsavedChangesState();
      plainToast(msg: "Drawing deleted");
    } else {
      plainToast(msg: "No element selected");
    }
  }

  void _clearAllAnnotations(PdfPageModel pageModel) {
    if (pageModel.drawings.isEmpty && pageModel.overlays.isEmpty) {
      plainToast(msg: "Page is already empty");
      return;
    }
    setState(() {
      pageModel.drawings.clear();
      pageModel.overlays.clear();
      _selectedAnnotation = null;
    });
    _updateUnsavedChangesState();
    plainToast(msg: "Page cleared");
  }

  Future<void> _initSession() async {
    setState(() {
      _isLoading = true;
      _statusText = "Analyzing and rendering pages...";
    });
    try {
      await PdfPageImageRenderer.closeDocument(widget.pdfFile.path);
      PdfPageImageRenderer.clearMemoryCache();
      final session = await PdfHelper.startEditSession(widget.pdfFile);
      setState(() {
        _session = session;
        _isLoading = false;
      });

      // Eagerly preload all pages for documents with lower page counts (<= 15 pages) or first 6 pages
      if (session.pages.isNotEmpty) {
        final total = session.pages.length;
        final preloadCount = total <= 15 ? total : 6;
        for (int i = 1; i <= preloadCount; i++) {
          PdfPageImageRenderer.renderPageBytes(
            pdfPath: widget.pdfFile.path,
            pageNumber: i,
            scale: 2.0,
          );
        }
      }
    } catch (e) {
      debugPrint("Failed to init session: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error loading PDF: $e")));
      Navigator.of(context).pop();
    }
  }

  Future<void> _promptSavePdf() async {
    if (_session == null) return;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10.r)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
            child: Wrap(
              children: [
                Center(
                  child: Container(
                    width: 40.w,
                    height: 5.h,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: allradius(10.r),
                    ),
                  ),
                ),
                SizedBox(height: 24.h),
                Text(
                  "Export Options",
                  style: GoogleFonts.outfit(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  "Choose how you want to save or export the edited PDF document.",
                  style: GoogleFonts.instrumentSans(
                    fontSize: 13.sp,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 30.h),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: allradius(12.r),
                    ),
                    child: Icon(
                      Icons.save_as_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    "Modify & Overwrite",
                    style: GoogleFonts.instrumentSans(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    "Save edits directly back to the source file.",
                    style: GoogleFonts.instrumentSans(
                      fontSize: 12.sp,
                      color: isDark ? Colors.grey : Colors.grey.shade600,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _saveAndOverwrite();
                  },
                ),
                Divider(
                  color: isDark ? Colors.white12 : Colors.black12,
                  height: 20.h,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: allradius(12.r),
                    ),
                    child: Icon(
                      Icons.file_upload_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    "Save As New (Export)",
                    style: GoogleFonts.instrumentSans(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    "Choose a location to save a copy of the edited document.",
                    style: GoogleFonts.instrumentSans(
                      fontSize: 12.sp,
                      color: Colors.grey,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _saveAsNew();
                  },
                ),
                SizedBox(height: 16.h),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveAndOverwrite() async {
    if (_session == null) return;
    setState(() {
      _isSaving = true;
    });

    try {
      // 1. Close open document handle & clear RAM cache so native file lock is released
      await PdfPageImageRenderer.closeDocument(widget.pdfFile.path);
      PdfPageImageRenderer.clearMemoryCache();

      // 2. Compile modified session into raw PDF bytes
      final docBytes = await PdfHelper.compileSessionBytes(session: _session!);

      // 3. Overwrite the original file bytes directly in-place and flush to disk
      await widget.pdfFile.writeAsBytes(docBytes, flush: true);

      // 4. Write back to Storage Access Framework (SAF) folder if available on Android
      if (widget.safDirectoryUri != null) {
        try {
          final treeUri = Uri.parse(
            makeUriString(path: widget.safDirectoryUri!, isTreeUri: true),
          );
          final fileName = widget.pdfFile.path.split('/').last;
          await createFileAsBytes(
            treeUri,
            mimeType: 'application/pdf',
            displayName: fileName,
            content: docBytes,
          );
        } catch (safError) {
          debugPrint("SAF writeback error on overwrite: $safError");
        }
      }

      // 5. Ensure handle and cache remain clean after writing
      await PdfPageImageRenderer.closeDocument(widget.pdfFile.path);
      PdfPageImageRenderer.clearMemoryCache();

      // 6. Re-initialize edit session from newly saved file so state is 100% fresh
      final freshSession = await PdfHelper.startEditSession(widget.pdfFile);

      setState(() {
        _session = freshSession;
        _hasUnsavedChanges = false;
        _drawingRedoHistory.clear();
        _overlayRedoHistory.clear();
        _renderVersion++;
      });

      if (!mounted) return;
      plainToast(msg: "Document saved and overwritten successfully!");
    } catch (e) {
      if (!mounted) return;
      plainToast(msg: "Failed to overwrite PDF: $e. Try Save As.");
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _saveAsNew() async {
    if (_session == null) return;
    setState(() {
      _isSaving = true;
    });

    try {
      final compiledFile = await PdfHelper.saveSession(
        session: _session!,
        safDirectoryUri: widget.safDirectoryUri,
      );

      final originalName = widget.pdfFile.path.split('/').last;
      final newName = "edited_${originalName.replaceAll('.pdf', '')}.pdf";
      final bytes = await compiledFile.readAsBytes();

      final savePath = await FilePicker.platform.saveFile(
        fileName: newName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: bytes,
      );

      if (savePath != null) {
        if (!Platform.isAndroid && !Platform.isIOS) {
          final newFile = File(savePath);
          await newFile.writeAsBytes(bytes);
        }

        setState(() {
          _hasUnsavedChanges = false;
        });

        if (!mounted) return;
        plainToast(msg: "PDF saved as copy successfully!");
      } else {
        setState(() {
          _hasUnsavedChanges = false;
        });
        if (!mounted) return;
        plainToast(msg: "PDF exported to ${compiledFile.path.split('/').last}");
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint("Failed to save PDF: $e");
      plainToast(msg: "Failed to save PDF: $e");
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _openExtractTextBottomSheet() {
    final pageCount = _session?.pages.length ?? 1;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ExtractTextBottomSheet(
        pdfFile: widget.pdfFile,
        currentPageIndex: _currentPageIndex,
        totalPages: pageCount,
      ),
    );
  }

  void _showEditToolsBottomSheet() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return EditToolsBottomSheet(
          theme: theme,
          isDark: isDark,
          onConvertTap: () {
            Navigator.pop(context);
            _pickAndConvertFile();
          },
          onSplitTap: () {
            Navigator.pop(context);
            showDialog(
              context: this.context,
              builder: (context) => SplitPdfDialog(pdfFile: widget.pdfFile),
            );
          },
          onMergeTap: () {
            Navigator.pop(context);
            Navigator.push(
              this.context,
              MaterialPageRoute(
                builder: (context) =>
                    MergePdfsPage(initialPdfFiles: [widget.pdfFile]),
              ),
            );
          },
          onRearrangeTap: () {
            Navigator.pop(context);
            Navigator.push(
              this.context,
              MaterialPageRoute(
                builder: (context) => ReArrangePDFPage(
                  pdfFile: widget.pdfFile,
                  safDirectoryUri: widget.safDirectoryUri,
                ),
              ),
            ).then((_) => _initSession());
          },
          onExtractTextTap: () {
            Navigator.pop(context);
            _openExtractTextBottomSheet();
          },
          onCompressTap: () {
            Navigator.pop(context);
            _compressCurrentPdf();
          },
        );
      },
    );
  }

  Future<void> _compressCurrentPdf() async {
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
                  "Compressing document...",
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

    final originalSize = await widget.pdfFile.length();
    final compressedFile = await PdfHelper.compressPdfOrImageFile(
      inputFile: widget.pdfFile,
      safDirectoryUri: widget.safDirectoryUri,
    );

    if (mounted) Navigator.pop(context);

    if (compressedFile != null && compressedFile.existsSync()) {
      final newSize = await compressedFile.length();
      final savedBytes = originalSize > newSize ? originalSize - newSize : 0;
      final savedPercentage = originalSize > 0
          ? ((savedBytes / originalSize) * 100).toStringAsFixed(1)
          : "0";

      final originalFormatted = (originalSize / (1024 * 1024)).toStringAsFixed(
        2,
      );
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
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: royalblue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: allradius(10.r)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PDFReaderPage(
                        pdfFile: compressedFile,
                        safDirectoryUri: widget.safDirectoryUri,
                      ),
                    ),
                  );
                },
                child: const Text("Open Compressed PDF"),
              ),
            ],
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to compress PDF document.")),
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
                Navigator.pushReplacement(
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
                Navigator.pushReplacement(
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

  void _showPageGridSelectionDialog() {
    final pageCount = _session?.pages.length ?? 0;
    if (pageCount == 0) return;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        String searchQuery = "";

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final query = searchQuery.trim().toLowerCase();
            final matchingIndices = List.generate(pageCount, (i) => i).where((
              index,
            ) {
              if (query.isEmpty) return true;
              final pageNumStr = "${index + 1}";
              final pageLabel = "page ${index + 1}";
              return pageNumStr == query ||
                  pageNumStr.contains(query) ||
                  pageLabel.contains(query);
            }).toList();

            return AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              contentPadding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 16.h),
              titlePadding: EdgeInsets.symmetric(
                horizontal: 14.w,
                vertical: 12.h,
              ),
              shape: RoundedRectangleBorder(borderRadius: allradius(16.r)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Go To Page",
                    style: GoogleFonts.outfit(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 18.sp,
                    ),
                  ),
                  InkWell(
                    borderRadius: allradius(12.r),
                    onTap: () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: EdgeInsets.all(4.r),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20.r,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: getWidth(context),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Realtime Search Bar
                    TextField(
                      controller: searchController,
                      style: GoogleFonts.instrumentSans(
                        fontSize: 14.sp,
                        color: theme.colorScheme.onSurface,
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          searchQuery = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: "Search page number...",
                        hintStyle: GoogleFonts.instrumentSans(
                          fontSize: 13.sp,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 20.r,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear_rounded,
                                  size: 18.r,
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.black54,
                                ),
                                onPressed: () {
                                  searchController.clear();
                                  setDialogState(() {
                                    searchQuery = "";
                                  });
                                },
                              )
                            : null,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 10.h,
                          horizontal: 12.w,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: allradius(12.r),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),

                    // Filtered Pages Grid
                    Flexible(
                      child: Container(
                        constraints: BoxConstraints(
                          maxHeight: getHeight(context) * 0.55,
                        ),
                        child: matchingIndices.isEmpty
                            ? Padding(
                                padding: EdgeInsets.symmetric(vertical: 24.h),
                                child: Center(
                                  child: Text(
                                    "No page matching '$searchQuery'",
                                    style: GoogleFonts.instrumentSans(
                                      color: isDark
                                          ? Colors.white60
                                          : Colors.black54,
                                      fontSize: 13.sp,
                                    ),
                                  ),
                                ),
                              )
                            : SingleChildScrollView(
                                child: Wrap(
                                  spacing: 10.w,
                                  runSpacing: 10.h,
                                  alignment: WrapAlignment.spaceEvenly,
                                  children: matchingIndices.map((index) {
                                    final pageModel = _session!.pages[index];
                                    final isSelected =
                                        index == _currentPageIndex;
                                    return InkWell(
                                      onTap: () {
                                        Navigator.of(context).pop();
                                        setState(() {
                                          _currentPageIndex = index;
                                          _isPageZoomed = false;
                                        });
                                        if (_scrollDirection == Axis.vertical) {
                                          if (_verticalScrollController
                                              .hasClients) {
                                            final isDouble =
                                                _displayLayout ==
                                                PageDisplayLayout.doublePage;
                                            final targetIdx = isDouble
                                                ? (index / 2).floor()
                                                : index;
                                            final estimatedHeight =
                                                (getHeight(context) * 0.8) +
                                                10.h;
                                            _verticalScrollController.jumpTo(
                                              (targetIdx * estimatedHeight)
                                                  .clamp(
                                                    0.0,
                                                    _verticalScrollController
                                                        .position
                                                        .maxScrollExtent,
                                                  ),
                                            );
                                          }
                                        } else {
                                          if (_pageController.hasClients) {
                                            final isDouble =
                                                _displayLayout ==
                                                PageDisplayLayout.doublePage;
                                            _pageController.jumpToPage(
                                              isDouble
                                                  ? (index / 2).floor()
                                                  : index,
                                            );
                                          }
                                        }
                                      },
                                      borderRadius: allradius(10.r),
                                      child: Container(
                                        width: 75.w,
                                        padding: EdgeInsets.all(6.r),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? theme.colorScheme.primary
                                                    .withValues(alpha: 0.15)
                                              : (isDark
                                                    ? Colors.white.withValues(
                                                        alpha: 0.05,
                                                      )
                                                    : Colors.grey.shade100),
                                          borderRadius: allradius(10.r),
                                          border: Border.all(
                                            color: isSelected
                                                ? theme.colorScheme.primary
                                                : (isDark
                                                      ? Colors.white12
                                                      : Colors.black12),
                                            width: isSelected ? 2 : 1,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              height: 90.h,
                                              width: double.infinity,
                                              decoration: BoxDecoration(
                                                borderRadius: allradius(6.r),
                                                color: Colors.white10,
                                              ),
                                              child: ClipRRect(
                                                borderRadius: allradius(6.r),
                                                child: _buildThumbnailImage(
                                                  pageModel,
                                                ),
                                              ),
                                            ),
                                            SizedBox(height: 6.h),
                                            Text(
                                              "Page ${index + 1}",
                                              style: GoogleFonts.outfit(
                                                fontSize: 11.sp,
                                                fontWeight: isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.w500,
                                                color: isSelected
                                                    ? theme.colorScheme.primary
                                                    : (isDark
                                                          ? Colors.white70
                                                          : Colors.black87),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
    } else if (page.cachedImagePath != null &&
        File(page.cachedImagePath!).existsSync()) {
      return Image.file(
        File(page.cachedImagePath!),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.picture_as_pdf_rounded),
      );
    } else if (page.originalPageIndex != null) {
      return PdfPageImageWidget(
        key: ValueKey(
          "${page.sourcePdfFile?.path ?? widget.pdfFile.path}_${page.originalPageIndex}_thumb_$_renderVersion",
        ),
        pdfFile: page.sourcePdfFile ?? widget.pdfFile,
        pageNumber: page.originalPageIndex!,
        fit: BoxFit.contain,
        scale: 0.5,
        version: _renderVersion,
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
              fontSize: 10.sp,
            ),
          ),
        ),
      );
    }
  }

  Future<bool?> _showUnsavedChangesDialog() async {
    final theme = Theme.of(context);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: allradius(14.r)),
        title: Text(
          "Unsaved Changes",
          style: GoogleFonts.outfit(color: theme.colorScheme.onSurface),
        ),
        content: Text(
          "You have unsaved changes. Would you like to save before leaving?",
          style: GoogleFonts.instrumentSans(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              "Discard",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop(false);
              await _promptSavePdf();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
            ),
            child: const Text("Save...", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

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
              Text(
                _statusText,
                style: GoogleFonts.instrumentSans(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 14.sp,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final pageCount = _session?.pages.length ?? 0;
    final pageModel = pageCount > 0 ? _session!.pages[_currentPageIndex] : null;

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _showUnsavedChangesDialog();
        if (shouldExit == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF101014)
            : theme.scaffoldBackgroundColor,
        extendBodyBehindAppBar: true,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: AnimatedSlide(
            offset: (_isAppBarVisible && !_isPageZoomed && !_isPinching)
                ? Offset.zero
                : const Offset(0, -1.2),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: AppBar(
              backgroundColor: theme.appBarTheme.backgroundColor,
              title: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_hasUnsavedChanges) ...[
                              Container(
                                width: 7.r,
                                height: 7.r,
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Gap(6.w),
                            ],
                            Flexible(
                              child: Text(
                                widget.pdfFile.path.split('/').last,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  color: theme.appBarTheme.foregroundColor,
                                  fontSize: 16.sp,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          pageCount > 0
                              ? "Page ${_currentPageIndex + 1} of $pageCount"
                              : "No pages",
                          style: GoogleFonts.instrumentSans(
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              iconTheme: IconThemeData(
                color: theme.appBarTheme.iconTheme?.color,
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    _isAnnotatingMode
                        ? Icons.draw_rounded
                        : Icons.draw_outlined,
                    color: _isAnnotatingMode ? theme.colorScheme.primary : null,
                  ),
                  tooltip: _isAnnotatingMode ? "Exit Annotation" : "Annotate",
                  onPressed: () {
                    if (_isAnnotatingMode) {
                      _exitAnnotationMode();
                    } else {
                      _enterAnnotationMode();
                    }
                  },
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: theme.appBarTheme.iconTheme?.color,
                  ),
                  tooltip: "Options",
                  onSelected: (value) {
                    switch (value) {
                      case 'save':
                        _saveAndOverwrite();
                        break;
                      case 'save_as':
                        _saveAsNew();
                        break;
                      case 'search':
                        _showPageGridSelectionDialog();
                        break;
                      case 'toggle_view_mode':
                        _toggleScrollDirection(
                          _scrollDirection == Axis.vertical
                              ? Axis.horizontal
                              : Axis.vertical,
                        );
                        break;
                      case 'toggle_layout':
                        setState(() {
                          _transformationController.value = Matrix4.identity();
                          _isPageZoomed = false;
                          if (_displayLayout == PageDisplayLayout.single) {
                            _displayLayout = PageDisplayLayout.doublePage;
                          } else {
                            _displayLayout = PageDisplayLayout.single;
                          }
                        });
                        break;
                      case 'extract_text':
                        _openExtractTextBottomSheet();
                        break;
                      case 'edit_pdf':
                        _showEditToolsBottomSheet();
                        break;
                      case 'share':
                        _sharePdf();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    if (_hasUnsavedChanges) ...[
                      PopupMenuItem<String>(
                        value: 'save',
                        child: Text(
                          "Save",
                          style: GoogleFonts.instrumentSans(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'save_as',
                        child: Text(
                          "Save as",
                          style: GoogleFonts.instrumentSans(),
                        ),
                      ),
                      const PopupMenuDivider(),
                    ],
                    PopupMenuItem<String>(
                      value: 'extract_text',
                      child: Text(
                        "Extract Text",
                        style: GoogleFonts.instrumentSans(),
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'search',
                      child: Text(
                        "Search",
                        style: GoogleFonts.instrumentSans(),
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'toggle_view_mode',
                      child: Text(
                        _scrollDirection == Axis.vertical
                            ? "Horizontal View"
                            : "Vertical View",
                        style: GoogleFonts.instrumentSans(),
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'toggle_layout',
                      child: Text(
                        _displayLayout == PageDisplayLayout.doublePage
                            ? "Single Page"
                            : "Double Page",
                        style: GoogleFonts.instrumentSans(),
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'edit_pdf',
                      child: Text("Tools", style: GoogleFonts.instrumentSans()),
                    ),
                    PopupMenuItem<String>(
                      value: 'share',
                      child: Text(
                        "Share PDF",
                        style: GoogleFonts.instrumentSans(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: pageModel == null
            ? Center(
                child: Text(
                  "No pages in this document.",
                  style: TextStyle(color: theme.colorScheme.onSurface),
                ),
              )
            : NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is UserScrollNotification) {
                    if (notification.direction == ScrollDirection.reverse) {
                      if (_isAppBarVisible) {
                        setState(() {
                          _isAppBarVisible = false;
                        });
                      }
                    } else if (notification.direction ==
                        ScrollDirection.forward) {
                      if (!_isAppBarVisible && !_isPageZoomed && !_isPinching) {
                        setState(() {
                          _isAppBarVisible = true;
                        });
                      }
                    }
                  }
                  return false;
                },
                child: Stack(
                  children: [
                    // Main viewport wrapped with InteractiveViewer and GestureDetector for Pinch-Zoom & Double-Tap reset
                    Positioned.fill(
                      child: Listener(
                        onPointerDown: (_) {
                          _activePointers++;
                          if (_activePointers >= 2 && !_isPinching) {
                            setState(() {
                              _isPinching = true;
                              _isAppBarVisible = false;
                            });
                          }
                        },
                        onPointerUp: (_) {
                          _activePointers = (_activePointers - 1).clamp(0, 10);
                          if (_activePointers < 2 && _isPinching) {
                            setState(() {
                              _isPinching = false;
                            });
                          }
                        },
                        onPointerCancel: (_) {
                          _activePointers = (_activePointers - 1).clamp(0, 10);
                          if (_activePointers < 2 && _isPinching) {
                            setState(() {
                              _isPinching = false;
                            });
                          }
                        },
                        child: InteractiveViewer(
                          transformationController: _transformationController,
                          minScale: 1.0,
                          maxScale: 120.0,
                          panEnabled: true,
                          scaleEnabled:
                              !_isAnnotatingMode ||
                              _activeTool == EditorTool.view,
                          boundaryMargin: EdgeInsets.symmetric(
                            horizontal: 160.w,
                            vertical: 160.h,
                          ),
                          clipBehavior: Clip.none,
                          onInteractionUpdate: (details) {
                            final scale = _transformationController.value
                                .getMaxScaleOnAxis();
                            final isZoomed = scale > 1.02;
                            if (isZoomed != _isPageZoomed ||
                                (isZoomed && _isAppBarVisible)) {
                              setState(() {
                                _isPageZoomed = isZoomed;
                                if (isZoomed) {
                                  _isAppBarVisible = false;
                                }
                              });
                            }
                            _updateDynamicRenderScale();
                          },
                          onInteractionEnd: (details) {
                            final scale = _transformationController.value
                                .getMaxScaleOnAxis();
                            if (scale < 1.02) {
                              if (_transformationController.value !=
                                  Matrix4.identity()) {
                                _animateZoomTo(Matrix4.identity());
                              }
                              if (_isPageZoomed) {
                                setState(() {
                                  _isPageZoomed = false;
                                });
                              }
                            } else {
                              if (_isAppBarVisible) {
                                setState(() {
                                  _isAppBarVisible = false;
                                });
                              }
                            }
                            _updateDynamicRenderScale();
                          },
                          child: Builder(
                            builder: (context) {
                              final isDouble =
                                  _displayLayout ==
                                  PageDisplayLayout.doublePage;
                              final totalItems = isDouble
                                  ? (pageCount / 2).ceil()
                                  : pageCount;

                              if (_scrollDirection == Axis.vertical) {
                                return ListView.separated(
                                  controller: _verticalScrollController,
                                  padding: EdgeInsets.only(
                                    bottom: 140.h,
                                    top:
                                        MediaQuery.of(context).padding.top +
                                        kToolbarHeight +
                                        (_displayLayout ==
                                                PageDisplayLayout.doublePage
                                            ? 45.h
                                            : 10.h),
                                  ),
                                  itemCount: totalItems,
                                  physics:
                                      (_isPinching ||
                                          (_isAnnotatingMode &&
                                              _activeTool != EditorTool.view))
                                      ? const NeverScrollableScrollPhysics()
                                      : const BouncingScrollPhysics(),
                                  separatorBuilder: (context, index) =>
                                      SizedBox(height: 0.h),
                                  itemBuilder: (context, index) {
                                    if (!isDouble) {
                                      final currentPage =
                                          _session!.pages[index];
                                      return _buildSinglePageViewItem(
                                        currentPage,
                                        index,
                                      );
                                    } else {
                                      final firstIdx = index * 2;
                                      final secondIdx = firstIdx + 1;
                                      return Row(
                                        children: [
                                          Expanded(
                                            child: _buildSinglePageViewItem(
                                              _session!.pages[firstIdx],
                                              firstIdx,
                                            ),
                                          ),
                                          SizedBox(width: 10.w),
                                          if (secondIdx < pageCount)
                                            Expanded(
                                              child: _buildSinglePageViewItem(
                                                _session!.pages[secondIdx],
                                                secondIdx,
                                              ),
                                            )
                                          else
                                            const Spacer(),
                                        ],
                                      );
                                    }
                                  },
                                );
                              } else {
                                return Padding(
                                  padding: EdgeInsets.only(
                                    top:
                                        MediaQuery.of(context).padding.top +
                                        kToolbarHeight,
                                  ),
                                  child: PageView.builder(
                                    controller: _pageController,
                                    scrollDirection: Axis.horizontal,
                                    physics:
                                        (_isPinching ||
                                            _isPageZoomed ||
                                            (_isAnnotatingMode &&
                                                _activeTool != EditorTool.view))
                                        ? const NeverScrollableScrollPhysics()
                                        : const BouncingScrollPhysics(),
                                    itemCount: totalItems,
                                    onPageChanged: (index) {
                                      setState(() {
                                        _currentPageIndex = isDouble
                                            ? (index * 2)
                                            : index;
                                        _isPageZoomed = false;
                                      });
                                    },
                                    itemBuilder: (context, index) {
                                      if (!isDouble) {
                                        final currentPage =
                                            _session!.pages[index];
                                        return _buildSinglePageViewItem(
                                          currentPage,
                                          index,
                                        );
                                      } else {
                                        final firstIdx = index * 2;
                                        final secondIdx = firstIdx + 1;
                                        return Row(
                                          children: [
                                            Expanded(
                                              child: _buildSinglePageViewItem(
                                                _session!.pages[firstIdx],
                                                firstIdx,
                                              ),
                                            ),
                                            SizedBox(width: 10.w),
                                            if (secondIdx < pageCount)
                                              Expanded(
                                                child: _buildSinglePageViewItem(
                                                  _session!.pages[secondIdx],
                                                  secondIdx,
                                                ),
                                              )
                                            else
                                              const Spacer(),
                                          ],
                                        );
                                      }
                                    },
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ),

                    // Left Vertical Overlay (Centered Left)
                    if (_isAnnotatingMode)
                      Positioned(
                        left: 12.w,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: _buildLeftAnnotationMenu(pageModel),
                        ),
                      ),

                    // Right Vertical Overlay (Bottom Right)
                    if (_isAnnotatingMode)
                      Positioned(
                        right: 12.w,
                        bottom: 24.h,
                        child: _buildRightAnnotationMenu(pageModel),
                      ),

                    // Saving overlay indicator
                    if (_isSaving)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black54,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(
                                  color: Colors.purpleAccent,
                                ),
                                SizedBox(height: 16.h),
                                Text(
                                  "Compiling and exporting PDF...",
                                  style: GoogleFonts.instrumentSans(
                                    color: Colors.white,
                                    fontSize: 14.sp,
                                  ),
                                ),
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

  Widget _buildPageBackground(PdfPageModel pageModel) {
    if (pageModel.newImageFilePath != null) {
      return Image.file(
        File(pageModel.newImageFilePath!),
        fit: BoxFit.fill,
        filterQuality: FilterQuality.high,
      );
    } else if (pageModel.originalPageIndex != null) {
      return PdfPageImageWidget(
        key: ValueKey(
          "${pageModel.sourcePdfFile?.path ?? widget.pdfFile.path}_${pageModel.originalPageIndex}_$_renderVersion",
        ),
        pdfFile: pageModel.sourcePdfFile ?? widget.pdfFile,
        pageNumber: pageModel.originalPageIndex!,
        fit: BoxFit.fill,
        scale: _dynamicRenderScale,
        version: _renderVersion,
      );
    } else if (pageModel.cachedImagePath != null &&
        File(pageModel.cachedImagePath!).existsSync()) {
      return Image.file(
        File(pageModel.cachedImagePath!),
        fit: BoxFit.fill,
        filterQuality: FilterQuality.high,
      );
    }
    return Container(color: Colors.white);
  }

  Widget _buildSinglePageViewItem(PdfPageModel currentPage, int index) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (_activeTool == EditorTool.view && !_isPageZoomed && !_isPinching) {
          setState(() {
            _isAppBarVisible = !_isAppBarVisible;
          });
        }
      },
      onDoubleTapDown: (details) {
        _doubleTapDetails = details;
      },
      onDoubleTap: _handleDoubleTap,
      child: PdfPageViewItem(
        pageModel: currentPage,
        pageIndex: index,
        currentPageIndex: _currentPageIndex,
        activeTool: _activeTool,
        selectedColor: _selectedColor,
        strokeWidth: _strokeWidth,
        currentPoints: _currentPoints,
        onDrawingStarted: (pts) {
          setState(() {
            _currentPoints = pts;
            _selectedAnnotation = null;
          });
        },
        onDrawingUpdated: (pts) {
          setState(() {
            _currentPoints = pts;
          });
        },
        onDrawingEnded: () {
          setState(() {
            _currentPoints = [];
          });
          _updateUnsavedChangesState();
        },
        fallbackPdfFile: widget.pdfFile,
        onAddDrawing: (newDrawing) {
          setState(() {
            currentPage.drawings.add(newDrawing);
          });
          _updateUnsavedChangesState();
        },
        onOpenExtractText: _openExtractTextBottomSheet,
        onLongPressAnnotation: () {},
        onZoomChanged: (isZoomed) {
          setState(() {
            _isPageZoomed = isZoomed;
          });
        },
        buildPageBackground: _buildPageBackground,
        selectedAnnotation: _selectedAnnotation,
        onSelectAnnotation: _onSelectAnnotation,
        selectedOverlayItem: _selectedOverlayItem,
        onSelectOverlayItem: (item) {
          setState(() {
            _selectedOverlayItem = item;
            if (item != null) _selectedAnnotation = null;
          });
        },
        onAnnotationMoved: _onAnnotationMoved,
        onDeleteAnnotation: _onDeleteAnnotation,
        onUpdateAnnotationColor: _onUpdateAnnotationColor,
      ),
    );
  }

  Widget _buildLeftAnnotationMenu(PdfPageModel pageModel) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF16151B).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: allradius(10.r),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: allradius(20.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 1.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildVerticalToolButton(
                tool: EditorTool.view,
                icon: Icons.touch_app_rounded,
                tooltip: "Touch & Navigation",
              ),
              Gap(8.h),
              _buildVerticalToolButton(
                tool: EditorTool.pen,
                icon: Icons.edit_rounded,
                tooltip: "Pen Tool",
              ),
              Gap(8.h),
              _buildVerticalToolButton(
                tool: EditorTool.highlighter,
                icon: Icons.highlight_rounded,
                tooltip: "Highlighter Tool",
              ),
              Gap(8.h),
              _buildVerticalToolButton(
                tool: EditorTool.resize,
                icon: CommunityMaterialIcons.move_resize_variant,
                tooltip: "Resize Tool",
              ),
              Gap(8.h),
              _buildVerticalToolButton(
                tool: EditorTool.select,
                icon: Icons.open_with_rounded,
                tooltip: "Move Tool",
              ),
              Gap(8.h),
              _buildVerticalActionButton(
                icon: Icons.add_circle_outline_rounded,
                label: "Insert",
                tooltip: "Insert Shape or Image",
                onTap: () => _showInsertOptionsSheet(pageModel),
              ),
              Gap(10.h),
              Divider(
                color: isDark ? Colors.white12 : Colors.black12,
                height: 1,
                indent: 6.w,
                endIndent: 6.w,
              ),
              Gap(8.h),
              _buildVerticalActionButton(
                icon: Icons.help_outline_rounded,
                label: "Help",
                color: isDark ? Colors.lightBlueAccent : Colors.blueAccent,
                tooltip: "Tool Guide & Help",
                onTap: () => _showHelpGuideSheet(pageModel),
              ),
              Gap(8.h),
              _buildVerticalActionButton(
                icon: Icons.close_rounded,
                label: "Exit",
                color: Colors.redAccent,
                tooltip: "Exit Annotation Mode",
                onTap: _exitAnnotationMode,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRightAnnotationMenu(PdfPageModel pageModel) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 54.w,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF16151B).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: allradius(10.r),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: allradius(10.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 1.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Color Wheel Button
              GestureDetector(
                onTap: () async {
                  final newColor = await ColorWheelDialog.show(
                    context,
                    initialColor: _selectedColor,
                  );
                  if (newColor != null) {
                    setState(() {
                      _selectedColor = newColor;
                      if (_selectedAnnotation != null) {
                        _selectedAnnotation!.color = newColor;
                      }
                    });
                  }
                },
                child: Container(
                  width: 30.r,
                  height: 30.r,
                  decoration: BoxDecoration(
                    color: _selectedColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.color_lens_outlined,
                    size: 16.sp,
                    color: _selectedColor.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                  ),
                ),
              ),
              Gap(10.h),
              // Vertical Stroke Size Slider
              if (_activeTool == EditorTool.pen ||
                  _activeTool == EditorTool.highlighter) ...[
                Text(
                  "${_strokeWidth.round()}px",
                  style: GoogleFonts.instrumentSans(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                Gap(4.h),
                SizedBox(
                  height: 90.h,
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 4.h,
                        thumbShape: RoundSliderThumbShape(
                          enabledThumbRadius: 7.r,
                        ),
                      ),
                      child: Slider(
                        value: _strokeWidth,
                        min: 1.0,
                        max: 30.0,
                        activeColor: theme.colorScheme.primary,
                        inactiveColor: isDark ? Colors.white12 : Colors.black12,
                        onChanged: (val) {
                          setState(() {
                            _strokeWidth = val;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                Gap(8.h),
              ],
              Divider(
                color: isDark ? Colors.white12 : Colors.black12,
                height: 1,
                indent: 4.w,
                endIndent: 4.w,
              ),
              Gap(6.h),
              // Undo
              IconButton(
                padding: EdgeInsets.zero,
                constraints: BoxConstraints.tight(Size(36.r, 36.r)),
                icon: Icon(
                  Icons.undo_rounded,
                  size: 20.r,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                tooltip: "Undo",
                onPressed: () => _undoAnnotation(pageModel),
              ),
              // Redo
              IconButton(
                padding: EdgeInsets.zero,
                constraints: BoxConstraints.tight(Size(36.r, 36.r)),
                icon: Icon(
                  Icons.redo_rounded,
                  size: 20.r,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                tooltip: "Redo",
                onPressed: () => _redoAnnotation(pageModel),
              ),
              // Delete
              () {
                final hasSelection =
                    _selectedOverlayItem != null || _selectedAnnotation != null;
                return IconButton(
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints.tight(Size(36.r, 36.r)),
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 20.r,
                    color: hasSelection
                        ? Colors.redAccent
                        : (isDark ? Colors.white24 : Colors.black26),
                  ),
                  tooltip: hasSelection
                      ? "Delete Selected Element"
                      : "No element selected",
                  onPressed: hasSelection
                      ? () => _deleteSelectedAnnotation(pageModel)
                      : null,
                );
              }(),
              // Clear All
              IconButton(
                padding: EdgeInsets.zero,
                constraints: BoxConstraints.tight(Size(36.r, 36.r)),
                icon: Icon(
                  Icons.layers_clear_rounded,
                  size: 20.r,
                  color: Colors.redAccent,
                ),
                tooltip: "Clear Page",
                onPressed: () => _clearAllAnnotations(pageModel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInsertOptionsSheet(PdfPageModel pageModel) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10.r)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Insert An Element",
                      style: GoogleFonts.outfit(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: Icon(Icons.close, size: 22.sp),
                    ),
                  ],
                ),
                Gap(12.h),
                ListTile(
                  leading: Icon(
                    Icons.add_photo_alternate_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(
                    "Insert Image",
                    style: GoogleFonts.instrumentSans(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndAddOverlayImage(pageModel);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.category_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(
                    "Insert Shape",
                    style: GoogleFonts.instrumentSans(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showShapePickerSheet(pageModel);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVerticalToolButton({
    required EditorTool tool,
    required IconData icon,
    String? tooltip,
  }) {
    final isSelected = _activeTool == tool;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final btn = InkWell(
      onTap: () {
        setState(() {
          _activeTool = tool;
        });
      },
      borderRadius: allradius(12.r),
      child: Container(
        width: 44.w,
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Icon(
          icon,
          color: isSelected
              ? theme.colorScheme.primary
              : (isDark ? Colors.white70 : Colors.black87),
          size: 20.sp,
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: btn);
    }
    return btn;
  }

  Widget _buildVerticalActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
    String? tooltip,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final btn = InkWell(
      onTap: onTap,
      borderRadius: allradius(12.r),
      child: Container(
        width: 44.w,
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color ?? (isDark ? Colors.white70 : Colors.black87),
              size: 20.r,
            ),
            SizedBox(height: 2.h),
            Text(
              label,
              style: GoogleFonts.instrumentSans(
                fontSize: 9.sp,
                color:
                    color ??
                    (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
              ),
            ),
          ],
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: btn);
    }
    return btn;
  }

  void _showHelpGuideSheet(PdfPageModel pageModel) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1D24) : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(10.r)),
          ),
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    "Editor Tool Guide & Tips",
                    style: GoogleFonts.outfit(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 24.r,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Gap(12.h),

              // Highlight Box for Deleting Elements
              Container(
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: royalblue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: royalblue.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                      size: 22.sp,
                    ),
                    Gap(10.w),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.outfit(
                            fontSize: 12.sp,
                            color: isDark ? Colors.white70 : Colors.black87,
                            height: 1.4,
                          ),
                          children: [
                            TextSpan(
                              text: "How to Delete an Element:\n",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const TextSpan(
                              text:
                                  "Select any shape or image using either the ",
                            ),
                            TextSpan(
                              text: "Move 🖐️",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: royalblue,
                              ),
                            ),
                            const TextSpan(text: " or "),
                            TextSpan(
                              text: "Resize 📐",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: royalblue,
                              ),
                            ),
                            const TextSpan(
                              text:
                                  " tool, tap the element on screen, then press the red ",
                            ),
                            TextSpan(
                              text: "Delete 🗑️",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.redAccent,
                              ),
                            ),
                            const TextSpan(
                              text:
                                  " button in the right side overlay menu. (Or scale any shape down to 0 to auto-delete!)",
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Gap(16.h),

              Text(
                "Toolbar Quick Reference",
                style: GoogleFonts.outfit(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              Gap(10.h),

              _buildHelpItem(
                icon: Icons.touch_app_rounded,
                title: "Touch & View",
                desc: "Pan, scroll, and pinch to zoom document pages.",
                isDark: isDark,
              ),
              _buildHelpItem(
                icon: Icons.edit_rounded,
                title: "Pen Tool",
                desc: "Draw freehand lines and sketch notes.",
                isDark: isDark,
              ),
              _buildHelpItem(
                icon: Icons.highlight_rounded,
                title: "Highlighter Tool",
                desc: "Highlight text & emphasis areas with transparency.",
                isDark: isDark,
              ),
              _buildHelpItem(
                icon: CommunityMaterialIcons.move_resize_variant,
                title: "Resize Tool",
                desc: "Shows 8-point corner/side guides to scale elements.",
                isDark: isDark,
              ),
              _buildHelpItem(
                icon: Icons.open_with_rounded,
                title: "Move Tool",
                desc:
                    "Displays top drag handle to reposition elements cleanly.",
                isDark: isDark,
              ),
              _buildHelpItem(
                icon: Icons.add_circle_outline_rounded,
                title: "Insert Options",
                desc:
                    "Add customizable shapes (rectangle, circle, star, etc.) & images.",
                isDark: isDark,
              ),
              Gap(16.h),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHelpItem({
    required IconData icon,
    required String title,
    required String desc,
    required bool isDark,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6.r),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, size: 16.sp, color: royalblue),
          ),
          Gap(12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  desc,
                  style: GoogleFonts.outfit(
                    fontSize: 10.5.sp,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndAddOverlayImage(PdfPageModel pageModel) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final overlay = EditorOverlayItem(
          type: ElementType.image,
          imagePath: path,
          position: const Offset(0.5, 0.5),
          width: 0.35,
          height: 0.35,
        );
        setState(() {
          pageModel.overlays.add(overlay);
          _selectedOverlayItem = overlay;
          _selectedAnnotation = null;
          _activeTool = EditorTool.select;
        });
        _updateUnsavedChangesState();
        plainToast(msg: "Image overlay added");
      }
    } catch (e) {
      plainToast(msg: "Error picking image: $e");
    }
  }

  void _showShapePickerSheet(PdfPageModel pageModel) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final shapes = [
      (ShapeType.rectangle, Icons.crop_square_rounded, "Rectangle"),
      (ShapeType.roundedRectangle, Icons.crop_portrait_rounded, "Rounded Rect"),
      (ShapeType.circle, Icons.circle_outlined, "Circle"),
      (ShapeType.oval, Icons.lens_outlined, "Oval"),
      (ShapeType.star, Icons.star_border_rounded, "Star"),
      (ShapeType.heart, Icons.favorite_border_rounded, "Heart"),
      (ShapeType.triangle, Icons.change_history_rounded, "Triangle"),
      (ShapeType.arrow, Icons.arrow_right_alt_rounded, "Arrow"),
      (ShapeType.line, Icons.horizontal_rule_rounded, "Line"),
      (ShapeType.checkmark, Icons.check_circle_outline_rounded, "Check"),
      (ShapeType.cross, Icons.cancel_outlined, "Cross"),
    ];

    int selectedShapeIndex = 0;
    Color shapeColor = _selectedColor;
    double shapeBorderWidth = _strokeWidth.clamp(1.0, 20.0);
    double shapeSize = 0.3;
    bool isFilled = false;

    final presetColors = [
      Colors.red,
      Colors.orange,
      Colors.amber,
      Colors.green,
      Colors.teal,
      royalblue,
      Colors.purple,
      isDark ? Colors.white : Colors.black,
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final selectedShape = shapes[selectedShapeIndex];

            return SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 16.h,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Insert Shape",
                            style: GoogleFonts.outfit(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, size: 22.sp),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      Gap(10.h),

                      // Live Shape Preview Container
                      Container(
                        width: double.infinity,
                        height: 100.h,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.35)
                              : Colors.grey.shade100,
                          borderRadius: allradius(14.r),
                          border: Border.all(
                            color: isDark ? Colors.white12 : Colors.black12,
                            width: 1.0,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              top: 6.h,
                              left: 10.w,
                              child: Text(
                                "Live Preview",
                                style: GoogleFonts.instrumentSans(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.grey.shade500
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ),
                            Center(
                              child: SizedBox(
                                width: 65.w,
                                height: 65.h,
                                child: CustomPaint(
                                  painter: ShapePainter(
                                    shapeType: selectedShape.$1,
                                    fillColor: isFilled
                                        ? shapeColor.withValues(alpha: 0.35)
                                        : Colors.transparent,
                                    borderColor: shapeColor,
                                    borderWidth: shapeBorderWidth,
                                    isFilled: isFilled,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Gap(12.h),

                      // Shape Type Picker Horizontal List
                      Text(
                        "Select Shape",
                        style: GoogleFonts.instrumentSans(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade700,
                        ),
                      ),
                      Gap(6.h),
                      SizedBox(
                        height: 80.h,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: shapes.length,
                          separatorBuilder: (_, _) => Gap(10.w),
                          itemBuilder: (context, index) {
                            final shape = shapes[index];
                            final isSelected = selectedShapeIndex == index;
                            return InkWell(
                              onTap: () {
                                setSheetState(() {
                                  selectedShapeIndex = index;
                                });
                              },
                              borderRadius: allradius(12.r),
                              child: Container(
                                width: 85.w,
                                padding: EdgeInsets.symmetric(vertical: 8.h),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? royalblue.withValues(alpha: 0.15)
                                      : (isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.05,
                                              )
                                            : Colors.black.withValues(
                                                alpha: 0.03,
                                              )),
                                  borderRadius: allradius(12.r),
                                  border: Border.all(
                                    color: isSelected
                                        ? royalblue
                                        : (isDark
                                              ? Colors.white12
                                              : Colors.black12),
                                    width: isSelected ? 1.8 : 1.0,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      shape.$2,
                                      color: isSelected
                                          ? royalblue
                                          : shapeColor,
                                      size: 26.sp,
                                    ),
                                    Gap(4.h),
                                    Text(
                                      shape.$3,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.instrumentSans(
                                        fontSize: 10.sp,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? royalblue
                                            : (isDark
                                                  ? Colors.white70
                                                  : Colors.black87),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Gap(14.h),

                      // Color Picker Row
                      Text(
                        "Color",
                        style: GoogleFonts.instrumentSans(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade700,
                        ),
                      ),
                      Gap(6.h),
                      Row(
                        children: [
                          for (final c in presetColors) ...[
                            GestureDetector(
                              onTap: () {
                                setSheetState(() {
                                  shapeColor = c;
                                });
                              },
                              child: Container(
                                margin: EdgeInsets.only(right: 8.w),
                                width: 28.r,
                                height: 28.r,
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: shapeColor == c
                                        ? royalblue
                                        : Colors.white,
                                    width: shapeColor == c ? 2.5 : 1.5,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 3,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          // Custom Color Wheel Button
                          GestureDetector(
                            onTap: () async {
                              final pickedColor = await ColorWheelDialog.show(
                                context,
                                initialColor: shapeColor,
                              );
                              if (pickedColor != null) {
                                setSheetState(() {
                                  shapeColor = pickedColor;
                                });
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.all(6.r),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.black26,
                                ),
                              ),
                              child: Icon(
                                Icons.color_lens_rounded,
                                size: 18.sp,
                                color: shapeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Gap(14.h),

                      // Border Width Slider
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Border Width",
                            style: GoogleFonts.instrumentSans(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade700,
                            ),
                          ),
                          Text(
                            "${shapeBorderWidth.toStringAsFixed(1)} px",
                            style: GoogleFonts.outfit(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: royalblue,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: shapeBorderWidth,
                        min: 1.0,
                        max: 20.0,
                        activeColor: royalblue,
                        inactiveColor: isDark ? Colors.white12 : Colors.black12,
                        onChanged: (val) {
                          setSheetState(() {
                            shapeBorderWidth = val;
                          });
                        },
                      ),

                      // Fill Shape Toggle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Fill Shape",
                            style: GoogleFonts.instrumentSans(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade700,
                            ),
                          ),
                          Switch.adaptive(
                            value: isFilled,
                            activeTrackColor: royalblue,
                            onChanged: (val) {
                              setSheetState(() {
                                isFilled = val;
                              });
                            },
                          ),
                        ],
                      ),
                      Gap(10.h),

                      // Insert Shape Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 44.h,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: royalblue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: allradius(10.r),
                            ),
                          ),
                          icon: Icon(selectedShape.$2, size: 20.sp),
                          label: Text(
                            "Insert ${selectedShape.$3}",
                            style: GoogleFonts.outfit(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            final overlay = EditorOverlayItem(
                              type: ElementType.shape,
                              shapeType: selectedShape.$1,
                              strokeColor: shapeColor,
                              fillColor: isFilled
                                  ? shapeColor.withValues(alpha: 0.3)
                                  : Colors.transparent,
                              isFilled: isFilled,
                              strokeWidth: shapeBorderWidth,
                              position: const Offset(0.5, 0.5),
                              width: shapeSize,
                              height: shapeSize,
                            );
                            setState(() {
                              pageModel.overlays.add(overlay);
                              _selectedOverlayItem = overlay;
                              _selectedAnnotation = null;
                              _activeTool = EditorTool.select;
                            });
                            _updateUnsavedChangesState();
                            plainToast(msg: "${selectedShape.$3} added");
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
