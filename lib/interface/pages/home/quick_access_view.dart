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
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:pdfhawk/data/class/p_d_f_hawk_icons_icons.dart';
import 'package:pdfhawk/data/models/folder_model.dart';
import 'package:pdfhawk/data/res/constants.dart';
import 'package:pdfhawk/data/res/theme.dart';
import 'package:pdfhawk/interface/pages/home/folder_documents_page.dart';
import 'package:pdfhawk/logic/services/folder_storage_service.dart';
import 'package:pdfhawk/logic/services/storage_service.dart';

class QuickAccessView extends StatefulWidget {
  final bool? isDark;
  final ThemeData? theme;

  const QuickAccessView({
    super.key,
    this.isDark,
    this.theme,
  });

  @override
  State<QuickAccessView> createState() => _QuickAccessViewState();
}

class _QuickAccessViewState extends State<QuickAccessView> {
  List<FolderModel> _folders = [];

  @override
  void initState() {
    super.initState();
    _loadFolders();
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
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.black.withValues(alpha: 0.02),
          borderRadius: allradius(14.r),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(PDFHawkIcons.folder, color: theme.primaryColor, size: 32.sp),
            Gap(4.h),
            Text(
              folder.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.instrumentSans(
                fontSize: 11.5.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? white : Colors.black87,
              ),
            ),
            Gap(1.h),
            Text(
              "$fileCount file${fileCount == 1 ? '' : 's'}",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.instrumentSans(
                fontSize: 9.5.sp,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
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
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.02)
              : Colors.black.withValues(alpha: 0.02),
          borderRadius: allradius(14.r),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(5.r),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_rounded,
                color: theme.colorScheme.primary,
                size: 18.r,
              ),
            ),
            Gap(4.h),
            Text(
              "Add Folder",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.instrumentSans(
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? white : Colors.black87,
              ),
            ),
            Gap(1.h),
            Text(
              "Custom",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.instrumentSans(
                fontSize: 9.5.sp,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme ?? Theme.of(context);
    final isDark = widget.isDark ?? (theme.brightness == Brightness.dark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(5, 0, 5, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Quick Access',
                style: GoogleFonts.lato(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              InkWell(
                onTap: _pickAndAddFolder,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 12.sp, color: theme.primaryColor),
                    Text(
                      ' Add',
                      style: GoogleFonts.lato(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: theme.primaryColor,
                        decoration: TextDecoration.underline,
                        decorationColor: theme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 8.w,
            mainAxisSpacing: 8.h,
            childAspectRatio: 0.85,
          ),
          itemCount: _folders.length + 1,
          itemBuilder: (context, index) {
            if (index < _folders.length) {
              final folder = _folders[index];
              return _buildFolderCard(folder, index == 0, isDark, theme);
            } else {
              return _buildAddFolderCard(isDark, theme);
            }
          },
        ),
      ],
    );
  }
}
