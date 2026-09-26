import 'package:photo_manager/photo_manager.dart';

class AlbumCategory {
  final AssetPathEntity? album;
  final String id;
  final String name;
  int totalCount;
  List<AssetEntity> assets;
  List<String> customFilePaths; // For imported files from device storage
  bool isExpanded;
  bool isLoadingMore;
  int currentPage;
  bool hasMore;

  AlbumCategory({
    this.album,
    required this.id,
    required this.name,
    required this.totalCount,
    List<AssetEntity>? assets,
    List<String>? customFilePaths,
    this.isExpanded = true,
    this.isLoadingMore = false,
    this.currentPage = 0,
    this.hasMore = true,
  }) : assets = assets ?? [],
       customFilePaths = customFilePaths ?? [];
}