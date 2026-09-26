/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';

import 'package:pdfhawk/data/res/theme.dart';
import 'package:pdfhawk/data/res/utils.dart';
import 'package:pdfhawk/interface/pages/FileViewers/pdf_reader_page.dart';
import 'package:pdfhawk/interface/pages/PDFTools/images_editor_page.dart';
import 'package:pdfhawk/logic/helpers/document_converter.dart';

// ============================================================================
// GALLERY PREVIEW ITEM MODEL
// ============================================================================

class GalleryPreviewItem {
  final String id;
  final AssetEntity? asset;
  String? filePath;

  GalleryPreviewItem({
    required this.id,
    this.asset,
    this.filePath,
  });

  ImageProvider get imageProvider {
    if (filePath != null && File(filePath!).existsSync()) {
      return FileImage(File(filePath!));
    }
    if (asset != null) {
      return AssetEntityImageProvider(asset!, isOriginal: false);
    }
    return const AssetImage('assets/src/logo.png');
  }

  Future<String?> getOrEnsureFilePath() async {
    if (filePath != null && File(filePath!).existsSync()) {
      return filePath;
    }
    if (asset != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final scansDir = Directory("${appDir.path}/scans");
      if (!scansDir.existsSync()) {
        scansDir.createSync(recursive: true);
      }
      final File? f = await asset!.file ?? await asset!.originFile;
      if (f != null && f.existsSync()) {
        final targetPath =
            "${scansDir.path}/img_${DateTime.now().millisecondsSinceEpoch}_${asset!.id.hashCode}.jpg";
        final saved = await f.copy(targetPath);
        filePath = saved.path;
        return filePath;
      }
    }
    return null;
  }
}

// ============================================================================
// UNIFIED IMAGE VIEWER PAGE
// ============================================================================

class ImageViewerPage extends StatefulWidget {
  final List<GalleryPreviewItem> items;
  final int initialIndex;
  final List<String> selectedIds; // Ordered IDs of selected items
  final void Function(String id, bool isSelected)? onToggleSelect;
  final void Function(String id, String updatedPath)? onImageEdited;
  final String? title;
  final bool enablePdfConversion;

  ImageViewerPage({
    super.key,
    List<GalleryPreviewItem>? items,
    File? imageFile,
    String? imagePath,
    List<File>? imageFiles,
    List<String>? imagePaths,
    this.initialIndex = 0,
    List<String>? selectedIds,
    this.onToggleSelect,
    this.onImageEdited,
    this.title,
    this.enablePdfConversion = true,
  })  : items = items ??
            (imageFile != null
                ? [GalleryPreviewItem(id: imageFile.path, filePath: imageFile.path)]
                : imagePath != null
                    ? [GalleryPreviewItem(id: imagePath, filePath: imagePath)]
                    : imageFiles != null
                        ? imageFiles
                            .map((f) => GalleryPreviewItem(
                                  id: f.path,
                                  filePath: f.path,
                                ))
                            .toList()
                        : imagePaths != null
                            ? imagePaths
                                .map((p) => GalleryPreviewItem(
                                      id: p,
                                      filePath: p,
                                    ))
                                .toList()
                            : []),
        selectedIds = selectedIds ?? const [];

  const ImageViewerPage.gallery({
    super.key,
    required this.items,
    this.initialIndex = 0,
    this.selectedIds = const [],
    this.onToggleSelect,
    this.onImageEdited,
    this.title,
    this.enablePdfConversion = true,
  });

  factory ImageViewerPage.singleFile({
    Key? key,
    required File imageFile,
    String? title,
    bool enablePdfConversion = true,
    void Function(String id, String updatedPath)? onImageEdited,
  }) {
    return ImageViewerPage(
      key: key,
      imageFile: imageFile,
      title: title,
      enablePdfConversion: enablePdfConversion,
      onImageEdited: onImageEdited,
    );
  }

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

typedef ImageGalleryPhotoViewerPage = ImageViewerPage;

class _ImageViewerPageState extends State<ImageViewerPage> {
  late int _currentIndex;
  late PageController _pageController;
  late List<String> _selectedIds;
  bool _showChrome = true;
  bool _isConverting = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.items.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.items.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _selectedIds = List.from(widget.selectedIds);
  }

