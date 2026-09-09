/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_reorderable_grid_view/widgets/reorderable_builder.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfhawk/data/class/p_d_f_hawk_icons_icons.dart';
import 'package:pdfhawk/data/res/constants.dart';
import 'package:pdfhawk/data/res/theme.dart';
import 'package:pdfhawk/interface/pages/images_editor_page.dart';
import 'package:pdfhawk/interface/widgets/pdf_page_renderer.dart';
import 'package:pdfhawk/logic/helpers/pdf_helper.dart';

typedef ReorderItemBuilder<T> =
    Widget Function(BuildContext context, T item, int index);

typedef ItemKeyGetter<T> = Key Function(T item, int index);

/// A high-performance, virtualized, and reusable reorderable grid widget.
///
/// Supports smooth drag-and-drop reordering with customizable grid layouts,
/// viewport virtualization, lazy item building, and auto-scrolling.
class AppReorderableGrid<T> extends StatefulWidget {
  final List<T> items;
  final ReorderItemBuilder<T> itemBuilder;
  final void Function(List<T> reorderedItems) onReorder;
  final ItemKeyGetter<T>? keyGetter;
  final ScrollController? scrollController;
  final int? crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double childAspectRatio;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics physics;
  final bool shrinkWrap;
  final Key? gridKey;

  const AppReorderableGrid({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.onReorder,
    this.keyGetter,
    this.scrollController,
    this.crossAxisCount,
    this.crossAxisSpacing = 10.0,
    this.mainAxisSpacing = 10.0,
    this.childAspectRatio = 0.72,
    this.padding,
    this.physics = const BouncingScrollPhysics(),
    this.shrinkWrap = false,
    this.gridKey,
  });

  @override
  State<AppReorderableGrid<T>> createState() => _AppReorderableGridState<T>();
}

class _AppReorderableGridState<T> extends State<AppReorderableGrid<T>> {
  ScrollController? _internalController;
  final GlobalKey _gridViewKey = GlobalKey();

  ScrollController get _effectiveController =>
      widget.scrollController ?? (_internalController ??= ScrollController());

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveCrossAxisCount =
        widget.crossAxisCount ??
        (MediaQuery.of(context).size.width > 600 ? 5 : 4);

    return ReorderableBuilder<T>.builder(
      key: widget.gridKey,
      scrollController: _effectiveController,
      itemCount: widget.items.length,
      onReorder: (ReorderedListFunction<T> reorderedListFunction) {
        final updatedList = reorderedListFunction(widget.items);
        widget.onReorder(updatedList);
      },
      childBuilder: (itemBuilder) {
        return GridView.builder(
          key: _gridViewKey,
          controller: widget.shrinkWrap ? null : _effectiveController,
          shrinkWrap: widget.shrinkWrap,
          padding: widget.padding ?? EdgeInsets.only(top: 4.h, bottom: 85.h),
          physics: widget.physics,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: effectiveCrossAxisCount,
            crossAxisSpacing: widget.crossAxisSpacing.w,
            mainAxisSpacing: widget.mainAxisSpacing.h,
            childAspectRatio: widget.childAspectRatio,
          ),
          itemCount: widget.items.length,
          itemBuilder: (context, index) {
            final item = widget.items[index];
            final itemKey = widget.keyGetter != null
                ? widget.keyGetter!(item, index)
                : ValueKey<String>('${item.hashCode}_$index');

            return itemBuilder(
              Container(
                key: itemKey,
                child: widget.itemBuilder(context, item, index),
              ),
              index,
            );
          },
        );
      },
    );
  }
}

/// Thumbnail renderer for a [PdfPageModel] supporting new images, cached edits, and native PDF pages.
class PdfPageThumbnail extends StatelessWidget {
  final PdfPageModel page;
  final File? fallbackPdfFile;
  final double scale;
  final BoxFit fit;

