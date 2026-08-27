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
  final Function(PdfPageModel, List<Offset>) onErase;
  final VoidCallback onLongPressAnnotation;
  final ValueChanged<bool> onZoomChanged;
  final Widget Function(PdfPageModel) buildPageBackground;
  final DrawingPath? selectedAnnotation;
  final Function(PdfPageModel, DrawingPath?) onSelectAnnotation;
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
    required this.onErase,
    required this.onLongPressAnnotation,
    required this.onZoomChanged,
    required this.buildPageBackground,
    required this.selectedAnnotation,
    required this.onSelectAnnotation,
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
    final itemW = (item.width * widgetWidth).clamp(28.0, widgetWidth);
    final itemH = (item.height * widgetHeight).clamp(28.0, widgetHeight);
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
    const double touchTargetSize = 40.0;

    return Positioned(
      left: itemLeft - handlePadding,
      top: itemTop - handlePadding,
      width: itemW + (handlePadding * 2),
      height: itemH + (handlePadding * 2),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Draggable overlay content
          Positioned(
            left: handlePadding,
            top: handlePadding,
            right: handlePadding,
            bottom: handlePadding,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
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
                decoration: BoxDecoration(
                  border: Border.all(
                    color: royalblue.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  borderRadius: allradius(4.r),
                ),
                child: Opacity(opacity: item.opacity, child: content),
              ),
            ),
          ),

          // 2. Corner resize handle (Bottom Right)
          Positioned(
            right: handlePadding - (touchTargetSize / 2),
            bottom: handlePadding - (touchTargetSize / 2),
            width: touchTargetSize,
            height: touchTargetSize,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (details) {
                setState(() {
                  final newW = (item.width + (details.delta.dx / widgetWidth))
                      .clamp(0.06, 0.95);
                  final newH = (item.height + (details.delta.dy / widgetHeight))
                      .clamp(0.06, 0.95);
                  item.width = newW;
                  item.height = newH;
                });
                widget.onAnnotationMoved();
              },
              child: Center(
                child: Container(
                  width: 26.r,
                  height: 26.r,
                  decoration: BoxDecoration(
                    color: royalblue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.open_in_full_rounded,
                      size: 13.r,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. Delete button on top right of overlay
          Positioned(
            right: handlePadding - (touchTargetSize / 2),
            top: handlePadding - (touchTargetSize / 2),
            width: touchTargetSize,
            height: touchTargetSize,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.mediumImpact();
                setState(() {
                  pageModel.overlays.remove(item);
                });
                widget.onAnnotationMoved();
                plainToast(msg: "Overlay deleted");
              },
              child: Center(
                child: Container(
                  width: 26.r,
                  height: 26.r,
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.close_rounded,
                      size: 15.r,
                      color: Colors.white,
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
                        onPanStart: widget.activeTool != EditorTool.view
                            ? (details) {
                                final localPos = Offset(
                                  details.localPosition.dx / scaleX,
                                  details.localPosition.dy / scaleY,
                                );
                                if (widget.activeTool == EditorTool.eraser) {
                                  widget.onErase(pageModel, [localPos]);
                                } else {
                                  widget.onDrawingStarted([localPos]);
                                }
                              }
                            : null,
                        onPanUpdate: widget.activeTool != EditorTool.view
                            ? (details) {
                                final localPos = Offset(
                                  details.localPosition.dx / scaleX,
                                  details.localPosition.dy / scaleY,
                                );
                                if (widget.activeTool == EditorTool.eraser) {
                                  widget.onErase(pageModel, [localPos]);
                                } else {
                                  widget.onDrawingUpdated([
                                    ...widget.currentPoints,
                                    localPos,
                                  ]);
                                }
                              }
                            : null,
                        onPanEnd: widget.activeTool != EditorTool.view
                            ? (details) {
                                if (widget.activeTool != EditorTool.eraser &&
                                    widget.currentPoints.isNotEmpty) {
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
                                }
                                widget.onDrawingEnded();
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
                                      _buildCornerHandle(Alignment.topRight),
                                      _buildCornerHandle(Alignment.bottomLeft),
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
