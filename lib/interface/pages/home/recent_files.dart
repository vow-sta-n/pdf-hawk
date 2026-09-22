/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:io';
import 'package:community_material_icon/community_material_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:pdfhawk/data/res/constants.dart';
import 'package:pdfhawk/data/res/theme.dart';
import 'package:pdfhawk/interface/widgets/pdf_thumbnail_widget.dart';
import 'package:pdfhawk/logic/helpers/document_viewer_helper.dart';
import 'package:pdfhawk/logic/services/device_documents_service.dart';
import 'package:share_plus/share_plus.dart';

/// Global function to add a document file path to recent files in Hive storage.
Future<void> addRecentFile(String filePath) async {
  try {
    final box = Hive.box('pdfhawk_box');
    List<String> list = List<String>.from(box.get('recent_files') ?? []);
    list.remove(filePath);
    list.insert(0, filePath);
    if (list.length > 50) {
      list = list.sublist(0, 50);
    }
    await box.put('recent_files', list);
  } catch (_) {}
}

/// Global function to add recently accessed file tag to Hive storage.
Future<void> addRecentFileTag(String filePath) => addRecentFile(filePath);

/// Global function to remove a document from recent files.
Future<void> removeRecentFile(String filePath) async {
  try {
    final box = Hive.box('pdfhawk_box');
    List<String> list = List<String>.from(box.get('recent_files') ?? []);
    list.remove(filePath);
    await box.put('recent_files', list);
  } catch (_) {}
}

/// Global function to clear all recent files from Hive storage.
Future<void> clearAllRecentFiles() async {
  try {
    final box = Hive.box('pdfhawk_box');
    await box.put('recent_files', <String>[]);
  } catch (_) {}
}

class RecentFilesView extends StatefulWidget {
  final bool isEmbedded;
  const RecentFilesView({super.key, this.isEmbedded = false});

  @override
  State<RecentFilesView> createState() => _RecentFilesViewState();
}

