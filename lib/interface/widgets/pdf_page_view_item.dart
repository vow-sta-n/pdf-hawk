import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfhawk/data/class/editor_overlay_item.dart';
import 'package:pdfhawk/data/res/constants.dart';
import 'package:pdfhawk/data/res/enum.dart';
import 'package:pdfhawk/data/res/theme.dart';
import 'package:pdfhawk/data/res/utils.dart';
import 'package:pdfhawk/interface/dialogs/color_wheel_dialog.dart';
import 'package:pdfhawk/interface/painters/drawing_painter.dart';
import 'package:pdfhawk/interface/painters/shape_painter.dart';
import 'package:pdfhawk/logic/helpers/pdf_helper.dart';

class PdfPageViewItem extends StatefulWidget {
  final PdfPageModel pageModel;
  final int pageIndex;
  final int currentPageIndex;
  final EditorTool activeTool;
  final Color selectedColor;
  final double strokeWidth;
  final List<Offset> currentPoints;
  final ValueChanged<List<Offset>> onDrawingStarted;
  final ValueChanged<List<Offset>> onDrawingUpdated;
  final VoidCallback onDrawingEnded;
  final VoidCallback onLongPressAnnotation;
  final ValueChanged<bool> onZoomChanged;
  final Widget Function(PdfPageModel) buildPageBackground;
  final DrawingPath? selectedAnnotation;
  final Function(PdfPageModel, DrawingPath?) onSelectAnnotation;
  final EditorOverlayItem? selectedOverlayItem;
  final ValueChanged<EditorOverlayItem?>? onSelectOverlayItem;
  final VoidCallback onAnnotationMoved;
  final Function(PdfPageModel, DrawingPath) onDeleteAnnotation;
  final Function(DrawingPath, Color) onUpdateAnnotationColor;
  final List<Color> availableColors;

  const PdfPageViewItem({
    super.key,
    required this.pageModel,
    required this.pageIndex,
    required this.currentPageIndex,
    required this.activeTool,
    required this.selectedColor,
    required this.strokeWidth,
    required this.currentPoints,
    required this.onDrawingStarted,
    required this.onDrawingUpdated,
    required this.onDrawingEnded,
    required this.onLongPressAnnotation,
    required this.onZoomChanged,
    required this.buildPageBackground,
    required this.selectedAnnotation,
    required this.onSelectAnnotation,
    this.selectedOverlayItem,
    this.onSelectOverlayItem,
    required this.onAnnotationMoved,
    required this.onDeleteAnnotation,
    required this.onUpdateAnnotationColor,
    this.availableColors = const [],
  });

  @override
  State<PdfPageViewItem> createState() => _PdfPageViewItemState();
}