  @override
  void didUpdateWidget(covariant ImageViewerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIds != oldWidget.selectedIds) {
      _selectedIds = List.from(widget.selectedIds);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleChrome() {
    setState(() {
      _showChrome = !_showChrome;
    });
  }

  void _toggleSelectCurrent() {
    if (widget.items.isEmpty) return;
    final currentItem = widget.items[_currentIndex];
    setState(() {
      if (_selectedIds.contains(currentItem.id)) {
        _selectedIds.remove(currentItem.id);
        widget.onToggleSelect?.call(currentItem.id, false);
      } else {
        _selectedIds.add(currentItem.id);
        widget.onToggleSelect?.call(currentItem.id, true);
      }
    });
  }

  Future<void> _openEditorForCurrent() async {
    if (widget.items.isEmpty) return;
    final item = widget.items[_currentIndex];
    final path = await item.getOrEnsureFilePath();
    if (path == null) {
      Fluttertoast.showToast(msg: "Could not prepare image for editing");
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImagesEditorPage(
          imagePath: path,
          onSave: (updatedPath) {
            setState(() {
              item.filePath = updatedPath;
            });
            PaintingBinding.instance.imageCache.evict(FileImage(File(updatedPath)));
            widget.onImageEdited?.call(item.id, updatedPath);
          },
        ),
      ),
    );
  }

  Future<void> _shareCurrentImage() async {
    if (widget.items.isEmpty) return;
    final item = widget.items[_currentIndex];
    final path = await item.getOrEnsureFilePath();
    if (path == null) {
      Fluttertoast.showToast(msg: "Could not prepare image for sharing");
      return;
    }

    SharePlus.instance.share(
      ShareParams(
        files: [XFile(path)],
        text: p.basename(path),
      ),
    );
  }