class _RecentFilesViewState extends State<RecentFilesView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) {
      return "${(bytes / 1024).toStringAsFixed(1)} KB";
    }
    if (bytes < 1024 * 1024 * 1024) {
      return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
    }
    return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB";
  }

  Color _getCategoryColor(DocumentCategory category) {
    switch (category) {
      case DocumentCategory.pdf:
        return const Color(0xFFE52521);
      case DocumentCategory.word:
        return const Color(0xFF2B579A);
      case DocumentCategory.excel:
        return const Color(0xFF217346);
      case DocumentCategory.ppt:
        return const Color(0xFFD24726);
      case DocumentCategory.text:
        return Colors.amber.shade800;
      case DocumentCategory.image:
        return Colors.teal;
      case DocumentCategory.hawk:
        return royalblue;
      case DocumentCategory.other:
      default:
        return Colors.blueGrey;
    }
  }

  Widget _getFileIcon(DocumentCategory category, {double size = 24}) {
    IconData icon;
    Color color = _getCategoryColor(category);

    switch (category) {
      case DocumentCategory.pdf:
        icon = CommunityMaterialIcons.file_pdf_box;
        break;
      case DocumentCategory.word:
        icon = CommunityMaterialIcons.file_word_box;
        break;
      case DocumentCategory.excel:
        icon = CommunityMaterialIcons.file_excel_box;
        break;
      case DocumentCategory.ppt:
        icon = CommunityMaterialIcons.file_powerpoint_box;
        break;
      case DocumentCategory.text:
        icon = CommunityMaterialIcons.file_document_outline;
        break;
      case DocumentCategory.image:
        icon = Icons.image_outlined;
        break;
      case DocumentCategory.hawk:
        icon = CommunityMaterialIcons.shield_lock_outline;
        break;
      case DocumentCategory.other:
      default:
        icon = CommunityMaterialIcons.file_outline;
        break;
    }

    return Icon(icon, size: size.r, color: color);
  }

  void _showFileInfoDialog(BuildContext context, File file, bool isDark) {
    final theme = Theme.of(context);
    final exists = file.existsSync();
    final size = exists ? file.lengthSync() : 0;
    final lastModified = exists ? file.lastModifiedSync() : null;
    final ext = p.extension(file.path).toLowerCase().replaceAll('.', '');
    final name = p.basename(file.path);
    final dateStr = lastModified != null
        ? DateFormat("MMM dd, yyyy • hh:mm a").format(lastModified)
        : "Unknown";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: allradius(18.r)),
        title: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary),
            Gap(10.w),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 16.sp,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDialogInfoRow("Name", name, isDark),
            Gap(8.h),
            _buildDialogInfoRow("Format", ext.toUpperCase(), isDark),
            Gap(8.h),
            _buildDialogInfoRow(
              "Size",
              exists ? _formatFileSize(size) : "Unavailable",
              isDark,
            ),
            Gap(8.h),
            _buildDialogInfoRow("Modified", dateStr, isDark),
            Gap(8.h),
            _buildDialogInfoRow("Path", file.path, isDark),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogInfoRow(String label, String value, bool isDark) {
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
            fontSize: 12.5.sp,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
      ],
    );
  }

  void _confirmClearAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: allradius(16.r)),
        title: Text(
          "Clear Recent Files?",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          "This will clear your recent files history. Your actual files will not be deleted from storage.",
          style: GoogleFonts.instrumentSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              clearAllRecentFiles();
              Fluttertoast.showToast(msg: "Recent files cleared");
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Clear All"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ValueListenableBuilder<Box>(
      valueListenable: Hive.box(
        'pdfhawk_box',
      ).listenable(keys: ['recent_files']),
      builder: (context, box, _) {
        final rawList = box.get('recent_files');
        final List<String> allRecentPaths = rawList is List
            ? List<String>.from(rawList)
            : <String>[];

        final filteredPaths = allRecentPaths.where((path) {
          if (_searchQuery.isEmpty) return true;
          final fileName = p.basename(path).toLowerCase();
          final q = _searchQuery.toLowerCase();
          return fileName.contains(q) || path.toLowerCase().contains(q);
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: widget.isEmbedded ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Text(
              'Recently Accessed Files',
              style: GoogleFonts.lato(
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            Gap(10),
            // Search Bar
            Container(
              height: 40.h,
              padding: EdgeInsets.symmetric(horizontal: 14.w),
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
                    Icons.search_rounded,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    size: 20.r,
                  ),
                  Gap(10.w),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim();
                        });
                      },
                      style: GoogleFonts.instrumentSans(
                        fontSize: 14.sp,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search recent files...',
                        hintStyle: GoogleFonts.instrumentSans(
                          color: isDark
                              ? Colors.grey.shade500
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
                        setState(() {
                          _searchQuery = '';
                        });
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
            Gap(10),
            // Header Section: Item Count + Clear All
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "${filteredPaths.length} ${filteredPaths.length == 1 ? 'file' : 'files'}",
                    style: GoogleFonts.instrumentSans(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                  if (allRecentPaths.isNotEmpty && _searchQuery.isEmpty)
                    GestureDetector(
                      onTap: () => _confirmClearAll(context),
                      child: Text(
                        "Clear All",
                        style: GoogleFonts.instrumentSans(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Gap(4.h),

            // Files List or Empty State
            Builder(
              builder: (context) {
                final listWidget = filteredPaths.isEmpty
                    ? _buildEmptyState(isDark, _searchQuery.isNotEmpty)
                    : ListView.separated(
                        shrinkWrap: widget.isEmbedded,
                        physics: widget.isEmbedded
                            ? const NeverScrollableScrollPhysics()
                            : const BouncingScrollPhysics(),
                        itemCount: filteredPaths.length,
                        padding: EdgeInsets.only(bottom: 150),
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          thickness: 0.5,
                          indent: 64.w,
                          endIndent: 16.w,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.05),
                        ),
                        itemBuilder: (context, index) {
                          final path = filteredPaths[index];
                          final file = File(path);
                          final exists = file.existsSync();
                          final ext = p
                              .extension(path)
                              .toLowerCase()
                              .replaceAll('.', '');
                          final name = p.basename(path);
                          final category =
                              DeviceDocumentsService.getCategoryForExtension(
                                ext,
                              );
                          final sizeStr = exists
                              ? _formatFileSize(file.lengthSync())
                              : "Unavailable";
                          final dateStr = exists
                              ? DateFormat(
                                  "MMM d, yyyy",
                                ).format(file.lastModifiedSync())
                              : "";

                          return ListTile(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 2.h,
                            ),
                            leading: _buildLeadingThumbnail(
                              file: file,
                              category: category,
                              isDark: isDark,
                              exists: exists,
                            ),
                            title: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.instrumentSans(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: exists
                                    ? (isDark ? Colors.white : Colors.black87)
                                    : (isDark
                                          ? Colors.white38
                                          : Colors.black38),
                              ),
                            ),
                            subtitle: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 5.w,
                                    vertical: 1.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getCategoryColor(
                                      category,
                                    ).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4.r),
                                  ),
                                  child: Text(
                                    ext.toUpperCase().isEmpty
                                        ? "FILE"
                                        : ext.toUpperCase(),
                                    style: GoogleFonts.outfit(
                                      fontSize: 9.5.sp,
                                      fontWeight: FontWeight.bold,
                                      color: _getCategoryColor(category),
                                    ),
                                  ),
                                ),
                                Gap(6.w),
                                Text(
                                  sizeStr,
                                  style: GoogleFonts.instrumentSans(
                                    fontSize: 11.5.sp,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                ),
                                if (dateStr.isNotEmpty) ...[
                                  Gap(4.w),
                                  Text(
                                    "•",
                                    style: TextStyle(
                                      fontSize: 10.sp,
                                      color: isDark
                                          ? Colors.grey.shade600
                                          : Colors.grey.shade400,
                                    ),
                                  ),
                                  Gap(4.w),
                                  Text(
                                    dateStr,
                                    style: GoogleFonts.instrumentSans(
                                      fontSize: 11.sp,
                                      color: isDark
                                          ? Colors.grey.shade500
                                          : Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_vert_rounded,
                                size: 18.r,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                              padding: EdgeInsets.zero,
                              onSelected: (action) async {
                                if (action == 'open') {
                                  if (exists) {
                                    await addRecentFile(file.path);
                                    if (!context.mounted) return;
                                    DocumentViewerHelper.openDocument(
                                      context,
                                      file,
                                    );
                                  } else {
                                    Fluttertoast.showToast(
                                      msg: "File no longer exists",
                                    );
                                  }
                                } else if (action == 'share') {
                                  if (exists) {
                                    SharePlus.instance.share(
                                      ShareParams(
                                        files: [XFile(file.path)],
                                        text: name,
                                      ),
                                    );
                                  } else {
                                    Fluttertoast.showToast(
                                      msg: "File no longer exists",
                                    );
                                  }
                                } else if (action == 'info') {
                                  _showFileInfoDialog(context, file, isDark);
                                } else if (action == 'remove') {
                                  removeRecentFile(path);
                                  Fluttertoast.showToast(
                                    msg: "Removed from recents",
                                  );
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'open',
                                  child: Row(
                                    children: [
                                      Icon(Icons.open_in_new_rounded, size: 18),
                                      Gap(8),
                                      Text("Open"),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'share',
                                  child: Row(
                                    children: [
                                      Icon(Icons.share_outlined, size: 18),
                                      Gap(8),
                                      Text("Share"),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'info',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline_rounded,
                                        size: 18,
                                      ),
                                      Gap(8),
                                      Text("File Details"),
                                    ],
                                  ),
                                ),
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
                                        "Remove from Recents",
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            onTap: () async {
                              if (!exists) {
                                Fluttertoast.showToast(
                                  msg: "File not found at path",
                                );
                                return;
                              }
                              await addRecentFile(file.path);
                              if (!context.mounted) return;
                              DocumentViewerHelper.openDocument(context, file);
                            },
                          );
                        },
                      );
                return widget.isEmbedded
                    ? listWidget
                    : Expanded(child: listWidget);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildLeadingThumbnail({
    required File file,
    required DocumentCategory category,
    required bool isDark,
    required bool exists,
  }) {
    if (!exists) {
      return Container(
        width: 38.w,
        height: 48.h,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: allradius(6.r),
        ),
        child: Icon(
          Icons.broken_image_outlined,
          size: 20.r,
          color: Colors.grey.shade500,
        ),
      );
    }

    if (category == DocumentCategory.pdf) {
      return PdfThumbnailWidget(
        filePath: file.path,
        width: 38,
        height: 48,
        borderRadius: 6,
      );
    } else if (category == DocumentCategory.image) {
      return ClipRRect(
        borderRadius: allradius(6.r),
        child: Container(
          width: 38.w,
          height: 48.h,
          color: isDark ? Colors.black38 : Colors.grey.shade100,
          child: Image.file(
            file,
            width: 38.w,
            height: 48.h,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Center(child: _getFileIcon(category, size: 22)),
          ),
        ),
      );
    }

    return Container(
      width: 38.w,
      height: 48.h,
      decoration: BoxDecoration(
        color: _getCategoryColor(category).withValues(alpha: 0.1),
        borderRadius: allradius(6.r),
      ),
      child: Center(child: _getFileIcon(category, size: 22)),
    );
  }

  Widget _buildEmptyState(bool isDark, bool isSearching) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSearching ? Icons.search_off_rounded : Icons.history_rounded,
              size: 52.r,
              color: Colors.grey.shade500,
            ),
            Gap(12.h),
            Text(
              isSearching ? "No matching files" : "No Recent Files",
              style: GoogleFonts.outfit(
                fontSize: 17.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Gap(4.h),
            Text(
              isSearching
                  ? "Try searching for a different file name."
                  : "Documents you open or access will appear here for quick access.",
              textAlign: TextAlign.center,
              style: GoogleFonts.instrumentSans(
                fontSize: 13.sp,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
