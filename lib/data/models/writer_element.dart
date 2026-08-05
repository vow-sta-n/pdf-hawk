import 'package:pdfhawk/data/res/enum.dart';

class WriterElement {
  final String id;
  final ElementType type;

  // Layout properties
  double x;
  double y;
  double width;
  double height;
  bool isOverlay;

  // Text specific properties (retained for elements that are text overlays if needed)
  String textContent;
  String fontFamily;
  double fontSize;
  bool isBold;
  bool isItalic;
  bool isUnderline;
  bool isStrikethrough;
  int? highlightColorValue; // ARGB int
  int? textColorValue;
  String? linkUrl;

  // Image specific properties
  String? imagePath;
  double rotation; // in degrees
  double cropLeft; // percentage/fraction of crop (0.0 to 1.0)
  double cropRight;
  double cropTop;
  double cropBottom;

  // Shape specific properties
  ShapeType? shapeType;
  int? fillColorValue;
  int? borderColorValue;
  double borderWidth;

  WriterElement({
    required this.id,
    required this.type,
    this.x = 20.0,
    this.y = 20.0,
    this.width = 200.0,
    this.height = 100.0,
    this.isOverlay = true,
    this.textContent = "",
    this.fontFamily = "Roboto",
    this.fontSize = 14.0,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.isStrikethrough = false,
    this.highlightColorValue,
    this.textColorValue,
    this.linkUrl,
    this.imagePath,
    this.rotation = 0.0,
    this.cropLeft = 0.0,
    this.cropRight = 0.0,
    this.cropTop = 0.0,
    this.cropBottom = 0.0,
    this.shapeType,
    this.fillColorValue,
    this.borderColorValue,
    this.borderWidth = 1.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'isOverlay': isOverlay,
      'textContent': textContent,
      'fontFamily': fontFamily,
      'fontSize': fontSize,
      'isBold': isBold,
      'isItalic': isItalic,
      'isUnderline': isUnderline,
      'isStrikethrough': isStrikethrough,
      'highlightColorValue': highlightColorValue,
      'textColorValue': textColorValue,
      'linkUrl': linkUrl,
      'imagePath': imagePath,
      'rotation': rotation,
      'cropLeft': cropLeft,
      'cropRight': cropRight,
      'cropTop': cropTop,
      'cropBottom': cropBottom,
      'shapeType': shapeType?.name,
      'fillColorValue': fillColorValue,
      'borderColorValue': borderColorValue,
      'borderWidth': borderWidth,
    };
  }

  factory WriterElement.fromJson(Map<String, dynamic> json) {
    return WriterElement(
      id: json['id'] as String,
      type: ElementType.values.firstWhere((e) => e.name == json['type']),
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      isOverlay: json['isOverlay'] as bool? ?? true,
      textContent: json['textContent'] as String? ?? "",
      fontFamily: json['fontFamily'] as String? ?? "Roboto",
      fontSize: (json['fontSize'] as num? ?? 14.0).toDouble(),
      isBold: json['isBold'] as bool? ?? false,
      isItalic: json['isItalic'] as bool? ?? false,
      isUnderline: json['isUnderline'] as bool? ?? false,
      isStrikethrough: json['isStrikethrough'] as bool? ?? false,
      highlightColorValue: json['highlightColorValue'] as int?,
      textColorValue: json['textColorValue'] as int?,
      linkUrl: json['linkUrl'] as String?,
      imagePath: json['imagePath'] as String?,
      rotation: (json['rotation'] as num? ?? 0.0).toDouble(),
      cropLeft: (json['cropLeft'] as num? ?? 0.0).toDouble(),
      cropRight: (json['cropRight'] as num? ?? 0.0).toDouble(),
      cropTop: (json['cropTop'] as num? ?? 0.0).toDouble(),
      cropBottom: (json['cropBottom'] as num? ?? 0.0).toDouble(),
      shapeType: json['shapeType'] != null
          ? ShapeType.values.firstWhere((e) => e.name == json['shapeType'])
          : null,
      fillColorValue: json['fillColorValue'] as int?,
      borderColorValue: json['borderColorValue'] as int?,
      borderWidth: (json['borderWidth'] as num? ?? 1.0).toDouble(),
    );
  }

  WriterElement copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    bool? isOverlay,
    String? textContent,
    String? fontFamily,
    double? fontSize,
    bool? isBold,
    bool? isItalic,
    bool? isUnderline,
    bool? isStrikethrough,
    int? highlightColorValue,
    int? textColorValue,
    String? linkUrl,
    String? imagePath,
    double? rotation,
    double? cropLeft,
    double? cropRight,
    double? cropTop,
    double? cropBottom,
    ShapeType? shapeType,
    int? fillColorValue,
    int? borderColorValue,
    double? borderWidth,
  }) {
    return WriterElement(
      id: id,
      type: type,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      isOverlay: isOverlay ?? this.isOverlay,
      textContent: textContent ?? this.textContent,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      isUnderline: isUnderline ?? this.isUnderline,
      isStrikethrough: isStrikethrough ?? this.isStrikethrough,
      highlightColorValue: highlightColorValue ?? this.highlightColorValue,
      textColorValue: textColorValue ?? this.textColorValue,
      linkUrl: linkUrl ?? this.linkUrl,
      imagePath: imagePath ?? this.imagePath,
      rotation: rotation ?? this.rotation,
      cropLeft: cropLeft ?? this.cropLeft,
      cropRight: cropRight ?? this.cropRight,
      cropTop: cropTop ?? this.cropTop,
      cropBottom: cropBottom ?? this.cropBottom,
      shapeType: shapeType ?? this.shapeType,
      fillColorValue: fillColorValue ?? this.fillColorValue,
      borderColorValue: borderColorValue ?? this.borderColorValue,
      borderWidth: borderWidth ?? this.borderWidth,
    );
  }
}
