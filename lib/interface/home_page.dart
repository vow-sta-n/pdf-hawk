import 'dart:convert';
import 'dart:io';
import 'package:community_material_icon/community_material_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfhawk/interface/pdf_editor_page.dart';
import 'package:pdfhawk/interface/pdf_writer_page.dart';
import 'package:pdfhawk/interface/pages/scan/camera_page.dart';
import 'package:pdfhawk/logic/helpers/document_converter.dart';
import 'package:path/path.dart' as p;
import 'package:pdfhawk/main.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<String> _recentFiles = [];
  List<String> _filteredFiles = [];
  String _searchQuery = "";
  bool _isLoading = false;

  // New Drawer and Search state properties
  bool _isSearchExpanded = false;
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRecentFiles();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoSavedWriterSession();
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentFiles() async {
    final box = Hive.box('pdfhawk_box');
    final list = List<String>.from(box.get('recent_files') ?? []);
    setState(() {
      _recentFiles = list;
      _filteredFiles = list;
    });
  }

  Future<void> _addRecentFile(String path) async {
    final box = Hive.box('pdfhawk_box');
    List<String> list = List<String>.from(box.get('recent_files') ?? []);

    // Remove duplicate if it exists and insert at index 0
    list.remove(path);
    list.insert(0, path);

    // Limit to 50 recent files
    if (list.length > 50) {
      list = list.sublist(0, 50);
    }

    await box.put('recent_files', list);
    setState(() {
      _recentFiles = list;
      _filterRecentFiles(_searchQuery);
    });
  }

  Future<void> _removeRecentFile(String path) async {
    final box = Hive.box('pdfhawk_box');
    List<String> list = List<String>.from(box.get('recent_files') ?? []);
    list.remove(path);
    await box.put('recent_files', list);
    setState(() {
      _recentFiles = list;
      _filterRecentFiles(_searchQuery);
    });
  }

  void _filterRecentFiles(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredFiles = _recentFiles;
      } else {
        _filteredFiles = _recentFiles.where((path) {
          final fileName = p.basename(path).toLowerCase();
          return fileName.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _pickPdf() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final file = File(path);

        await _addRecentFile(path);
        if (!mounted) return;

        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (context) => PdfEditorPage(pdfFile: file),
              ),
            )
            .then((_) => _loadRecentFiles());
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error opening PDF: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _openRecentFile(String path) {
    final file = File(path);
    if (file.existsSync()) {
      _addRecentFile(path);
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (context) => PdfEditorPage(pdfFile: file),
            ),
          )
          .then((_) => _loadRecentFiles());
    } else {
      // File no longer exists, remove it and warn user
      _removeRecentFile(path);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("File no longer exists: ${p.basename(path)}"),
          backgroundColor: Colors.amber.shade800,
        ),
      );
    }
  }

  String _getFileSizeString(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        final bytes = file.lengthSync();
        return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
      }
    } catch (_) {}
    return "-- MB";
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return "Good Morning,";
    } else if (hour < 17) {
      return "Good Afternoon,";
    } else {
      return "Good Evening,";
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    double h = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey.shade100,
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Section (Scrollable main content)
            Padding(
              padding: EdgeInsets.only(top: 20.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Help Icon Button
                  InkWell(
                    child: Icon(
                      Icons.help_outline_rounded,
                      size: 28.r,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("PDF Hawk Help & Guide")),
                      );
                    },
                  ),

                  SizedBox(),
                ],
              ),
            ),
            Gap(h / 16),
            // Greeting text header
            Text.rich(
              TextSpan(
                text: "${_getGreeting()}\n",
                style: GoogleFonts.outfit(
                  fontSize: 37.sp,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  height: 1.2,
                ),
                children: [
                  TextSpan(
                    text: "How can I help\nyou today?",
                    style: GoogleFonts.outfit(
                      fontSize: 38.sp,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            Gap(20.h),
            // Grid Layout (2x2 Grid)
            Stack(
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 15.w,
                  mainAxisSpacing: 15.h,
                  childAspectRatio: 1.4,
                  children: [
                    _buildGridTile(
                      icon: CommunityMaterialIcons.file_pdf_outline,
                      title: "Open PDF",
                      description: _isLoading
                          ? "Opening file..."
                          : "Read, search...",
                      onTap: _isLoading ? () {} : _pickPdf,
                      theme: theme,
                      isDark: isDark,
                      isLoading: _isLoading,
                    ),
                    _buildGridTile(
                      icon: Icons.qr_code_scanner_rounded,
                      title: "Scan",
                      description: "Documents, ID cards...",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CameraPage(),
                          ),
                        ).then((_) => _loadRecentFiles());
                      },
                      theme: theme,
                      isDark: isDark,
                    ),
                    _buildGridTile(
                      icon: Icons.edit_note_rounded,
                      title: "Create",
                      description: "Create your own...",
                      onTap: _showCreateOptions,
                      theme: theme,
                      isDark: isDark,
                    ),
                    _buildGridTile(
                      icon: CommunityMaterialIcons.file_export_outline,
                      title: "Convert",
                      description: "Convert docs or images to PDF",
                      onTap: _showConvertOptions,
                      theme: theme,
                      isDark: isDark,
                    ),
                  ],
                ),
                searchBox(h, context, isDark, theme),
              ],
            ),

            // Search Bar / Input
            GestureDetector(
              onTap: () {
                if (!_isSearchExpanded) {
                  setState(() {
                    _isSearchExpanded = true;
                  });
                  _searchFocusNode.requestFocus();
                }
              },
              child: AbsorbPointer(
                absorbing: !_isSearchExpanded,
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  onChanged: _filterRecentFiles,
                  decoration: InputDecoration(
                    hintText: "Search recent files...",
                    hintStyle: GoogleFonts.outfit(
                      color: isDark
                          ? Colors.grey.shade500
                          : Colors.grey.shade600,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.search,
                        color: theme.colorScheme.primary.withAlpha(155),
                      ),
                    ),
                    suffixIcon: _isSearchExpanded
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              setState(() {
                                _isSearchExpanded = false;
                                _searchFocusNode.unfocus();
                                _searchController.clear();
                                _filterRecentFiles("");
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(56.r),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                    ),
                    constraints: BoxConstraints(maxHeight: 50),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(56.r),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Nav Bar (pill layout + floating add) if not expanded
            if (!_isSearchExpanded) _buildBottomNavBar(isDark, theme),
          ],
        ),
      ),
    );
  }

  AnimatedContainer searchBox(
    double h,
    BuildContext context,
    bool isDark,
    ThemeData theme,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: _isSearchExpanded ? h / 2 : 0,
      color: isDark ? Colors.black : Colors.grey.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isSearchExpanded) ...[
            Gap(16.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Recent Documents",
                  style: GoogleFonts.outfit(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (_recentFiles.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      // Clear recent files history
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: isDark
                              ? Colors.grey.shade900
                              : Colors.white,
                          title: Text(
                            "Clear History?",
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          content: Text(
                            "Are you sure you want to clear your recently opened PDFs history?",
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Cancel"),
                            ),
                            TextButton(
                              onPressed: () async {
                                final navigator = Navigator.of(context);
                                final box = Hive.box('pdfhawk_box');
                                await box.delete('recent_files');
                                await _loadRecentFiles();
                                navigator.pop();
                              },
                              child: Text(
                                "Clear",
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Text(
                      "Clear All",
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            Gap(8.h),
            Expanded(
              child: _filteredFiles.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 32.r,
                            color: Colors.grey.shade600,
                          ),
                          Gap(8.h),
                          Text(
                            _searchQuery.isEmpty
                                ? "No recently opened PDFs"
                                : "No matching documents found",
                            style: GoogleFonts.instrumentSans(
                              fontSize: 13.sp,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _filteredFiles.length,
                      itemBuilder: (context, index) {
                        final filePath = _filteredFiles[index];
                        final fileName = p.basename(filePath);
                        final fileSize = _getFileSizeString(filePath);

                        return Container(
                          margin: EdgeInsets.only(bottom: 10.h),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.02)
                                : Colors.black.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : Colors.black.withValues(alpha: 0.05),
                              width: 1,
                            ),
                          ),
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 2.h,
                            ),
                            leading: Container(
                              padding: EdgeInsets.all(8.r),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: Icon(
                                Icons.picture_as_pdf_rounded,
                                color: theme.colorScheme.primary,
                                size: 20.r,
                              ),
                            ),
                            title: Text(
                              fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.instrumentSans(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            subtitle: Text(
                              fileSize,
                              style: GoogleFonts.instrumentSans(
                                fontSize: 11.sp,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            trailing: Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Colors.grey.shade600,
                              size: 12.r,
                            ),
                            onTap: () {
                              _openRecentFile(filePath);
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGridTile({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
    required ThemeData theme,
    required bool isDark,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            isLoading
                ? SizedBox(
                    width: 34.r,
                    height: 34.r,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  )
                : Icon(icon, size: 34.r, color: theme.colorScheme.primary),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Gap(1.h),
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.instrumentSans(
                    fontSize: 11.sp,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBar(bool isDark, ThemeData theme) {
    double w = MediaQuery.of(context).size.width;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left: Pill theme switch button
        ValueListenableBuilder<ThemeMode>(
          valueListenable: themeNotifier,
          builder: (context, currentMode, _) {
            return Container(
              height: 50.h,
              width: w / 3,
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.black,
                borderRadius: BorderRadius.circular(30.r),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Active layers tab
                  AnimatedPositioned(
                    left: currentMode == ThemeMode.dark ? 0 : null,
                    right: currentMode == ThemeMode.light ? 0 : null,
                    duration: Duration(milliseconds: 1500),
                    child: Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: SizedBox.square(dimension: 20.r),
                    ),
                  ),
                  Positioned.fill(
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              updateThemeMode(ThemeMode.dark);
                            },
                            child: Icon(
                              Icons.dark_mode,
                              color: currentMode == ThemeMode.dark
                                  ? Colors.black87
                                  : Colors.white70,
                              size: 20.r,
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              updateThemeMode(ThemeMode.system);
                            },
                            child: Icon(
                              Icons.auto_mode,
                              color: currentMode == ThemeMode.system
                                  ? Colors.black87
                                  : Colors.white70,
                              size: 20.r,
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              updateThemeMode(ThemeMode.light);
                            },
                            child: Icon(
                              Icons.light_mode,
                              color: currentMode == ThemeMode.light
                                  ? Colors.black87
                                  : Colors.white70,
                              size: 20.r,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // Right: Floating circular settings button
        Visibility(
          visible: true,
          child: Container(
            width: 50.r,
            height: 50.r,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.black,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(Icons.settings, color: Colors.white, size: 20.sp),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickAndConvertDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['docx', 'pptx', 'txt'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final file = File(path);
        final fileName = result.files.single.name;
        final extension = fileName.split('.').last.toLowerCase();
        final bytesCount = file.lengthSync();
        final fileSizeString = "${(bytesCount / 1024).toStringAsFixed(1)} KB";

        if (!mounted) return;

        // Open Bottom Sheet preview
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) {
            return _DocumentConvertBottomSheet(
              file: file,
              fileName: fileName,
              extension: extension,
              fileSize: fileSizeString,
              onConversionSuccess: (outputPdfFile) {
                // Refresh list
                _loadRecentFiles();
                // Navigate to PdfEditorPage
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PdfEditorPage(pdfFile: outputPdfFile),
                  ),
                );
              },
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error picking document: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _pickAndConvertImages() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final List<File> files = result.files
            .where((f) => f.path != null)
            .map((f) => File(f.path!))
            .toList();

        if (files.isEmpty) return;

        if (!mounted) return;

        // Calculate total size
        int totalBytes = 0;
        for (var file in files) {
          totalBytes += file.lengthSync();
        }
        final fileSizeString = "${(totalBytes / 1024).toStringAsFixed(1)} KB";

        // Open bottom sheet preview for multiple images
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) {
            return _ImagesConvertBottomSheet(
              files: files,
              fileSize: fileSizeString,
              onConversionSuccess: (outputPdfFile) {
                // Refresh list
                _loadRecentFiles();
                // Navigate to PdfEditorPage
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PdfEditorPage(pdfFile: outputPdfFile),
                  ),
                );
              },
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error picking images: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showConvertOptions() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _ConvertPromptBottomSheet(
          theme: theme,
          isDark: isDark,
          onImagesTap: () {
            Navigator.pop(context); // Close prompt bottom sheet
            _pickAndConvertImages();
          },
          onDocumentTap: () {
            Navigator.pop(context); // Close prompt bottom sheet
            _pickAndConvertDocument();
          },
        );
      },
    );
  }

  Future<void> _checkAutoSavedWriterSession() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File("${dir.path}/auto_save_writer.json");
      if (await file.exists()) {
        final jsonStr = await file.readAsString();
        final map = jsonDecode(jsonStr);
        final doc = WriterDocumentModel.fromJson(map);
        final bool hasContent = doc.overlays.isNotEmpty ||
            (doc.quillDeltaJson.isNotEmpty && doc.quillDeltaJson != "[]");
        if (!hasContent) return;

        if (!mounted) return;

        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text("Restore Progress"),
              content: const Text(
                "We found an auto-saved document from your last session. Would you like to restore it?",
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    if (await file.exists()) {
                      await file.delete();
                    }
                  },
                  child: const Text("Start Fresh"),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PdfWriterPage(
                          initialDeltaJson: doc.quillDeltaJson,
                          initialOverlays: doc.overlays,
                        ),
                      ),
                    ).then((_) => _loadRecentFiles());
                  },
                  child: const Text("Restore"),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      debugPrint("Failed to load auto-saved session: $e");
    }
  }

  void _showCreateOptions() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _CreatePromptBottomSheet(
          theme: theme,
          isDark: isDark,
          onDocxTap: () {
            Navigator.pop(context);
            _pickDocxAndOpenWriter();
          },
          onBlankTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PdfWriterPage()),
            ).then((_) => _loadRecentFiles());
          },
        );
      },
    );
  }

  Future<void> _pickDocxAndOpenWriter() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['docx'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final file = File(path);
        final elements = PdfWriterPage.parseDocx(file);

        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfWriterPage(initialElements: elements),
          ),
        ).then((_) => _loadRecentFiles());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error opening docx template: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}

class _DocumentConvertBottomSheet extends StatefulWidget {
  final File file;
  final String fileName;
  final String extension;
  final String fileSize;
  final Function(File outputPdfFile) onConversionSuccess;

  const _DocumentConvertBottomSheet({
    required this.file,
    required this.fileName,
    required this.extension,
    required this.fileSize,
    required this.onConversionSuccess,
  });

  @override
  State<_DocumentConvertBottomSheet> createState() =>
      __DocumentConvertBottomSheetState();
}

class __DocumentConvertBottomSheetState
    extends State<_DocumentConvertBottomSheet> {
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
              borderRadius: BorderRadius.circular(2.r),
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

class _ConvertPromptBottomSheet extends StatelessWidget {
  final ThemeData theme;
  final bool isDark;
  final VoidCallback onImagesTap;
  final VoidCallback onDocumentTap;

  const _ConvertPromptBottomSheet({
    required this.theme,
    required this.isDark,
    required this.onImagesTap,
    required this.onDocumentTap,
  });

  @override
  Widget build(BuildContext context) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          Gap(24.h),
          Text(
            "Convert to PDF",
            style: GoogleFonts.outfit(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          Gap(6.h),
          Text(
            "Select the type of source file you want to convert",
            style: GoogleFonts.instrumentSans(
              fontSize: 13.sp,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          Gap(24.h),
          Row(
            children: [
              Expanded(
                child: _buildTile(
                  context: context,
                  icon: Icons.image_outlined,
                  title: "Images",
                  description: "Convert JPG, PNG files",
                  onTap: onImagesTap,
                ),
              ),
              Gap(16.w),
              Expanded(
                child: _buildTile(
                  context: context,
                  icon: Icons.description_outlined,
                  title: "Document",
                  description: "Convert docx, pptx, txt",
                  onTap: onDocumentTap,
                ),
              ),
            ],
          ),
          Gap(12.h),
        ],
      ),
    );
  }

  Widget _buildTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28.r, color: theme.colorScheme.primary),
            ),
            Gap(16.h),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Gap(4.h),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.instrumentSans(
                fontSize: 11.sp,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagesConvertBottomSheet extends StatefulWidget {
  final List<File> files;
  final String fileSize;
  final Function(File outputPdfFile) onConversionSuccess;

  const _ImagesConvertBottomSheet({
    required this.files,
    required this.fileSize,
    required this.onConversionSuccess,
  });

  @override
  State<_ImagesConvertBottomSheet> createState() =>
      __ImagesConvertBottomSheetState();
}

class __ImagesConvertBottomSheetState extends State<_ImagesConvertBottomSheet> {
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

class _CreatePromptBottomSheet extends StatelessWidget {
  final ThemeData theme;
  final bool isDark;
  final VoidCallback onDocxTap;
  final VoidCallback onBlankTap;

  const _CreatePromptBottomSheet({
    required this.theme,
    required this.isDark,
    required this.onDocxTap,
    required this.onBlankTap,
  });

  @override
  Widget build(BuildContext context) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          Gap(24.h),
          Text(
            "Create Document",
            style: GoogleFonts.outfit(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          Gap(6.h),
          Text(
            "Select how you would like to start creating your PDF",
            style: GoogleFonts.instrumentSans(
              fontSize: 13.sp,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          Gap(24.h),
          Row(
            children: [
              Expanded(
                child: _buildTile(
                  context: context,
                  icon: Icons.upload_file_rounded,
                  title: "Start from DOCX",
                  description: "Import & parse docx file",
                  onTap: onDocxTap,
                ),
              ),
              Gap(16.w),
              Expanded(
                child: _buildTile(
                  context: context,
                  icon: Icons.add_circle_outline_rounded,
                  title: "Start Blank",
                  description: "Create new empty document",
                  onTap: onBlankTap,
                ),
              ),
            ],
          ),
          Gap(12.h),
        ],
      ),
    );
  }

  Widget _buildTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28.r, color: theme.colorScheme.primary),
            ),
            Gap(16.h),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Gap(4.h),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.instrumentSans(
                fontSize: 11.sp,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
