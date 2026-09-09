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
import 'package:path_provider/path_provider.dart';
import 'package:pdfhawk/data/res/constants.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:pdfhawk/data/res/theme.dart';
import 'package:pdfhawk/interface/pages/pdf_reader_page.dart';
import 'package:pdfhawk/interface/pages/images_editor_page.dart';
import 'package:pdfhawk/interface/widgets/bubble_button.dart';
import 'package:pdfhawk/interface/widgets/reorderable_grid.dart';
import 'package:pdfhawk/logic/helpers/document_converter.dart';
import 'package:pdfhawk/logic/services/storage_service.dart';

class CreateFromImagesPage extends StatefulWidget {
  final List<String>? initialImagePaths;

  const CreateFromImagesPage({super.key, this.initialImagePaths});

  @override
  State<CreateFromImagesPage> createState() => _CreateFromImagesPageState();
}

class _CreateFromImagesPageState extends State<CreateFromImagesPage> {
  // Ordered images list for creating the PDF
  final List<String> _orderedImagePaths = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialImagePaths != null &&
        widget.initialImagePaths!.isNotEmpty) {
      _orderedImagePaths.addAll(widget.initialImagePaths!);
    }
  }

  // --- OPEN IMAGE PICKER BOTTOM SHEET ---

  Future<void> _openImagePickerBottomSheet() async {
    final List<String>? selectedPaths =
        await showModalBottomSheet<List<String>>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const _GalleryPickerBottomSheet(),
        );

    if (selectedPaths != null && selectedPaths.isNotEmpty && mounted) {
      setState(() {
        _orderedImagePaths.addAll(selectedPaths);
      });
      Fluttertoast.showToast(
        msg: "Added ${selectedPaths.length} image(s) to order!",
      );
    }
  }

  // --- ACTIONS FOR ORDERED IMAGES ---

  void _openEditorForImage(int index) {
    if (_orderedImagePaths.isEmpty || index >= _orderedImagePaths.length) {
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImagesEditorPage(
          imagePath: _orderedImagePaths[index],
          onSave: (updatedPath) {
            setState(() {
              _orderedImagePaths[index] = updatedPath;
            });
          },
        ),
      ),
    );
  }

  Future<void> _saveImageToStorage(String path) async {
    try {
      final file = File(path);
      if (!file.existsSync()) return;
      final bytes = await file.readAsBytes();
      final fileName = "Image_${DateTime.now().millisecondsSinceEpoch}.jpg";
      await StorageService.saveExportedFile(
        fileName: fileName,
        bytes: bytes,
        subFolder: "Scans",
      );
      Fluttertoast.showToast(msg: "Saved to PDFHawk/Scans/$fileName");
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to save image: $e");
    }
  }

  void _shareImage(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        SharePlus.instance.share(
          ShareParams(files: [XFile(path)], text: "PDF Hawk Image"),
        );
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to share image: $e");
    }
  }

  void _deleteOrderedImage(int index) {
    if (index >= 0 && index < _orderedImagePaths.length) {
      setState(() {
        _orderedImagePaths.removeAt(index);
      });
      Fluttertoast.showToast(msg: "Image removed from order");
    }
  }

  void _clearAllOrderedImages() {
    if (_orderedImagePaths.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E24) : white,
          shape: RoundedRectangleBorder(borderRadius: allradius(16.r)),
          title: Text(
            "Clear All Images?",
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          content: Text(
            "This will remove all ${_orderedImagePaths.length} pages from the order list.",
            style: GoogleFonts.instrumentSans(
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Cancel",
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: white,
                shape: RoundedRectangleBorder(borderRadius: allradius(10.r)),
              ),
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _orderedImagePaths.clear();
                });
                Fluttertoast.showToast(msg: "Cleared all images");
              },
              child: const Text("Clear All"),
            ),
          ],
        );
      },
    );
  }

  // --- EXPORT TO PDF ---

  Future<void> _exportToPdf() async {
    if (_orderedImagePaths.isEmpty) {
      Fluttertoast.showToast(msg: "No images to export.");
      return;
    }

    final nameController = TextEditingController(
      text: "Document_${DateTime.now().millisecondsSinceEpoch}",
    );

    final bool? shouldExport = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E24) : white,
          shape: RoundedRectangleBorder(borderRadius: allradius(20.r)),
          title: Text(
            "Export to PDF",
            style: GoogleFonts.outfit(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Enter document filename (${_orderedImagePaths.length} pages):",
                style: GoogleFonts.instrumentSans(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 13.sp,
                ),
              ),
              Gap(12.h),
              TextField(
                controller: nameController,
                autofocus: true,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  suffixText: ".pdf",
                  suffixStyle: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: allradius(12.r),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                "Cancel",
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: royalblue,
                foregroundColor: white,
                shape: RoundedRectangleBorder(borderRadius: allradius(12.r)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Export"),
            ),
          ],
        );
      },
    );

    if (shouldExport != true) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E1E24) : white,
            shape: RoundedRectangleBorder(borderRadius: allradius(16.r)),
            content: Row(
              children: [
                const CircularProgressIndicator(color: royalblue),
                Gap(20.w),
                Expanded(
                  child: Text(
                    "Compiling PDF document...",
                    style: GoogleFonts.outfit(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      final imageFiles = _orderedImagePaths.map((p) => File(p)).toList();
      final outputFile = await DocumentConverter.convertImagesToPdf(imageFiles);

      String filename = nameController.text.trim();
      if (!filename.toLowerCase().endsWith(".pdf")) {
        filename = "$filename.pdf";
      }

      final bytes = await outputFile.readAsBytes();
      final savedPdf = await StorageService.saveExportedFile(
        fileName: filename,
        bytes: bytes,
      );

      if (mounted) {
        Navigator.pop(context); // Close progress dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("PDF saved: ${savedPdf.path.split('/').last}"),
            backgroundColor: royalblue,
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PDFReaderPage(pdfFile: savedPdf),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        Fluttertoast.showToast(msg: "Failed to export PDF: $e");
      }
    }
  }

  // --- BUILD UI ---

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
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Navigation & Action Row
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  BubbleButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  Row(
                    children: [
                      if (_orderedImagePaths.isNotEmpty)
                        BubbleButton(
                          icon: Icons.delete_sweep_rounded,
                          onTap: _clearAllOrderedImages,
                        ),
                      BubbleButton(
                        icon: Icons.add_photo_alternate_rounded,
                        onTap: _openImagePickerBottomSheet,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Gap(12.h),

            // Header Title Section
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Create PDF",
                    style: GoogleFonts.outfit(
                      height: 1,
                      fontSize: 34.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Gap(5.h),
                  Text(
                    _orderedImagePaths.isEmpty
                        ? "0 pages • Tap below to add images"
                        : "${_orderedImagePaths.length} page(s) ready • Drag to reorder",
                    style: GoogleFonts.instrumentSans(
                      height: 1.1,
                      fontSize: 14.5.sp,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Gap(14.h),

            // Content: Empty State or Reorder View
            Expanded(
              child: _orderedImagePaths.isEmpty
                  ? _buildEmptyState(isDark)
                  : _buildReorderView(isDark, theme),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // EMPTY STATE: NO IMAGES SELECTED
  // ==========================================

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.r),
        child: InkWell(
          onTap: _openImagePickerBottomSheet,
          borderRadius: allradius(24.r),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 36.h),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.white,
              borderRadius: allradius(24.r),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon with subtle glow
                Container(
                  width: 80.r,
                  height: 80.r,
                  decoration: BoxDecoration(
                    color: royalblue.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: royalblue.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 40.r,
                    color: royalblue,
                  ),
                ),
                Gap(18.h),
                Text(
                  "No Images Selected",
                  style: GoogleFonts.outfit(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Gap(8.h),
                Text(
                  "Tap here to choose images from your device gallery and folders to create a PDF.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.instrumentSans(
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                    fontSize: 13.5.sp,
                    height: 1.4,
                  ),
                ),
                Gap(24.h),
                ElevatedButton.icon(
                  icon: const Icon(Icons.photo_library_rounded, size: 18),
                  label: Text(
                    "Select Images",
                    style: GoogleFonts.outfit(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: royalblue,
                    foregroundColor: white,
                    elevation: 2,
                    padding: EdgeInsets.symmetric(
                      horizontal: 24.w,
                      vertical: 12.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: allradius(14.r),
                    ),
                  ),
                  onPressed: _openImagePickerBottomSheet,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // REORDER VIEW: GRID & EXPORT BUTTON
  // ==========================================

  Widget _buildReorderView(bool isDark, ThemeData theme) {
    return Column(
      children: [
        // Helper hint banner
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: allradius(10.r),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black12,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.touch_app_outlined, size: 16.sp, color: royalblue),
                Gap(8.w),
                Expanded(
                  child: Text(
                    "Drag to rearrange • Tap an image for Edit & Delete options",
                    style: GoogleFonts.instrumentSans(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontSize: 11.5.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Reorderable Grid
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            child: ImageReorderableGrid(
              imagePaths: _orderedImagePaths,
              crossAxisCount: 3,
              crossAxisSpacing: 10.w,
              mainAxisSpacing: 10.h,
              childAspectRatio: 0.72,
              padding: EdgeInsets.zero,
              onReorder: (updated) {
                setState(() {
                  _orderedImagePaths.clear();
                  _orderedImagePaths.addAll(updated);
                });
              },
              onItemTap: (index, path) => _openEditorForImage(index),
              onEditImage: (index, path) => _openEditorForImage(index),
              onSaveImage: (index, path) => _saveImageToStorage(path),
              onShareImage: (index, path) => _shareImage(path),
              onDeleteImage: (index, path) => _deleteOrderedImage(index),
            ),
          ),
        ),

        // Bottom Export Bar
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141418) : white,
            border: Border(
              top: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
            ),
          ),
          child: SafeArea(
            top: false,
            child: InkWell(
              onTap: _exportToPdf,
              borderRadius: allradius(14.r),
              child: Container(
                width: double.infinity,
                height: 48.h,
                decoration: BoxDecoration(
                  color: royalblue,
                  borderRadius: allradius(6.r),
                  boxShadow: [
                    BoxShadow(
                      color: royalblue.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Export to PDF (${_orderedImagePaths.length} Pages)",
                        style: GoogleFonts.outfit(
                          color: white,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// GALLERY PICKER BOTTOM SHEET (MULTI-SELECTION WITH ALBUMS & FOLDERS)
// ============================================================================

class _GalleryPickerBottomSheet extends StatefulWidget {
  const _GalleryPickerBottomSheet();

  @override
  State<_GalleryPickerBottomSheet> createState() =>
      _GalleryPickerBottomSheetState();
}

class _GalleryPickerBottomSheetState extends State<_GalleryPickerBottomSheet> {
  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _currentAlbum;
  List<AssetEntity> _albumAssets = [];
  final Set<AssetEntity> _selectedAssets = {};
  bool _isLoadingGallery = true;
  bool _hasGalleryPermission = true;
  int _currentGalleryPage = 0;
  bool _hasMoreGalleryAssets = true;
  bool _isLoadingMoreAssets = false;
  bool _isProcessingSelection = false;
  static const int _galleryPageSize = 80;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initGalleryAlbums();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        !_isLoadingGallery &&
        !_isLoadingMoreAssets &&
        _hasMoreGalleryAssets) {
      _loadAssetsForCurrentAlbum(page: _currentGalleryPage + 1);
    }
  }

  Future<void> _initGalleryAlbums() async {
    setState(() => _isLoadingGallery = true);
    try {
      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      if (!ps.isAuth && !ps.hasAccess) {
        if (mounted) {
          setState(() {
            _hasGalleryPermission = false;
            _isLoadingGallery = false;
          });
        }
        return;
      }

      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        hasAll: true,
        filterOption: FilterOptionGroup(
          imageOption: const FilterOption(
            needTitle: true,
            sizeConstraint: SizeConstraint(ignoreSize: true),
          ),
          orders: [
            const OrderOption(type: OrderOptionType.createDate, asc: false),
          ],
        ),
      );

      if (mounted) {
        setState(() {
          _hasGalleryPermission = true;
          _albums = albums;
          _currentAlbum = albums.isNotEmpty ? albums.first : null;
        });
      }

      if (_currentAlbum != null) {
        await _loadAssetsForCurrentAlbum(page: 0);
      }
    } catch (e) {
      debugPrint("Error initializing PhotoManager gallery: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingGallery = false);
      }
    }
  }

  Future<void> _loadAssetsForCurrentAlbum({int page = 0}) async {
    if (_currentAlbum == null) return;
    if (page == 0) {
      setState(() {
        _isLoadingGallery = true;
        _currentGalleryPage = 0;
        _albumAssets.clear();
        _hasMoreGalleryAssets = true;
      });
    } else {
      if (!_hasMoreGalleryAssets || _isLoadingMoreAssets) return;
      setState(() => _isLoadingMoreAssets = true);
    }

    try {
      final assets = await _currentAlbum!.getAssetListPaged(
        page: page,
        size: _galleryPageSize,
      );

      if (mounted) {
        setState(() {
          if (page == 0) {
            _albumAssets = assets;
          } else {
            _albumAssets.addAll(assets);
          }
          _currentGalleryPage = page;
          _hasMoreGalleryAssets = assets.length == _galleryPageSize;
        });
      }
    } catch (e) {
      debugPrint("Error loading assets for album: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingGallery = false;
          _isLoadingMoreAssets = false;
        });
      }
    }
  }

  void _onAlbumSelected(AssetPathEntity album) {
    if (_currentAlbum?.id == album.id) return;
    setState(() {
      _currentAlbum = album;
      _selectedAssets.clear();
    });
    _loadAssetsForCurrentAlbum(page: 0);
  }

  void _showAlbumSelectionSheet() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E24) : white,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.35,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 14.h,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Device Albums",
                        style: GoogleFonts.outfit(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Divider(
                  color: isDark ? Colors.white12 : Colors.black12,
                  height: 1,
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _albums.length,
                    itemBuilder: (context, index) {
                      final album = _albums[index];
                      final isSelected = _currentAlbum?.id == album.id;

                      return FutureBuilder<int>(
                        future: album.assetCountAsync,
                        builder: (context, snapshot) {
                          final count = snapshot.data ?? 0;
                          return ListTile(
                            leading: FutureBuilder<List<AssetEntity>>(
                              future: album.getAssetListRange(start: 0, end: 1),
                              builder: (context, thumbSnap) {
                                if (thumbSnap.hasData &&
                                    thumbSnap.data!.isNotEmpty) {
                                  return ClipRRect(
                                    borderRadius: allradius(8.r),
                                    child: SizedBox(
                                      width: 48.r,
                                      height: 48.r,
                                      child: AssetEntityImage(
                                        thumbSnap.data!.first,
                                        isOriginal: false,
                                        thumbnailSize:
                                            const ThumbnailSize.square(150),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  );
                                }
                                return Container(
                                  width: 48.r,
                                  height: 48.r,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white10
                                        : Colors.black.withValues(alpha: 0.05),
                                    borderRadius: allradius(8.r),
                                  ),
                                  child: Icon(
                                    Icons.photo_album_rounded,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.black38,
                                  ),
                                );
                              },
                            ),
                            title: Text(
                              album.name.isEmpty ? "Recent" : album.name,
                              style: GoogleFonts.outfit(
                                color: isSelected
                                    ? royalblue
                                    : (isDark ? Colors.white : Colors.black87),
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                fontSize: 15.sp,
                              ),
                            ),
                            subtitle: Text(
                              "$count photos",
                              style: GoogleFonts.instrumentSans(
                                color: isDark
                                    ? Colors.white54
                                    : Colors.grey.shade600,
                                fontSize: 12.sp,
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    color: royalblue,
                                  )
                                : null,
                            onTap: () {
                              Navigator.pop(context);
                              _onAlbumSelected(album);
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _pickImagesFromCustomPicker() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );
      if (result != null && result.paths.isNotEmpty) {
        final appDir = await getApplicationDocumentsDirectory();
        final scansDir = Directory("${appDir.path}/scans");
        if (!scansDir.existsSync()) {
          scansDir.createSync(recursive: true);
        }

        final List<String> addedPaths = [];
        for (int i = 0; i < result.paths.length; i++) {
          final path = result.paths[i];
          if (path != null) {
            final srcFile = File(path);
            if (srcFile.existsSync()) {
              final targetPath =
                  "${scansDir.path}/img_${DateTime.now().millisecondsSinceEpoch}_$i.jpg";
              final saved = await srcFile.copy(targetPath);
              addedPaths.add(saved.path);
            }
          }
        }
        if (mounted && addedPaths.isNotEmpty) {
          Navigator.pop(context, addedPaths);
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to pick images from folders: $e");
    }
  }

  Future<void> _confirmSelectionAndClose() async {
    if (_selectedAssets.isEmpty) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isProcessingSelection = true);

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final scansDir = Directory("${appDir.path}/scans");
      if (!scansDir.existsSync()) {
        scansDir.createSync(recursive: true);
      }

      final selectedList = _selectedAssets.toList();
      final List<String> savedPaths = [];

      for (int i = 0; i < selectedList.length; i++) {
        final asset = selectedList[i];
        final File? file = await asset.file ?? await asset.originFile;
        if (file != null && file.existsSync()) {
          final targetPath =
              "${scansDir.path}/img_${DateTime.now().millisecondsSinceEpoch}_$i.jpg";
          final savedFile = await file.copy(targetPath);
          savedPaths.add(savedFile.path);
        }
      }

      if (mounted) {
        setState(() => _isProcessingSelection = false);
        Navigator.pop(context, savedPaths);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingSelection = false);
      }
      Fluttertoast.showToast(msg: "Error importing images: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final albumTitle = _currentAlbum?.name.isEmpty ?? true
        ? "Recent"
        : _currentAlbum!.name;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141418) : white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle
          Gap(10.h),
          Center(
            child: Container(
              width: 42.w,
              height: 4.5.h,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: allradius(3.r),
              ),
            ),
          ),
          Gap(8.h),

          // Header Toolbar: Album Selector, Folder Picker, Select All, Close
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
            child: Row(
              children: [
                // Album Selector Pill
                InkWell(
                  onTap: _showAlbumSelectionSheet,
                  borderRadius: allradius(12.r),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: allradius(12.r),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.photo_album_rounded,
                          color: royalblue,
                          size: 16.sp,
                        ),
                        Gap(6.w),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: 110.w),
                          child: Text(
                            albumTitle,
                            style: GoogleFonts.outfit(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Gap(2.w),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: isDark ? Colors.white70 : Colors.black54,
                          size: 18.sp,
                        ),
                      ],
                    ),
                  ),
                ),
                Gap(8.w),

                // Folder Picker Button (Device Storage / Files)
                InkWell(
                  onTap: _pickImagesFromCustomPicker,
                  borderRadius: allradius(12.r),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: allradius(12.r),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.folder_open_rounded,
                          color: royalblue,
                          size: 16.sp,
                        ),
                        Gap(4.w),
                        Text(
                          "Folders",
                          style: GoogleFonts.outfit(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),

                // Select All / Deselect All
                if (_albumAssets.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (_selectedAssets.length == _albumAssets.length) {
                          _selectedAssets.clear();
                        } else {
                          _selectedAssets.addAll(_albumAssets);
                        }
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 8.w),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      _selectedAssets.length == _albumAssets.length
                          ? "Deselect"
                          : "Select All",
                      style: GoogleFonts.outfit(
                        color: royalblue,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                Gap(6.w),

                // Close Button
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDark ? Colors.white70 : Colors.black54,
                    size: 20.sp,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Divider(color: isDark ? Colors.white12 : Colors.black12, height: 1),

          // Body: Photo Grid or Permission Prompt
          Expanded(
            child: !_hasGalleryPermission && !_isLoadingGallery
                ? _buildPermissionPrompt(isDark)
                : _isLoadingGallery && _albumAssets.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                      color: royalblue,
                      strokeWidth: 2.5,
                    ),
                  )
                : _albumAssets.isEmpty
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.r),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.photo_library_outlined,
                            size: 48.r,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                          Gap(12.h),
                          Text(
                            "No photos in this album",
                            style: GoogleFonts.outfit(
                              color: isDark ? Colors.white70 : Colors.black87,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : GridView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 8.h,
                    ),
                    itemCount:
                        _albumAssets.length + (_isLoadingMoreAssets ? 1 : 0),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8.w,
                      mainAxisSpacing: 8.h,
                      childAspectRatio: 1.0,
                    ),
                    itemBuilder: (context, index) {
                      if (index >= _albumAssets.length) {
                        return const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: royalblue,
                            ),
                          ),
                        );
                      }

                      final asset = _albumAssets[index];
                      final isSelected = _selectedAssets.contains(asset);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedAssets.remove(asset);
                            } else {
                              _selectedAssets.add(asset);
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            borderRadius: allradius(10.r),
                            border: Border.all(
                              color: isSelected ? royalblue : transparent,
                              width: isSelected ? 3 : 0,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: allradius(isSelected ? 7.r : 10.r),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                AssetEntityImage(
                                  asset,
                                  isOriginal: false,
                                  thumbnailSize: const ThumbnailSize.square(
                                    260,
                                  ),
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return Container(
                                      color: isDark
                                          ? Colors.white10
                                          : Colors.black12,
                                      child: const Center(
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 1.5,
                                            color: royalblue,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                if (isSelected)
                                  Container(
                                    color: royalblue.withValues(alpha: 0.35),
                                  ),
                                Positioned(
                                  top: 6.r,
                                  right: 6.r,
                                  child: Container(
                                    width: 22.r,
                                    height: 22.r,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? royalblue
                                          : Colors.black45,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: white,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: isSelected
                                        ? Icon(
                                            Icons.check_rounded,
                                            color: white,
                                            size: 14.sp,
                                          )
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Bottom Confirmation Bar
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141418) : white,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 48.h,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: royalblue,
                    foregroundColor: white,
                    shape: RoundedRectangleBorder(
                      borderRadius: allradius(14.r),
                    ),
                    elevation: 2,
                  ),
                  onPressed: _isProcessingSelection
                      ? null
                      : _selectedAssets.isNotEmpty
                      ? _confirmSelectionAndClose
                      : null,
                  child: _isProcessingSelection
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: white,
                              ),
                            ),
                            Gap(10.w),
                            Text(
                              "Adding Images...",
                              style: GoogleFonts.outfit(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _selectedAssets.isNotEmpty
                                  ? "Add ${_selectedAssets.length} Image${_selectedAssets.length == 1 ? '' : 's'}"
                                  : "Select Images",
                              style: GoogleFonts.outfit(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_selectedAssets.isNotEmpty) ...[
                              Gap(6.w),
                              const Icon(Icons.check_rounded, size: 18),
                            ],
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionPrompt(bool isDark) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.no_photography_outlined,
              size: 52.r,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
            Gap(12.h),
            Text(
              "Photo Access Required",
              style: GoogleFonts.outfit(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 17.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            Gap(6.h),
            Text(
              "PDF Hawk needs permission to access your device photos to select images to create a PDF.",
              textAlign: TextAlign.center,
              style: GoogleFonts.instrumentSans(
                color: isDark ? Colors.white54 : Colors.grey.shade600,
                fontSize: 13.sp,
              ),
            ),
            Gap(16.h),
            ElevatedButton.icon(
              icon: const Icon(Icons.settings_rounded, size: 16),
              label: const Text("Open App Settings"),
              style: ElevatedButton.styleFrom(
                backgroundColor: royalblue,
                foregroundColor: white,
                shape: RoundedRectangleBorder(borderRadius: allradius(10.r)),
              ),
              onPressed: () => PhotoManager.openSetting(),
            ),
            Gap(8.h),
            TextButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text("Retry Access"),
              style: TextButton.styleFrom(foregroundColor: royalblue),
              onPressed: _initGalleryAlbums,
            ),
          ],
        ),
      ),
    );
  }
}
