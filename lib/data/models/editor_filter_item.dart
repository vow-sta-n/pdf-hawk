import 'package:flutter_image_filters/flutter_image_filters.dart';

class EditorFilterItem {
  final String id;
  final String name;
  final ShaderConfiguration Function() createConfig;
  ShaderConfiguration? _config;

  EditorFilterItem({
    required this.id,
    required this.name,
    required this.createConfig,
  });

  ShaderConfiguration get config => _config ??= createConfig();

  void dispose() {
    _config?.dispose();
    _config = null;
  }
}