  const PdfPageThumbnail({
    super.key,
    required this.page,
    this.fallbackPdfFile,
    this.scale = 0.35,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (page.newImageFilePath != null) {
      return Image.file(
        File(page.newImageFilePath!),
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image_rounded),
      );
    } else if (page.cachedImagePath != null &&
        File(page.cachedImagePath!).existsSync()) {
      return Image.file(
        File(page.cachedImagePath!),
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.picture_as_pdf_rounded),
      );
    } else if (page.originalPageIndex != null) {
      final pdfFile = page.sourcePdfFile ?? fallbackPdfFile;
      if (pdfFile != null) {
        return PdfPageImageWidget(
          pdfFile: pdfFile,
          pageNumber: page.originalPageIndex!,
          fit: fit,
          scale: scale,
        );
      }
    }

    return Container(
      color: Colors.white,
      child: Center(
        child: Text(
          "Blank A4",
          style: GoogleFonts.instrumentSans(
            color: Colors.black54,
            fontWeight: FontWeight.bold,
            fontSize: 12.sp,
          ),
        ),
      ),
    );
  }
}

/// A premium visual card tile for a PDF page in a reorderable grid.
class PdfPageGridCard extends StatelessWidget {
  final PdfPageModel page;
  final int index;
  final bool isSelected;
  final bool isDark;
  final ThemeData theme;
  final File? fallbackPdfFile;
  final bool isDragging;
  final bool isDropTarget;
  final Key? menuKey;
  final VoidCallback? onTap;
  final VoidCallback? onMenuTap;
  final double thumbnailScale;

  const PdfPageGridCard({
    super.key,
    required this.page,
    required this.index,
    required this.isSelected,
    required this.isDark,
    required this.theme,
    this.fallbackPdfFile,
    this.isDragging = false,
    this.isDropTarget = false,
    this.menuKey,
    this.onTap,
    this.onMenuTap,
    this.thumbnailScale = 0.35,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: allradius(6.r),
          border: Border.all(
            color: isDropTarget
                ? theme.colorScheme.primary
                : (isSelected
                      ? theme.colorScheme.primary
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.12))),
            width: (isSelected || isDropTarget || isDragging) ? 2.5 : 1.0,
          ),
          boxShadow: isDragging
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: ClipRRect(
          borderRadius: allradius(6.r),
          child: Stack(
            children: [
              // Page Thumbnail Preview
              Positioned.fill(
                child: PdfPageThumbnail(
                  page: page,
                  fallbackPdfFile: fallbackPdfFile,
                  scale: thumbnailScale,
                ),
              ),

              // Gradient overlays for text readability
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.3, 0.65, 1.0],
                      colors: [
                        Colors.black.withValues(alpha: 0.55),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.65),
                      ],
                    ),
                  ),
                ),
              ),

              // Page Number Badge (Top Left)
              Positioned(
                top: 6.r,
                left: 6.r,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : Colors.black.withValues(alpha: 0.75),
                    borderRadius: allradius(6.r),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.4,
                          ),
                          blurRadius: 6,
                        ),
                    ],
                  ),
                  child: Text(
                    "${page.originalPageIndex ?? (index + 1)}",
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.sp,
                    ),
                  ),
                ),
              ),

              // Options Context Menu Button (Top Right)
              if (onMenuTap != null)
                Positioned(
                  top: 4.r,
                  right: 4.r,
                  child: GestureDetector(
                    key: menuKey,
                    onTap: onMenuTap,
                    child: Container(
                      padding: EdgeInsets.all(5.r),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.more_vert_rounded,
                        size: 16.r,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

              // Page Type Icon Indicator (Bottom Right)
              Positioned(
                bottom: 6.r,
                right: 6.r,
                child: Container(
                  padding: EdgeInsets.all(4.r),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: allradius(2.r),
                  ),
                  child: Icon(
                    page.newImageFilePath != null
                        ? Icons.image
                        : PDFHawkIcons.pdf,
                    size: 14.r,
                    color: Colors.white70,
                  ),
                ),
              ),

              // Drop Target Highlight visual overlay
              if (isDropTarget)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.25),
                      borderRadius: allradius(8.r),
                    ),
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.swap_horiz_rounded,
                          color: Colors.white,
                          size: 22.r,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A specialized, batteries-included reorderable grid for PDF pages with built-in context actions.
