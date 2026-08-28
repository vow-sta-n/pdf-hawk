/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:community_material_icon/community_material_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfhawk/data/class/p_d_f_hawk_icons_icons.dart';
import 'package:pdfhawk/data/models/writer_document_model.dart';
import 'package:pdfhawk/data/res/theme.dart';
import 'package:pdfhawk/data/res/variables.dart';
import 'package:pdfhawk/interface/pages/pdf_reader_page.dart';
import 'package:pdfhawk/interface/pages/pdf_writer_page.dart';
import 'package:pdfhawk/interface/pages/camera_page.dart';
import 'package:pdfhawk/interface/pages/rearrange_pdf_page.dart';
import 'package:pdfhawk/interface/pages/merge_pdfs_page.dart';
import 'package:pdfhawk/interface/dialogs/split_pdf_dialog.dart';
import 'package:path/path.dart' as p;
import 'package:pdfhawk/interface/pages/create_from_images_page.dart';
import 'package:pdfhawk/interface/pages/settings_page.dart';
import 'package:pdfhawk/logic/helpers/pdf_helper.dart';
import 'package:pdfhawk/main.dart';
import 'package:pdfhawk/interface/bottomsheets/create_prompt_bottom_sheet.dart';
import 'package:pdfhawk/interface/bottomsheets/document_convert_bottom_sheet.dart';
import 'package:pdfhawk/interface/bottomsheets/edit_tools_bottom_sheet.dart';
import 'package:pdfhawk/interface/bottomsheets/images_convert_bottom_sheet.dart';
import 'package:pdfhawk/interface/widgets/glass_grid_tile_button.dart';
import 'package:pdfhawk/interface/widgets/pdf_thumbnail_widget.dart';
import 'package:pdfhawk/data/res/utils.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:pdfhawk/logic/services/hawk_crypto_service.dart';
import 'package:pdfhawk/logic/services/intent_service.dart';
import 'package:pdfhawk/data/models/folder_model.dart';
import 'package:pdfhawk/interface/pages/all_folders_page.dart';
import 'package:pdfhawk/interface/pages/folder_documents_page.dart';
import 'package:pdfhawk/logic/services/folder_storage_service.dart';
import 'package:pdfhawk/logic/services/storage_service.dart';
import 'package:pdfhawk/interface/widgets/tutorial_card_widget.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:pdfhawk/data/res/constants.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<String>? _intentSubscription;
  final FocusNode _searchFocusNode = FocusNode();
  final GlobalKey _keySettings = GlobalKey();
  final GlobalKey _keyOpenPdf = GlobalKey();
  final GlobalKey _keySearch = GlobalKey();
  final GlobalKey _keyCreate = GlobalKey();
  final GlobalKey _keyTheme = GlobalKey();
  final GlobalKey _keyHelp = GlobalKey();
  final GlobalKey _keyScan = GlobalKey();
  final GlobalKey _keyEdit = GlobalKey();
  List<String> _filteredFiles = [];
  bool _isSearchExpanded = false;
  List<String> _recentFiles = [];
  List<FolderModel> _folders = [];
  String _searchQuery = "";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRecentFiles();
    _loadFolders();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoSavedWriterSession();
      _initIntentHandling();
    });
  }

  Future<void> _initIntentHandling() async {
    // 1. Check for initial PDF when app is launched cold by tapping a PDF
    final initialPath = await IntentService.getInitialPdf();
    if (initialPath != null && mounted) {
      _openRecentFile(initialPath);
    }

    // 2. Listen for PDFs opened when app is already running (warm start)
    _intentSubscription = IntentService.onPdfReceived.listen((path) {
      if (mounted) {
        _openRecentFile(path);
      }
    });
  }

  @override
  void dispose() {
    _intentSubscription?.cancel();
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

  Future<void> _loadFolders() async {
    final box = Hive.box('pdfhawk_box');
    List<dynamic>? rawList = box.get('user_folders');
    List<FolderModel> loaded = [];

    if (rawList != null && rawList.isNotEmpty) {
      for (var item in rawList) {
        try {
          if (item is Map) {
            loaded.add(FolderModel.fromJson(Map<String, dynamic>.from(item)));
          }
        } catch (_) {}
      }
    }

    // Ensure default "Documents" folder points to PDFHawk's user documents directory
    try {
      final targetDocsDir = await StorageService.getPDFHawkDirectory();
      final defaultIndex = loaded.indexWhere(
        (f) =>
            f.id == 'default_documents' ||
            (f.isDefault && f.name.toLowerCase() == 'documents'),
      );

      if (defaultIndex != -1) {
        // Automatically migrate old app-internal directory to PDFHawk user directory
        if (loaded[defaultIndex].path != targetDocsDir.path) {
          loaded[defaultIndex] = FolderModel(
            id: 'default_documents',
            name: 'Documents',
            path: targetDocsDir.path,
            isDefault: true,
            colorValue: 0xFF256EF1,
          );
          await _saveFolders(loaded);
        }
      } else {
        final defaultFolder = FolderModel(
          id: 'default_documents',
          name: 'Documents',
          path: targetDocsDir.path,
          isDefault: true,
          colorValue: 0xFF256EF1,
        );
        loaded.insert(0, defaultFolder);
        await _saveFolders(loaded);
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _folders = loaded;
      });
    }
  }

  Future<void> _saveFolders(List<FolderModel> folders) async {
    final box = Hive.box('pdfhawk_box');
    final rawList = folders.map((f) => f.toJson()).toList();
    await box.put('user_folders', rawList);
  }

  Future<void> _pickAndAddFolder() async {
    try {
      if (Platform.isAndroid) {
        await FolderStorageService.ensureStoragePermission();
      }

      final selectedPath = await FilePicker.platform.getDirectoryPath();
      if (selectedPath == null || selectedPath.isEmpty) return;

      String cleanPath = FolderStorageService.normalizePath(selectedPath);

      final exists = _folders.any(
        (f) =>
            f.path == cleanPath ||
            f.normalizedPath == cleanPath ||
            f.path == selectedPath,
      );
      if (exists) {
        Fluttertoast.showToast(msg: "Folder already added");
        return;
      }

      final folderName = p.basename(cleanPath);
      final newFolder = FolderModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: folderName.isEmpty ? "Folder" : folderName,
        path: cleanPath,
        isDefault: false,
      );

      final files = await FolderStorageService.getFolderFiles(newFolder);
      newFolder.cachedFileCount = files.length;

      final updated = List<FolderModel>.from(_folders)..add(newFolder);
      await _saveFolders(updated);
      setState(() {
        _folders = updated;
      });
      Fluttertoast.showToast(msg: "Added folder: ${newFolder.name}");
    } catch (e) {
      Fluttertoast.showToast(msg: "Could not add folder: $e");
    }
  }

  Future<void> _removeFolder(FolderModel folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remove Folder?"),
        content: Text(
          "Remove \"${folder.name}\" from your folders list? (Files won't be deleted from device)",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Remove"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final updated = _folders.where((f) => f.id != folder.id).toList();
      await _saveFolders(updated);
      setState(() {
        _folders = updated;
      });
      Fluttertoast.showToast(msg: "Folder removed");
    }
  }

  void _showFolderInfoDialog(FolderModel folder) {
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        final fileCount = folder.getFileCountSync();

        return AlertDialog(
          backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: allradius(20.r)),
          title: Row(
            children: [
              Icon(
                Icons.folder_rounded,
                color: const Color(0xFF256EF1),
                size: 28.r,
              ),
              Gap(10.w),
              Expanded(
                child: Text(
                  folder.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Files: $fileCount",
                style: GoogleFonts.instrumentSans(fontSize: 13.sp),
              ),
              Gap(6.h),
              Text(
                "Path: ${folder.path}",
                style: GoogleFonts.instrumentSans(
                  fontSize: 12.sp,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
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
        if (bytes < 1024) {
          return "$bytes B";
        } else if (bytes < 1024 * 1024) {
          return "${(bytes / 1024).toStringAsFixed(1)} KB";
        } else if (bytes < 1024 * 1024 * 1024) {
          return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
        } else {
          return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB";
        }
      }
    } catch (_) {}
    return "--";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    double h = MediaQuery.of(context).size.height;

    return PopScope(
      canPop: !_isSearchExpanded,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isSearchExpanded) {
          setState(() {
            _isSearchExpanded = false;
            _searchFocusNode.unfocus();
            _searchController.clear();
            _filterRecentFiles("");
          });
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: isDark ? Colors.black : Colors.grey.shade100,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            child: _isSearchExpanded
                ? _buildSearchModeView(isDark, theme)
                : _buildNormalHomeView(h, isDark, theme),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchModeView(bool isDark, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Search Header with Back / Clear
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                setState(() {
                  _isSearchExpanded = false;
                  _searchFocusNode.unfocus();
                  _searchController.clear();
                  _filterRecentFiles("");
                });
              },
            ),
            Gap(4.w),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: TextStyle(color: theme.colorScheme.onSurface),
                onChanged: _filterRecentFiles,
                decoration: InputDecoration(
                  hintText: "Search recent files...",
                  hintStyle: GoogleFonts.outfit(
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.search,
                      color: theme.colorScheme.primary.withAlpha(155),
                    ),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            setState(() {
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
                    borderRadius: allradius(56.r),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: allradius(56.r),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 10.h,
                  ),
                ),
              ),
            ),
          ],
        ),
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
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: isDark
                          ? Colors.grey.shade900
                          : Colors.white,
                      title: Text(
                        "Clear History?",
                        style: TextStyle(color: theme.colorScheme.onSurface),
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
                            style: TextStyle(color: theme.colorScheme.error),
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
        Gap(10.h),
        Expanded(
          child: _filteredFiles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 36.r,
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
                        borderRadius: allradius(12.r),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.black.withValues(alpha: 0.05),
                          width: 1,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: allradius(12.r),
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 4.h,
                          ),
                          leading: PdfThumbnailWidget(
                            filePath: filePath,
                            width: 36,
                            height: 46,
                            borderRadius: 6,
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
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildNormalHomeView(double h, bool isDark, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Top Section (Help Icon Button)
        Column(
          children: [
            Gap(15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Gap(10),
                Text(
                  'My',
                  style: GoogleFonts.outfit(
                    height: 1,
                    fontSize: 37.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Documents',
                      style: GoogleFonts.outfit(
                        height: 1,
                        fontSize: 37.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    InkWell(
                      key: _keyHelp,
                      onTap: _showTutorial,
                      child: Icon(
                        Icons.help_outline_rounded,
                        size: 28.r,

                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Gap(30),
            // Folders Section (Header + Horizontal List)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'FOLDERS',
                        style: GoogleFonts.lato(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                      if (_folders.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AllFoldersPage(),
                              ),
                            ).then((_) => _loadFolders());
                          },
                          child: Text(
                            'All',
                            style: GoogleFonts.outfit(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: grey,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Gap(10.h),
                SizedBox(
                  height: 150.h,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _folders.length + 1,
                    separatorBuilder: (context, index) => Gap(12.w),
                    itemBuilder: (context, index) {
                      if (index == _folders.length) {
                        return _buildAddFolderCard(isDark, theme);
                      }
                      final folder = _folders[index];
                      final isFirst = index == 0;
                      return _buildFolderCard(folder, isFirst, isDark, theme);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),

        Column(
          children: [
            // Grid Layout (2x2 Grid)
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 15.w,
              mainAxisSpacing: 15.h,
              childAspectRatio: 1.4,
              children: [
                GlassGridTileButton(
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
                GlassGridTileButton(
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
                GlassGridTileButton(
                  key: _keyCreate,
                  icon: PDFHawkIcons.edit,
                  title: "Create",
                  description: "Create your own...",
                  onTap: _showCreateOptions,
                  theme: theme,
                  isDark: isDark,
                ),
                GlassGridTileButton(
                  key: _keyEdit,
                  icon: CommunityMaterialIcons.file_edit_outline,
                  title: "Edit",
                  description: "Split, Merge, Convert & more",
                  onTap: _showEditOptions,
                  theme: theme,
                  isDark: isDark,
                ),
              ],
            ),
            Gap(20),
            // Search Bar Trigger Button
            GestureDetector(
              key: _keySearch,
              onTap: () {
                setState(() {
                  _isSearchExpanded = true;
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _searchFocusNode.requestFocus();
                });
              },
              child: Container(
                height: 50.h,
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: allradius(56.r),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      color: theme.colorScheme.primary.withAlpha(155),
                      size: 22.r,
                    ),
                    Gap(10.w),
                    Expanded(
                      child: Text(
                        "Search recent files...",
                        style: GoogleFonts.outfit(
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade600,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Gap(20),
            // Bottom Nav Bar (pill layout + floating add)
            _buildBottomNavBar(isDark, theme),
          ],
        ),
      ],
    );
  }

  void _showFolderContextMenu(
    BuildContext context,
    FolderModel folder,
    Offset position,
  ) async {
    HapticFeedback.mediumImpact();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: allradius(16.r)),
      color: isDark ? Colors.grey.shade900 : Colors.white,
      items: [
        PopupMenuItem(
          value: 'open',
          child: Row(
            children: [
              Icon(
                Icons.folder_open_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              Gap(8.w),
              Text("Open Folder", style: GoogleFonts.outfit()),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'info',
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              Gap(8.w),
              Text("Folder Info", style: GoogleFonts.outfit()),
            ],
          ),
        ),
        if (!folder.isDefault)
          PopupMenuItem(
            value: 'remove',
            child: Row(
              children: [
                const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: Colors.red,
                ),
                Gap(8.w),
                Text("Remove", style: GoogleFonts.outfit(color: Colors.red)),
              ],
            ),
          ),
      ],
    );

    if (selected == 'open') {
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FolderDocumentsPage(folder: folder),
        ),
      ).then((_) => _loadFolders());
    } else if (selected == 'info') {
      _showFolderInfoDialog(folder);
    } else if (selected == 'remove') {
      _removeFolder(folder);
    }
  }

  Widget _buildFolderCard(
    FolderModel folder,
    bool isFirst,
    bool isDark,
    ThemeData theme,
  ) {
    final fileCount = FolderStorageService.getFolderFileCount(folder);
    Offset tapPosition = Offset.zero;

    return GestureDetector(
      onTapDown: (details) {
        tapPosition = details.globalPosition;
      },
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FolderDocumentsPage(folder: folder),
          ),
        ).then((_) => _loadFolders());
      },
      onLongPress: () {
        _showFolderContextMenu(context, folder, tapPosition);
      },
      child: Container(
        width: 220.w,
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.02)
              : Colors.black.withValues(alpha: 0.02),
          borderRadius: allradius(22.r),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.12),
            width: 1.5,
          ),
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: Folder Icon
            Icon(PDFHawkIcons.folder, color: theme.primaryColor, size: 70.sp),
            // Bottom Section: Folder Name + File Count
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    folder.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 18.5.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    "$fileCount file${fileCount == 1 ? '' : 's'}",
                    style: GoogleFonts.instrumentSans(
                      fontSize: 14.sp,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddFolderCard(bool isDark, ThemeData theme) {
    return GestureDetector(
      onTap: _pickAndAddFolder,
      child: Container(
        width: 130.w,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.02)
              : Colors.black.withValues(alpha: 0.02),
          borderRadius: allradius(22.r),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.12),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_rounded,
                color: theme.colorScheme.primary,
                size: 22.r,
              ),
            ),
            Gap(8.h),
            Text(
              "Add Folder",
              style: GoogleFonts.outfit(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _switchThemeMode(ThemeMode newMode) {
    if (themeNotifier.value != newMode) {
      HapticFeedback.selectionClick();
      updateThemeMode(newMode);
    }
  }

  void _handleThemeDrag(Offset localPosition, double totalWidth) {
    if (totalWidth <= 0) return;
    final relativeX = (localPosition.dx / totalWidth).clamp(0.0, 1.0);
    ThemeMode newMode;
    if (relativeX < 1.0 / 3.0) {
      newMode = ThemeMode.dark;
    } else if (relativeX < 2.0 / 3.0) {
      newMode = ThemeMode.system;
    } else {
      newMode = ThemeMode.light;
    }
    _switchThemeMode(newMode);
  }

  void _handleThemeSwipeEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0.0;
    final current = themeNotifier.value;
    if (velocity > 250) {
      if (current == ThemeMode.dark) {
        _switchThemeMode(ThemeMode.system);
      } else if (current == ThemeMode.system) {
        _switchThemeMode(ThemeMode.light);
      }
    } else if (velocity < -250) {
      if (current == ThemeMode.light) {
        _switchThemeMode(ThemeMode.system);
      } else if (current == ThemeMode.system) {
        _switchThemeMode(ThemeMode.dark);
      }
    }
  }

  Widget _buildBottomNavBar(bool isDark, ThemeData theme) {
    double w = MediaQuery.of(context).size.width;
    final pillWidth = w / 3;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left: Pill theme switch button with slide, swipe & tap support
        ValueListenableBuilder<ThemeMode>(
          valueListenable: themeNotifier,
          builder: (context, currentMode, _) {
            return GestureDetector(
              key: _keyTheme,
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) =>
                  _handleThemeDrag(details.localPosition, pillWidth),
              onHorizontalDragStart: (details) =>
                  _handleThemeDrag(details.localPosition, pillWidth),
              onHorizontalDragUpdate: (details) =>
                  _handleThemeDrag(details.localPosition, pillWidth),
              onHorizontalDragEnd: _handleThemeSwipeEnd,
              child: Container(
                height: 50.h,
                width: pillWidth,
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : Colors.black,
                  borderRadius: allradius(30.r),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final totalWidth = constraints.maxWidth;
                    final totalHeight = constraints.maxHeight;
                    final itemWidth = totalWidth / 3;
                    final indicatorSize = totalHeight;

                    double indicatorLeft;
                    switch (currentMode) {
                      case ThemeMode.dark:
                        indicatorLeft = (itemWidth - indicatorSize) / 2;
                        break;
                      case ThemeMode.system:
                        indicatorLeft =
                            itemWidth + (itemWidth - indicatorSize) / 2;
                        break;
                      case ThemeMode.light:
                        indicatorLeft =
                            2 * itemWidth + (itemWidth - indicatorSize) / 2;
                        break;
                    }

                    return Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        // Smooth sliding active indicator
                        AnimatedPositioned(
                          left: indicatorLeft,
                          top: (totalHeight - indicatorSize) / 2,
                          width: indicatorSize,
                          height: indicatorSize,
                          duration: const Duration(milliseconds: 850),
                          curve: Curves.easeOutCubic,
                          child: Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Center(
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
                              child: Center(
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
                              child: Center(
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
                      ],
                    );
                  },
                ),
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
          borderRadius: allradius(25.r),
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
    showAppTutorial(
      context: context,
      steps: [
        TutorialStep(
          identify: "help",
          keyTarget: _keyHelp,
          shape: ShapeLightFocus.Circle,
          align: ContentAlign.bottom,
          title: "Help & Quick Tour",
          description:
              "Tap this Help icon anytime to replay this interactive feature tour and explore how to get the most out of PDF Hawk.",
          icon: Icons.help_outline_rounded,
        ),
        TutorialStep(
          identify: "theme",
          keyTarget: _keyTheme,
          shape: ShapeLightFocus.RRect,
          radius: 20.r,
          align: ContentAlign.top,
          title: "Theme Mode Toggle",
          description:
              "Switch instantly between Dark Mode, System Default, and Light Mode to match your reading preferences.",
          icon: Icons.light_mode_rounded,
        ),
        TutorialStep(
          identify: "settings",
          keyTarget: _keySettings,
          shape: ShapeLightFocus.Circle,
          align: ContentAlign.top,
          title: "App Settings & Accents",
          description:
              "Customize primary theme colors, read privacy policies, share the app, rate on Play Store, or view GitHub open-source code.",
          icon: PDFHawkIcons.cog,
        ),
        TutorialStep(
          identify: "openPdf",
          keyTarget: _keyOpenPdf,
          shape: ShapeLightFocus.RRect,
          radius: 20.r,
          align: ContentAlign.bottom,
          title: "Open & Read PDF",
          description:
              "Pick any PDF file from storage to view pages, zoom smoothly, search text, draw annotations, or add e-signatures.",
          icon: CommunityMaterialIcons.file_pdf_outline,
        ),
        TutorialStep(
          identify: "scan",
          keyTarget: _keyScan,
          shape: ShapeLightFocus.RRect,
          radius: 20.r,
          align: ContentAlign.bottom,
          title: "Camera PDF Scanner",
          description:
              "Capture physical documents or ID cards via camera, crop, apply photo filters, and convert directly into PDF.",
          icon: PDFHawkIcons.scan,
        ),
        TutorialStep(
          identify: "create",
          keyTarget: _keyCreate,
          shape: ShapeLightFocus.RRect,
          radius: 20.r,
          align: ContentAlign.top,
          title: "Create New PDF",
          description:
              "Compose a fresh blank document or import a DOCX template using the rich text PDF Writer.",
          icon: PDFHawkIcons.add_document,
        ),
        TutorialStep(
          identify: "edit",
          keyTarget: _keyEdit,
          shape: ShapeLightFocus.RRect,
          radius: 20.r,
          align: ContentAlign.top,
          title: "PDF Editing Tools",
          description:
              "Split PDFs into custom parts, merge multiple PDFs together, convert images/docx, or reorder and edit pages.",
          icon: PDFHawkIcons.edit,
        ),
        TutorialStep(
          identify: "search",
          keyTarget: _keySearch,
          shape: ShapeLightFocus.RRect,
          radius: 30.r,
          align: ContentAlign.top,
          title: "Search Recent Files",
          description:
              "Quickly search through your recently opened documents list or clear recent files history.",
          icon: Icons.search,
        ),
      ],
    );
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
                _loadRecentFiles();
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
                _loadRecentFiles();
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

  void _showEditOptions() {
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
          onCompressTap: () {
            Navigator.pop(context);
            _pickAndCompressFile();
          },
        );
      },
    );
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

        final originalFormatted =
            (originalSize / (1024 * 1024)).toStringAsFixed(2);
        final newFormatted = (newSize / (1024 * 1024)).toStringAsFixed(2);

        _loadRecentFiles();

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

      if (pdfFiles.isNotEmpty && mounted) {
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
            builder: (context) => ReArrangePDFPage(pdfFile: file),
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
          final savedHawkFile = await HawkCryptoService.saveHawkFile(
            docName,
            jsonMap,
          );

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
          onImagesTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CreateFromImagesPage(),
              ),
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
