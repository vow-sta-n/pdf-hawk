/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'package:community_material_icon/community_material_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:pdfhawk/data/models/writer_document_model.dart';
import 'package:pdfhawk/data/res/constants.dart';
import 'package:pdfhawk/data/res/theme.dart';
import 'package:pdfhawk/interface/bottomsheets/document_convert_bottom_sheet.dart';
import 'package:pdfhawk/interface/pages/pdf_reader_page.dart';
import 'package:pdfhawk/interface/pages/pdf_writer_page.dart';
import 'package:pdfhawk/interface/widgets/pdf_thumbnail_widget.dart';
import 'package:pdfhawk/logic/services/device_documents_service.dart';
import 'package:pdfhawk/logic/services/folder_storage_service.dart';
import 'package:pdfhawk/logic/services/hawk_crypto_service.dart';
import 'package:flutter/services.dart';
import 'package:pdfhawk/data/class/p_d_f_hawk_icons_icons.dart';
import 'package:pdfhawk/data/models/folder_model.dart';
import 'package:pdfhawk/interface/pages/folder_documents_page.dart';
import 'package:share_plus/share_plus.dart';

enum DocumentSortOption { dateNewest, dateOldest, nameAsc, sizeLargest }

class FolderDirectoryGroup {
  final String directoryPath;
  final String folderName;
  final List<DeviceDocumentModel> documents;
  final int totalSize;

  const FolderDirectoryGroup({
    required this.directoryPath,
    required this.folderName,
    required this.documents,
    required this.totalSize,
  });
}

class AllDocumentsPage extends StatefulWidget {
  final DocumentCategory initialCategory;

  const AllDocumentsPage({
    super.key,
    this.initialCategory = DocumentCategory.all,
  });

  @override
  State<AllDocumentsPage> createState() => _AllDocumentsPageState();
}

