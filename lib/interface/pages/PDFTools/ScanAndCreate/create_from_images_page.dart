/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfhawk/data/models/album_category_model.dart';
import 'package:pdfhawk/data/res/utils.dart';
import 'package:pdfhawk/interface/globals/bubble_button.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:pdfhawk/data/res/theme.dart';
import 'package:pdfhawk/interface/pages/FileViewers/image_viewer_page.dart';
import 'package:pdfhawk/interface/pages/FileViewers/image_to_pdf_preview_page.dart';
import 'package:pdfhawk/logic/helpers/image_to_pdf_helper.dart';

class ImageToPdfPage extends StatefulWidget {
  final List<String>? initialImagePaths;

  const ImageToPdfPage({super.key, this.initialImagePaths});

  @override
  State<ImageToPdfPage> createState() => _ImageToPdfPageState();
}

class _ImageToPdfPageState extends State<ImageToPdfPage> {
  final ScrollController _scrollController = ScrollController();
  final List<String> _orderedImagePaths = [];
  final Map<String, String> _assetIdToPath = {};
  final List<AssetEntity> _selectedAssets = [];
  final Set<String> _selectedCustomPaths = {};
  static const int _gridCrossAxisCount = 5;
  List<AlbumCategory> _categories = [];
  bool _hasGalleryPermission = true;
  bool _isLoadingGallery = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialImagePaths != null &&
        widget.initialImagePaths!.isNotEmpty) {
      _orderedImagePaths.addAll(widget.initialImagePaths!);
      _selectedCustomPaths.addAll(widget.initialImagePaths!);
    }

    _initGalleryCategories();
  }

  Future<void> _initGalleryCategories() async {
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

      final List<AlbumCategory> loadedCategories = [];

      // Check if user has specific albums (like Camera, Screenshots, Downloads, etc.)
      final specificAlbums = albums.where((a) => !a.isAll).toList();

      if (specificAlbums.isNotEmpty) {
        for (final album in specificAlbums) {
          final count = await album.assetCountAsync;
          if (count == 0) continue;

          // Load initial batch of assets for this album
          final assets = await album.getAssetListPaged(page: 0, size: 40);

          String albumName = album.name.trim();
          if (albumName.isEmpty) {
            albumName = "Album";
          }

          loadedCategories.add(
            AlbumCategory(
              album: album,
              id: album.id,
              name: albumName,
              totalCount: count,
              assets: assets,
              isExpanded: true, // Expanded by default!
              hasMore: assets.length < count,
              currentPage: 0,
            ),
          );
        }
      } else if (albums.isNotEmpty) {
        // No albums present - simply show images present in device under parent folder name!
        final allAlbum = albums.first;
        final count = await allAlbum.assetCountAsync;
        if (count > 0) {
          final assets = await allAlbum.getAssetListRange(
            start: 0,
            end: count.clamp(0, 3000),
          );

          final Map<String, List<AssetEntity>> folderMap = {};
          final List<AssetEntity> unclassified = [];

          for (final asset in assets) {
            final folder = _extractFolderFromAssetSync(asset);
            if (folder != null && folder.isNotEmpty) {
              folderMap.putIfAbsent(folder, () => []).add(asset);
            } else {
              unclassified.add(asset);
            }
          }

          if (unclassified.isNotEmpty) {
            for (final asset in unclassified) {
              final folder = await _resolveAssetParentFolderAsync(asset);
              folderMap.putIfAbsent(folder, () => []).add(asset);
            }
          }

          // Sort folders alphabetically, with 'Camera' first if present
          final sortedFolders = folderMap.keys.toList()
            ..sort((a, b) {
              if (a.toLowerCase() == 'camera') return -1;
              if (b.toLowerCase() == 'camera') return 1;
              return a.toLowerCase().compareTo(b.toLowerCase());
            });

          for (final folderName in sortedFolders) {
            final list = folderMap[folderName]!;
            loadedCategories.add(
              AlbumCategory(
                album: allAlbum,
                id: "folder_$folderName",
                name: folderName,
                totalCount: list.length,
                assets: list,
                isExpanded: true,
                hasMore: false,
                currentPage: 0,
              ),
            );
          }
        }
      }

      // Add custom picked photos category if initial paths were provided
      if (_orderedImagePaths.isNotEmpty) {
        final Map<String, List<String>> initialFolderMap = {};
        for (final path in _orderedImagePaths) {
          final parentDirName = p.basename(File(path).parent.path).trim();
          final folderName =
              parentDirName.isNotEmpty &&
                  parentDirName != "/" &&
                  parentDirName != "."
              ? parentDirName
              : "Device Photos";
          initialFolderMap.putIfAbsent(folderName, () => []).add(path);
        }

        for (final entry in initialFolderMap.entries) {
          loadedCategories.insert(
            0,
            AlbumCategory(
              id: "custom_folder_${entry.key}",
              name: entry.key,
              totalCount: entry.value.length,
              customFilePaths: List.from(entry.value),
              isExpanded: true,
              hasMore: false,
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          _hasGalleryPermission = true;
          _categories = loadedCategories;
        });
      }
    } catch (e) {
      debugPrint("Error initializing PhotoManager categories: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingGallery = false);
      }
    }
  }

  String? _extractFolderFromAssetSync(AssetEntity asset) {
    final rel = asset.relativePath?.trim();
    if (rel != null && rel.isNotEmpty) {
      final clean = rel.replaceAll('\\', '/');
      final segments = clean.split('/').where((s) => s.isNotEmpty).toList();
      if (segments.isNotEmpty) {
        return segments.last;
      }
    }
    return null;
  }

  Future<String> _resolveAssetParentFolderAsync(AssetEntity asset) async {
    try {
      final f = await asset.file ?? await asset.originFile;
      if (f != null) {
        final parentName = p.basename(f.parent.path).trim();
        if (parentName.isNotEmpty && parentName != "/" && parentName != ".") {
          return parentName;
        }
      }
    } catch (_) {}

    return "Device Photos";
  }

  Future<void> _loadMoreForCategory(AlbumCategory category) async {
    if (category.album == null || !category.hasMore || category.isLoadingMore) {
      return;
    }

    setState(() => category.isLoadingMore = true);

    try {
      final nextPage = category.currentPage + 1;
      final newAssets = await category.album!.getAssetListPaged(
        page: nextPage,
        size: 40,
      );

      if (mounted) {
        setState(() {
          category.assets.addAll(newAssets);
          category.currentPage = nextPage;
          category.hasMore = category.assets.length < category.totalCount;
        });
      }
    } catch (e) {
      debugPrint("Error loading more assets for category: $e");
    } finally {
      if (mounted) {
        setState(() => category.isLoadingMore = false);
      }
    }
  }

  void _toggleCategoryExpand(AlbumCategory category) {
    setState(() {
      category.isExpanded = !category.isExpanded;
    });
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
          setState(() {
            _orderedImagePaths.addAll(addedPaths);
            _selectedCustomPaths.addAll(addedPaths);

            // Group added paths by their parent folder name
            final Map<String, List<String>> folderMap = {};
            for (final path in addedPaths) {
              final parentName = p.basename(File(path).parent.path).trim();
              final folderName =
                  parentName.isNotEmpty &&
                      parentName != "/" &&
                      parentName != "."
                  ? parentName
                  : "Device Photos";
              folderMap.putIfAbsent(folderName, () => []).add(path);
            }

            for (final entry in folderMap.entries) {
              final folderName = entry.key;
              final catId = "custom_folder_$folderName";
              final existingCat = _categories
                  .where((c) => c.id == catId || c.name == folderName)
                  .firstOrNull;

              if (existingCat != null) {
                for (final pth in entry.value) {
                  if (!existingCat.customFilePaths.contains(pth)) {
                    existingCat.customFilePaths.add(pth);
                  }
                }
                existingCat.totalCount = existingCat.customFilePaths.length;
                existingCat.isExpanded = true;
              } else {
                _categories.insert(
                  0,
                  AlbumCategory(
                    id: catId,
                    name: folderName,
                    totalCount: entry.value.length,
                    customFilePaths: List.from(entry.value),
                    isExpanded: true,
                    hasMore: false,
                  ),
                );
              }
            }
          });
          Fluttertoast.showToast(msg: "Added ${addedPaths.length} image(s)");
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to pick images from folders: $e");
    }
  }

  void _toggleAssetSelection(AssetEntity asset) {
    setState(() {
      final idx = _selectedAssets.indexWhere((a) => a.id == asset.id);
      if (idx != -1) {
        _selectedAssets.removeAt(idx);
        final path = _assetIdToPath[asset.id];
        if (path != null) {
          _orderedImagePaths.remove(path);
        }
      } else {
        _selectedAssets.add(asset);
      }
    });
  }

  void _toggleCustomPathSelection(String path) {
    setState(() {
      if (_selectedCustomPaths.contains(path)) {
        _selectedCustomPaths.remove(path);
        _orderedImagePaths.remove(path);
      } else {
        _selectedCustomPaths.add(path);
        if (!_orderedImagePaths.contains(path)) {
          _orderedImagePaths.add(path);
        }
      }
    });
  }

  int _getAssetSelectionIndex(AssetEntity asset) {
    return _selectedAssets.indexWhere((a) => a.id == asset.id);
  }

  int _getCustomPathSelectionIndex(String path) {
    // Selection order index includes both assets and custom paths
    return _orderedImagePaths.indexOf(path);
  }

  Future<List<String>> _ensureAllSelectedPaths() async {
    final appDir = await getApplicationDocumentsDirectory();
    final scansDir = Directory("${appDir.path}/scans");
    if (!scansDir.existsSync()) {
      scansDir.createSync(recursive: true);
    }

    final List<String> resolvedPaths = [];

    // Cache selected assets to file paths
    for (int i = 0; i < _selectedAssets.length; i++) {
      final asset = _selectedAssets[i];
      if (!_assetIdToPath.containsKey(asset.id)) {
        final File? file = await asset.file ?? await asset.originFile;
        if (file != null && file.existsSync()) {
          final targetPath =
              "${scansDir.path}/img_${DateTime.now().millisecondsSinceEpoch}_$i.jpg";
          final savedFile = await file.copy(targetPath);
          _assetIdToPath[asset.id] = savedFile.path;
        }
      }

      final path = _assetIdToPath[asset.id];
      if (path != null) {
        resolvedPaths.add(path);
        if (!_orderedImagePaths.contains(path)) {
          _orderedImagePaths.add(path);
        }
      }
    }

    // Include selected custom paths
    for (final pth in _selectedCustomPaths) {
      if (!resolvedPaths.contains(pth)) {
        resolvedPaths.add(pth);
      }
    }

    return resolvedPaths;
  }

  void _openPhotoViewFullscreen(AssetEntity asset, List<AssetEntity> list) {
    final initialIndex = list.indexOf(asset);

    final previewItems = list.map((a) {
      return GalleryPreviewItem(
        id: a.id,
        asset: a,
        filePath: _assetIdToPath[a.id],
      );
    }).toList();

    final selectedIds = _selectedAssets.map((a) => a.id).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageGalleryPhotoViewerPage(
          items: previewItems,
          initialIndex: initialIndex != -1 ? initialIndex : 0,
          selectedIds: selectedIds,
          onToggleSelect: (id, isSelected) {
            final targetAsset = list.where((a) => a.id == id).firstOrNull;
            if (targetAsset != null) {
              _toggleAssetSelection(targetAsset);
            }
          },
          onImageEdited: (id, updatedPath) {
            setState(() {
              _assetIdToPath[id] = updatedPath;
              final ordIdx = _orderedImagePaths.indexOf(
                _assetIdToPath[id] ?? "",
              );
              if (ordIdx != -1) {
                _orderedImagePaths[ordIdx] = updatedPath;
              }
            });
          },
        ),
      ),
    );
  }

  Future<void> _openPreviewScreen() async {
    final paths = await _ensureAllSelectedPaths();
    if (paths.isEmpty) {
      Fluttertoast.showToast(
        msg: "Please select at least one photo to preview",
      );
      return;
    }

    if (!mounted) return;

    final updatedPaths = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (context) => ImageToPdfPreviewPage(
          orderedImagePaths: List.from(paths),
          onSavePdf: (newPaths) {
            _exportToPdf(customPaths: newPaths);
          },
        ),
      ),
    );

    if (updatedPaths != null && mounted) {
      setState(() {
        _orderedImagePaths.clear();
        _orderedImagePaths.addAll(updatedPaths);

        // Synchronize selected assets to match updated paths
        final List<AssetEntity> reorderedAssets = [];
        for (final pth in updatedPaths) {
          final assetId = _assetIdToPath.entries
              .where((e) => e.value == pth)
              .map((e) => e.key)
              .firstOrNull;
          if (assetId != null) {
            final asset = _selectedAssets
                .where((a) => a.id == assetId)
                .firstOrNull;
            if (asset != null) {
              reorderedAssets.add(asset);
            }
          }
        }
        _selectedAssets.clear();
        _selectedAssets.addAll(reorderedAssets);
      });
    }
  }

  Future<void> _exportToPdf({List<String>? customPaths}) async {
    final pathsToExport = customPaths ?? await _ensureAllSelectedPaths();

    if (pathsToExport.isEmpty) {
      Fluttertoast.showToast(msg: "Please select at least one image");
      return;
    }

    if (!mounted) return;

    await ImageToPdfHelper.exportImagesToPdfDialog(
      context,
      imagePaths: pathsToExport,
      openReaderOnSuccess: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final totalSelected = _selectedAssets.length + _selectedCustomPaths.length;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey.shade100,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Bar with Search & Folders
                _buildTopBar(isDark, theme),

                // Main Content: All photos categorized by Album Name
                Expanded(
                  child: !_hasGalleryPermission && !_isLoadingGallery
                      ? _buildPermissionPrompt(isDark)
                      : _buildCategorizedPhotosList(isDark, theme),
                ),
              ],
            ),

            // Floating Pill Bar: [Preview] and [Create PDF]
            _buildFloatingPillBar(isDark, theme, totalSelected),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isDark, ThemeData theme) {
    final totalAllPhotos = _categories.fold<int>(
      0,
      (sum, cat) => sum + cat.totalCount,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(10, 12.h, 10, 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Image to PDF",
                style: GoogleFonts.outfit(
                  fontSize: 30.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Row(
                children: [
                  // Pick from device storage folders
                  BubbleButton(
                    icon: Icons.image_search_rounded,
                    tooltip: "Pick from device folders",
                    shape: BoxShape.circle,
                    onTap: _pickImagesFromCustomPicker,
                  ),

                  // Close button
                  BubbleButton(
                    icon: Icons.close_rounded,
                    padding: EdgeInsets.all(0),
                    tooltip: "Close",
                    shape: BoxShape.circle,
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),

          Text(
            "$totalAllPhotos photos available",
            style: GoogleFonts.instrumentSans(
              fontSize: 13.5.sp,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          Gap(4.h),
        ],
      ),
    );
  }

  Widget _buildCategorizedPhotosList(bool isDark, ThemeData theme) {
    if (_isLoadingGallery && _categories.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          color: theme.colorScheme.primary,
          strokeWidth: 2.5,
        ),
      );
    }

    final totalSelected = _selectedAssets.length + _selectedCustomPaths.length;

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        for (final category in _categories) ...[
          // Expandable Album Category Header
          SliverToBoxAdapter(
            child: _buildCategoryHeader(category, isDark, theme),
          ),

          // Photos Grid (visible when expanded)
          if (category.isExpanded) ...[
            _buildCategoryGrid(category, isDark, theme),
          ],
        ],

        // Bottom space so floating pill bar never obscures photos
        SliverToBoxAdapter(child: Gap(totalSelected > 0 ? 110.h : 30.h)),
      ],
    );
  }

  Widget _buildCategoryHeader(
    AlbumCategory category,
    bool isDark,
    ThemeData theme,
  ) {
    // Count selected in this category
    int selectedInCat = 0;
    if (category.customFilePaths.isNotEmpty) {
      selectedInCat = category.customFilePaths
          .where((p) => _selectedCustomPaths.contains(p))
          .length;
    } else {
      selectedInCat = category.assets
          .where((a) => _selectedAssets.any((sel) => sel.id == a.id))
          .length;
    }

    return InkWell(
      onTap: () => _toggleCategoryExpand(category),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
        child: Row(
          children: [
            // Album Name
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  Gap(8.w),

                  // Total Photos Pill
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                      borderRadius: allradius(10.r),
                    ),
                    child: Text(
                      "${category.totalCount}",
                      style: GoogleFonts.outfit(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),

                  // Selected in this album pill badge
                  if (selectedInCat > 0) ...[
                    Gap(6.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                        borderRadius: allradius(10.r),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.4,
                          ),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        "$selectedInCat selected",
                        style: GoogleFonts.outfit(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Animated Expand/Collapse Chevron
            AnimatedRotation(
              turns: category.isExpanded ? 0 : -0.25,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 24.sp,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryGrid(
    AlbumCategory category,
    bool isDark,
    ThemeData theme,
  ) {
    final bool isCustom = category.customFilePaths.isNotEmpty;
    final int itemCount = isCustom
        ? category.customFilePaths.length
        : category.assets.length;

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _gridCrossAxisCount,
          crossAxisSpacing: 3,
          mainAxisSpacing: 3,
          childAspectRatio: 1.0,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          dynamic artifact = isCustom
              ? category.customFilePaths[index]
              : category.assets[index];
          final selIndex = isCustom
              ? _getCustomPathSelectionIndex(artifact)
              : _getAssetSelectionIndex(artifact);
          final isSelected = isCustom
              ? _selectedCustomPaths.contains(artifact)
              : (selIndex != -1);

          // Auto-fetch more if near end
          if (index >= category.assets.length - 10 && category.hasMore) {
            _loadMoreForCategory(category);
          }

          return GestureDetector(
            onTap: () {
              if (isCustom) {
                _toggleCustomPathSelection(artifact as String);
              } else {
                _toggleAssetSelection(artifact as AssetEntity);
              }
            },
            onLongPress: () {
              if (isCustom) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ImageViewerPage(imagePath: artifact as String),
                  ),
                );
              } else {
                _openPhotoViewFullscreen(
                  artifact as AssetEntity,
                  category.assets,
                );
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (isCustom)
                  Image.file(
                    File(artifact),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: isDark ? Colors.white10 : Colors.black12,
                      child: Icon(
                        Icons.broken_image_rounded,
                        size: 24.sp,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                if (!isCustom)
                  AssetEntityImage(
                    artifact,
                    isOriginal: false,
                    thumbnailSize: const ThumbnailSize.square(240),
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: isDark ? Colors.white10 : Colors.black12,
                      );
                    },
                  ),

                // Selected Color Tint
                if (isSelected)
                  Container(
                    color: theme.colorScheme.primary.withValues(alpha: 0.35),
                  ),

                // Selection Order Badge (bottom-left)
                if (isSelected)
                  Positioned(
                    bottom: 4.r,
                    left: 4.r,
                    child: Container(
                      height: 20.r,
                      padding: EdgeInsets.symmetric(horizontal: 5.r),
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        borderRadius: allradius(1.r),
                      ),
                      child: Center(
                        child: Text(
                          "Pg - ${selIndex + 1}",
                          style: GoogleFonts.instrumentSans(
                            color: white,
                            height: 0,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }, childCount: itemCount),
      ),
    );
  }

  Widget _buildFloatingPillBar(
    bool isDark,
    ThemeData theme,
    int totalSelected,
  ) {
    final isVisible = totalSelected > 0;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      bottom: isVisible ? 24.h : -90.h,
      left: 20.w,
      right: 20.w,
      child: Center(
        child: ClipRRect(
          borderRadius: allradius(32.r),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xDD1C1C24)
                    : Colors.white.withValues(alpha: 0.94),
                borderRadius: allradius(32.r),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.08),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Button 1: Preview (with eye icon)
                  InkWell(
                    onTap: isVisible ? _openPreviewScreen : null,
                    borderRadius: allradius(24.r),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 18.w,
                        vertical: 10.h,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.06),
                        borderRadius: allradius(24.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.remove_red_eye_outlined,
                            size: 18.sp,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          Gap(8.w),
                          Text(
                            "Preview",
                            style: GoogleFonts.outfit(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Gap(10.w),

                  // Button 2: Create PDF (with badge count and gradient primary)
                  InkWell(
                    onTap: isVisible ? () => _exportToPdf() : null,
                    borderRadius: allradius(24.r),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.w,
                        vertical: 10.h,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.primary.withValues(alpha: 0.85),
                          ],
                        ),
                        borderRadius: allradius(24.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, size: 18.sp, color: white),
                          Gap(8.w),
                          Text(
                            "Create PDF",
                            style: GoogleFonts.outfit(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
              onPressed: _initGalleryCategories,
            ),
          ],
        ),
      ),
    );
  }
}
