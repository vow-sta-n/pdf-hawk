import 'package:flutter/material.dart';
import 'package:flutter_image_filters/flutter_image_filters.dart';

class EditorFilterItem {
  final String id;
  final String name;
  final ShaderConfiguration Function() createConfig;
  final ColorFilter? colorFilter;
  ShaderConfiguration? _config;

  EditorFilterItem({
    required this.id,
    required this.name,
    required this.createConfig,
    this.colorFilter,
  });

  ShaderConfiguration get config => _config ??= createConfig();

  void dispose() {
    _config?.dispose();
    _config = null;
  }
}

List<double> _grayscaleMatrix() => const [
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0, 0, 0, 1, 0,
    ];

List<double> _saturationMatrix(double s) {
  final sr = (1 - s) * 0.2126;
  final sg = (1 - s) * 0.7152;
  final sb = (1 - s) * 0.0722;
  return [
    sr + s, sg, sb, 0, 0,
    sr, sg + s, sb, 0, 0,
    sr, sg, sb + s, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

List<double> _contrastMatrix(double c) {
  final t = (1.0 - c) / 2.0 * 255.0;
  return [
    c, 0, 0, 0, t,
    0, c, 0, 0, t,
    0, 0, c, 0, t,
    0, 0, 0, 1, 0,
  ];
}

List<double> _sepiaMatrix() => const [
      0.393, 0.769, 0.189, 0, 0,
      0.349, 0.686, 0.168, 0, 0,
      0.272, 0.534, 0.131, 0, 0,
      0, 0, 0, 1, 0,
    ];

List<double> _invertMatrix() => const [
      -1, 0, 0, 0, 255,
      0, -1, 0, 0, 255,
      0, 0, -1, 0, 255,
      0, 0, 0, 1, 0,
    ];

List<double> _magicScanMatrix() {
  const r = 0.2126 * 1.8;
  const g = 0.7152 * 1.8;
  const b = 0.0722 * 1.8;
  const t = -80.0;
  return const [
    r, g, b, 0, t,
    r, g, b, 0, t,
    r, g, b, 0, t,
    0, 0, 0, 1, 0,
  ];
}

List<double> _docCleanMatrix() {
  const r = 0.2126 * 2.8;
  const g = 0.7152 * 2.8;
  const b = 0.0722 * 2.8;
  const t = -170.0;
  return const [
    r, g, b, 0, t,
    r, g, b, 0, t,
    r, g, b, 0, t,
    0, 0, 0, 1, 0,
  ];
}

List<double> _warmMatrix() => const [
      1.15, 0, 0, 0, 10,
      0, 1.02, 0, 0, 2,
      0, 0, 0.85, 0, -12,
      0, 0, 0, 1, 0,
    ];

List<double> _coolMatrix() => const [
      0.88, 0, 0, 0, -10,
      0, 1.0, 0, 0, 0,
      0, 0, 1.18, 0, 15,
      0, 0, 0, 1, 0,
    ];

List<double> _brightnessMatrix(double offset) => [
      1, 0, 0, 0, offset,
      0, 1, 0, 0, offset,
      0, 0, 1, 0, offset,
      0, 0, 0, 1, 0,
    ];

List<double> _exposureMatrix(double mult) => [
      mult, 0, 0, 0, 0,
      0, mult, 0, 0, 0,
      0, 0, mult, 0, 0,
      0, 0, 0, 1, 0,
    ];

List<double> _vintageMatrix() => const [
      0.92, 0.08, 0.08, 0, 15,
      0.08, 0.88, 0.08, 0, 8,
      0.08, 0.08, 0.78, 0, 0,
      0, 0, 0, 1, 0,
    ];

List<double> _falseColorMatrix() => const [
      0.2, 0.4, 0.4, 0, 20,
      0.4, 0.3, 0.1, 0, 10,
      0.6, 0.1, 0.1, 0, 50,
      0, 0, 0, 1, 0,
    ];

List<double> _cgaMatrix() => const [
      0.3, 0.5, 0.2, 0, 30,
      0.1, 0.7, 0.2, 0, 10,
      0.4, 0.2, 0.4, 0, 40,
      0, 0, 0, 1, 0,
    ];

/// Global shared filters list used across Camera and Images Editor
final List<EditorFilterItem> kAppEditorFilters = [
  EditorFilterItem(
    id: 'none',
    name: 'Original',
    createConfig: () => NoneShaderConfiguration(),
    colorFilter: null,
  ),
  EditorFilterItem(
    id: 'magicScan',
    name: 'Magic Scan',
    createConfig: () => ContrastShaderConfiguration()..contrast = 2.0,
    colorFilter: ColorFilter.matrix(_magicScanMatrix()),
  ),
  EditorFilterItem(
    id: 'grayscale',
    name: 'B&W',
    createConfig: () => GrayscaleShaderConfiguration(),
    colorFilter: ColorFilter.matrix(_grayscaleMatrix()),
  ),
  EditorFilterItem(
    id: 'docClean',
    name: 'Doc Clean',
    createConfig: () =>
        LuminanceThresholdShaderConfiguration()..threshold = 0.5,
    colorFilter: ColorFilter.matrix(_docCleanMatrix()),
  ),
  EditorFilterItem(
    id: 'sepia',
    name: 'Sepia',
    createConfig: () => MonochromeShaderConfiguration()
      ..color = const Color(0xFF704214)
      ..intensity = 0.85,
    colorFilter: ColorFilter.matrix(_sepiaMatrix()),
  ),
  EditorFilterItem(
    id: 'vivid',
    name: 'Vivid',
    createConfig: () => SaturationShaderConfiguration()..saturation = 1.6,
    colorFilter: ColorFilter.matrix(_saturationMatrix(1.6)),
  ),
  EditorFilterItem(
    id: 'vibrance',
    name: 'Vibrance',
    createConfig: () => VibranceShaderConfiguration()..vibrance = 0.9,
    colorFilter: ColorFilter.matrix(_saturationMatrix(1.35)),
  ),
  EditorFilterItem(
    id: 'warm',
    name: 'Warm',
    createConfig: () => WhiteBalanceShaderConfiguration()
      ..temperature = 6500
      ..tint = 12,
    colorFilter: ColorFilter.matrix(_warmMatrix()),
  ),
  EditorFilterItem(
    id: 'cool',
    name: 'Cool',
    createConfig: () => WhiteBalanceShaderConfiguration()
      ..temperature = 4000
      ..tint = -12,
    colorFilter: ColorFilter.matrix(_coolMatrix()),
  ),
  EditorFilterItem(
    id: 'vintage',
    name: 'Vintage',
    createConfig: () => VignetteShaderConfiguration()
      ..start = 0.3
      ..end = 0.75,
    colorFilter: ColorFilter.matrix(_vintageMatrix()),
  ),
  EditorFilterItem(
    id: 'contrast',
    name: 'Contrast',
    createConfig: () => ContrastShaderConfiguration()..contrast = 1.5,
    colorFilter: ColorFilter.matrix(_contrastMatrix(1.5)),
  ),
  EditorFilterItem(
    id: 'brighten',
    name: 'Brighten',
    createConfig: () => BrightnessShaderConfiguration()..brightness = 0.2,
    colorFilter: ColorFilter.matrix(_brightnessMatrix(50)),
  ),
  EditorFilterItem(
    id: 'exposure',
    name: 'Exposure',
    createConfig: () => ExposureShaderConfiguration()..exposure = 0.4,
    colorFilter: ColorFilter.matrix(_exposureMatrix(1.35)),
  ),
  EditorFilterItem(
    id: 'invert',
    name: 'Invert',
    createConfig: () => ColorInvertShaderConfiguration(),
    colorFilter: ColorFilter.matrix(_invertMatrix()),
  ),
  EditorFilterItem(
    id: 'gamma',
    name: 'Gamma',
    createConfig: () => GammaShaderConfiguration()..gamma = 1.4,
    colorFilter: ColorFilter.matrix(_contrastMatrix(1.2)),
  ),
  EditorFilterItem(
    id: 'posterize',
    name: 'Posterize',
    createConfig: () => PosterizeShaderConfiguration()..colorLevels = 6,
    colorFilter: ColorFilter.matrix(_contrastMatrix(1.8)),
  ),
  EditorFilterItem(
    id: 'solarize',
    name: 'Solarize',
    createConfig: () => SolarizeShaderConfiguration()..threshold = 0.5,
    colorFilter: ColorFilter.matrix(const [
      -0.8, 0, 0, 0, 180,
      0, -0.8, 0, 0, 180,
      0, 0, -0.8, 0, 180,
      0, 0, 0, 1, 0,
    ]),
  ),
  EditorFilterItem(
    id: 'falseColor',
    name: 'False Color',
    createConfig: () => FalseColorShaderConfiguration()
      ..firstColor = const Color(0xFF1565C0)
      ..secondColor = const Color(0xFFFFB300),
    colorFilter: ColorFilter.matrix(_falseColorMatrix()),
  ),
  EditorFilterItem(
    id: 'haze',
    name: 'Haze',
    createConfig: () => HazeShaderConfiguration()
      ..distance = 0.2
      ..slope = 0.1,
    colorFilter: ColorFilter.matrix(_contrastMatrix(0.85)),
  ),
  EditorFilterItem(
    id: 'halftone',
    name: 'Halftone',
    createConfig: () =>
        HalftoneShaderConfiguration()..fractionalWidthOfPixel = 0.01,
    colorFilter: ColorFilter.matrix(_grayscaleMatrix()),
  ),
  EditorFilterItem(
    id: 'crosshatch',
    name: 'Crosshatch',
    createConfig: () =>
        CrosshatchShaderConfiguration()..crossHatchSpacing = 0.02,
    colorFilter: ColorFilter.matrix(_grayscaleMatrix()),
  ),
  EditorFilterItem(
    id: 'cga',
    name: 'CGA Retro',
    createConfig: () => CGAColorspaceShaderConfiguration(),
    colorFilter: ColorFilter.matrix(_cgaMatrix()),
  ),
  EditorFilterItem(
    id: 'pixelate',
    name: 'Pixelate',
    createConfig: () => PixelationShaderConfiguration()..pixel = 0.02,
    colorFilter: null,
  ),
  EditorFilterItem(
    id: 'swirl',
    name: 'Swirl',
    createConfig: () => SwirlShaderConfiguration()
      ..angle = 1.0
      ..radius = 0.5,
    colorFilter: null,
  ),
  EditorFilterItem(
    id: 'bulge',
    name: 'Bulge',
    createConfig: () => BulgeDistortionShaderConfiguration()
      ..radius = 0.5
      ..scale = 0.3,
    colorFilter: null,
  ),
  EditorFilterItem(
    id: 'zoomBlur',
    name: 'Zoom Blur',
    createConfig: () => ZoomBlurShaderConfiguration()..size = 2.0,
    colorFilter: null,
  ),
  EditorFilterItem(
    id: 'highlights',
    name: 'Shadows',
    createConfig: () => HighlightShadowShaderConfiguration()
      ..highlights = 0.8
      ..shadows = 0.4,
    colorFilter: ColorFilter.matrix(_contrastMatrix(1.15)),
  ),
];

EditorFilterItem getEditorFilterItem(String id) {
  return kAppEditorFilters.firstWhere(
    (f) => f.id == id,
    orElse: () => kAppEditorFilters.first,
  );
}