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
  void _resizeOverlayItem({
    required EditorOverlayItem item,
    required Offset deltaPx,
    required Alignment alignment,
    required double widgetWidth,
    required double widgetHeight,
    required PdfPageModel pageModel,
  }) {
    if (widgetWidth <= 0 || widgetHeight <= 0) return;
    final deltaDx = deltaPx.dx / widgetWidth;
    final deltaDy = deltaPx.dy / widgetHeight;

    final normLeft = item.position.dx - (item.width / 2);
    final normRight = item.position.dx + (item.width / 2);
    final normTop = item.position.dy - (item.height / 2);
    final normBottom = item.position.dy + (item.height / 2);

    const minSize = 0.03; // Minimum normalized size (~20-25px)

    double newLeft = normLeft;
    double newRight = normRight;
    double newTop = normTop;
    double newBottom = normBottom;

    // Horizontal adjustment
    if (alignment.x < 0) {
      newLeft = (normLeft + deltaDx).clamp(0.0, normRight - minSize);
    } else if (alignment.x > 0) {
      newRight = (normRight + deltaDx).clamp(normLeft + minSize, 1.0);
    }

    // Vertical adjustment
    if (alignment.y < 0) {
      newTop = (normTop + deltaDy).clamp(0.0, normBottom - minSize);
    } else if (alignment.y > 0) {
      newBottom = (normBottom + deltaDy).clamp(normTop + minSize, 1.0);
    }

    setState(() {
      item.width = (newRight - newLeft).clamp(minSize, 1.0);
      item.height = (newBottom - newTop).clamp(minSize, 1.0);
      item.position = Offset(
        (newLeft + newRight) / 2,
        (newTop + newBottom) / 2,
      );
    });
    widget.onAnnotationMoved();
  }

  void _resizeDrawingPath({
    required DrawingPath drawing,
    required Offset deltaPx,
    required Alignment alignment,
    required double widgetWidth,
    required double widgetHeight,
    required double scaleX,
    required double scaleY,
    required PdfPageModel pageModel,
  }) {
    if (scaleX <= 0 || scaleY <= 0) return;
    final bounds = drawing.getBounds(padding: 0.0);
    if (bounds.width == 0 || bounds.height == 0) return;

    final pxLeft = bounds.left * scaleX;
    final pxRight = bounds.right * scaleX;
    final pxTop = bounds.top * scaleY;
    final pxBottom = bounds.bottom * scaleY;

    const minPx = 20.0;

    double newPxLeft = pxLeft;
    double newPxRight = pxRight;
    double newPxTop = pxTop;
    double newPxBottom = pxBottom;

    if (alignment.x < 0) {
      newPxLeft = (pxLeft + deltaPx.dx).clamp(0.0, pxRight - minPx);
    } else if (alignment.x > 0) {
      newPxRight = (pxRight + deltaPx.dx).clamp(pxLeft + minPx, widgetWidth);
    }

    if (alignment.y < 0) {
      newPxTop = (pxTop + deltaPx.dy).clamp(0.0, pxBottom - minPx);
    } else if (alignment.y > 0) {
      newPxBottom = (pxBottom + deltaPx.dy).clamp(pxTop + minPx, widgetHeight);
    }

    final newBounds = Rect.fromLTRB(
      newPxLeft / scaleX,
      newPxTop / scaleY,
      newPxRight / scaleX,
      newPxBottom / scaleY,
    );

    setState(() {
      drawing.scaleFromBounds(bounds, newBounds);
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

    final dotSize = 12.r;
    final borderW = 1.8;

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
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: royalblue, width: borderW),
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

  Widget _buildDrawingResizeHandle({
    required Alignment alignment,
    required double touchTargetSize,
    required double selLeft,
    required double selTop,
    required double selWidth,
    required double selHeight,
    required double widgetWidth,
    required double widgetHeight,
    required double scaleX,
    required double scaleY,
    required DrawingPath drawing,
    required PdfPageModel pageModel,
  }) {
    double leftPos;
    double topPos;

    if (alignment.x == -1.0) {
      leftPos = selLeft - (touchTargetSize / 2);
    } else if (alignment.x == 1.0) {
      leftPos = selLeft + selWidth - (touchTargetSize / 2);
    } else {
      leftPos = selLeft + (selWidth / 2) - (touchTargetSize / 2);
    }

    if (alignment.y == -1.0) {
      topPos = selTop - (touchTargetSize / 2);
    } else if (alignment.y == 1.0) {
      topPos = selTop + selHeight - (touchTargetSize / 2);
    } else {
      topPos = selTop + (selHeight / 2) - (touchTargetSize / 2);
    }

    final dotSize = 12.r;
    final borderW = 1.8;

    return Positioned(
      left: leftPos,
      top: topPos,
      width: touchTargetSize,
      height: touchTargetSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) {
          _resizeDrawingPath(
            drawing: drawing,
            deltaPx: details.delta,
            alignment: alignment,
            widgetWidth: widgetWidth,
            widgetHeight: widgetHeight,
            scaleX: scaleX,
            scaleY: scaleY,
            pageModel: pageModel,
          );
        },
        child: Center(
          child: Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: royalblue, width: borderW),
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
              onPanStart: isMoveEnabled
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
                        ? royalblue
                        : Colors.transparent,
                    width: isSelected ? 1.5 : 0,
                  ),
                  borderRadius: allradius(4.r),
                ),
                child: Opacity(opacity: item.opacity, child: content),
              ),
            ),
          ),

          // 2. Drag Handle on top of element (ONLY when MOVE tool is active AND item is selected)
          if (isMoveEnabled && isSelected)
            Positioned(
              top: handlePadding - 26.h,
              left: handlePadding + (itemW / 2) - 20.w,
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
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.5.h),
                  decoration: BoxDecoration(
                    color: royalblue,
                    borderRadius: allradius(14.r),
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
                        Icons.open_with_rounded,
                        color: Colors.white,
                        size: 13.sp,
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
                          } else {
                            widget.onSelectAnnotation(pageModel, null);
                            widget.onSelectOverlayItem?.call(null);
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
                                widget.activeTool == EditorTool.select)
                            ? (details) {
                                final localPos = Offset(
                                  details.localPosition.dx / scaleX,
                                  details.localPosition.dy / scaleY,
                                );
                                if (widget.activeTool == EditorTool.select) {
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
                                widget.activeTool == EditorTool.select)
                            ? (details) {
                                final localPos = Offset(
                                  details.localPosition.dx / scaleX,
                                  details.localPosition.dy / scaleY,
                                );
                                if (widget.activeTool == EditorTool.select) {
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
                                widget.activeTool == EditorTool.select)
                            ? (details) {
                                if (widget.activeTool == EditorTool.select) {
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

                        final isMoveActive =
                            widget.activeTool == EditorTool.select;
                        final isResizeActive =
                            widget.activeTool == EditorTool.resize;

                        final toolbarTop = (selTop - 64.h) < 10.h
                            ? (selTop + selHeight + 14.h)
                            : (selTop - 64.h);
                        final toolbarLeft = (selLeft + (selWidth / 2) - 75.w)
                            .clamp(
                              8.w,
                              (widgetWidth - 160.w).clamp(8.w, widgetWidth),
                            );
                        const double touchTargetSize = 36.0;

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // 1. Selection Frame Border (draggable only when MOVE tool is active)
                            Positioned(
                              left: selLeft,
                              top: selTop,
                              width: selWidth,
                              height: selHeight,
                              child: GestureDetector(
                                behavior: isMoveActive
                                    ? HitTestBehavior.opaque
                                    : HitTestBehavior.deferToChild,
                                onPanUpdate: isMoveActive
                                    ? (details) {
                                        final delta = Offset(
                                          details.delta.dx / scaleX,
                                          details.delta.dy / scaleY,
                                        );
                                        setState(() {
                                          widget.selectedAnnotation!
                                              .translate(delta);
                                        });
                                      }
                                    : null,
                                onPanEnd: isMoveActive
                                    ? (_) {
                                        widget.onAnnotationMoved();
                                        widget.onDrawingEnded();
                                      }
                                    : null,
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: royalblue,
                                      width: 1.5,
                                    ),
                                    borderRadius: allradius(4.r),
                                    color: royalblue.withValues(alpha: 0.06),
                                  ),
                                ),
                              ),
                            ),

                            // 2. Drag Handle on TOP of drawing (ONLY when MOVE tool is active)
                            if (isMoveActive)
                              Positioned(
                                top: selTop - 26.h,
                                left: selLeft + (selWidth / 2) - 20.w,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onPanUpdate: (details) {
                                    final delta = Offset(
                                      details.delta.dx / scaleX,
                                      details.delta.dy / scaleY,
                                    );
                                    setState(() {
                                      widget.selectedAnnotation!
                                          .translate(delta);
                                    });
                                  },
                                  onPanEnd: (_) {
                                    widget.onAnnotationMoved();
                                    widget.onDrawingEnded();
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8.w,
                                      vertical: 3.5.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: royalblue,
                                      borderRadius: allradius(14.r),
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
                                          Icons.open_with_rounded,
                                          color: Colors.white,
                                          size: 13.sp,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                            // 3. 8 Resize handles (ONLY when RESIZE tool is active)
                            if (isResizeActive) ...[
                              _buildDrawingResizeHandle(
                                alignment: Alignment.topLeft,
                                touchTargetSize: touchTargetSize,
                                selLeft: selLeft,
                                selTop: selTop,
                                selWidth: selWidth,
                                selHeight: selHeight,
                                widgetWidth: widgetWidth,
                                widgetHeight: widgetHeight,
                                scaleX: scaleX,
                                scaleY: scaleY,
                                drawing: widget.selectedAnnotation!,
                                pageModel: pageModel,
                              ),
                              _buildDrawingResizeHandle(
                                alignment: Alignment.topCenter,
                                touchTargetSize: touchTargetSize,
                                selLeft: selLeft,
                                selTop: selTop,
                                selWidth: selWidth,
                                selHeight: selHeight,
                                widgetWidth: widgetWidth,
                                widgetHeight: widgetHeight,
                                scaleX: scaleX,
                                scaleY: scaleY,
                                drawing: widget.selectedAnnotation!,
                                pageModel: pageModel,
                              ),
                              _buildDrawingResizeHandle(
                                alignment: Alignment.topRight,
                                touchTargetSize: touchTargetSize,
                                selLeft: selLeft,
                                selTop: selTop,
                                selWidth: selWidth,
                                selHeight: selHeight,
                                widgetWidth: widgetWidth,
                                widgetHeight: widgetHeight,
                                scaleX: scaleX,
                                scaleY: scaleY,
                                drawing: widget.selectedAnnotation!,
                                pageModel: pageModel,
                              ),
                              _buildDrawingResizeHandle(
                                alignment: Alignment.centerLeft,
                                touchTargetSize: touchTargetSize,
                                selLeft: selLeft,
                                selTop: selTop,
                                selWidth: selWidth,
                                selHeight: selHeight,
                                widgetWidth: widgetWidth,
                                widgetHeight: widgetHeight,
                                scaleX: scaleX,
                                scaleY: scaleY,
                                drawing: widget.selectedAnnotation!,
                                pageModel: pageModel,
                              ),
                              _buildDrawingResizeHandle(
                                alignment: Alignment.centerRight,
                                touchTargetSize: touchTargetSize,
                                selLeft: selLeft,
                                selTop: selTop,
                                selWidth: selWidth,
                                selHeight: selHeight,
                                widgetWidth: widgetWidth,
                                widgetHeight: widgetHeight,
                                scaleX: scaleX,
                                scaleY: scaleY,
                                drawing: widget.selectedAnnotation!,
                                pageModel: pageModel,
                              ),
                              _buildDrawingResizeHandle(
                                alignment: Alignment.bottomLeft,
                                touchTargetSize: touchTargetSize,
                                selLeft: selLeft,
                                selTop: selTop,
                                selWidth: selWidth,
                                selHeight: selHeight,
                                widgetWidth: widgetWidth,
                                widgetHeight: widgetHeight,
                                scaleX: scaleX,
                                scaleY: scaleY,
                                drawing: widget.selectedAnnotation!,
                                pageModel: pageModel,
                              ),
                              _buildDrawingResizeHandle(
                                alignment: Alignment.bottomCenter,
                                touchTargetSize: touchTargetSize,
                                selLeft: selLeft,
                                selTop: selTop,
                                selWidth: selWidth,
                                selHeight: selHeight,
                                widgetWidth: widgetWidth,
                                widgetHeight: widgetHeight,
                                scaleX: scaleX,
                                scaleY: scaleY,
                                drawing: widget.selectedAnnotation!,
                                pageModel: pageModel,
                              ),
                              _buildDrawingResizeHandle(
                                alignment: Alignment.bottomRight,
                                touchTargetSize: touchTargetSize,
                                selLeft: selLeft,
                                selTop: selTop,
                                selWidth: selWidth,
                                selHeight: selHeight,
                                widgetWidth: widgetWidth,
                                widgetHeight: widgetHeight,
                                scaleX: scaleX,
                                scaleY: scaleY,
                                drawing: widget.selectedAnnotation!,
                                pageModel: pageModel,
                              ),
                            ],

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
