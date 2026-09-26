/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdfhawk/data/res/theme.dart';
import 'package:pdfhawk/data/res/utils.dart';
import 'package:pdfhawk/interface/globals/reorderable_grid.dart';
import 'package:pdfhawk/interface/pages/FileViewers/image_viewer_page.dart';
import 'package:pdfhawk/interface/pages/PDFTools/images_editor_page.dart';
import 'package:pdfhawk/logic/helpers/image_to_pdf_helper.dart';
import 'package:pdfhawk/logic/services/storage_service.dart';

class DocumentBoardBottomSheet extends StatefulWidget {
  final List<String> capturedImages;
  final ValueChanged<List<String>> onImagesUpdated;

  const DocumentBoardBottomSheet({
    super.key,
    required this.capturedImages,
    required this.onImagesUpdated,
  });

  @override
  State<DocumentBoardBottomSheet> createState() =>
      _DocumentBoardBottomSheetState();
}

class _DocumentBoardBottomSheetState extends State<DocumentBoardBottomSheet>
    with SingleTickerProviderStateMixin {
  late List<String> _capturedImages;
  late final TabController _sheetTabController;

  List<AssetEntity> _albumAssets = [];
  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _currentAlbum;
  final Set<AssetEntity> _selectedAssets = {};
  static const int _galleryPageSize = 80;
  final ScrollController _galleryScrollController = ScrollController();
  bool _hasGalleryPermission = true;
  bool _hasMoreGalleryAssets = true;
  bool _isLoadingMoreAssets = false;
  bool _isLoadingGallery = false;
  int _currentGalleryPage = 0;

  @override
  void initState() {
    super.initState();
    _capturedImages = List.from(widget.capturedImages);
    _sheetTabController = TabController(length: 2, vsync: this);
    _galleryScrollController.addListener(_onGalleryScroll);
    _initGalleryAlbums();
  }

  @override
  void dispose() {
    _sheetTabController.dispose();
    _galleryScrollController.removeListener(_onGalleryScroll);
    _galleryScrollController.dispose();
    super.dispose();
  }

  void _notifyImagesChanged() {
    widget.onImagesUpdated(List.from(_capturedImages));
  }

  void _showSnackBar(String text) {
    if (!mounted) return;
    plainToast(msg: text);
  }

  // --- ACTIONS FOR CAPTURED IMAGES ---
  void _openEditorForImage(int index) {
    if (_capturedImages.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImagesEditorPage(
          imagePath: _capturedImages[index],
          onSave: (updatedPath) {
            setState(() {
              _capturedImages[index] = updatedPath;
            });
            _notifyImagesChanged();
          },
        ),
      ),
    );
  }

  Future<void> _saveImageToGallery(String path) async {
    try {
      final file = File(path);
      if (!file.existsSync()) return;
      final bytes = await file.readAsBytes();
      final fileName = "Scan_${DateTime.now().millisecondsSinceEpoch}.jpg";
      await StorageService.saveExportedFile(
        fileName: fileName,
        bytes: bytes,
        subFolder: "Scans",
      );
      _showSnackBar("Saved to PDFHawk/Scans/$fileName");
    } catch (e) {
      _showSnackBar("Failed to save image: $e");
    }
  }

  void _shareImage(String path) {
    final file = File(path);
    if (file.existsSync()) {
      SharePlus.instance.share(
        ShareParams(files: [XFile(path)], text: "Scanned Document Page"),
      );
    }
  }

  void _deleteCapturedImage(int index) {
    if (index < 0 || index >= _capturedImages.length) return;
    setState(() {
      final path = _capturedImages.removeAt(index);
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    });
    _notifyImagesChanged();
    _showSnackBar("Page ${index + 1} deleted");
  }

  void _clearAllCapturedImages() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          "Clear All Scanned Pages?",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "Are you sure you want to discard all scanned images?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white60),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                for (final path in _capturedImages) {
                  final file = File(path);
                  if (file.existsSync()) {
                    file.deleteSync();
                  }
                }
                _capturedImages.clear();
              });
              _notifyImagesChanged();
              Navigator.pop(context);
            },
            child: const Text(
              "Clear All",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  // --- GALLERY ACTIONS VIA PHOTO MANAGER ---
  void _onGalleryScroll() {
    if (_galleryScrollController.hasClients &&
        _galleryScrollController.position.pixels >=
            _galleryScrollController.position.maxScrollExtent - 250) {
      if (_hasMoreGalleryAssets &&
          !_isLoadingMoreAssets &&
          !_isLoadingGallery) {
        _loadAssetsForCurrentAlbum(page: _currentGalleryPage + 1);
      }
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
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E24),
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
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white70,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
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
                                    color: Colors.white10,
                                    borderRadius: allradius(8.r),
                                  ),
                                  child: const Icon(
                                    Icons.photo_album_rounded,
                                    color: Colors.white38,
                                  ),
                                );
                              },
                            ),
                            title: Text(
                              album.name.isEmpty ? "Recent" : album.name,
                              style: GoogleFonts.outfit(
                                color: isSelected ? royalblue : Colors.white,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                fontSize: 14.sp,
                              ),
                            ),
                            subtitle: Text(
                              "$count photos",
                              style: GoogleFonts.instrumentSans(
                                color: Colors.white54,
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
        final scanDir = Directory("${appDir.path}/scans");
        if (!scanDir.existsSync()) {
          scanDir.createSync(recursive: true);
        }

        int added = 0;
        for (final path in result.paths) {
          if (path != null) {
            final srcFile = File(path);
            if (srcFile.existsSync()) {
              final targetPath =
                  "${scanDir.path}/scan_${DateTime.now().millisecondsSinceEpoch}_${_capturedImages.length + added}.jpg";
              final saved = await srcFile.copy(targetPath);
              if (!_capturedImages.contains(saved.path)) {
                _capturedImages.add(saved.path);
                added++;
              }
            }
          }
        }
        if (mounted) {
          setState(() {
            _sheetTabController.animateTo(0);
          });
          _notifyImagesChanged();
          _showSnackBar("Imported $added image(s) to scanned document!");
        }
      }
    } catch (e) {
      _showSnackBar("Failed to pick images: $e");
    }
  }

  Future<void> _addSelectedAssetsToScanList() async {
    if (_selectedAssets.isEmpty) return;

    final selectedList = _selectedAssets.toList();
    _showSnackBar("Adding ${selectedList.length} image(s)...");

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final scanDir = Directory("${appDir.path}/scans");
      if (!scanDir.existsSync()) {
        scanDir.createSync(recursive: true);
      }

      int addedCount = 0;
      for (int i = 0; i < selectedList.length; i++) {
        final asset = selectedList[i];
        final File? file = await asset.file ?? await asset.originFile;
        if (file != null && file.existsSync()) {
          final targetPath =
              "${scanDir.path}/scan_${DateTime.now().millisecondsSinceEpoch}_${_capturedImages.length + i}.jpg";
          final savedFile = await file.copy(targetPath);
          if (!_capturedImages.contains(savedFile.path)) {
            _capturedImages.add(savedFile.path);
            addedCount++;
          }
        }
      }

      if (mounted) {
        setState(() {
          _selectedAssets.clear();
          _sheetTabController.animateTo(0);
        });
        _notifyImagesChanged();
        _showSnackBar("Added $addedCount image(s) to scanned document!");
      }
    } catch (e) {
      _showSnackBar("Error adding images: $e");
    }
  }

  // --- EXPORT TO PDF ---
  Future<void> _exportToPdf() async {
    if (_capturedImages.isEmpty) {
      _showSnackBar("No scanned images to export.");
      return;
    }

    await ImageToPdfHelper.exportImagesToPdfDialog(
      context,
      imagePaths: _capturedImages,
      defaultFileName:
          "Scanned_Document_${DateTime.now().millisecondsSinceEpoch}",
      openReaderOnSuccess: true,
    );
  }

  // --- TAB 1: SCANNED IMAGES (REORDERABLE GRID) ---
  Widget _buildScannedImagesTab() {
    if (_capturedImages.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.document_scanner_outlined,
                size: 56.r,
                color: Colors.white24,
              ),
              SizedBox(height: 12.h),
              Text(
                "No scanned pages yet",
                style: GoogleFonts.outfit(
                  color: Colors.white70,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                "Take photos using the camera shutter or import images from the Gallery tab.",
                textAlign: TextAlign.center,
                style: GoogleFonts.instrumentSans(
                  color: Colors.white38,
                  fontSize: 13.sp,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      child: ImageReorderableGrid(
        imagePaths: _capturedImages,
        crossAxisCount: 3,
        crossAxisSpacing: 10.w,
        mainAxisSpacing: 10.h,
        childAspectRatio: 0.72,
        padding: EdgeInsets.zero,
        onReorder: (updated) {
          setState(() {
            _capturedImages.clear();
            _capturedImages.addAll(updated);
          });
          _notifyImagesChanged();
        },
        onItemTap: (index, path) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ImageViewerPage(
                imagePaths: _capturedImages,
                initialIndex: index,
                onImageEdited: (id, updatedPath) {
                  setState(() {
                    final idx = _capturedImages.indexOf(id);
                    if (idx != -1) {
                      _capturedImages[idx] = updatedPath;
                    }
                  });
                  _notifyImagesChanged();
                },
              ),
            ),
          );
        },
        onEditImage: (index, path) => _openEditorForImage(index),
        onSaveImage: (index, path) => _saveImageToGallery(path),
        onShareImage: (index, path) => _shareImage(path),
        onDeleteImage: (index, path) => _deleteCapturedImage(index),
      ),
    );
  }

  // --- TAB 2: GALLERY PICKER TAB ---
  Widget _buildGalleryPickerTab() {
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
                color: Colors.white30,
              ),
              SizedBox(height: 12.h),
              Text(
                "Photo Access Required",
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                "PDF Hawk needs permission to access your device photos to select images for scanning.",
                textAlign: TextAlign.center,
                style: GoogleFonts.instrumentSans(
                  color: Colors.white54,
                  fontSize: 12.sp,
                ),
              ),
              SizedBox(height: 16.h),
              ElevatedButton.icon(
                icon: const Icon(Icons.settings_rounded, size: 16),
                label: const Text("Open App Settings"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: royalblue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: allradius(10.r)),
                ),
                onPressed: () {
                  PhotoManager.openSetting();
                },
              ),
              SizedBox(height: 8.h),
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
        // Album Selector & Control Toolbar
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          child: Row(
            children: [
              // Album Dropdown Button
              InkWell(
                onTap: _showAlbumSelectionSheet,
                borderRadius: allradius(10.r),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: allradius(10.r),
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.photo_album_rounded,
                        color: royalblue,
                        size: 15.sp,
                      ),
                      SizedBox(width: 6.w),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 130.w),
                        child: Text(
                          albumTitle,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white70,
                        size: 18.sp,
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),

              // Quick Actions: Select/Clear All
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
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              // External Files Picker Fallback
              IconButton(
                tooltip: "Pick from System File Picker",
                icon: const Icon(
                  Icons.folder_open_rounded,
                  color: Colors.white70,
                  size: 20,
                ),
                onPressed: _pickImagesFromCustomPicker,
              ),
            ],
          ),
        ),

        // Gallery Grid View
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
                          color: Colors.white24,
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          "No photos in this album",
                          style: GoogleFonts.outfit(
                            color: Colors.white70,
                            fontSize: 15.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : GridView.builder(
                  controller: _galleryScrollController,
                  padding: EdgeInsets.symmetric(horizontal: 10.w),
                  itemCount:
                      _albumAssets.length + (_isLoadingMoreAssets ? 1 : 0),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 6.w,
                    mainAxisSpacing: 6.h,
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
                          borderRadius: allradius(8.r),
                          border: Border.all(
                            color: isSelected ? royalblue : Colors.transparent,
                            width: isSelected ? 2.5 : 0,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: allradius(isSelected ? 6.r : 8.r),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              AssetEntityImage(
                                asset,
                                isOriginal: false,
                                thumbnailSize: const ThumbnailSize.square(240),
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return Container(
                                    color: Colors.white10,
                                    child: const Center(
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          color: Colors.white24,
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
                                top: 5.r,
                                right: 5.r,
                                child: Container(
                                  padding: EdgeInsets.all(1.5.r),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? royalblue
                                        : Colors.black45,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Icon(
                                    isSelected ? Icons.check_rounded : null,
                                    color: Colors.white,
                                    size: 14.sp,
                                  ),
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

        // Add Selected Button
        if (_selectedAssets.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(
                  "Add ${_selectedAssets.length} to Scanned Pages",
                  style: GoogleFonts.outfit(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: royalblue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(borderRadius: allradius(12.r)),
                  elevation: 4,
                ),
                onPressed: _addSelectedAssetsToScanList,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final double sheetHeight = getHeight(context);

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: const Color(0xFF141419),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      child: Column(
        children: [
          uihandle(top: 8.h, bottom: 2.h),
          // Top Sheet Header
          Padding(
            padding: EdgeInsets.only(left: 8.w, right: 8.w, top: 4.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: "Collapse Sheet",
                  icon: const Icon(
                    Icons.arrow_back_ios_new_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                Text(
                  "Document Board",
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 17.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_capturedImages.isNotEmpty)
                  IconButton(
                    tooltip: "Clear All",
                    icon: const Icon(
                      Icons.delete_forever_outlined,
                      color: red,
                      size: 24,
                    ),
                    onPressed: _clearAllCapturedImages,
                  )
                else
                  const SizedBox(width: 48),
              ],
            ),
          ),

          // Tab Bar
          TabBar(
            controller: _sheetTabController,
            indicatorColor: royalblue,
            indicatorWeight: 5,
            labelColor: Colors.white,
            dividerColor: transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            unselectedLabelColor: Colors.white54,
            labelStyle: GoogleFonts.outfit(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
            tabs: [
              Tab(text: "Scanned (${_capturedImages.length})"),
              Tab(
                text: _selectedAssets.isNotEmpty
                    ? "Gallery (${_selectedAssets.length} sel)"
                    : "Gallery (${_albumAssets.length})",
              ),
            ],
          ),

          // Tab Bar Views
          Expanded(
            child: TabBarView(
              controller: _sheetTabController,
              children: [
                // Tab 1: Scanned Images Reorderable Grid
                _buildScannedImagesTab(),

                // Tab 2: Gallery Picker Grid
                _buildGalleryPickerTab(),
              ],
            ),
          ),

          // Bottom Export / Action Bar
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: const Color(0xFF191920),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            child: SafeArea(
              top: false,
              child: InkWell(
                onTap: _capturedImages.isNotEmpty ? _exportToPdf : null,
                child: Container(
                  width: double.infinity,
                  height: 48.h,
                  decoration: BoxDecoration(
                    borderRadius: allradius(5),
                    border: Border.all(color: royalblue, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      _capturedImages.isEmpty
                          ? "Export to PDF"
                          : "Export to PDF (${_capturedImages.length} Pages)",
                      style: GoogleFonts.outfit(
                        color: royalblue,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
