/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:pdfhawk/data/class/p_d_f_hawk_icons_icons.dart';
import 'package:pdfhawk/data/models/folder_model.dart';
import 'package:pdfhawk/data/res/theme.dart';
import 'package:pdfhawk/interface/pages/folder_documents_page.dart';
import 'package:pdfhawk/interface/widgets/bubble_button.dart';
import 'package:pdfhawk/logic/services/folder_storage_service.dart';
import 'package:pdfhawk/logic/services/storage_service.dart';

class AllFoldersPage extends StatefulWidget {
  const AllFoldersPage({super.key});

  @override
  State<AllFoldersPage> createState() => _AllFoldersPageState();
}

class _AllFoldersPageState extends State<AllFoldersPage> {
  List<FolderModel> _folders = [];
  List<FolderModel> _filteredFolders = [];
  bool _isLoading = true;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadFolders() async {
    setState(() {
      _isLoading = true;
    });

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

    // Ensure default "Documents" folder exists and points to PDFHawk's user documents directory
    try {
      final targetDocsDir = await StorageService.getPDFHawkDirectory();
      final defaultIndex = loaded.indexWhere(
        (f) =>
            f.id == 'default_documents' ||
            (f.isDefault && f.name.toLowerCase() == 'documents'),
      );

      if (defaultIndex != -1) {
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
        _applySearch();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveFolders(List<FolderModel> folders) async {
    final box = Hive.box('pdfhawk_box');
    final rawList = folders.map((f) => f.toJson()).toList();
    await box.put('user_folders', rawList);
  }

  void _applySearch() {
    if (_searchQuery.trim().isEmpty) {
      _filteredFolders = List.from(_folders);
    } else {
      final query = _searchQuery.trim().toLowerCase();
      _filteredFolders = _folders.where((f) {
        return f.name.toLowerCase().contains(query) ||
            f.path.toLowerCase().contains(query);
      }).toList();
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _applySearch();
    });
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
        _applySearch();
      });
      Fluttertoast.showToast(msg: "Added folder: ${newFolder.name}");
    } catch (e) {
      Fluttertoast.showToast(msg: "Could not add folder: $e");
    }
  }

  Future<void> _removeFolder(FolderModel folder) async {
    if (folder.isDefault) {
      Fluttertoast.showToast(msg: "Default documents folder cannot be removed");
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Text(
          "Remove Folder?",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Remove \"${folder.name}\" from your folders list? (Files won't be deleted from device)",
          style: GoogleFonts.instrumentSans(),
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
        _applySearch();
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
        final fileCount = FolderStorageService.getFolderFileCount(folder);

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18.r),
          ),
          title: Row(
            children: [
              Icon(
                PDFHawkIcons.folder,
                color: theme.colorScheme.primary,
                size: 26.r,
              ),
              Gap(10.w),
              Expanded(
                child: Text(
                  folder.name,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 18.sp,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow(
                "Type",
                folder.isDefault
                    ? "Default App Storage"
                    : "Custom Device Folder",
                isDark,
              ),
              Gap(8.h),
              _buildInfoRow(
                "Files",
                "$fileCount item${fileCount == 1 ? '' : 's'}",
                isDark,
              ),
              Gap(8.h),
              _buildInfoRow("Path", folder.path, isDark),
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

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.lato(
            fontSize: 10.sp,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
            color: Colors.grey.shade500,
          ),
        ),
        Gap(2.h),
        Text(
          value,
          style: GoogleFonts.instrumentSans(
            fontSize: 13.sp,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
      ],
    );
  }

  void _openFolder(FolderModel folder) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FolderDocumentsPage(folder: folder),
      ),
    ).then((_) => _loadFolders());
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
              onRefresh: _loadFolders,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                        icon: Icons.add_rounded,
                        onTap: _pickAndAddFolder,
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
                              "Folders",
                              style: GoogleFonts.outfit(
                                height: 1,
                                fontSize: 38.sp,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Gap(5),
                            Text(
                              "${_filteredFolders.length} folder${_filteredFolders.length == 1 ? '' : 's'}",
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
                  // Realtime Search Bar
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
                        borderRadius: BorderRadius.circular(56.r),
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
                                hintText: "Search folders...",
                                hintStyle: GoogleFonts.instrumentSans(
                                  color: isDark
                                      ? Colors.grey.shade600
                                      : Colors.grey.shade400,
                                  fontSize: 14.sp,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                              child: Icon(
                                Icons.close_rounded,
                                size: 18.r,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  Gap(8.h),

                  // Folders Grid View / Empty State
                  Expanded(
                    child: _filteredFolders.isEmpty
                        ? _buildEmptyState(isDark)
                        : _buildFoldersGrid(isDark, theme),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFoldersGrid(bool isDark, ThemeData theme) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12.w,
        mainAxisSpacing: 12.h,
        childAspectRatio: 1.2,
      ),
      itemCount: _filteredFolders.length,
      itemBuilder: (context, index) {
        final folder = _filteredFolders[index];
        final fileCount = FolderStorageService.getFolderFileCount(folder);

        return Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade900 : Colors.white,
            borderRadius: BorderRadius.circular(18.r),
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
            borderRadius: BorderRadius.circular(18.r),
            child: InkWell(
              borderRadius: BorderRadius.circular(18.r),
              onTap: () => _openFolder(folder),
              child: Padding(
                padding: EdgeInsets.all(0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top: Folder Icon & Menu
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 0, 0),
                              child: Icon(
                                PDFHawkIcons.folder,
                                color: theme.colorScheme.primary,
                                size: 72.r,
                              ),
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_vert_rounded,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                            size: 18.r,
                          ),
                          padding: EdgeInsets.all(0),
                          onSelected: (value) {
                            if (value == 'open') {
                              _openFolder(folder);
                            } else if (value == 'info') {
                              _showFolderInfoDialog(folder);
                            } else if (value == 'remove') {
                              _removeFolder(folder);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'open',
                              child: Row(
                                children: [
                                  Icon(Icons.folder_open_rounded, size: 18),
                                  Gap(8),
                                  Text("Open Folder"),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'info',
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline_rounded, size: 18),
                                  Gap(8),
                                  Text("Folder Info"),
                                ],
                              ),
                            ),
                            if (!folder.isDefault) ...[
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: 'remove',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                      color: Colors.red,
                                    ),
                                    Gap(8),
                                    Text(
                                      "Remove",
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Bottom: Name & File Count
                    Padding(
                      padding: const EdgeInsets.fromLTRB(15, 0, 12, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            folder.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Gap(2.h),
                          Text(
                            "$fileCount item${fileCount == 1 ? '' : 's'}",
                            style: GoogleFonts.instrumentSans(
                              height: 1,
                              fontSize: 12.sp,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
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
    final isSearching = _searchQuery.trim().isNotEmpty;

    final content = Padding(
      padding: EdgeInsets.symmetric(horizontal: 32.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearching ? Icons.search_off_rounded : Icons.folder_open_rounded,
            size: 56.r,
            color: Colors.grey.shade500,
          ),
          Gap(16.h),
          Text(
            isSearching ? "No matching folders" : "No Folders Added",
            style: GoogleFonts.outfit(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          Gap(6.h),
          Text(
            isSearching
                ? "Try searching for a different folder name."
                : "Add folders from your device to quickly organize and browse documents.",
            textAlign: TextAlign.center,
            style: GoogleFonts.instrumentSans(
              fontSize: 13.sp,
              color: Colors.grey.shade500,
            ),
          ),
          if (!isSearching) ...[
            Gap(16.h),
            ElevatedButton.icon(
              onPressed: _pickAndAddFolder,
              icon: const Icon(Icons.add_rounded),
              label: const Text("Add Folder"),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
          ],
        ],
      ),
    );

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
