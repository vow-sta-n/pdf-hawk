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
  const CreateFromImagesPage({super.key});

  @override
  State<CreateFromImagesPage> createState() => _CreateFromImagesPageState();
}

class _CreateFromImagesPageState extends State<CreateFromImagesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Gallery & Albums State
  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _currentAlbum;
  List<AssetEntity> _albumAssets = [];
  final Set<AssetEntity> _selectedAssets = {};
  bool _isLoadingGallery = false;
  bool _hasGalleryPermission = true;
  int _currentGalleryPage = 0;
  bool _hasMoreGalleryAssets = true;
  bool _isLoadingMoreAssets = false;
  static const int _galleryPageSize = 80;
  final ScrollController _galleryScrollController = ScrollController();

  // Order & Export State
  final List<String> _orderedImagePaths = [];
  bool _isProcessingSelection = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _galleryScrollController.addListener(_onGalleryScroll);
    _initGalleryAlbums();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _galleryScrollController.removeListener(_onGalleryScroll);
    _galleryScrollController.dispose();
    super.dispose();
  }

  void _onGalleryScroll() {
    if (_galleryScrollController.position.pixels >=
            _galleryScrollController.position.maxScrollExtent - 300 &&
        !_isLoadingGallery &&
        !_isLoadingMoreAssets &&
        _hasMoreGalleryAssets) {
      _loadAssetsForCurrentAlbum(page: _currentGalleryPage + 1);
    }
  }

  // --- GALLERY PERMISSIONS & ALBUMS ---

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

  // --- IMPORT FILES FALLBACK ---

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

        int added = 0;
        for (final path in result.paths) {
          if (path != null) {
            final srcFile = File(path);
            if (srcFile.existsSync()) {
              final targetPath =
                  "${scansDir.path}/img_${DateTime.now().millisecondsSinceEpoch}_${_orderedImagePaths.length + added}.jpg";
              final saved = await srcFile.copy(targetPath);
              if (!_orderedImagePaths.contains(saved.path)) {
                _orderedImagePaths.add(saved.path);
                added++;
              }
            }
          }
        }
        if (mounted) {
          setState(() {
            _tabController.animateTo(1);
          });
          Fluttertoast.showToast(
            msg: "Imported $added image(s) to order list!",
          );
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to pick images: $e");
    }
  }

  // --- PROCEED FROM GALLERY TO ORDER ---

  Future<void> _proceedToOrderTab() async {
    if (_selectedAssets.isEmpty) {
      if (_orderedImagePaths.isNotEmpty) {
        _tabController.animateTo(1);
      }
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
      int addedCount = 0;

      for (int i = 0; i < selectedList.length; i++) {
        final asset = selectedList[i];
        final File? file = await asset.file ?? await asset.originFile;
        if (file != null && file.existsSync()) {
          final targetPath =
              "${scansDir.path}/img_${DateTime.now().millisecondsSinceEpoch}_${_orderedImagePaths.length + i}.jpg";
          final savedFile = await file.copy(targetPath);
          if (!_orderedImagePaths.contains(savedFile.path)) {
            _orderedImagePaths.add(savedFile.path);
            addedCount++;
          }
        }
      }

      if (mounted) {
        setState(() {
          _selectedAssets.clear();
          _isProcessingSelection = false;
          _tabController.animateTo(1);
        });
        Fluttertoast.showToast(msg: "Added $addedCount image(s) to order!");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingSelection = false);
      }
      Fluttertoast.showToast(msg: "Error adding images: $e");
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
            // Top Navigation & Action Row (Modeled after AllFoldersPage)
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
                      if (_tabController.index == 0) ...[
                        BubbleButton(
                          icon: Icons.photo_album_rounded,
                          onTap: _showAlbumSelectionSheet,
                        ),
                        BubbleButton(
                          icon: Icons.folder_open_rounded,
                          onTap: _pickImagesFromCustomPicker,
                        ),
                      ] else ...[
                        if (_orderedImagePaths.isNotEmpty)
                          BubbleButton(
                            icon: Icons.delete_sweep_rounded,
                            onTap: _clearAllOrderedImages,
                          ),
                        BubbleButton(
                          icon: Icons.add_photo_alternate_rounded,
                          onTap: () => _tabController.animateTo(0),
                        ),
                      ],
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
                    _tabController.index == 0
                        ? (_selectedAssets.isNotEmpty
                              ? "${_selectedAssets.length} image(s) selected • ${_currentAlbum?.name.isEmpty ?? true ? 'Recent' : _currentAlbum!.name}"
                              : "${_albumAssets.length} photos in ${_currentAlbum?.name.isEmpty ?? true ? 'Recent' : _currentAlbum!.name}")
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

            // Segmented Tab Bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 15),
              child: Container(
                padding: EdgeInsets.all(4.r),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: allradius(16.r),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: transparent,
                  dividerColor: transparent,
                  labelColor: white,
                  unselectedLabelColor: isDark
                      ? Colors.white60
                      : Colors.black54,
                  indicator: BoxDecoration(
                    color: royalblue,
                    borderRadius: allradius(12.r),
                    boxShadow: [
                      BoxShadow(
                        color: royalblue.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  labelStyle: GoogleFonts.outfit(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelStyle: GoogleFonts.outfit(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _selectedAssets.isNotEmpty
                                ? "Gallery (${_selectedAssets.length})"
                                : "Gallery",
                          ),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Order (${_orderedImagePaths.length})"),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Gap(10.h),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildGalleryTab(isDark), _buildOrderTab(isDark)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: GALLERY TAB
  // ==========================================

  Widget _buildGalleryTab(bool isDark) {
    if (!_hasGalleryPermission && !_isLoadingGallery) {
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

    final albumTitle = _currentAlbum?.name.isEmpty ?? true
        ? "Recent"
        : _currentAlbum!.name;

    return Column(
      children: [
        // Gallery Toolbar: Album Dropdown + Select All + Fallback
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
          child: Row(
            children: [
              // Album Pill
              InkWell(
                onTap: _showAlbumSelectionSheet,
                borderRadius: allradius(12.r),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 7.h,
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
                        size: 15.sp,
                      ),
                      Gap(6.w),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 130.w),
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
                      Gap(4.w),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: isDark ? Colors.white70 : Colors.black54,
                        size: 18.sp,
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),

              // Quick Toggle: Select All / Deselect All
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
                  child: Text(
                    _selectedAssets.length == _albumAssets.length
                        ? "Deselect All"
                        : "Select All",
                    style: GoogleFonts.outfit(
                      color: royalblue,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Photo Grid View
        Expanded(
          child: _isLoadingGallery && _albumAssets.isEmpty
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
                  controller: _galleryScrollController,
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
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
                                thumbnailSize: const ThumbnailSize.square(260),
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

        // Bottom Proceed Button
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
            child: SizedBox(
              width: double.infinity,
              height: 48.h,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: royalblue,
                  foregroundColor: white,
                  shape: RoundedRectangleBorder(borderRadius: allradius(14.r)),
                  elevation: 2,
                ),
                onPressed:
                    (_selectedAssets.isNotEmpty ||
                        _orderedImagePaths.isNotEmpty)
                    ? _proceedToOrderTab
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
                                ? "Proceed with ${_selectedAssets.length} Image${_selectedAssets.length == 1 ? '' : 's'}"
                                : "Go to Order (${_orderedImagePaths.length} Pages)",
                            style: GoogleFonts.outfit(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Gap(6.w),
                          const Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 2: ORDER TAB (REORDERABLE GRID & POPUP OPTIONS)
  // ==========================================

  Widget _buildOrderTab(bool isDark) {
    if (_orderedImagePaths.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.collections_bookmark_outlined,
                size: 56.r,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
              Gap(14.h),
              Text(
                "No images added to order",
                style: GoogleFonts.outfit(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 17.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Gap(6.h),
              Text(
                "Select images from the Gallery tab or import files to arrange them in order.",
                textAlign: TextAlign.center,
                style: GoogleFonts.instrumentSans(
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                  fontSize: 13.sp,
                ),
              ),
              Gap(18.h),
              ElevatedButton.icon(
                icon: const Icon(Icons.photo_library_rounded, size: 16),
                label: const Text("Select from Gallery"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: royalblue,
                  foregroundColor: white,
                  shape: RoundedRectangleBorder(borderRadius: allradius(12.r)),
                ),
                onPressed: () => _tabController.animateTo(0),
              ),
            ],
          ),
        ),
      );
    }

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
            child: AppReorderableGrid<String>(
              items: _orderedImagePaths,
              crossAxisCount: 3,
              crossAxisSpacing: 10.w,
              mainAxisSpacing: 10.h,
              childAspectRatio: 0.72,
              padding: EdgeInsets.zero,
              keyGetter: (path, index) => ValueKey<String>(path),
              onReorder: (updated) {
                setState(() {
                  _orderedImagePaths.clear();
                  _orderedImagePaths.addAll(updated);
                });
              },
              itemBuilder: (context, path, index) {
                return _buildOrderedImageCard(path, index, isDark);
              },
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
                  borderRadius: allradius(14.r),
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
                      const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: white,
                        size: 20,
                      ),
                      Gap(8.w),
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

  // Ordered Image Thumbnail Card with Popup Options
  Widget _buildOrderedImageCard(String path, int index, bool isDark) {
    return PopupMenuButton<String>(
      tooltip: 'Options',
      color: isDark ? const Color(0xFF24242A) : white,
      shape: RoundedRectangleBorder(borderRadius: allradius(14.r)),
      onSelected: (value) {
        switch (value) {
          case 'edit':
            _openEditorForImage(index);
            break;
          case 'save':
            _saveImageToStorage(path);
            break;
          case 'share':
            _shareImage(path);
            break;
          case 'delete':
            _deleteOrderedImage(index);
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              const Icon(Icons.edit_rounded, color: royalblue, size: 18),
              Gap(10.w),
              Text(
                "Edit Photo",
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'save',
          child: Row(
            children: [
              const Icon(
                Icons.save_alt_rounded,
                color: Colors.tealAccent,
                size: 18,
              ),
              Gap(10.w),
              Text(
                "Save to Storage",
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'share',
          child: Row(
            children: [
              const Icon(
                Icons.share_rounded,
                color: Colors.amberAccent,
                size: 18,
              ),
              Gap(10.w),
              Text(
                "Share",
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
                size: 18,
              ),
              SizedBox(width: 10),
              Text("Delete", style: TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
      ],
      child: Container(
        decoration: BoxDecoration(
          borderRadius: allradius(10.r),
          border: Border.all(
            color: isDark ? Colors.white24 : Colors.black12,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: allradius(9.r),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: isDark ? Colors.white10 : Colors.black12,
                  child: const Center(
                    child: Icon(Icons.broken_image_rounded, color: Colors.grey),
                  ),
                ),
              ),

              // Page index badge on bottom-left
              Positioned(
                bottom: 6.r,
                left: 6.r,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: allradius(8.r),
                    border: Border.all(
                      color: royalblue.withValues(alpha: 0.8),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    "Page ${index + 1}",
                    style: TextStyle(
                      color: white,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // Tap options icon on top-right
              Positioned(
                top: 5.r,
                right: 5.r,
                child: Container(
                  padding: EdgeInsets.all(3.r),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: allradius(6.r),
                  ),
                  child: const Icon(
                    Icons.more_vert_rounded,
                    color: white,
                    size: 14,
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