class PdfReorderableGrid extends StatelessWidget {
  final List<PdfPageModel> pages;
  final void Function(List<PdfPageModel> reorderedPages) onReorder;
  final File? fallbackPdfFile;
  final int? selectedPageIndex;
  final void Function(int index)? onPageSelected;
  final void Function(int index)? onAddBefore;
  final void Function(int index)? onAddAfter;
  final void Function(int index, PdfPageModel page)? onEditImage;
  final void Function(int index)? onDeletePage;
  final void Function(int index)? onCustomMenuTap;
  final Key? firstItemMenuKey;
  final ScrollController? scrollController;
  final int? crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double childAspectRatio;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics physics;
  final bool shrinkWrap;
  final Key? gridKey;
  final double thumbnailScale;
  final bool enableContextMenu;

  const PdfReorderableGrid({
    super.key,
    required this.pages,
    required this.onReorder,
    this.fallbackPdfFile,
    this.selectedPageIndex,
    this.onPageSelected,
    this.onAddBefore,
    this.onAddAfter,
    this.onEditImage,
    this.onDeletePage,
    this.onCustomMenuTap,
    this.firstItemMenuKey,
    this.scrollController,
    this.crossAxisCount,
    this.crossAxisSpacing = 10.0,
    this.mainAxisSpacing = 10.0,
    this.childAspectRatio = 0.72,
    this.padding,
    this.physics = const BouncingScrollPhysics(),
    this.shrinkWrap = false,
    this.gridKey,
    this.thumbnailScale = 0.35,
    this.enableContextMenu = true,
  });

  /// Helper to open a page in ImagesEditorPage directly
  static Future<void> openPageInEditor({
    required BuildContext context,
    required PdfPageModel page,
    File? fallbackPdfFile,
    required void Function(String newPath) onSaved,
  }) async {
    String? imgPath = page.newImageFilePath ?? page.cachedImagePath;
    if (imgPath == null && page.originalPageIndex != null) {
      final sourceFile = page.sourcePdfFile ?? fallbackPdfFile;
      if (sourceFile != null) {
        final bytes = await PdfPageImageRenderer.renderPageBytes(
          pdfPath: sourceFile.path,
          pageNumber: page.originalPageIndex!,
          scale: 2.0,
        );
        if (bytes != null) {
          final tempDir = await getTemporaryDirectory();
          final tempFile = File(
            '${tempDir.path}/edit_page_${page.originalPageIndex}_${DateTime.now().millisecondsSinceEpoch}.png',
          );
          await tempFile.writeAsBytes(bytes);
          page.cachedImagePath = tempFile.path;
          imgPath = tempFile.path;
        }
      }
    }

    if (imgPath != null && context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ImagesEditorPage(imagePath: imgPath!, onSave: onSaved),
        ),
      );
    }
  }

  /// Displays the standard modal bottom sheet context menu for a page tile
  void showPageContextMenu(BuildContext context, int pageIndex) {
    if (pageIndex < 0 || pageIndex >= pages.length) return;
    final page = pages[pageIndex];
    final isImagePage =
        page.newImageFilePath != null ||
        page.cachedImagePath != null ||
        page.originalPageIndex != null;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: allradius(2.r),
                  ),
                ),
                Gap(10.h),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 6.h),
                  child: Text(
                    "Page ${pageIndex + 1}",
                    style: GoogleFonts.outfit(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Gap(6.h),
                if (onAddBefore != null)
                  ListTile(
                    leading: Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.fork_left_rounded,
                        color: Colors.blueAccent,
                        size: 20.r,
                      ),
                    ),
                    title: Text(
                      "Add Page to Left",
                      style: GoogleFonts.instrumentSans(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      onAddBefore!(pageIndex);
                    },
                  ),
                if (onAddAfter != null)
                  ListTile(
                    leading: Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.fork_right_rounded,
                        color: Colors.green,
                        size: 20.r,
                      ),
                    ),
                    title: Text(
                      "Add Page to Right",
                      style: GoogleFonts.instrumentSans(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      onAddAfter!(pageIndex);
                    },
                  ),
                if (onEditImage != null && isImagePage)
                  ListTile(
                    leading: Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(
                        color: Colors.purpleAccent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.auto_fix_high_rounded,
                        color: Colors.purpleAccent,
                        size: 20.r,
                      ),
                    ),
                    title: Text(
                      "Edit in Image Editor",
                      style: GoogleFonts.instrumentSans(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      onEditImage!(pageIndex, page);
                    },
                  ),
                if (onDeletePage != null)
                  ListTile(
                    leading: Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.redAccent,
                        size: 20.r,
                      ),
                    ),
                    title: Text(
                      "Delete",
                      style: GoogleFonts.instrumentSans(
                        fontWeight: FontWeight.w600,
                        color: Colors.redAccent,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      onDeletePage!(pageIndex);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppReorderableGrid<PdfPageModel>(
      gridKey: gridKey,
      items: pages,
      scrollController: scrollController,
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: crossAxisSpacing,
      mainAxisSpacing: mainAxisSpacing,
      childAspectRatio: childAspectRatio,
      padding: padding,
      physics: physics,
      shrinkWrap: shrinkWrap,
      keyGetter: (page, index) => ValueKey<String>(page.id),
      onReorder: onReorder,
      itemBuilder: (context, page, index) {
        final isSelected = selectedPageIndex == index;
        return PdfPageGridCard(
          page: page,
          index: index,
          isSelected: isSelected,
          isDark: isDark,
          theme: theme,
          fallbackPdfFile: fallbackPdfFile,
          menuKey: index == 0 ? firstItemMenuKey : null,
          thumbnailScale: thumbnailScale,
          onTap: onPageSelected != null ? () => onPageSelected!(index) : null,
          onMenuTap: enableContextMenu
              ? () {
                  if (onCustomMenuTap != null) {
                    onCustomMenuTap!(index);
                  } else {
                    showPageContextMenu(context, index);
                  }
                }
              : null,
        );
      },
    );
  }
}

