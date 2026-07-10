import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfhawk/logic/helpers/pdf_helper.dart';
import 'package:pdfhawk/interface/rearrange_page.dart';

enum EditorTool { view, pen, highlighter, eraser }

enum ToolbarTab { navigate, draw, pages, export }

class PdfEditorPage extends StatefulWidget {
  final File pdfFile;
  final String? safDirectoryUri;

  const PdfEditorPage({super.key, required this.pdfFile, this.safDirectoryUri});

  @override
  State<PdfEditorPage> createState() => _PdfEditorPageState();
}

class _PdfEditorPageState extends State<PdfEditorPage> {
  PdfEditSession? _session;
  int _currentPageIndex = 0;
  bool _isLoading = true;
  bool _isSaving = false;
  String _statusText = "Loading PDF file...";

  // Editor states
  EditorTool _activeTool = EditorTool.view;
  ToolbarTab _activeTab = ToolbarTab.navigate;
  Color _selectedColor = Colors.red;
  double _strokeWidth = 4.0;
  List<Offset> _currentPoints = [];
  bool _hasUnsavedChanges = false;

  // Brush color options
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
    _initSession();
  }

  Future<void> _initSession() async {
    setState(() {
      _isLoading = true;
      _statusText = "Analyzing and rendering pages...";
    });
    try {
      final session = await PdfHelper.startEditSession(widget.pdfFile);
      setState(() {
        _session = session;
        _isLoading = false;
      });
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
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
                SizedBox(height: 24.h),
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
                Divider(color: isDark ? Colors.white12 : Colors.black12, height: 20.h),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("PDF modified and overwritten successfully!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to overwrite PDF: $e. Try Save As New."),
        ),
      );
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

  void _deleteCurrentPage() {
    if (_session == null || _session!.pages.isEmpty) return;

    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text(
          "Delete Page",
          style: GoogleFonts.outfit(color: theme.colorScheme.onSurface),
        ),
        content: Text(
          "Are you sure you want to delete Page ${_currentPageIndex + 1}?",
          style: GoogleFonts.instrumentSans(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _session!.pages.removeAt(_currentPageIndex);
                _hasUnsavedChanges = true;
                if (_currentPageIndex >= _session!.pages.length &&
                    _currentPageIndex > 0) {
                  _currentPageIndex = _session!.pages.length - 1;
                }
              });
            },
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _addPage() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return SafeArea(
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
                  Navigator.of(context).pop();
                  setState(() {
                    _session!.pages.insert(
                      _currentPageIndex + 1,
                      PdfPageModel(
                        originalPageIndex: null,
                        drawings: [],
                        width: 595.0,
                        height: 842.0,
                      ),
                    );
                    _currentPageIndex++;
                    _hasUnsavedChanges = true;
                  });
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
                onTap: () async {
                  Navigator.of(context).pop();
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.image,
                  );
                  if (result != null && result.files.single.path != null) {
                    final imageFile = File(result.files.single.path!);
                    final decodedImage = await decodeImageFromList(
                      await imageFile.readAsBytes(),
                    );
                    setState(() {
                      _session!.pages.insert(
                        _currentPageIndex + 1,
                        PdfPageModel(
                          originalPageIndex: null,
                          newImageFilePath: imageFile.path,
                          drawings: [],
                          width: decodedImage.width.toDouble(),
                          height: decodedImage.height.toDouble(),
                        ),
                      );
                      _currentPageIndex++;
                      _hasUnsavedChanges = true;
                    });
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _openRearrangeScreen() {
    if (_session == null) return;
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => RearrangePage(session: _session!),
          ),
        )
        .then((updatedSession) {
          if (updatedSession != null) {
            setState(() {
              _session = updatedSession;
              _hasUnsavedChanges = true;
              if (_currentPageIndex >= _session!.pages.length) {
                _currentPageIndex = _session!.pages.length - 1;
              }
              if (_currentPageIndex < 0) _currentPageIndex = 0;
            });
          }
        });
  }

  Future<void> _mergeWithAnotherPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _isLoading = true;
          _statusText = "Extracting pages from chosen PDF...";
        });
        final selectedFile = File(result.files.single.path!);
        final newSession = await PdfHelper.startEditSession(selectedFile);

        setState(() {
          _session!.pages.addAll(newSession.pages);
          _hasUnsavedChanges = true;
          _isLoading = false;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Merged ${newSession.pages.length} pages from ${selectedFile.path.split('/').last}",
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to merge PDF: $e")));
    }
  }

  void _showGotoPageDialog() {
    final pageCount = _session?.pages.length ?? 0;
    if (pageCount <= 1) return;

    final controller = TextEditingController(text: "${_currentPageIndex + 1}");
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text(
          "Goto Page",
          style: GoogleFonts.outfit(color: theme.colorScheme.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Enter a page index between 1 and $pageCount:",
              style: GoogleFonts.instrumentSans(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: theme.colorScheme.primary),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              final idx = int.tryParse(controller.text);
              if (idx != null && idx >= 1 && idx <= pageCount) {
                Navigator.of(context).pop();
                setState(() {
                  _currentPageIndex = idx - 1;
                });
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Invalid page number")),
                );
              }
            },
            child: Text(
              "Go",
              style: TextStyle(color: theme.colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showUnsavedChangesDialog() async {
    final theme = Theme.of(context);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text(
          "Unsaved Changes",
          style: GoogleFonts.outfit(color: theme.colorScheme.onSurface),
        ),
        content: Text(
          "You have unsaved changes. Would you like to save before leaving?",
          style: GoogleFonts.instrumentSans(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
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
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.appBarTheme.backgroundColor,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.pdfFile.path.split('/').last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(color: theme.appBarTheme.foregroundColor, fontSize: 16.sp),
              ),
              Text(
                pageCount > 0
                    ? "Page ${_currentPageIndex + 1} of $pageCount"
                    : "No pages",
                style: GoogleFonts.instrumentSans(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontSize: 12.sp,
                ),
              ),
            ],
          ),
          iconTheme: IconThemeData(color: theme.appBarTheme.iconTheme?.color),
          actions: [
            if (_hasUnsavedChanges)
              Container(
                margin: EdgeInsets.only(right: 12.w),
                width: 8.r,
                height: 8.r,
                decoration: const BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                ),
              ),
          ],
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
                  // Main viewport with InteractiveViewer zooming/panning
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 120.h),
                      child: InteractiveViewer(
                        panEnabled: _activeTool == EditorTool.view,
                        scaleEnabled: _activeTool == EditorTool.view,
                        minScale: 1.0,
                        maxScale: 4.0,
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.r),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final pdfWidth = pageModel.width;
                                final pdfHeight = pageModel.height;
                                final aspectRatio = pdfWidth / pdfHeight;

                                double widgetWidth, widgetHeight;
                                if (constraints.maxWidth /
                                        constraints.maxHeight >
                                    aspectRatio) {
                                  widgetHeight = constraints.maxHeight;
                                  widgetWidth =
                                      constraints.maxHeight * aspectRatio;
                                } else {
                                  widgetWidth = constraints.maxWidth;
                                  widgetHeight =
                                      constraints.maxWidth / aspectRatio;
                                }

                                final scaleX = widgetWidth / pdfWidth;
                                final scaleY = widgetHeight / pdfHeight;

                                return Container(
                                  width: widgetWidth,
                                  height: widgetHeight,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.5,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      // Background page rendering
                                      Positioned.fill(
                                        child: _buildPageBackground(pageModel),
                                      ),

                                      // Canvas paint annotations overlay
                                      Positioned.fill(
                                        child: CustomPaint(
                                          painter: DrawingPainter(
                                            paths: pageModel.drawings,
                                            currentPoints: _currentPoints,
                                            currentColor: _selectedColor,
                                            currentStrokeWidth: _strokeWidth,
                                            isCurrentHighlighter:
                                                _activeTool ==
                                                EditorTool.highlighter,
                                            scaleX: scaleX,
                                            scaleY: scaleY,
                                          ),
                                        ),
                                      ),

                                      // Gesture capturing overlay when drawing tools are selected
                                      if (_activeTool != EditorTool.view)
                                        Positioned.fill(
                                          child: GestureDetector(
                                            onPanStart: (details) {
                                              final localPos =
                                                  details.localPosition;
                                              final pdfPt = Offset(
                                                localPos.dx / scaleX,
                                                localPos.dy / scaleY,
                                              );
                                              setState(() {
                                                _currentPoints = [pdfPt];
                                              });
                                            },
                                            onPanUpdate: (details) {
                                              final localPos =
                                                  details.localPosition;
                                              if (localPos.dx >= 0 &&
                                                  localPos.dx <= widgetWidth &&
                                                  localPos.dy >= 0 &&
                                                  localPos.dy <= widgetHeight) {
                                                final pdfPt = Offset(
                                                  localPos.dx / scaleX,
                                                  localPos.dy / scaleY,
                                                );
                                                setState(() {
                                                  _currentPoints.add(pdfPt);
                                                });
                                              }
                                            },
                                            onPanEnd: (_) {
                                              if (_currentPoints.isNotEmpty) {
                                                if (_activeTool ==
                                                    EditorTool.eraser) {
                                                  _eraseDrawingsAt(
                                                    pageModel,
                                                    _currentPoints,
                                                  );
                                                } else {
                                                  setState(() {
                                                    pageModel.drawings.add(
                                                      DrawingPath(
                                                        points: List.from(
                                                          _currentPoints,
                                                        ),
                                                        color: _selectedColor,
                                                        strokeWidth:
                                                            _strokeWidth,
                                                        isHighlighter:
                                                            _activeTool ==
                                                            EditorTool
                                                                .highlighter,
                                                      ),
                                                    );
                                                    _hasUnsavedChanges = true;
                                                  });
                                                }
                                              }
                                              setState(() {
                                                _currentPoints = [];
                                              });
                                            },
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Floating Toolbar
                  Positioned(
                    left: 20.w,
                    right: 20.w,
                    bottom: 20.h,
                    child: _buildFloatingToolbar(pageModel),
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
      return Image.file(File(pageModel.newImageFilePath!), fit: BoxFit.fill);
    } else if (pageModel.cachedImagePath != null) {
      return Image.file(File(pageModel.cachedImagePath!), fit: BoxFit.fill);
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
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Expandable parameters panel depending on selected tab
              _buildExpandedTabControls(pageModel),

              // Divider if parameters panel is open
              if (_shouldShowExpansionPanel())
                Divider(color: isDark ? Colors.white10 : Colors.black12, height: 1),

              // Navigation tab bars
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildTabButton(
                      tab: ToolbarTab.navigate,
                      icon: Icons.navigation_rounded,
                      label: "Navigate",
                    ),
                    _buildTabButton(
                      tab: ToolbarTab.draw,
                      icon: Icons.gesture_rounded,
                      label: "Annotate",
                    ),
                    _buildTabButton(
                      tab: ToolbarTab.pages,
                      icon: Icons.pages_rounded,
                      label: "Page Edit",
                    ),
                    _buildTabButton(
                      tab: ToolbarTab.export,
                      icon: Icons.ios_share_rounded,
                      label: "Export",
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _shouldShowExpansionPanel() {
    return _activeTab == ToolbarTab.navigate ||
        _activeTab == ToolbarTab.draw ||
        _activeTab == ToolbarTab.pages;
  }

  Widget _buildExpandedTabControls(PdfPageModel pageModel) {
    final pageCount = _session?.pages.length ?? 0;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    switch (_activeTab) {
      case ToolbarTab.navigate:
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                onPressed: _currentPageIndex > 0
                    ? () {
                        setState(() {
                          _currentPageIndex--;
                        });
                      }
                    : null,
              ),
              InkWell(
                onTap: _showGotoPageDialog,
                borderRadius: BorderRadius.circular(12.r),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 8.h,
                  ),
                  child: Row(
                    children: [
                      Text(
                        "Page ${_currentPageIndex + 1} of $pageCount",
                        style: GoogleFonts.outfit(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: theme.colorScheme.primary,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                onPressed: _currentPageIndex < (pageCount - 1)
                    ? () {
                        setState(() {
                          _currentPageIndex++;
                        });
                      }
                    : null,
              ),
            ],
          ),
        );

      case ToolbarTab.draw:
        return Padding(
          padding: EdgeInsets.all(12.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tool toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildDrawingToolButton(
                    EditorTool.view,
                    Icons.pan_tool_outlined,
                    "Pan/Zoom",
                  ),
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
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Text(
                      "Size: ",
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 11.sp),
                    ),
                    Expanded(
                      child: Slider(
                        value: _strokeWidth,
                        min: 1.0,
                        max: 20.0,
                        activeColor: theme.colorScheme.primary,
                        inactiveColor: isDark ? Colors.white12 : Colors.black12,
                        onChanged: (val) {
                          setState(() {
                            _strokeWidth = val;
                          });
                        },
                      ),
                    ),
                    Text(
                      _strokeWidth.toStringAsFixed(0),
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 11.sp),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                SizedBox(
                  height: 36.h,
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
                                ? Border.all(color: isDark ? Colors.white : Colors.black, width: 2.r)
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
        );

      case ToolbarTab.pages:
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPageActionButton(
                icon: Icons.add_circle_outline_rounded,
                label: "Add Page",
                onTap: _addPage,
              ),
              _buildPageActionButton(
                icon: Icons.delete_outline_rounded,
                label: "Delete Page",
                onTap: _deleteCurrentPage,
                color: Colors.redAccent,
              ),
              _buildPageActionButton(
                icon: Icons.swap_vert_rounded,
                label: "Rearrange",
                onTap: _openRearrangeScreen,
              ),
              _buildPageActionButton(
                icon: Icons.merge_rounded,
                label: "Merge PDF",
                onTap: _mergeWithAnotherPdf,
              ),
            ],
          ),
        );

      case ToolbarTab.export:
        return const SizedBox.shrink();
    }
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
              color: isSelected ? theme.colorScheme.primary : (isDark ? Colors.white70 : Colors.black87),
              size: 20.r,
            ),
            SizedBox(height: 2.h),
            Text(
              label,
              style: GoogleFonts.instrumentSans(
                fontSize: 10.sp,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? (isDark ? Colors.white : Colors.black87) : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
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
    required VoidCallback onTap,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveColor = color ?? (isDark ? Colors.white : Colors.black87);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
        child: Column(
          children: [
            Icon(icon, color: effectiveColor, size: 22.r),
            SizedBox(height: 4.h),
            Text(
              label,
              style: GoogleFonts.instrumentSans(
                fontSize: 11.sp,
                color: effectiveColor.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required ToolbarTab tab,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _activeTab == tab;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = tab;
          if (tab == ToolbarTab.export) {
            _promptSavePdf();
          }
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22.r,
              color: isSelected ? theme.colorScheme.primary : (isDark ? Colors.white60 : Colors.black54),
            ),
            SizedBox(height: 2.h),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11.sp,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? (isDark ? Colors.white : Colors.black87) : (isDark ? Colors.white60 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DrawingPainter extends CustomPainter {
  final List<DrawingPath> paths;
  final List<Offset> currentPoints;
  final Color currentColor;
  final double currentStrokeWidth;
  final bool isCurrentHighlighter;
  final double scaleX;
  final double scaleY;

  DrawingPainter({
    required this.paths,
    required this.currentPoints,
    required this.currentColor,
    required this.currentStrokeWidth,
    required this.isCurrentHighlighter,
    required this.scaleX,
    required this.scaleY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final dp in paths) {
      _drawPath(canvas, dp.points, dp.color, dp.strokeWidth, dp.isHighlighter);
    }

    if (currentPoints.isNotEmpty) {
      _drawPath(
        canvas,
        currentPoints,
        currentColor,
        currentStrokeWidth,
        isCurrentHighlighter,
      );
    }
  }

  void _drawPath(
    Canvas canvas,
    List<Offset> pts,
    Color color,
    double strokeWidth,
    bool isHighlighter,
  ) {
    if (pts.isEmpty) return;

    final paint = Paint()
      ..color = isHighlighter ? color.withValues(alpha: 0.4) : color
      ..strokeWidth = strokeWidth * ((scaleX + scaleY) / 2)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(pts.first.dx * scaleX, pts.first.dy * scaleY);
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx * scaleX, pts[i].dy * scaleY);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) => true;
}