class _PdfPageViewItemState extends State<PdfPageViewItem> {
  Widget _buildCornerHandle(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 8.r,
        height: 8.r,
        decoration: BoxDecoration(
          color: royalblue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
      ),
    );
  }

  void _resizeOverlayItem({
    required EditorOverlayItem item,
    required Offset deltaPx,
    required Alignment alignment,
    required double widgetWidth,
    required double widgetHeight,
    required PdfPageModel pageModel,
  }) {
    final deltaDx = deltaPx.dx / widgetWidth;
    final deltaDy = deltaPx.dy / widgetHeight;

    double newWidth = item.width;
    double newHeight = item.height;
    double changeX = 0;
    double changeY = 0;

    // Horizontal resizing
    if (alignment.x > 0) {
      // Right handles (top-right, right-center, bottom-right)
      newWidth = (item.width + deltaDx).clamp(0.0, 0.95);
      changeX = (newWidth - item.width) / 2;
    } else if (alignment.x < 0) {
      // Left handles (top-left, left-center, bottom-left)
      newWidth = (item.width - deltaDx).clamp(0.0, 0.95);
      changeX = -(newWidth - item.width) / 2;
    }

    // Vertical resizing
    if (alignment.y > 0) {
      // Bottom handles (bottom-left, bottom-center, bottom-right)
      newHeight = (item.height + deltaDy).clamp(0.0, 0.95);
      changeY = (newHeight - item.height) / 2;
    } else if (alignment.y < 0) {
      // Top handles (top-left, top-center, top-right)
      newHeight = (item.height - deltaDy).clamp(0.0, 0.95);
      changeY = -(newHeight - item.height) / 2;
    }

    // If scaled down to zero or near zero, automatically delete the element
    if (newWidth <= 0.008 || newHeight <= 0.008) {
      HapticFeedback.mediumImpact();
      setState(() {
        pageModel.overlays.remove(item);
      });
      widget.onSelectOverlayItem?.call(null);
      widget.onAnnotationMoved();
      plainToast(msg: "Element deleted");
      return;
    }

    setState(() {
      item.width = newWidth;
      item.height = newHeight;
      item.position = Offset(
        (item.position.dx + changeX).clamp(0.01, 0.99),
        (item.position.dy + changeY).clamp(0.01, 0.99),
      );
    });
    widget.onAnnotationMoved();
  }

  Widget _buildOverlayResizeHandle({
    required Alignment alignment,
    required double handlePadding,
    required double touchTargetSize,
    required double itemW,
    required double itemH,
    required double widgetWidth,
    required double widgetHeight,
    required EditorOverlayItem item,
    required PdfPageModel pageModel,
  }) {
    double leftPos;
    double topPos;

    if (alignment.x == -1.0) {
      leftPos = handlePadding - (touchTargetSize / 2);
    } else if (alignment.x == 1.0) {
      leftPos = handlePadding + itemW - (touchTargetSize / 2);
    } else {
      leftPos = handlePadding + (itemW / 2) - (touchTargetSize / 2);
    }

    if (alignment.y == -1.0) {
      topPos = handlePadding - (touchTargetSize / 2);
    } else if (alignment.y == 1.0) {
      topPos = handlePadding + itemH - (touchTargetSize / 2);
    } else {
      topPos = handlePadding + (itemH / 2) - (touchTargetSize / 2);
    }

    final minDimension = itemW < itemH ? itemW : itemH;
    final dotSize = (minDimension * 0.12).clamp(4.r, 14.r);
    final borderW = (dotSize * 0.14).clamp(1.0, 2.0);

    return Positioned(
      left: leftPos,
      top: topPos,
      width: touchTargetSize,
      height: touchTargetSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) {
          widget.onSelectOverlayItem?.call(item);
        },
        onPanUpdate: (details) {
          _resizeOverlayItem(
            item: item,
            deltaPx: details.delta,
            alignment: alignment,
            widgetWidth: widgetWidth,
            widgetHeight: widgetHeight,
            pageModel: pageModel,
          );
        },
        child: Center(
          child: Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: royalblue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: borderW),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 3,
                  offset: Offset(0, 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayLayer(
    double widgetWidth,
    double widgetHeight,
    PdfPageModel pageModel,
  ) {
    if (pageModel.overlays.isEmpty) return const SizedBox.shrink();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final item in pageModel.overlays)
          _buildSingleOverlay(item, widgetWidth, widgetHeight, pageModel),
      ],
    );
  }

  Widget _buildSingleOverlay(
    EditorOverlayItem item,
    double widgetWidth,
    double widgetHeight,
    PdfPageModel pageModel,
  ) {
    final itemW = (item.width * widgetWidth).clamp(0.0, widgetWidth);
    final itemH = (item.height * widgetHeight).clamp(0.0, widgetHeight);
    final itemLeft = ((item.position.dx * widgetWidth) - (itemW / 2)).clamp(
      0.0,
      widgetWidth - itemW,
    );
    final itemTop = ((item.position.dy * widgetHeight) - (itemH / 2)).clamp(
      0.0,
      widgetHeight - itemH,
    );

    Widget content;
    if (item.type == ElementType.image && item.imagePath != null) {
      final imgFile = File(item.imagePath!);
      content = imgFile.existsSync()
          ? Image.file(imgFile, fit: BoxFit.contain)
          : const SizedBox.shrink();
    } else if (item.type == ElementType.shape) {
      content = CustomPaint(
        size: Size(itemW, itemH),
        painter: ShapePainter(
          shapeType: item.shapeType,
          fillColor: item.isFilled ? item.fillColor : Colors.transparent,
          borderColor: item.strokeColor,
          borderWidth: item.strokeWidth,
          isFilled: item.isFilled,
        ),
      );
    } else {
      content = const SizedBox.shrink();
    }

    const double handlePadding = 20.0;
    const double touchTargetSize = 36.0;

    final isMoveEnabled = widget.activeTool == EditorTool.select;
    final isResizeEnabled = widget.activeTool == EditorTool.resize;
    final isInteractive = isMoveEnabled || isResizeEnabled;

    final isExplicitlySelected = widget.selectedOverlayItem == item;
    final isSingleElementOnPage = pageModel.overlays.length == 1;
    // Auto-select when only 1 element exists on page, otherwise require tap selection
    final isSelected = isExplicitlySelected ||
        (isSingleElementOnPage && isInteractive);

    return Positioned(
      left: itemLeft - handlePadding,
      top: itemTop - handlePadding,
      width: itemW + (handlePadding * 2),
      height: itemH + (handlePadding * 2),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Overlay content box (tappable to select, draggable when Move tool is active)
          Positioned(
            left: handlePadding,
            top: handlePadding,
            right: handlePadding,
            bottom: handlePadding,
            child: GestureDetector(
              behavior: isInteractive
                  ? HitTestBehavior.opaque
                  : HitTestBehavior.deferToChild,
              onTap: isInteractive
                  ? () {
                      widget.onSelectOverlayItem?.call(item);
                    }
                  : null,
              onPanStart: isInteractive
                  ? (_) {
                      widget.onSelectOverlayItem?.call(item);
                    }
                  : null,
              onPanUpdate: isMoveEnabled
                  ? (details) {
                      setState(() {
                        final newDx =
                            (item.position.dx + (details.delta.dx / widgetWidth))
                                .clamp(0.05, 0.95);
                        final newDy =
                            (item.position.dy + (details.delta.dy / widgetHeight))
                                .clamp(0.05, 0.95);
                        item.position = Offset(newDx, newDy);
                      });
                      widget.onAnnotationMoved();
                    }
                  : null,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected
                        ? royalblue.withValues(alpha: 0.6)
                        : Colors.transparent,
                    width: isSelected ? 1.5 : 0,
                  ),
                  borderRadius: allradius(4.r),
                ),
                child: Opacity(opacity: item.opacity, child: content),
              ),
            ),
          ),

          // 2. Drag Handle next to element (ONLY when MOVE tool is active AND item is selected)
          if (isMoveEnabled && isSelected)
            Positioned(
              top: handlePadding - 24.h,
              left: handlePadding + (itemW / 2) - 18.w,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) {
                  widget.onSelectOverlayItem?.call(item);
                },
                onPanUpdate: (details) {
                  setState(() {
                    final newDx =
                        (item.position.dx + (details.delta.dx / widgetWidth))
                            .clamp(0.05, 0.95);
                    final newDy =
                        (item.position.dy + (details.delta.dy / widgetHeight))
                            .clamp(0.05, 0.95);
                    item.position = Offset(newDx, newDy);
                  });
                  widget.onAnnotationMoved();
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: royalblue,
                    borderRadius: allradius(12.r),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.drag_indicator_rounded,
                        color: Colors.white,
                        size: 14.sp,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 3. Guide points ONLY when RESIZE tool is active AND item is selected
          if (isResizeEnabled && isSelected) ...[
            // 8 Guide Points (4 corners + 4 axis sides)
            _buildOverlayResizeHandle(
              alignment: Alignment.topLeft,
              handlePadding: handlePadding,
              touchTargetSize: touchTargetSize,
              itemW: itemW,
              itemH: itemH,
              widgetWidth: widgetWidth,
              widgetHeight: widgetHeight,
              item: item,
              pageModel: pageModel,
            ),
            _buildOverlayResizeHandle(
              alignment: Alignment.topCenter,
              handlePadding: handlePadding,
              touchTargetSize: touchTargetSize,
              itemW: itemW,
              itemH: itemH,
              widgetWidth: widgetWidth,
              widgetHeight: widgetHeight,
              item: item,
              pageModel: pageModel,
            ),
            _buildOverlayResizeHandle(
              alignment: Alignment.topRight,
              handlePadding: handlePadding,
              touchTargetSize: touchTargetSize,
              itemW: itemW,
              itemH: itemH,
              widgetWidth: widgetWidth,
              widgetHeight: widgetHeight,
              item: item,
              pageModel: pageModel,
            ),
            _buildOverlayResizeHandle(
              alignment: Alignment.centerLeft,
              handlePadding: handlePadding,
              touchTargetSize: touchTargetSize,
              itemW: itemW,
              itemH: itemH,
              widgetWidth: widgetWidth,
              widgetHeight: widgetHeight,
              item: item,
              pageModel: pageModel,
            ),
            _buildOverlayResizeHandle(
              alignment: Alignment.centerRight,
              handlePadding: handlePadding,
              touchTargetSize: touchTargetSize,
              itemW: itemW,
              itemH: itemH,
              widgetWidth: widgetWidth,
              widgetHeight: widgetHeight,
              item: item,
              pageModel: pageModel,
            ),
            _buildOverlayResizeHandle(
              alignment: Alignment.bottomLeft,
              handlePadding: handlePadding,
              touchTargetSize: touchTargetSize,
              itemW: itemW,
              itemH: itemH,
              widgetWidth: widgetWidth,
              widgetHeight: widgetHeight,
              item: item,
              pageModel: pageModel,
            ),
            _buildOverlayResizeHandle(
              alignment: Alignment.bottomCenter,
              handlePadding: handlePadding,
              touchTargetSize: touchTargetSize,
              itemW: itemW,
              itemH: itemH,
              widgetWidth: widgetWidth,
              widgetHeight: widgetHeight,
              item: item,
              pageModel: pageModel,
            ),
            _buildOverlayResizeHandle(
              alignment: Alignment.bottomRight,
              handlePadding: handlePadding,
              touchTargetSize: touchTargetSize,
              itemW: itemW,
              itemH: itemH,
              widgetWidth: widgetWidth,
              widgetHeight: widgetHeight,
              item: item,
              pageModel: pageModel,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pageModel = widget.pageModel;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final pdfWidth = pageModel.width;
            final pdfHeight = pageModel.height;
            final aspectRatio = pdfWidth / pdfHeight;

            double widgetWidth, widgetHeight;
            if (constraints.maxWidth / constraints.maxHeight > aspectRatio) {
              widgetHeight = constraints.maxHeight;
              widgetWidth = constraints.maxHeight * aspectRatio;
            } else {
              widgetWidth = constraints.maxWidth;
              widgetHeight = constraints.maxWidth / aspectRatio;
            }

            final scaleX = widgetWidth / pdfWidth;
            final scaleY = widgetHeight / pdfHeight;

            final isDark = Theme.of(context).brightness == Brightness.dark;
            final isCurrentPageSelected =
                widget.selectedAnnotation != null &&
                pageModel.drawings.contains(widget.selectedAnnotation);

            return SizedBox(
              width: widgetWidth,
              height: widgetHeight,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: allradius(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.45 : 0.12,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Background page rendering
                    Positioned.fill(
                      child: widget.buildPageBackground(pageModel),
                    ),

                    // Page Number Identifier (Top Left - Low Contrast Grey)
                    Positioned(
                      top: 4.h,
                      left: 4.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 3.5.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade800.withValues(alpha: 0.15),
                          borderRadius: allradius(2.r),
                          border: Border.all(
                            color: Colors.grey.shade400.withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          "${widget.pageIndex + 1}",
                          style: GoogleFonts.outfit(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w900,
                            color: arsenic,
                          ),
                        ),
                      ),
                    ),

                    // Canvas paint annotations overlay
                    Positioned.fill(
                      child: CustomPaint(
                        painter: DrawingPainter(
                          paths: pageModel.drawings,
                          currentPoints:
                              widget.pageIndex == widget.currentPageIndex
                              ? widget.currentPoints
                              : [],
                          currentColor: widget.selectedColor,
                          currentStrokeWidth: widget.strokeWidth,
                          isCurrentHighlighter:
                              widget.activeTool == EditorTool.highlighter,
                          scaleX: scaleX,
                          scaleY: scaleY,
                        ),
                      ),
                    ),

                    // Base Gesture Handler for Tap selection & Drawing
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) {
                          final localPos = Offset(
                            details.localPosition.dx / scaleX,
                            details.localPosition.dy / scaleY,
                          );
                          DrawingPath? hitDrawing;
                          for (final drawing in pageModel.drawings.reversed) {
                            if (drawing.hitTest(localPos)) {
                              hitDrawing = drawing;
                              break;
                            }
                          }
                          if (hitDrawing != null) {
                            HapticFeedback.mediumImpact();
                            widget.onSelectAnnotation(pageModel, hitDrawing);
                          } else if (widget.selectedAnnotation != null) {
                            widget.onSelectAnnotation(pageModel, null);
                          }
                        },
                        onLongPress: widget.activeTool == EditorTool.view
                            ? () {
                                HapticFeedback.heavyImpact();
                                widget.onLongPressAnnotation();
                              }
                            : null,
                        onPanStart: (widget.activeTool == EditorTool.pen ||
                                widget.activeTool == EditorTool.highlighter ||
                                widget.activeTool == EditorTool.select ||
                                widget.activeTool == EditorTool.resize)
                            ? (details) {
                                final localPos = Offset(
                                  details.localPosition.dx / scaleX,
                                  details.localPosition.dy / scaleY,
                                );
                                if (widget.activeTool == EditorTool.select ||
                                    widget.activeTool == EditorTool.resize) {
                                  DrawingPath? hitDrawing;
                                  for (final drawing in pageModel.drawings.reversed) {
                                    if (drawing.hitTest(localPos)) {
                                      hitDrawing = drawing;
                                      break;
                                    }
                                  }
                                  if (hitDrawing != null) {
                                    HapticFeedback.mediumImpact();
                                    widget.onSelectAnnotation(pageModel, hitDrawing);
                                  } else if (widget.selectedAnnotation != null) {
                                    widget.onSelectAnnotation(pageModel, null);
                                  }
                                } else {
                                  widget.onDrawingStarted([localPos]);
                                }
                              }
                            : null,
                        onPanUpdate: (widget.activeTool == EditorTool.pen ||
                                widget.activeTool == EditorTool.highlighter ||
                                widget.activeTool == EditorTool.select ||
                                widget.activeTool == EditorTool.resize)
                            ? (details) {
                                final localPos = Offset(
                                  details.localPosition.dx / scaleX,
                                  details.localPosition.dy / scaleY,
                                );
                                if (widget.activeTool == EditorTool.select ||
                                    widget.activeTool == EditorTool.resize) {
                                  if (widget.selectedAnnotation != null &&
                                      pageModel.drawings.contains(widget.selectedAnnotation)) {
                                    final delta = Offset(
                                      details.delta.dx / scaleX,
                                      details.delta.dy / scaleY,
                                    );
                                    setState(() {
                                      widget.selectedAnnotation!.translate(delta);
                                    });
                                  }
                                } else {
                                  widget.onDrawingUpdated([
                                    ...widget.currentPoints,
                                    localPos,
                                  ]);
                                }
                              }
                            : null,
                        onPanEnd: (widget.activeTool == EditorTool.pen ||
                                widget.activeTool == EditorTool.highlighter ||
                                widget.activeTool == EditorTool.select ||
                                widget.activeTool == EditorTool.resize)
                            ? (details) {
                                if (widget.activeTool == EditorTool.select ||
                                    widget.activeTool == EditorTool.resize) {
                                  widget.onAnnotationMoved();
                                } else if (widget.currentPoints.isNotEmpty) {
                                  pageModel.drawings.add(
                                    DrawingPath(
                                      points: List.from(widget.currentPoints),
                                      color: widget.selectedColor,
                                      strokeWidth: widget.strokeWidth,
                                      isHighlighter:
                                          widget.activeTool ==
                                          EditorTool.highlighter,
                                    ),
                                  );
                                  widget.onDrawingEnded();
                                } else {
                                  widget.onDrawingEnded();
                                }
                              }
                            : null,
                      ),
                    ),

                    // Image and Shape Overlays Layer (Placed ON TOP so gestures and delete work!)
                    _buildOverlayLayer(widgetWidth, widgetHeight, pageModel),

                    // Interactive Selection Bounding Box & Floating Action Bar
                    if (isCurrentPageSelected) ...[
                      () {
                        final bounds = widget.selectedAnnotation!.getBounds(
                          padding: 10.0,
                        );
                        final selLeft = (bounds.left * scaleX).clamp(
                          0.0,
                          widgetWidth - 40.0,
                        );
                        final selTop = (bounds.top * scaleY).clamp(
                          0.0,
                          widgetHeight - 40.0,
                        );
                        final selWidth = (bounds.width * scaleX).clamp(
                          40.0,
                          widgetWidth,
                        );
                        final selHeight = (bounds.height * scaleY).clamp(
                          40.0,
                          widgetHeight,
                        );

                        final toolbarTop = (selTop - 52.h) < 10.h
                            ? (selTop + selHeight + 10.h)
                            : (selTop - 52.h);
                        final toolbarLeft = (selLeft + (selWidth / 2) - 75.w)
                            .clamp(
                              8.w,
                              (widgetWidth - 160.w).clamp(8.w, widgetWidth),
                            );

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Draggable Selection Frame
                            Positioned(
                              left: selLeft,
                              top: selTop,
                              width: selWidth,
                              height: selHeight,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onPanUpdate: (details) {
                                  final delta = Offset(
                                    details.delta.dx / scaleX,
                                    details.delta.dy / scaleY,
                                  );
                                  setState(() {
                                    widget.selectedAnnotation!.translate(delta);
                                  });
                                },
                                onPanEnd: (_) {
                                  widget.onAnnotationMoved();
                                  widget.onDrawingEnded();
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: royalblue,
                                      width: 1.5,
                                    ),
                                    borderRadius: allradius(4.r),
                                    color: royalblue.withValues(alpha: 0.06),
                                  ),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      _buildCornerHandle(Alignment.topLeft),
                                      _buildCornerHandle(Alignment.topCenter),
                                      _buildCornerHandle(Alignment.topRight),
                                      _buildCornerHandle(Alignment.centerLeft),
                                      _buildCornerHandle(Alignment.centerRight),
                                      _buildCornerHandle(Alignment.bottomLeft),
                                      _buildCornerHandle(Alignment.bottomCenter),
                                      _buildCornerHandle(Alignment.bottomRight),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Floating Quick-Action Pill (Delete, Edit Color, Close)
                            Positioned(
                              left: toolbarLeft,
                              top: toolbarTop,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8.w,
                                  vertical: 4.h,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1E1E24)
                                      : Colors.white,
                                  borderRadius: allradius(16.r),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white24
                                        : Colors.black12,
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.25,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Main Actions Row
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Edit Color Button (Opens Color Wheel)
                                        GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () async {
                                            HapticFeedback.selectionClick();
                                            final newColor =
                                                await ColorWheelDialog.show(
                                                  context,
                                                  initialColor: widget
                                                      .selectedAnnotation!
                                                      .color,
                                                );
                                            if (newColor != null) {
                                              widget.onUpdateAnnotationColor(
                                                widget.selectedAnnotation!,
                                                newColor,
                                              );
                                            }
                                          },
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 6.w,
                                              vertical: 4.h,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 16.r,
                                                  height: 16.r,
                                                  decoration: BoxDecoration(
                                                    color: widget
                                                        .selectedAnnotation!
                                                        .color,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: Colors.white,
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                ),
                                                Gap(4.w),
                                                Icon(
                                                  Icons.color_lens_outlined,
                                                  size: 13.sp,
                                                  color: isDark
                                                      ? Colors.white70
                                                      : Colors.black87,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Container(
                                          height: 16.h,
                                          width: 1,
                                          color: isDark
                                              ? Colors.white12
                                              : Colors.black12,
                                          margin: EdgeInsets.symmetric(
                                            horizontal: 4.w,
                                          ),
                                        ),

                                        // Delete Button
                                        GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () =>
                                              widget.onDeleteAnnotation(
                                                pageModel,
                                                widget.selectedAnnotation!,
                                              ),
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 6.w,
                                              vertical: 4.h,
                                            ),
                                            child: Icon(
                                              Icons.delete_outline_rounded,
                                              size: 18.r,
                                              color: Colors.redAccent,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          height: 16.h,
                                          width: 1,
                                          color: isDark
                                              ? Colors.white12
                                              : Colors.black12,
                                          margin: EdgeInsets.symmetric(
                                            horizontal: 4.w,
                                          ),
                                        ),

                                        // Deselect Button
                                        GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () =>
                                              widget.onSelectAnnotation(
                                                pageModel,
                                                null,
                                              ),
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 4.w,
                                              vertical: 4.h,
                                            ),
                                            child: Icon(
                                              Icons.close_rounded,
                                              size: 16.r,
                                              color: isDark
                                                  ? Colors.white60
                                                  : Colors.black54,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }(),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
