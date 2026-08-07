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
import 'package:pdfhawk/data/class/p_d_f_hawk_icons_icons.dart';
import 'package:pdfhawk/data/models/writer_document_model.dart';
import 'package:pdfhawk/interface/pages/pdf_reader_page.dart';
import 'package:pdfhawk/interface/pages/pdf_writer_page.dart';
import 'package:pdfhawk/interface/pages/camera_page.dart';
import 'package:pdfhawk/interface/pages/master_pdf_editor_page.dart';
import 'package:pdfhawk/interface/pages/merge_pdfs_page.dart';
import 'package:pdfhawk/interface/dialogs/split_pdf_dialog.dart';
import 'package:path/path.dart' as p;
import 'package:pdfhawk/interface/pages/settings_page.dart';
import 'package:pdfhawk/main.dart';
import 'package:pdfhawk/interface/bottomsheets/convert_prompt_bottom_sheet.dart';
import 'package:pdfhawk/interface/bottomsheets/create_prompt_bottom_sheet.dart';
import 'package:pdfhawk/interface/bottomsheets/document_convert_bottom_sheet.dart';
import 'package:pdfhawk/interface/bottomsheets/edit_tools_bottom_sheet.dart';
import 'package:pdfhawk/interface/bottomsheets/images_convert_bottom_sheet.dart';
import 'package:pdfhawk/data/res/utils.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:pdfhawk/logic/services/hawk_crypto_service.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey _keyHelp = GlobalKey();
  final GlobalKey _keyTheme = GlobalKey();
  final GlobalKey _keySettings = GlobalKey();
  final GlobalKey _keyOpenPdf = GlobalKey();
  final GlobalKey _keyScan = GlobalKey();
  final GlobalKey _keyCreate = GlobalKey();
  final GlobalKey _keyEdit = GlobalKey();
  final GlobalKey _keySearch = GlobalKey();

  List<String> _recentFiles = [];
  List<String> _filteredFiles = [];
  String _searchQuery = "";
  bool _isLoading = false;
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
                builder: (context) => PDFReaderPage(pdfFile: file),
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
              builder: (context) => PDFReaderPage(pdfFile: file),
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
                    key: _keyHelp,
                    onTap: _showTutorial,
                    child: Icon(
                      Icons.help_outline_rounded,
                      size: 28.r,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),

                  SizedBox(),
                ],
              ),
            ),
            Gap(h / 16),
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
                      key: _keyOpenPdf,
                      icon: CommunityMaterialIcons.file_pdf_outline,
                      title: "Open PDF",
                      description: _isLoading
                          ? "Opening file..."
                          : "Read, Annotate, Search...",
                      onTap: _isLoading ? () {} : _pickPdf,
                      theme: theme,
                      isDark: isDark,
                      isLoading: _isLoading,
                    ),
                    _buildGridTile(
                      key: _keyScan,
                      icon: PDFHawkIcons.scan,
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
                      key: _keyCreate,
                      icon: PDFHawkIcons.edit,
                      title: "Write",
                      description: "Create your own...",
                      onTap: _showCreateOptions,
                      theme: theme,
                      isDark: isDark,
                    ),
                    _buildGridTile(
                      key: _keyEdit,
                      icon: CommunityMaterialIcons.file_edit_outline,
                      title: "Edit",
                      description: "Split, Merge, Convert & more",
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
              key: _keySearch,
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
    Key? key,
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
    required ThemeData theme,
    required bool isDark,
    bool isLoading = false,
  }) {
    return GestureDetector(
      key: key,
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
              key: _keyTheme,
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
                              Icons.auto_mode_rounded,
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
        InkWell(
          key: _keySettings,
          onTap: () {
            bottomSheet(
              context,
              SettingsPage(ctx: context, onUpdateCompare: (hj, cls) {}),
            );
          },
          borderRadius: BorderRadius.circular(25.r),
          child: Container(
            width: 50.r,
            height: 50.r,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.black,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(PDFHawkIcons.cog, color: Colors.white, size: 20.sp),
            ),
          ),
        ),
      ],
    );
  }

  void _showTutorial() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final targets = <TargetFocus>[
      TargetFocus(
        identify: "help",
        keyTarget: _keyHelp,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => _buildTutorialCard(
              step: "Step 1 of 8",
              title: "Help & Quick Tour",
              description:
                  "Tap this Help icon anytime to replay this interactive feature tour and explore how to get the most out of PDF Hawk.",
              icon: Icons.help_outline_rounded,
              controller: controller,
              isDark: isDark,
              theme: theme,
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "theme",
        keyTarget: _keyTheme,
        shape: ShapeLightFocus.RRect,
        radius: 20.r,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => _buildTutorialCard(
              step: "Step 2 of 8",
              title: "Theme Mode Toggle",
              description:
                  "Switch instantly between Dark Mode, System Default, and Light Mode to match your reading preferences.",
              icon: Icons.light_mode_rounded,
              controller: controller,
              isDark: isDark,
              theme: theme,
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "settings",
        keyTarget: _keySettings,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => _buildTutorialCard(
              step: "Step 3 of 8",
              title: "App Settings & Accents",
              description:
                  "Customize primary theme colors, read privacy policies, share the app, rate on Play Store, or view GitHub open-source code.",
              icon: PDFHawkIcons.cog,
              controller: controller,
              isDark: isDark,
              theme: theme,
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "openPdf",
        keyTarget: _keyOpenPdf,
        shape: ShapeLightFocus.RRect,
        radius: 20.r,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => _buildTutorialCard(
              step: "Step 4 of 8",
              title: "Open & Read PDF",
              description:
                  "Pick any PDF file from storage to view pages, zoom smoothly, search text, draw annotations, or add e-signatures.",
              icon: CommunityMaterialIcons.file_pdf_outline,
              controller: controller,
              isDark: isDark,
              theme: theme,
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "scan",
        keyTarget: _keyScan,
        shape: ShapeLightFocus.RRect,
        radius: 20.r,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => _buildTutorialCard(
              step: "Step 5 of 8",
              title: "Camera PDF Scanner",
              description:
                  "Capture physical documents or ID cards via camera, crop, apply photo filters, and convert directly into PDF.",
              icon: PDFHawkIcons.scan,
              controller: controller,
              isDark: isDark,
              theme: theme,
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "create",
        keyTarget: _keyCreate,
        shape: ShapeLightFocus.RRect,
        radius: 20.r,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => _buildTutorialCard(
              step: "Step 6 of 8",
              title: "Create New PDF",
              description:
                  "Compose a fresh blank document or import a DOCX template using the rich text PDF Writer.",
              icon: PDFHawkIcons.add_document,
              controller: controller,
              isDark: isDark,
              theme: theme,
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "edit",
        keyTarget: _keyEdit,
        shape: ShapeLightFocus.RRect,
        radius: 20.r,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => _buildTutorialCard(
              step: "Step 7 of 8",
              title: "PDF Editing Tools",
              description:
                  "Split PDFs into custom parts, merge multiple PDFs together, convert images/docx, or reorder and edit pages.",
              icon: PDFHawkIcons.edit,
              controller: controller,
              isDark: isDark,
              theme: theme,
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "search",
        keyTarget: _keySearch,
        shape: ShapeLightFocus.RRect,
        radius: 30.r,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => _buildTutorialCard(
              step: "Step 8 of 8",
              title: "Search Recent Files",
              description:
                  "Quickly search through your recently opened documents list or clear recent files history.",
              icon: Icons.search,
              controller: controller,
              isDark: isDark,
              theme: theme,
              isLast: true,
            ),
          ),
        ],
      ),
    ];

    TutorialCoachMark(
      targets: targets,
      colorShadow: isDark ? Colors.black : Colors.black,
      opacityShadow: 0.85,
      hideSkip: true,
      paddingFocus: 8,
    ).show(context: context);
  }

  Widget _buildTutorialCard({
    required String step,
    required String title,
    required String description,
    required IconData icon,
    required TutorialCoachMarkController controller,
    required bool isDark,
    required ThemeData theme,
    bool isLast = false,
  }) {
    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.black12,
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 22.sp,
                  color: theme.colorScheme.primary,
                ),
              ),
              Gap(10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.toUpperCase(),
                      style: GoogleFonts.instrumentSans(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Gap(12.h),
          Text(
            description,
            style: GoogleFonts.instrumentSans(
              fontSize: 13.sp,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              height: 1.4,
            ),
          ),
          Gap(16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => controller.skip(),
                child: Text(
                  "SKIP",
                  style: GoogleFonts.outfit(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => isLast ? controller.skip() : controller.next(),
                iconAlignment: IconAlignment.end,
                icon: Icon(
                  isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
                  size: 16.sp,
                  color: Colors.white,
                ),
                label: Text(
                  isLast ? "GOT IT" : "NEXT",
                  style: GoogleFonts.outfit(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 8.h,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
            return DocumentConvertBottomSheet(
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
            return ImagesConvertBottomSheet(
              files: files,
              fileSize: fileSizeString,
              onConversionSuccess: (outputPdfFile) {
                // Refresh list
                _loadRecentFiles();
                // Navigate to PdfEditorPage
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
        return EditToolsBottomSheet(
          theme: theme,
          isDark: isDark,
          onConvertTap: () {
            Navigator.pop(context);
            _showConvertSubOptions();
          },
          onSplitTap: () {
            Navigator.pop(context);
            _pickAndSplitPdf();
          },
          onMergeTap: () {
            Navigator.pop(context);
            _pickAndMergePdfs();
          },
          onRearrangeTap: () {
            Navigator.pop(context);
            _pickAndRearrangePdf();
          },
        );
      },
    );
  }

  void _showConvertSubOptions() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return ConvertPromptBottomSheet(
          theme: theme,
          isDark: isDark,
          onImagesTap: () {
            Navigator.pop(context);
            _pickAndConvertImages();
          },
          onDocumentTap: () {
            Navigator.pop(context);
            _pickAndConvertDocument();
          },
        );
      },
    );
  }

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
        ).then((_) => _loadRecentFiles());
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

      if (pdfFiles.length < 2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Please select at least 2 PDF files to merge."),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MergePdfsPage(initialPdfFiles: pdfFiles),
          ),
        ).then((_) => _loadRecentFiles());
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
            builder: (context) => MasterPdfEditorPage(pdfFile: file),
          ),
        ).then((_) => _loadRecentFiles());
      }
    }
  }

  Future<void> _checkAutoSavedWriterSession() async {
    try {
      Map<String, dynamic>? jsonMap;
      final box = Hive.box('pdfhawk_box');
      final draftData = box.get('ongoing_writer_session');
      if (draftData != null) {
        if (draftData is Map) {
          jsonMap = Map<String, dynamic>.from(draftData);
        } else if (draftData is String) {
          jsonMap = jsonDecode(draftData) as Map<String, dynamic>;
        }
      }

      final dir = await getApplicationDocumentsDirectory();
      final legacyFile = File("${dir.path}/auto_save_writer.json");
      if (jsonMap == null && await legacyFile.exists()) {
        final jsonStr = await legacyFile.readAsString();
        jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
      }

      if (jsonMap != null) {
        final doc = WriterDocumentModel.fromJson(jsonMap);
        final bool hasContent =
            doc.overlays.isNotEmpty ||
            (doc.quillDeltaJson.isNotEmpty &&
                doc.quillDeltaJson != "[]" &&
                doc.quillDeltaJson != '[{"insert":"\\n"}]');

        if (hasContent) {
          final docName = "AutoSaved_${DateTime.now().millisecondsSinceEpoch}";
          final savedHawkFile =
              await HawkCryptoService.saveHawkFile(docName, jsonMap);

          await box.delete('ongoing_writer_session');
          if (await legacyFile.exists()) {
            await legacyFile.delete();
          }

          Fluttertoast.showToast(
            msg:
                "Saved unsaved session to storage as '${p.basename(savedHawkFile.path)}'",
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.indigo.shade800,
            textColor: Colors.white,
            fontSize: 13.sp,
          );
        } else {
          await box.delete('ongoing_writer_session');
          if (await legacyFile.exists()) {
            await legacyFile.delete();
          }
        }
      }
    } catch (e) {
      debugPrint("Failed auto-save background recovery: $e");
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
        return CreatePromptBottomSheet(
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
        final deltaJson = PdfWriterPage.parseDocxToDeltaJson(file);

        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfWriterPage(initialDeltaJson: deltaJson),
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