class _AllDocumentsPageState extends State<AllDocumentsPage> {
  late DocumentCategory _selectedCategory;
  DocumentSortOption _sortOption = DocumentSortOption.dateNewest;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchActive = false;
  bool _isFolderView = true;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    DeviceDocumentsService.getCachedDocuments();
    // Trigger fresh scan in background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeviceDocumentsService.scanDeviceDocuments();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<DeviceDocumentModel> _getProcessedDocuments(
    List<DeviceDocumentModel> allDocs,
  ) {
    var filtered = DeviceDocumentsService.filterByCategory(
      allDocs,
      _selectedCategory,
    );

    if (_searchQuery.isNotEmpty) {
      filtered = DeviceDocumentsService.searchDocuments(filtered, _searchQuery);
    }

    // Apply sorting
    final sorted = List<DeviceDocumentModel>.from(filtered);
    switch (_sortOption) {
      case DocumentSortOption.dateNewest:
        sorted.sort((a, b) => b.lastModified.compareTo(a.lastModified));
        break;
      case DocumentSortOption.dateOldest:
        sorted.sort((a, b) => a.lastModified.compareTo(b.lastModified));
        break;
      case DocumentSortOption.nameAsc:
        sorted.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case DocumentSortOption.sizeLargest:
        sorted.sort((a, b) => b.size.compareTo(a.size));
        break;
    }

    return sorted;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) {
      return "${(bytes / 1024).toStringAsFixed(1)} KB";
    }
    return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
  }

  List<FolderDirectoryGroup> _getFolderGroups(List<DeviceDocumentModel> docs) {
    final Map<String, List<DeviceDocumentModel>> map = {};
    for (final doc in docs) {
      final dir = p.dirname(doc.path);
      map.putIfAbsent(dir, () => []).add(doc);
    }

    final List<FolderDirectoryGroup> groups = [];
    map.forEach((dir, dirDocs) {
      final name = p.basename(dir);
      int totalSize = 0;
      for (final d in dirDocs) {
        totalSize += d.size;
      }
      groups.add(
        FolderDirectoryGroup(
          directoryPath: dir,
          folderName: name.isEmpty ? "Root" : name,
          documents: dirDocs,
          totalSize: totalSize,
        ),
      );
    });

    switch (_sortOption) {
      case DocumentSortOption.nameAsc:
        groups.sort(
          (a, b) =>
              a.folderName.toLowerCase().compareTo(b.folderName.toLowerCase()),
        );
        break;
      case DocumentSortOption.sizeLargest:
        groups.sort((a, b) => b.totalSize.compareTo(a.totalSize));
        break;
      case DocumentSortOption.dateNewest:
        groups.sort((a, b) {
          final aMax = a.documents
              .map((d) => d.lastModified)
              .reduce((x, y) => x.isAfter(y) ? x : y);
          final bMax = b.documents
              .map((d) => d.lastModified)
              .reduce((x, y) => x.isAfter(y) ? x : y);
          return bMax.compareTo(aMax);
        });
        break;
      case DocumentSortOption.dateOldest:
        groups.sort((a, b) {
          final aMin = a.documents
              .map((d) => d.lastModified)
              .reduce((x, y) => x.isBefore(y) ? x : y);
          final bMin = b.documents
              .map((d) => d.lastModified)
              .reduce((x, y) => x.isBefore(y) ? x : y);
          return aMin.compareTo(bMin);
        });
        break;
    }

    return groups;
  }

  Widget _getFileIcon(DeviceDocumentModel doc, {double size = 26}) {
    IconData icon;
    Color color;

    switch (doc.category) {
      case DocumentCategory.pdf:
        icon = CommunityMaterialIcons.file_pdf_box;
        color = const Color(0xFFE52521);
        break;
      case DocumentCategory.word:
        icon = CommunityMaterialIcons.file_word_box;
        color = const Color(0xFF2B579A);
        break;
      case DocumentCategory.excel:
        icon = CommunityMaterialIcons.file_excel_box;
        color = const Color(0xFF217346);
        break;
      case DocumentCategory.ppt:
        icon = CommunityMaterialIcons.file_powerpoint_box;
        color = const Color(0xFFD24726);
        break;
      case DocumentCategory.text:
        icon = CommunityMaterialIcons.file_document_outline;
        color = Colors.amber.shade800;
        break;
      case DocumentCategory.hawk:
        icon = CommunityMaterialIcons.shield_lock_outline;
        color = royalblue;
        break;
      default:
        icon = CommunityMaterialIcons.file_outline;
        color = Colors.grey.shade600;
        break;
    }

    return Icon(icon, size: size.r, color: color);
  }

  Future<void> _openDocument(DeviceDocumentModel doc) async {
    final file = doc.file;
    if (!file.existsSync()) {
      Fluttertoast.showToast(msg: "File no longer exists at path");
      return;
    }

    if (doc.category == DocumentCategory.pdf) {
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
      );
    } else if (doc.category == DocumentCategory.hawk) {
      try {
        final jsonMap = await HawkCryptoService.readHawkFile(file);
        final writerDoc = WriterDocumentModel.fromJson(jsonMap);
        if (!mounted) return;
        final isAuto = p
            .basename(file.path)
            .toLowerCase()
            .startsWith('autosaved_');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfWriterPage(
              initialDeltaJson: writerDoc.quillDeltaJson,
              initialOverlays: writerDoc.overlays,
              sourceHawkFile: file,
              isAutoSaved: isAuto,
            ),
          ),
        );
      } catch (e) {
        Fluttertoast.showToast(msg: "Error opening .hawk document: $e");
      }
    } else if (doc.category == DocumentCategory.word) {
      _showWordOptions(doc);
    } else {
      _showFileDetailsDialog(doc);
    }
  }

  void _showWordOptions(DeviceDocumentModel doc) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                doc.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Gap(16.h),
              ListTile(
                leading: const Icon(
                  CommunityMaterialIcons.file_edit_outline,
                  color: royalblue,
                ),
                title: const Text("Edit in PDF Hawk Writer"),
                subtitle: const Text("Import as editable rich-text document"),
                onTap: () {
                  Navigator.pop(ctx);
                  try {
                    final deltaJson = PdfWriterPage.parseDocxToDeltaJson(
                      doc.file,
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            PdfWriterPage(initialDeltaJson: deltaJson),
                      ),
                    );
                  } catch (e) {
                    Fluttertoast.showToast(msg: "Error importing Word doc: $e");
                  }
                },
              ),
              ListTile(
                leading: const Icon(
                  CommunityMaterialIcons.file_pdf_box,
                  color: Color(0xFFE52521),
                ),
                title: const Text("Convert to PDF"),
                subtitle: const Text("Export as high quality PDF document"),
                onTap: () {
                  Navigator.pop(ctx);
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (context) => DocumentConvertBottomSheet(
                      file: doc.file,
                      fileName: doc.name,
                      extension: doc.extension,
                      fileSize: doc.formattedSize,
                      onConversionSuccess: (outputPdfFile) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                PDFReaderPage(pdfFile: outputPdfFile),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.share_rounded,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                title: const Text("Share File"),
                onTap: () {
                  Navigator.pop(ctx);
                  SharePlus.instance.share(
                    ShareParams(files: [XFile(doc.path)], text: doc.name),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFileDetailsDialog(DeviceDocumentModel doc) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dateStr = DateFormat(
      "MMM dd, yyyy • hh:mm a",
    ).format(doc.lastModified);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: allradius(16.r)),
        title: Row(
          children: [
            _getFileIcon(doc, size: 24),
            Gap(10.w),
            Expanded(
              child: Text(
                doc.name,
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
            _buildDetailRow("Size", doc.formattedSize),
            _buildDetailRow("Modified", dateStr),
            _buildDetailRow("Type", doc.extension.toUpperCase()),
            _buildDetailRow("Path", doc.path, isPath: true),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              SharePlus.instance.share(
                ShareParams(files: [XFile(doc.path)], text: doc.name),
              );
            },
            icon: const Icon(Icons.share_rounded, size: 16),
            label: const Text("Share"),
          ),
          if (doc.category == DocumentCategory.word ||
              doc.category == DocumentCategory.text)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (context) => DocumentConvertBottomSheet(
                    file: doc.file,
                    fileName: doc.name,
                    extension: doc.extension,
                    fileSize: doc.formattedSize,
                    onConversionSuccess: (outputPdfFile) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PDFReaderPage(pdfFile: outputPdfFile),
                        ),
                      );
                    },
                  ),
                );
              },
              icon: const Icon(CommunityMaterialIcons.file_pdf_box, size: 16),
              label: const Text("To PDF"),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isPath = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.instrumentSans(
              fontSize: 11.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          Gap(2.h),
          Text(
            value,
            maxLines: isPath ? 3 : 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.instrumentSans(
              fontSize: 12.5.sp,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        toolbarHeight: 80,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: _isSearchActive
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                style: GoogleFonts.outfit(
                  fontSize: 15.sp,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: "Search device files...",
                  hintStyle: GoogleFonts.outfit(
                    fontSize: 14.sp,
                    color: Colors.grey.shade500,
                  ),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              )
            : ValueListenableBuilder<List<DeviceDocumentModel>>(
                valueListenable: DeviceDocumentsService.documentsNotifier,
                builder: (context, docs, _) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          "Documents",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
        actions: [
          if (_isSearchActive)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                setState(() {
                  _isSearchActive = false;
                  _searchController.clear();
                  _searchQuery = "";
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: () {
                setState(() {
                  _isSearchActive = true;
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _searchFocusNode.requestFocus();
                });
              },
            ),
          IconButton(
            icon: Icon(
              _isFolderView
                  ? Icons.format_list_bulleted_rounded
                  : Icons.folder_copy_outlined,
              color: _isFolderView ? royalblue : null,
            ),
            tooltip: _isFolderView
                ? "Switch to Flat View"
                : "Switch to Folder View",
            onPressed: () {
              setState(() {
                _isFolderView = !_isFolderView;
              });
            },
          ),
          PopupMenuButton<DocumentSortOption>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: "Sort by",
            onSelected: (opt) {
              setState(() {
                _sortOption = opt;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: DocumentSortOption.dateNewest,
                child: Text("Date Modified (Newest)"),
              ),
              const PopupMenuItem(
                value: DocumentSortOption.dateOldest,
                child: Text("Date Modified (Oldest)"),
              ),
              const PopupMenuItem(
                value: DocumentSortOption.nameAsc,
                child: Text("Name (A - Z)"),
              ),
              const PopupMenuItem(
                value: DocumentSortOption.sizeLargest,
                child: Text("Size (Largest first)"),
              ),
            ],
          ),
          ValueListenableBuilder<bool>(
            valueListenable: DeviceDocumentsService.isScanningNotifier,
            builder: (context, isScanning, _) {
              if (isScanning) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14.w),
                    child: SizedBox(
                      width: 18.r,
                      height: 18.r,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: royalblue,
                      ),
                    ),
                  ),
                );
              }
              return IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: "Rescan storage",
                onPressed: () {
                  DeviceDocumentsService.scanDeviceDocuments(force: true);
                  Fluttertoast.showToast(msg: "Scanning device storage...");
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Category Selector Pills
          _buildCategoryPills(isDark),

          // Document List
          Expanded(
            child: ValueListenableBuilder<List<DeviceDocumentModel>>(
              valueListenable: DeviceDocumentsService.documentsNotifier,
              builder: (context, allDocs, _) {
                final processed = _getProcessedDocuments(allDocs);

                if (processed.isEmpty) {
                  return _buildEmptyState(isDark);
                }

                if (_isFolderView) {
                  return _buildFolderView(processed, isDark, theme);
                }

                return RefreshIndicator(
                  color: royalblue,
                  onRefresh: () async {
                    await DeviceDocumentsService.scanDeviceDocuments(
                      force: true,
                    );
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 8.h,
                    ),
                    itemCount: processed.length,
                    itemBuilder: (context, index) {
                      final doc = processed[index];
                      return _buildDocumentCard(doc, isDark, theme);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPills(bool isDark) {
    final categories = [
      (DocumentCategory.all, "All"),
      (DocumentCategory.pdf, "PDFs"),
      (DocumentCategory.word, "Word"),
      (DocumentCategory.excel, "Excel"),
      (DocumentCategory.ppt, "PowerPoint"),
      (DocumentCategory.text, "Text"),
      (DocumentCategory.hawk, "Hawk"),
    ];

    return Container(
      height: 48.h,
      padding: EdgeInsets.symmetric(vertical: 6.h),
      color: isDark ? Colors.black : Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        itemCount: categories.length,
        separatorBuilder: (_, _) => Gap(8.w),
        itemBuilder: (context, index) {
          final (cat, label) = categories[index];
          final isSelected = _selectedCategory == cat;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = cat;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              decoration: BoxDecoration(
                color: isSelected
                    ? royalblue
                    : isDark
                    ? Colors.grey.shade900
                    : Colors.grey.shade200,
                borderRadius: allradius(20.r),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
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
          );
        },
      ),
    );
  }

  Widget _buildFolderView(
    List<DeviceDocumentModel> processed,
    bool isDark,
    ThemeData theme,
  ) {
    final folderGroups = _getFolderGroups(processed);

    return RefreshIndicator(
      color: royalblue,
      onRefresh: () async {
        await DeviceDocumentsService.scanDeviceDocuments(force: true);
      },
      child: Column(
        children: [
          // Folder Explorer Summary Header Bar
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            color: isDark ? Colors.black26 : Colors.grey.shade50,
            child: Row(
              children: [
                Icon(Icons.folder_open_rounded, size: 16.sp, color: royalblue),
                Gap(6.w),
                Text(
                  "${folderGroups.length} ${folderGroups.length == 1 ? 'Folder' : 'Folders'} • ${processed.length} Files",
                  style: GoogleFonts.outfit(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
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
              itemCount: folderGroups.length,
              itemBuilder: (context, index) {
                final group = folderGroups[index];
                return _buildFolderGridCard(group, isDark, theme);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderGridCard(
    FolderDirectoryGroup group,
    bool isDark,
    ThemeData theme,
  ) {
    final formattedSize = _formatBytes(group.totalSize);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        borderRadius: allradius(18.r),
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
        borderRadius: allradius(18.r),
        child: InkWell(
          borderRadius: allradius(18.r),
          onTap: () => _openFolderGroup(group),
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
                    padding: EdgeInsets.zero,
                    onSelected: (value) {
                      if (value == 'open') {
                        _openFolderGroup(group);
                      } else if (value == 'info') {
                        _showFolderInfoDialog(group);
                      } else if (value == 'copy_path') {
                        Clipboard.setData(
                          ClipboardData(text: group.directoryPath),
                        );
                        Fluttertoast.showToast(msg: "Directory path copied");
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
                      const PopupMenuItem(
                        value: 'copy_path',
                        child: Row(
                          children: [
                            Icon(Icons.copy_rounded, size: 18),
                            Gap(8),
                            Text("Copy Path"),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const Spacer(),

              // Bottom: Name & File Count / Size
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 0, 12, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.folderName,
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
                      "${group.documents.length} ${group.documents.length == 1 ? 'item' : 'items'}${group.documents.isNotEmpty ? ' • $formattedSize' : ''}",
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
    );
  }

  void _openFolderGroup(FolderDirectoryGroup group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FolderDocumentsPage(
          folder: FolderModel(
            id: group.directoryPath,
            name: group.folderName,
            path: group.directoryPath,
          ),
          initialFiles: group.documents.map((d) => d.file).toList(),
        ),
      ),
    );
  }

  void _showFolderInfoDialog(FolderDirectoryGroup group) {
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: allradius(18.r)),
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
                  group.folderName,
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
              _buildFolderInfoRow("Type", "Device Folder", isDark),
              Gap(8.h),
              _buildFolderInfoRow(
                "Files",
                "${group.documents.length} item${group.documents.length == 1 ? '' : 's'}",
                isDark,
              ),
              Gap(8.h),
              _buildFolderInfoRow(
                "Size",
                _formatBytes(group.totalSize),
                isDark,
              ),
              Gap(8.h),
              _buildFolderInfoRow("Path", group.directoryPath, isDark),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: group.directoryPath));
                Fluttertoast.showToast(msg: "Directory path copied");
              },
              child: const Text("Copy Path"),
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

  Widget _buildFolderInfoRow(String label, String value, bool isDark) {
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

  Widget _buildDocumentCard(
    DeviceDocumentModel doc,
    bool isDark,
    ThemeData theme,
  ) {
    final dateStr = DateFormat("MMM dd, yyyy").format(doc.lastModified);
    final parentDirName = p.basename(p.dirname(doc.path));

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        borderRadius: allradius(12.r),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black12,
          width: 0.8,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: allradius(12.r),
        child: InkWell(
          borderRadius: allradius(12.r),
          onTap: () => _openDocument(doc),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            child: Row(
              children: [
                // Leading Thumbnail / Icon
                if (doc.category == DocumentCategory.pdf)
                  PdfThumbnailWidget(
                    filePath: doc.path,
                    width: 38,
                    height: 48,
                    borderRadius: 6,
                  )
                else
                  Container(
                    width: 38.w,
                    height: 48.h,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black38 : Colors.grey.shade100,
                      borderRadius: allradius(6.r),
                    ),
                    child: Center(child: _getFileIcon(doc, size: 24)),
                  ),
                Gap(12.w),
                // File info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.instrumentSans(
                          fontSize: 13.5.sp,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Gap(4.h),
                      Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6.w,
                                vertical: 1.5.h,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.06),
                                borderRadius: allradius(4.r),
                              ),
                              child: Text(
                                parentDirName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.instrumentSans(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                          Gap(6.w),
                          Text(
                            doc.formattedSize,
                            style: GoogleFonts.instrumentSans(
                              fontSize: 11.sp,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          Gap(6.w),
                          Text(
                            "•",
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 10.sp,
                            ),
                          ),
                          Gap(6.w),
                          Text(
                            dateStr,
                            style: GoogleFonts.instrumentSans(
                              fontSize: 11.sp,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Trailing options button
                IconButton(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 18.r,
                    color: Colors.grey.shade500,
                  ),
                  onPressed: () => _showFileDetailsDialog(doc),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return ValueListenableBuilder<bool>(
      valueListenable: DeviceDocumentsService.isScanningNotifier,
      builder: (context, isScanning, _) {
        if (isScanning) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: royalblue),
                Gap(16.h),
                Text(
                  "Scanning device for documents...",
                  style: GoogleFonts.outfit(
                    fontSize: 15.sp,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }

        return Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 28.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.folder_open_rounded,
                  size: 48.r,
                  color: Colors.grey.shade600,
                ),
                Gap(12.h),
                Text(
                  _searchQuery.isNotEmpty
                      ? "No matching documents found"
                      : "No documents discovered on device",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                Gap(8.h),
                Text(
                  _searchQuery.isNotEmpty
                      ? "Try searching for a different keyword or check your category filter."
                      : "Make sure all-files storage permission is granted to allow scanning device storage.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.instrumentSans(
                    fontSize: 13.sp,
                    color: Colors.grey.shade500,
                  ),
                ),
                Gap(16.h),
                InkWell(
                  onTap: () async {
                    await FolderStorageService.ensureStoragePermission();
                    await DeviceDocumentsService.scanDeviceDocuments(
                      force: true,
                    );
                  },
                  borderRadius: allradius(24.r),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 10.h,
                    ),
                    decoration: BoxDecoration(
                      color: royalblue,
                      borderRadius: allradius(24.r),
                    ),
                    child: Text(
                      "Grant Permission & Scan",
                      style: GoogleFonts.outfit(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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
  }
}
