/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:io';
import 'package:community_material_icon/community_material_icon.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:pdfhawk/data/models/folder_model.dart';
import 'package:pdfhawk/data/models/writer_document_model.dart';
import 'package:pdfhawk/data/res/constants.dart';
import 'package:pdfhawk/data/res/theme.dart';
import 'package:pdfhawk/interface/pages/pdf_reader_page.dart';
import 'package:pdfhawk/interface/pages/pdf_writer_page.dart';
import 'package:pdfhawk/interface/widgets/bubble_button.dart';
import 'package:pdfhawk/interface/widgets/pdf_thumbnail_widget.dart';
import 'package:pdfhawk/logic/services/folder_storage_service.dart';
import 'package:pdfhawk/logic/services/hawk_crypto_service.dart';
import 'package:share_plus/share_plus.dart';

enum FileSortOption { nameAsc, nameDesc, dateDesc, dateAsc, sizeDesc, sizeAsc }

class FolderDocumentsPage extends StatefulWidget {
  final FolderModel folder;

  const FolderDocumentsPage({super.key, required this.folder});

  @override
  State<FolderDocumentsPage> createState() => _FolderDocumentsPageState();
}

class _FolderDocumentsPageState extends State<FolderDocumentsPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<File> _allFiles = [];
  List<File> _filteredFiles = [];
  Set<String> _availableTypes = {};
  String _selectedType = "All";
  String _searchQuery = "";
  bool _isLoading = true;
  bool _isGridView = false;
  FileSortOption _sortOption = FileSortOption.dateDesc;

  bool _hasStoragePermission = true;

  @override
  void initState() {
    super.initState();
    _loadFolderContents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadFolderContents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (Platform.isAndroid && !widget.folder.isDefault) {
        await FolderStorageService.ensureStoragePermission();
      }

      final files = await FolderStorageService.getFolderFiles(widget.folder);
      final permissionGranted =
          await FolderStorageService.isStoragePermissionGranted();
      final Set<String> types = {};
      for (var file in files) {
        final ext = p.extension(file.path).toLowerCase().replaceAll('.', '');
        if (ext.isNotEmpty) {
          types.add(ext.toUpperCase());
        }
      }

      setState(() {
        _allFiles = files;
        _availableTypes = types;
        _hasStoragePermission = permissionGranted;
        _applyFiltersAndSort();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Fluttertoast.showToast(msg: "Error reading folder: $e");
    }
  }

  void _applyFiltersAndSort() {
    List<File> result = List.from(_allFiles);

    // 1. Filter by category / extension chip
    if (_selectedType != "All") {
      result = result.where((file) {
        final ext = p
            .extension(file.path)
            .toLowerCase()
            .replaceAll('.', '')
            .toUpperCase();
        return ext == _selectedType;
      }).toList();
    }

    // 2. Filter by search query
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      result = result.where((file) {
        final name = p.basename(file.path).toLowerCase();
        return name.contains(query);
      }).toList();
    }

    // 3. Sort files
    result.sort((a, b) {
      switch (_sortOption) {
        case FileSortOption.nameAsc:
          return p
              .basename(a.path)
              .toLowerCase()
              .compareTo(p.basename(b.path).toLowerCase());
        case FileSortOption.nameDesc:
          return p
              .basename(b.path)
              .toLowerCase()
              .compareTo(p.basename(a.path).toLowerCase());
        case FileSortOption.dateDesc:
          return b.lastModifiedSync().compareTo(a.lastModifiedSync());
        case FileSortOption.dateAsc:
          return a.lastModifiedSync().compareTo(b.lastModifiedSync());
        case FileSortOption.sizeDesc:
          return b.lengthSync().compareTo(a.lengthSync());
        case FileSortOption.sizeAsc:
          return a.lengthSync().compareTo(b.lengthSync());
      }
    });

    _filteredFiles = result;
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _applyFiltersAndSort();
    });
  }

  void _onTypeSelected(String type) {
    setState(() {
      _selectedType = type;
      _applyFiltersAndSort();
    });
  }

  Future<void> _openFile(File file) async {
    final ext = p.extension(file.path).toLowerCase();

    if (ext == '.pdf') {
      // Add to recent files
      final box = Hive.box('pdfhawk_box');
      List<String> list = List<String>.from(box.get('recent_files') ?? []);
      list.remove(file.path);
      list.insert(0, file.path);
      if (list.length > 50) list = list.sublist(0, 50);
      await box.put('recent_files', list);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PDFReaderPage(pdfFile: file)),
      ).then((_) => _loadFolderContents());
    } else if (ext == '.hawk') {
      try {
        final jsonMap = await HawkCryptoService.readHawkFile(file);
        final doc = WriterDocumentModel.fromJson(jsonMap);
        if (!mounted) return;
        final isAuto =
            p.basename(file.path).toLowerCase().startsWith('autosaved_');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfWriterPage(
              initialDeltaJson: doc.quillDeltaJson,
              initialOverlays: doc.overlays,
              sourceHawkFile: file,
              isAutoSaved: isAuto,
            ),
          ),
        ).then((_) => _loadFolderContents());
      } catch (e) {
        Fluttertoast.showToast(msg: "Error opening .hawk document: $e");
      }
    } else {
      // Show file actions bottom sheet or share
      _showFileDetailsDialog(file);
    }
  }

  Future<void> _addFileToFolder() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        int copied = 0;
        for (var picked in result.files) {
          if (picked.path != null) {
            final srcFile = File(picked.path!);
            if (srcFile.existsSync()) {
              final fileName = p.basename(picked.path!);
              final destPath = p.join(widget.folder.path, fileName);
              await srcFile.copy(destPath);
              copied++;
            }
          }
        }
        if (copied > 0) {
          Fluttertoast.showToast(
            msg: "Added $copied file(s) to ${widget.folder.name}",
          );
          _loadFolderContents();
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to add files: $e");
    }
  }

  Future<void> _deleteFile(File file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete File?"),
        content: Text(
          "Are you sure you want to delete \"${p.basename(file.path)}\"?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (file.existsSync()) {
          file.deleteSync();
          Fluttertoast.showToast(msg: "File deleted");
          _loadFolderContents();
        }
      } catch (e) {
        Fluttertoast.showToast(msg: "Could not delete file: $e");
      }
    }
  }

  void _showFileDetailsDialog(File file) {
    final name = p.basename(file.path);
    final size = _getFileSize(file);
    final modified = DateFormat.yMMMd().add_jm().format(
      file.lastModifiedSync(),
    );
    final ext = p.extension(file.path).toUpperCase().replaceAll('.', '');

    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;

        return AlertDialog(
          backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: allradius(20.r),
          ),
          title: Row(
            children: [
              _getFileIcon(file.path, size: 24),
              Gap(10.w),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 16.sp,
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
              _detailRow("Type", ext.isEmpty ? "Unknown" : ext),
              _detailRow("Size", size),
              _detailRow("Modified", modified),
              _detailRow("Location", file.parent.path),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                SharePlus.instance.share(
                  ShareParams(files: [XFile(file.path)], text: name),
                );
              },
              icon: const Icon(Icons.share_rounded, size: 18),
              label: const Text("Share"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.instrumentSans(
              fontSize: 11.sp,
              color: Colors.grey.shade500,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.instrumentSans(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    if (bytes < 1024 * 1024 * 1024) {
      return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
    }
    return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB";
  }

  String _getTotalFilesSize() {
    try {
      int totalBytes = 0;
      for (final file in _allFiles) {
        totalBytes += file.lengthSync();
      }
      return _formatBytes(totalBytes);
    } catch (_) {
      return "--";
    }
  }

  String _getFileSize(File file) {
    try {
      return _formatBytes(file.lengthSync());
    } catch (_) {
      return "--";
    }
  }

  Widget _getFileIcon(String path, {double size = 28}) {
    final ext = p.extension(path).toLowerCase();
    IconData icon;
    Color color;

    switch (ext) {
      case '.pdf':
        icon = CommunityMaterialIcons.file_pdf_box;
        color = const Color(0xFFE52521);
        break;
      case '.doc':
      case '.docx':
        icon = CommunityMaterialIcons.file_word_box;
        color = const Color(0xFF2B579A);
        break;
      case '.xls':
      case '.xlsx':
      case '.csv':
        icon = CommunityMaterialIcons.file_excel_box;
        color = const Color(0xFF217346);
        break;
      case '.ppt':
      case '.pptx':
        icon = CommunityMaterialIcons.file_powerpoint_box;
        color = const Color(0xFFD24726);
        break;
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.webp':
      case '.gif':
        icon = CommunityMaterialIcons.file_image;
        color = Colors.purple.shade600;
        break;
      case '.txt':
      case '.md':
      case '.rtf':
        icon = CommunityMaterialIcons.file_document_outline;
        color = Colors.amber.shade800;
        break;
      case '.zip':
      case '.rar':
      case '.7z':
        icon = CommunityMaterialIcons.zip_box;
        color = Colors.orange.shade700;
        break;
      default:
        icon = CommunityMaterialIcons.file_outline;
        color = Colors.grey.shade600;
        break;
    }

    return Icon(icon, size: size.r, color: color);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey.shade100,
      appBar: AppBar(
        toolbarHeight: 10,
        automaticallyImplyActions: false,
        automaticallyImplyLeading: false,
        backgroundColor: isDark ? Colors.black : Colors.grey.shade100,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadFolderContents,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      BubbleButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                      BubbleButton(icon: Icons.add, onTap: _addFileToFolder),
                    ],
                  ),
                  Gap(15),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.folder.name,
                              style: GoogleFonts.outfit(
                                height: 1,
                                fontSize: 38.sp,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Gap(5),
                            Text(
                              "${_allFiles.length} item${_allFiles.length == 1 ? '' : 's'}${_allFiles.isNotEmpty ? ' • (Size ${_getTotalFilesSize()})' : ''}",
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
                  // 1. Realtime Search Bar
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 8.h,
                    ),
                    child: Container(
                      height: 46.h,
                      padding: EdgeInsets.symmetric(horizontal: 14.w),

                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.03),
                        borderRadius: allradius(56.r),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.transparent
                                : Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            color: grey.withAlpha(200),
                            size: 20.r,
                          ),
                          Gap(10.w),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              onChanged: _onSearchChanged,
                              style: GoogleFonts.instrumentSans(
                                fontSize: 14.sp,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              decoration: InputDecoration(
                                hintText: "Search by filename...",
                                hintStyle: GoogleFonts.instrumentSans(
                                  color: isDark
                                      ? Colors.grey.shade600
                                      : Colors.grey.shade500,
                                  fontSize: 13.sp,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                _onSearchChanged("");
                              },
                              child: Icon(
                                Icons.close_rounded,
                                size: 18.r,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                            ),
                          Gap(10),
                          PopupMenuButton<FileSortOption>(
                            icon: Icon(
                              Icons.sort_rounded,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                            tooltip: "Sort By",
                            padding: EdgeInsets.all(0),
                            onSelected: (val) {
                              setState(() {
                                _sortOption = val;
                                _applyFiltersAndSort();
                              });
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: FileSortOption.dateDesc,
                                child: Text("Newest first"),
                              ),
                              const PopupMenuItem(
                                value: FileSortOption.dateAsc,
                                child: Text("Oldest first"),
                              ),
                              const PopupMenuItem(
                                value: FileSortOption.nameAsc,
                                child: Text("Name (A to Z)"),
                              ),
                              const PopupMenuItem(
                                value: FileSortOption.nameDesc,
                                child: Text("Name (Z to A)"),
                              ),
                              const PopupMenuItem(
                                value: FileSortOption.sizeDesc,
                                child: Text("Largest first"),
                              ),
                              const PopupMenuItem(
                                value: FileSortOption.sizeAsc,
                                child: Text("Smallest first"),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Gap(2),
                  // 2. Type Filter Chips
                  SizedBox(
                    width: getWidth(context),
                    child: Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        _buildFilterChips(isDark, theme),
                        Container(
                          width: 60,
                          color: isDark ? Colors.black : Colors.grey.shade100,
                          child: Center(
                            child: IconButton(
                              padding: EdgeInsets.all(0),
                              icon: Icon(
                                _isGridView
                                    ? Icons.view_list_rounded
                                    : Icons.grid_view_rounded,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                              tooltip: _isGridView ? "List View" : "Grid View",
                              onPressed: () {
                                setState(() {
                                  _isGridView = !_isGridView;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Gap(15),

                  // 3. Document Files List / Grid
                  Expanded(
                    child: _filteredFiles.isEmpty
                        ? _buildEmptyState(isDark)
                        : _isGridView
                        ? _buildGridView(isDark, theme)
                        : _buildListView(isDark, theme),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterChips(bool isDark, ThemeData theme) {
    final List<String> chipList = ["All", ..._availableTypes.toList()..sort()];

    return SizedBox(
      height: 35.h,
      child: ListView.separated(
        padding: EdgeInsets.only(left: 10),
        scrollDirection: Axis.horizontal,
        itemCount: chipList.length,
        separatorBuilder: (context, index) => Gap(10),
        itemBuilder: (context, index) {
          final type = chipList[index];
          final isSelected = _selectedType == type;

          int count;
          if (type == "All") {
            count = _allFiles.length;
          } else {
            count = _allFiles.where((f) {
              final ext = p
                  .extension(f.path)
                  .toLowerCase()
                  .replaceAll('.', '')
                  .toUpperCase();
              return ext == type;
            }).length;
          }

          return GestureDetector(
            onTap: () => _onTypeSelected(type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary
                    : isDark
                    ? Colors.white.withValues(alpha: 0.02)
                    : Colors.black.withValues(alpha: 0.02),
                borderRadius: allradius(20.r),
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.12),
                ),
              ),
              child: Center(
                child: Text(
                  "$type ($count)",
                  style: GoogleFonts.outfit(
                    fontSize: 12.sp,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : isDark
                        ? Colors.grey.shade400
                        : Colors.grey.shade700,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildListView(bool isDark, ThemeData theme) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      itemCount: _filteredFiles.length,
      itemBuilder: (context, index) {
        final file = _filteredFiles[index];
        final name = p.basename(file.path);
        final size = _getFileSize(file);
        final date = DateFormat.yMMMd().format(file.lastModifiedSync());
        final isPdf = p.extension(file.path).toLowerCase() == '.pdf';

        return Container(
          margin: EdgeInsets.only(bottom: 10.h),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade900 : Colors.white,
            borderRadius: allradius(16.r),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.transparent
                    : Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: allradius(16.r),
            child: InkWell(
              borderRadius: allradius(16.r),
              onTap: () => _openFile(file),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                child: Row(
                  children: [
                    // Thumbnail or Icon
                    isPdf
                        ? PdfThumbnailWidget(
                            filePath: file.path,
                            width: 38,
                            height: 48,
                            borderRadius: 8,
                          )
                        : Container(
                            width: 38.w,
                            height: 48.h,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.grey.shade100,
                              borderRadius: allradius(8.r),
                            ),
                            child: Center(
                              child: _getFileIcon(file.path, size: 24),
                            ),
                          ),
                    Gap(12.w),
                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Gap(3.h),
                          Row(
                            children: [
                              Text(
                                size,
                                style: GoogleFonts.instrumentSans(
                                  fontSize: 12.sp,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6.w),
                                child: Text(
                                  "•",
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ),
                              Text(
                                date,
                                style: GoogleFonts.instrumentSans(
                                  fontSize: 12.sp,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Actions Menu
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: isDark ? Colors.white70 : Colors.black54,
                        size: 20.r,
                      ),
                      onSelected: (action) {
                        if (action == 'open') {
                          _openFile(file);
                        } else if (action == 'share') {
                          SharePlus.instance.share(
                            ShareParams(files: [XFile(file.path)], text: name),
                          );
                        } else if (action == 'info') {
                          _showFileDetailsDialog(file);
                        } else if (action == 'delete') {
                          _deleteFile(file);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'open',
                          child: Row(
                            children: [
                              Icon(Icons.remove_red_eye_outlined, size: 18),
                              Gap(8),
                              Text("Open"),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'share',
                          child: Row(
                            children: [
                              Icon(Icons.share_rounded, size: 18),
                              Gap(8),
                              Text("Share"),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'info',
                          child: Row(
                            children: [
                              Icon(Icons.info_outline_rounded, size: 18),
                              Gap(8),
                              Text("File Info"),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: Colors.red,
                              ),
                              Gap(8),
                              Text(
                                "Delete",
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridView(bool isDark, ThemeData theme) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12.w,
        mainAxisSpacing: 12.h,
        childAspectRatio: 0.85,
      ),
      itemCount: _filteredFiles.length,
      itemBuilder: (context, index) {
        final file = _filteredFiles[index];
        final name = p.basename(file.path);
        final size = _getFileSize(file);
        final isPdf = p.extension(file.path).toLowerCase() == '.pdf';

        return Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade900 : Colors.white,
            borderRadius: allradius(16.r),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.transparent
                    : Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: allradius(16.r),
            child: InkWell(
              borderRadius: allradius(16.r),
              onTap: () => _openFile(file),
              child: Padding(
                padding: EdgeInsets.all(12.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Center(
                        child: isPdf
                            ? PdfThumbnailWidget(
                                filePath: file.path,
                                width: 70,
                                height: 90,
                                borderRadius: 8,
                              )
                            : _getFileIcon(file.path, size: 48),
                      ),
                    ),
                    Gap(8.h),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Gap(2.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          size,
                          style: GoogleFonts.instrumentSans(
                            fontSize: 11.sp,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _showFileDetailsDialog(file),
                          child: Icon(
                            Icons.more_horiz_rounded,
                            size: 16.r,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final isSearching =
        _searchQuery.trim().isNotEmpty || _selectedType != "All";

    Widget content;
    if (!_hasStoragePermission &&
        Platform.isAndroid &&
        !widget.folder.isDefault) {
      content = Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_shared_rounded,
              size: 56.r,
              color: Theme.of(context).primaryColor,
            ),
            Gap(16.h),
            Text(
              "Storage Access Required",
              style: GoogleFonts.outfit(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Gap(6.h),
            Text(
              "PDF Hawk needs permission to access files in this folder.",
              textAlign: TextAlign.center,
              style: GoogleFonts.instrumentSans(
                fontSize: 13.sp,
                color: Colors.grey.shade500,
              ),
            ),
            Gap(20.h),
            ElevatedButton.icon(
              onPressed: () async {
                await FolderStorageService.ensureStoragePermission();
                _loadFolderContents();
              },
              icon: const Icon(Icons.security_rounded),
              label: const Text("Grant Storage Access"),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: allradius(12.r),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      content = Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSearching
                  ? Icons.search_off_rounded
                  : Icons.folder_open_rounded,
              size: 56.r,
              color: Colors.grey.shade500,
            ),
            Gap(16.h),
            Text(
              isSearching ? "No matching files" : "Folder is Empty",
              style: GoogleFonts.outfit(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Gap(6.h),
            Text(
              isSearching
                  ? "Try searching for a different name or clear the filter."
                  : "Import or save files to this folder to view them here.",
              textAlign: TextAlign.center,
              style: GoogleFonts.instrumentSans(
                fontSize: 13.sp,
                color: Colors.grey.shade500,
              ),
            ),
            if (!isSearching) ...[
              Gap(16.h),
              ElevatedButton.icon(
                onPressed: _addFileToFolder,
                icon: const Icon(Icons.add_rounded),
                label: const Text("Import File"),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: allradius(12.r),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: content),
          ),
        );
      },
    );
  }
}