/// A premium visual card tile for a captured or standalone image in a reorderable grid.
class ImagePageGridCard extends StatelessWidget {
  final String imagePath;
  final int index;
  final bool isSelected;
  final bool isDark;
  final ThemeData theme;
  final Key? menuKey;
  final VoidCallback? onTap;
  final VoidCallback? onMenuTap;

  const ImagePageGridCard({
    super.key,
    required this.imagePath,
    required this.index,
    this.isSelected = false,
    required this.isDark,
    required this.theme,
    this.menuKey,
    this.onTap,
    this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    final file = File(imagePath);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: allradius(6.r),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : (isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.12)),
            width: isSelected ? 2.5 : 1.0,
          ),
        ),
        child: ClipRRect(
          borderRadius: allradius(6.r),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image Preview
              if (file.existsSync())
                Image.file(file, fit: BoxFit.cover)
              else
                Container(
                  color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                  child: Icon(
                    Icons.broken_image_rounded,
                    color: Colors.grey.shade500,
                    size: 28.r,
                  ),
                ),

              // Gradient overlays for text readability
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.3, 0.65, 1.0],
                      colors: [
                        Colors.black.withValues(alpha: 0.55),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.65),
                      ],
                    ),
                  ),
                ),
              ),

              // Page Number Badge (Top Left)
              Positioned(
                top: 6.r,
                left: 6.r,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : Colors.black.withValues(alpha: 0.75),
                    borderRadius: allradius(6.r),
                  ),
                  child: Text(
                    "${index + 1}",
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.sp,
                    ),
                  ),
                ),
              ),

              // Context Menu Button (Top Right)
              if (onMenuTap != null)
                Positioned(
                  top: 4.r,
                  right: 4.r,
                  child: GestureDetector(
                    key: menuKey,
                    onTap: onMenuTap,
                    child: Container(
                      padding: EdgeInsets.all(5.r),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.more_vert_rounded,
                        size: 16.r,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

              // Image Type Icon Indicator (Bottom Right)
              Positioned(
                bottom: 6.r,
                right: 6.r,
                child: Container(
                  padding: EdgeInsets.all(4.r),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: allradius(2.r),
                  ),
                  child: Icon(
                    Icons.image_rounded,
                    size: 14.r,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A specialized, batteries-included reorderable grid for images with built-in context actions.
class ImageReorderableGrid extends StatelessWidget {
  final List<String> imagePaths;
  final void Function(List<String> reorderedPaths) onReorder;
  final int? selectedIndex;
  final void Function(int index, String path)? onItemTap;
  final void Function(int index, String path)? onEditImage;
  final void Function(int index, String path)? onSaveImage;
  final void Function(int index, String path)? onShareImage;
  final void Function(int index, String path)? onDeleteImage;
  final void Function(int index, String path)? onCustomMenuTap;
  final Key? firstItemMenuKey;
  final ScrollController? scrollController;
  final int? crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double childAspectRatio;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics physics;
  final bool shrinkWrap;
  final Key? gridKey;
  final bool enableContextMenu;

  const ImageReorderableGrid({
    super.key,
    required this.imagePaths,
    required this.onReorder,
    this.selectedIndex,
    this.onItemTap,
    this.onEditImage,
    this.onSaveImage,
    this.onShareImage,
    this.onDeleteImage,
    this.onCustomMenuTap,
    this.firstItemMenuKey,
    this.scrollController,
    this.crossAxisCount,
    this.crossAxisSpacing = 10.0,
    this.mainAxisSpacing = 10.0,
    this.childAspectRatio = 0.72,
    this.padding,
    this.physics = const BouncingScrollPhysics(),
    this.shrinkWrap = false,
    this.gridKey,
    this.enableContextMenu = true,
  });

  /// Displays the standard modal bottom sheet context menu for an image tile
  void showImageContextMenu(BuildContext context, int index, String path) {
    if (index < 0 || index >= imagePaths.length) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: allradius(2.r),
                  ),
                ),
                Gap(10.h),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 6.h),
                  child: Text(
                    "Photo ${index + 1}",
                    style: GoogleFonts.outfit(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Gap(6.h),
                if (onEditImage != null)
                  ListTile(
                    leading: Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(
                        color: royalblue.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.edit_rounded,
                        color: royalblue,
                        size: 20.r,
                      ),
                    ),
                    title: Text(
                      "Edit Photo",
                      style: GoogleFonts.instrumentSans(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      onEditImage!(index, path);
                    },
                  ),
                if (onSaveImage != null)
                  ListTile(
                    leading: Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(
                        color: Colors.tealAccent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.save_alt_rounded,
                        color: Colors.tealAccent,
                        size: 20.r,
                      ),
                    ),
                    title: Text(
                      "Save to Storage",
                      style: GoogleFonts.instrumentSans(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      onSaveImage!(index, path);
                    },
                  ),
                if (onShareImage != null)
                  ListTile(
                    leading: Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(
                        color: Colors.amberAccent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.share_rounded,
                        color: Colors.amberAccent,
                        size: 20.r,
                      ),
                    ),
                    title: Text(
                      "Share",
                      style: GoogleFonts.instrumentSans(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      onShareImage!(index, path);
                    },
                  ),
                if (onDeleteImage != null)
                  ListTile(
                    leading: Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.redAccent,
                        size: 20.r,
                      ),
                    ),
                    title: Text(
                      "Delete",
                      style: GoogleFonts.instrumentSans(
                        fontWeight: FontWeight.w600,
                        color: Colors.redAccent,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      onDeleteImage!(index, path);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppReorderableGrid<String>(
      gridKey: gridKey,
      items: imagePaths,
      scrollController: scrollController,
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: crossAxisSpacing,
      mainAxisSpacing: mainAxisSpacing,
      childAspectRatio: childAspectRatio,
      padding: padding,
      physics: physics,
      shrinkWrap: shrinkWrap,
      keyGetter: (path, index) => ValueKey<String>('${path}_$index'),
      onReorder: onReorder,
      itemBuilder: (context, path, index) {
        final isSelected = selectedIndex == index;
        return ImagePageGridCard(
          imagePath: path,
          index: index,
          isSelected: isSelected,
          isDark: isDark,
          theme: theme,
          menuKey: index == 0 ? firstItemMenuKey : null,
          onTap: onItemTap != null ? () => onItemTap!(index, path) : null,
          onMenuTap: enableContextMenu
              ? () {
                  if (onCustomMenuTap != null) {
                    onCustomMenuTap!(index, path);
                  } else {
                    showImageContextMenu(context, index, path);
                  }
                }
              : null,
        );
      },
    );
  }
}
