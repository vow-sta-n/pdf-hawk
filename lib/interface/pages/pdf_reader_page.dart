/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfhawk/data/res/enum.dart';
import 'package:pdfhawk/data/res/utils.dart';
import 'package:pdfhawk/interface/widgets/pdf_page_renderer.dart';
import 'package:pdfhawk/interface/widgets/pdf_page_view_item.dart';
import 'package:pdfhawk/logic/helpers/pdf_helper.dart';
import 'package:pdfhawk/interface/pages/master_pdf_editor_page.dart';
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
  Color _selectedColor = Colors.red;
  late PageController _pageController;
  late ScrollController _verticalScrollController;
  late TransformationController _transformationController;
  late AnimationController _zoomAnimationController;
  Animation<Matrix4>? _zoomAnimation;
  TapDownDetails? _doubleTapDetails;
  List<Offset> _currentPoints = [];
  bool _hasUnsavedChanges = false;
  bool _isPageZoomed = false;
  int _activePointers = 0;
  bool _isPinching = false;
  double _dynamicRenderScale = 2.0;
  Timer? _zoomDebounceTimer;
  Map<int, List<DrawingPath>> _sessionInitialDrawings = {};
  DrawingPath? _selectedAnnotation;
  int _currentPageIndex = 0;
  PdfEditSession? _session;
  bool _isLoading = true;
  bool _isSaving = false;
  double _strokeWidth = 4.0;
  final List<Color> _colors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.orange,
    Colors.purple,
    Colors.black,
  ];

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
      });
    }
  }

  void _toggleScrollDirection(Axis direction) {
    if (_scrollDirection == direction) return;
    setState(() {
      _scrollDirection = direction;
      _transformationController.value = Matrix4.identity();
      _isPageZoomed = false;
      _pageController.dispose();
      _pageController = PageController(initialPage: _currentPageIndex);
    });
  }

  void _enterAnnotationMode() {
    HapticFeedback.mediumImpact();
    _sessionInitialDrawings = {
      for (int i = 0; i < (_session?.pages.length ?? 0); i++)
        i: List<DrawingPath>.from(_session!.pages[i].drawings),
    };
    setState(() {
      _activeTool = EditorTool.pen;
    });
  }

  void _cancelAnnotationMode() {
    if (_session != null) {
      for (final entry in _sessionInitialDrawings.entries) {
        if (entry.key < _session!.pages.length) {
          _session!.pages[entry.key].drawings
            ..clear()
            ..addAll(entry.value);
        }
      }
    }
    setState(() {
      _currentPoints = [];
      _selectedAnnotation = null;
      _activeTool = EditorTool.view;
    });
  }

  void _exitAnnotationMode() {
    setState(() {
      _selectedAnnotation = null;
      _activeTool = EditorTool.view;
    });
  }

  void _onSelectAnnotation(PdfPageModel pageModel, DrawingPath? annotation) {
    setState(() {
      _selectedAnnotation = annotation;
    });
  }

  void _onDeleteAnnotation(PdfPageModel pageModel, DrawingPath annotation) {
    HapticFeedback.mediumImpact();
    setState(() {
      pageModel.drawings.remove(annotation);
      _selectedAnnotation = null;
      _hasUnsavedChanges = true;
    });
    plainToast(msg: "Annotation deleted");
  }

  void _onUpdateAnnotationColor(DrawingPath annotation, Color newColor) {
    HapticFeedback.selectionClick();
    setState(() {
      annotation.color = newColor;
      _hasUnsavedChanges = true;
    });
  }

  void _onAnnotationMoved() {
    _hasUnsavedChanges = true;
  }

  Future<void> _initSession() async {
    setState(() {
      _isLoading = true;
      _statusText = "Analyzing and rendering pages...";
    });
    try {
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
                      borderRadius: BorderRadius.circular(10.r),
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
                      borderRadius: BorderRadius.circular(12.r),
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
                      borderRadius: BorderRadius.circular(12.r),
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
    setState(() {
      _isSaving = true;
    });

    try {
      final compiledFile = await PdfHelper.saveSession(
        session: _session!,
        safDirectoryUri: widget.safDirectoryUri,
      );

      // Overwrite the original file bytes
      final originalBytes = await compiledFile.readAsBytes();
      await widget.pdfFile.writeAsBytes(originalBytes);

      setState(() {
        _hasUnsavedChanges = false;
      });

      if (!mounted) return;
      plainToast(msg: "PDF modified and overwritten successfully!");
    } catch (e) {
      if (!mounted) return;
      plainToast(msg: "Failed to overwrite PDF: $e. Try Save As New.");
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _saveAsNew() async {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("PDF saved as copy successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint("Failed to save PDF: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to save PDF: $e")));
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _openMasterEditor() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MasterPdfEditorPage(
          pdfFile: widget.pdfFile,
          safDirectoryUri: widget.safDirectoryUri,
        ),
      ),
    );
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
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
                    borderRadius: BorderRadius.circular(12.r),
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
                          borderRadius: BorderRadius.circular(12.r),
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
                                      borderRadius: BorderRadius.circular(10.r),
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
                                          borderRadius: BorderRadius.circular(
                                            10.r,
                                          ),
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
                                                borderRadius:
                                                    BorderRadius.circular(6.r),
                                                color: Colors.white10,
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(6.r),
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
        pdfFile: page.sourcePdfFile ?? widget.pdfFile,
        pageNumber: page.originalPageIndex!,
        fit: BoxFit.contain,
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
        appBar: AppBar(
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

              if (_hasUnsavedChanges)
                IconButton(
                  icon: Icon(Icons.check, color: theme.colorScheme.primary),
                  tooltip: "Save Changes",
                  onPressed: _promptSavePdf,
                ),
            ],
          ),
          iconTheme: IconThemeData(color: theme.appBarTheme.iconTheme?.color),
        ),
        body: pageModel == null
            ? Center(
                child: Text(
                  "No pages in this document.",
                  style: TextStyle(color: theme.colorScheme.onSurface),
                ),
              )
            : Stack(
                children: [
                  // Main viewport wrapped with InteractiveViewer and GestureDetector for Pinch-Zoom & Double-Tap reset
                  Positioned.fill(
                    child: Listener(
                      onPointerDown: (_) {
                        _activePointers++;
                        if (_activePointers >= 2 && !_isPinching) {
                          setState(() {
                            _isPinching = true;
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
                        scaleEnabled: _activeTool == EditorTool.view,
                        boundaryMargin: EdgeInsets.symmetric(
                          horizontal: 160.w,
                          vertical: 160.h,
                        ),
                        clipBehavior: Clip.none,
                        onInteractionUpdate: (details) {
                          final scale = _transformationController.value
                              .getMaxScaleOnAxis();
                          final isZoomed = scale > 1.02;
                          if (isZoomed != _isPageZoomed) {
                            setState(() {
                              _isPageZoomed = isZoomed;
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
                          }
                          _updateDynamicRenderScale();
                        },
                        child: Builder(
                          builder: (context) {
                            final isDouble =
                                _displayLayout == PageDisplayLayout.doublePage;
                            final totalItems = isDouble
                                ? (pageCount / 2).ceil()
                                : pageCount;

                            if (_scrollDirection == Axis.vertical) {
                              return ListView.separated(
                                controller: _verticalScrollController,
                                padding: EdgeInsets.only(
                                  bottom: 140.h,
                                  top:
                                      _displayLayout ==
                                          PageDisplayLayout.doublePage
                                      ? 45.h
                                      : 10.h,
                                ),
                                itemCount: totalItems,
                                physics:
                                    (_isPinching ||
                                        _activeTool != EditorTool.view)
                                    ? const NeverScrollableScrollPhysics()
                                    : const BouncingScrollPhysics(),
                                separatorBuilder: (context, index) =>
                                    SizedBox(height: 0.h),
                                itemBuilder: (context, index) {
                                  if (!isDouble) {
                                    final currentPage = _session!.pages[index];
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
                              return PageView.builder(
                                controller: _pageController,
                                scrollDirection: Axis.horizontal,
                                physics:
                                    (_isPinching ||
                                        _isPageZoomed ||
                                        _activeTool != EditorTool.view)
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
                                    final currentPage = _session!.pages[index];
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
                            }
                          },
                        ),
                      ),
                    ),
                  ),

                  // Floating Toolbar or Annotation Options Overlay
                  Positioned(
                    left: 20.w,
                    right: 20.w,
                    bottom: 20.h,
                    child: _activeTool == EditorTool.view
                        ? _buildFloatingToolbar(pageModel)
                        : _buildAnnotationOverlay(pageModel),
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
    );
  }

  Widget _buildPageBackground(PdfPageModel pageModel) {
    if (pageModel.newImageFilePath != null) {
      return Image.file(
        File(pageModel.newImageFilePath!),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      );
    } else if (pageModel.originalPageIndex != null) {
      return PdfPageImageWidget(
        pdfFile: pageModel.sourcePdfFile ?? widget.pdfFile,
        pageNumber: pageModel.originalPageIndex!,
        fit: BoxFit.contain,
        scale: _dynamicRenderScale,
      );
    } else if (pageModel.cachedImagePath != null &&
        File(pageModel.cachedImagePath!).existsSync()) {
      return Image.file(
        File(pageModel.cachedImagePath!),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      );
    }
    return Container(color: Colors.white);
  }

  void _eraseDrawingsAt(PdfPageModel pageModel, List<Offset> erasePoints) {
    const threshold = 15.0;
    bool deleted = false;
    setState(() {
      pageModel.drawings.removeWhere((drawing) {
        for (final pt in drawing.points) {
          for (final ep in erasePoints) {
            if ((pt - ep).distance < threshold) {
              deleted = true;
              return true;
            }
          }
        }
        return false;
      });
      if (deleted) {
        _hasUnsavedChanges = true;
      }
    });
  }

  Widget _buildFloatingToolbar(PdfPageModel pageModel) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF16151B).withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 8.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildViewModeToggleButton(),
                _buildPageActionButton(
                  icon: Icons.auto_stories_rounded,
                  label: "Double Page",
                  description:
                      "Display two pages side-by-side in book spread layout.",
                  onTap: () {
                    setState(() {
                      _transformationController.value = Matrix4.identity();
                      _isPageZoomed = false;
                      if (_displayLayout == PageDisplayLayout.single) {
                        _displayLayout = PageDisplayLayout.doublePage;
                      } else {
                        _displayLayout = PageDisplayLayout.single;
                      }
                    });
                  },
                  color: _displayLayout == PageDisplayLayout.doublePage
                      ? theme.colorScheme.primary
                      : null,
                ),
                _buildPageActionButton(
                  icon: Icons.search,
                  label: "Search Page",
                  description:
                      "View all document pages in a grid to quickly jump to any page.",
                  onTap: _showPageGridSelectionDialog,
                ),
                _buildPageActionButton(
                  icon: Icons.edit_note_rounded,
                  label: "Editor",
                  description:
                      "Open PDF Editor to reorder, add, delete, sign, or combine pages.",
                  onTap: _openMasterEditor,
                  color: null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSinglePageViewItem(PdfPageModel currentPage, int index) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
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
            _hasUnsavedChanges = true;
          });
        },
        onErase: _eraseDrawingsAt,
        onLongPressAnnotation: _enterAnnotationMode,
        onZoomChanged: (isZoomed) {
          setState(() {
            _isPageZoomed = isZoomed;
          });
        },
        buildPageBackground: _buildPageBackground,
        selectedAnnotation: _selectedAnnotation,
        onSelectAnnotation: _onSelectAnnotation,
        onAnnotationMoved: _onAnnotationMoved,
        onDeleteAnnotation: _onDeleteAnnotation,
        onUpdateAnnotationColor: _onUpdateAnnotationColor,
        availableColors: _colors,
      ),
    );
  }

  Widget _buildDescriptiveTooltip({
    required String title,
    required String description,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Tooltip(
      triggerMode: TooltipTriggerMode.longPress,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      verticalOffset: 28.h,
      constraints: BoxConstraints(maxWidth: getWidth(context) / 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF23222A) : const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      richMessage: TextSpan(
        children: [
          TextSpan(
            text: "$title\n",
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 13.sp,
              color: Colors.white,
              height: 1.4,
            ),
          ),
          TextSpan(
            text: description,
            style: GoogleFonts.instrumentSans(
              fontSize: 11.sp,
              color: Colors.white70,
              height: 1.3,
            ),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildViewModeToggleButton() {
    final isVertical = _scrollDirection == Axis.vertical;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final title = isVertical ? "Vertical View Mode" : "Horizontal View Mode";
    final description = isVertical
        ? "Currently in vertical mode. Tap to switch to horizontal page swiping reading mode."
        : "Currently in horizontal mode. Tap to switch to vertical continuous scrolling reading mode.";

    return _buildDescriptiveTooltip(
      title: title,
      description: description,
      child: GestureDetector(
        onTap: () {
          _toggleScrollDirection(isVertical ? Axis.horizontal : Axis.vertical);
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          child: Icon(
            isVertical ? Icons.swap_vert_rounded : Icons.swap_horiz_rounded,
            size: 22.r,
            color: isDark ? white : black,
          ),
        ),
      ),
    );
  }

  Widget _buildAnnotationOverlay(PdfPageModel pageModel) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF16151B).withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16.r),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: EdgeInsets.all(14.r),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with Title and Done Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.draw,
                          color: theme.colorScheme.primary,
                          size: 24.r,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          "Add Annotation",
                          style: GoogleFonts.outfit(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        InkWell(
                          onTap: _cancelAnnotationMode,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(Icons.close_rounded, size: 18.r),
                          ),
                        ),
                        SizedBox(width: 4.w),
                        InkWell(
                          onTap: _exitAnnotationMode,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(Icons.check_rounded, size: 18.r),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                Divider(
                  color: isDark ? Colors.white10 : Colors.black12,
                  height: 1,
                ),
                SizedBox(height: 10.h),
                // Tool selection
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildDrawingToolButton(
                      EditorTool.pen,
                      Icons.edit_rounded,
                      "Pen",
                    ),
                    _buildDrawingToolButton(
                      EditorTool.highlighter,
                      Icons.border_color_rounded,
                      "Highlight",
                    ),
                    _buildDrawingToolButton(
                      EditorTool.eraser,
                      Icons.cleaning_services_rounded,
                      "Eraser",
                    ),
                  ],
                ),
                if (_activeTool == EditorTool.pen ||
                    _activeTool == EditorTool.highlighter) ...[
                  SizedBox(height: 10.h),
                  Row(
                    children: [
                      Text(
                        "Size: ",
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontSize: 11.sp,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: _strokeWidth,
                          min: 1.0,
                          max: 20.0,
                          activeColor: theme.colorScheme.primary,
                          inactiveColor: isDark
                              ? Colors.white12
                              : Colors.black12,
                          onChanged: (val) {
                            setState(() {
                              _strokeWidth = val;
                            });
                          },
                        ),
                      ),
                      Text(
                        _strokeWidth.toStringAsFixed(0),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 11.sp,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  SizedBox(
                    height: 32.h,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _colors.length,
                      itemBuilder: (context, index) {
                        final color = _colors[index];
                        final isSelected = _selectedColor == color;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedColor = color;
                            });
                          },
                          child: Container(
                            width: 24.r,
                            height: 24.r,
                            margin: EdgeInsets.only(right: 12.w),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black,
                                      width: 2.r,
                                    )
                                  : Border.all(color: Colors.transparent),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawingToolButton(EditorTool tool, IconData icon, String label) {
    final isSelected = _activeTool == tool;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        setState(() {
          _activeTool = tool;
        });
      },
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? theme.colorScheme.primary
                  : (isDark ? Colors.white70 : Colors.black87),
              size: 20.r,
            ),
            SizedBox(height: 2.h),
            Text(
              label,
              style: GoogleFonts.instrumentSans(
                fontSize: 10.sp,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black87)
                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageActionButton({
    required IconData icon,
    required String label,
    required String description,
    required VoidCallback onTap,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveColor = color ?? (isDark ? Colors.white : Colors.black87);

    return _buildDescriptiveTooltip(
      title: label,
      description: description,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),

          child: Icon(icon, color: effectiveColor, size: 22.r),
        ),
      ),
    );
  }
}