  Future<void> _convertToPdf() async {
    if (_isConverting || widget.items.isEmpty) return;
    final item = widget.items[_currentIndex];
    final path = await item.getOrEnsureFilePath();
    if (path == null) {
      Fluttertoast.showToast(msg: "Could not prepare image for PDF conversion");
      return;
    }

    setState(() => _isConverting = true);

    try {
      final pdfFile = await DocumentConverter.convertToPreviewPdf(File(path));
      if (!mounted) return;
      setState(() => _isConverting = false);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PDFReaderPage(pdfFile: pdfFile),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isConverting = false);
      Fluttertoast.showToast(msg: "Error converting image to PDF: $e");
    }
  }

  void _showInfoDialog() async {
    if (widget.items.isEmpty) return;
    final item = widget.items[_currentIndex];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final width = item.asset?.width;
    final height = item.asset?.height;
    DateTime? date = item.asset?.createDateTime;
    final name =
        item.asset?.title ??
        (item.filePath != null ? p.basename(item.filePath!) : "Photo");
    int? sizeBytes;

    if (item.filePath != null) {
      final f = File(item.filePath!);
      if (f.existsSync()) {
        sizeBytes = f.lengthSync();
        date ??= f.lastModifiedSync();
      }
    }

    final ext = item.filePath != null
        ? p.extension(item.filePath!).toUpperCase().replaceAll('.', '')
        : (item.asset?.mimeType ?? "IMAGE");

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E24) : white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Image Details",
                      style: GoogleFonts.outfit(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                Divider(color: isDark ? Colors.white12 : Colors.black12),
                _buildInfoRow("Name", name, isDark),
                if (ext.isNotEmpty) _buildInfoRow("Format", ext, isDark),
                if (width != null && height != null)
                  _buildInfoRow("Resolution", "$width × $height px", isDark),
                if (sizeBytes != null)
                  _buildInfoRow("File Size", _formatBytes(sizeBytes), isDark),
                if (date != null)
                  _buildInfoRow(
                    "Date",
                    DateFormat.yMMMd().add_jm().format(date),
                    isDark,
                  ),
                if (item.filePath != null)
                  _buildInfoRow("Path", item.filePath!, isDark),
                Gap(14.h),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) {
      return "${(bytes / 1024).toStringAsFixed(1)} KB";
    }
    return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90.w,
            child: Text(
              label,
              style: GoogleFonts.instrumentSans(
                color: isDark ? Colors.white54 : Colors.grey.shade600,
                fontSize: 13.sp,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.instrumentSans(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 13.sp,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Text(
            "No image to display",
            style: GoogleFonts.outfit(
              color: Colors.white70,
              fontSize: 16.sp,
            ),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final currentItem = widget.items[_currentIndex];
    final orderIndex = _selectedIds.indexOf(currentItem.id);
    final isSelected = orderIndex != -1;
    final isMulti = widget.items.length > 1;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // PhotoViewGallery with smooth horizontal swipe
            PhotoViewGallery.builder(
              scrollPhysics: const BouncingScrollPhysics(),
              pageController: _pageController,
              itemCount: widget.items.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              builder: (BuildContext context, int index) {
                final itm = widget.items[index];
                return PhotoViewGalleryPageOptions(
                  imageProvider: itm.imageProvider,
                  initialScale: PhotoViewComputedScale.contained,
                  minScale: PhotoViewComputedScale.contained * 0.8,
                  maxScale: PhotoViewComputedScale.covered * 3.5,
                  onTapUp: (context, details, controllerValue) => _toggleChrome(),
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image_rounded,
                          size: 64.r,
                          color: Colors.grey.shade600,
                        ),
                        Gap(12.h),
                        Text(
                          "Failed to render image",
                          style: GoogleFonts.outfit(
                            color: Colors.grey.shade400,
                            fontSize: 14.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              loadingBuilder: (context, event) => const Center(
                child: CircularProgressIndicator(color: royalblue),
              ),
            ),

            // Top Header Bar with prominent back button & counter/title
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              top: _showChrome ? 0 : -100.h,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back Button
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: allradius(20.r),
                        child: Container(
                          width: 38.r,
                          height: 38.r,
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 1.2,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 17.sp,
                            ),
                          ),
                        ),
                      ),

                      // Center Title or Page Index Counter
                      if (isMulti)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14.w,
                            vertical: 6.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: allradius(16.r),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            "${_currentIndex + 1} / ${widget.items.length}",
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: Container(
                            margin: EdgeInsets.symmetric(horizontal: 12.w),
                            padding: EdgeInsets.symmetric(
                              horizontal: 14.w,
                              vertical: 6.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: allradius(16.r),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              widget.title ??
                                  (currentItem.filePath != null
                                      ? p.basename(currentItem.filePath!)
                                      : (currentItem.asset?.title ?? "Photo")),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 13.5.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                      // Balance Spacer
                      if (isMulti)
                        const SizedBox(width: 38)
                      else
                        const SizedBox(width: 0),
                    ],
                  ),
                ),
              ),
            ),

            // Floating Pill Bar at the Bottom: [Edit] | [Info] | [Share] | [To PDF] | [Selection Badge]
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              bottom: _showChrome ? 28.h : -100.h,
              left: 0,
              right: 0,
              child: Center(
                child: ClipRRect(
                  borderRadius: allradius(30.r),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xCC1A1A22),
                        borderRadius: allradius(30.r),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Edit action
                          _buildPillAction(
                            icon: Icons.tune_rounded,
                            tooltip: "Edit",
                            onTap: _openEditorForCurrent,
                          ),
                          _buildPillDivider(),

                          // Info action
                          _buildPillAction(
                            icon: Icons.info_outline_rounded,
                            tooltip: "Info",
                            onTap: _showInfoDialog,
                          ),
                          _buildPillDivider(),

                          // Share action
                          _buildPillAction(
                            icon: Icons.share_rounded,
                            tooltip: "Share",
                            onTap: _shareCurrentImage,
                          ),

                          // To PDF action
                          if (widget.enablePdfConversion) ...[
                            _buildPillDivider(),
                            if (_isConverting)
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14.w,
                                  vertical: 8.h,
                                ),
                                child: SizedBox(
                                  width: 20.r,
                                  height: 20.r,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            else
                              _buildPillAction(
                                icon: Icons.picture_as_pdf_rounded,
                                tooltip: "Convert to PDF",
                                onTap: _convertToPdf,
                              ),
                          ],

                          // Select action (shows selection index badge if enabled)
                          if (widget.onToggleSelect != null) ...[
                            _buildPillDivider(),
                            Tooltip(
                              message: isSelected
                                  ? "Deselect (Page #${orderIndex + 1})"
                                  : "Select",
                              child: InkWell(
                                onTap: _toggleSelectCurrent,
                                borderRadius: allradius(20.r),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12.w,
                                    vertical: 6.h,
                                  ),
                                  child: Container(
                                    width: 26.r,
                                    height: 26.r,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : Colors.white12,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.white60,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: isSelected
                                          ? Text(
                                              "${orderIndex + 1}",
                                              style: GoogleFonts.outfit(
                                                color: Colors.white,
                                                fontSize: 13.sp,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            )
                                          : Icon(
                                              Icons.add_rounded,
                                              color: Colors.white70,
                                              size: 16.sp,
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: allradius(20.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          child: Icon(icon, size: 21.sp, color: iconColor ?? Colors.white70),
        ),
      ),
    );
  }

  Widget _buildPillDivider() {
    return Container(
      width: 1,
      height: 18.h,
      margin: EdgeInsets.symmetric(horizontal: 3.w),
      color: Colors.white24,
    );
  }
}
