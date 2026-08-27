/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */


import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pdfhawk/data/res/constants.dart';

class ResizeDragWrapper extends StatefulWidget {
  final Widget child;
  final double x;
  final double y;
  final double width;
  final double height;
  final bool isSelected;
  final ValueChanged<Rect> onRectChanged;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onLongPress;

  const ResizeDragWrapper({
    super.key,
    required this.child,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.isSelected,
    required this.onRectChanged,
    required this.onTap,
    required this.onDoubleTap,
    required this.onLongPress,
  });

  @override
  State<ResizeDragWrapper> createState() => _ResizeDragWrapperState();
}

class _ResizeDragWrapperState extends State<ResizeDragWrapper> {
  @override
  Widget build(BuildContext context) {
    final handleSize = 12.r;
    final halfHandle = handleSize / 2;

    return Positioned(
      left: widget.x - (widget.isSelected ? halfHandle : 0),
      top: widget.y - (widget.isSelected ? halfHandle : 0),
      width: widget.width + (widget.isSelected ? handleSize : 0),
      height: widget.height + (widget.isSelected ? handleSize : 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Dimension Tooltip Badge
          if (widget.isSelected)
            Positioned(
              top: -30,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: allradius(6.r),
                  ),
                  child: Text(
                    "${widget.width.toInt()} × ${widget.height.toInt()} px",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

          // Content
          Positioned(
            left: widget.isSelected ? halfHandle : 0,
            top: widget.isSelected ? halfHandle : 0,
            width: widget.width,
            height: widget.height,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
              onDoubleTap: widget.onDoubleTap,
              onLongPress: widget.onLongPress,
              onPanUpdate: widget.isSelected
                  ? (details) {
                      widget.onRectChanged(
                        Rect.fromLTWH(
                          widget.x + details.delta.dx,
                          widget.y + details.delta.dy,
                          widget.width,
                          widget.height,
                        ),
                      );
                    }
                  : null,
              child: Container(
                decoration: BoxDecoration(
                  border: widget.isSelected
                      ? Border.all(color: Colors.teal.shade500, width: 1.5)
                      : null,
                ),
                child: widget.child,
              ),
            ),
          ),

          // Resizing Handles (only when selected)
          if (widget.isSelected) ...[
            // Top Left
            Positioned(
              left: 0,
              top: 0,
              width: handleSize,
              height: handleSize,
              child: GestureDetector(
                onPanUpdate: (details) {
                  widget.onRectChanged(
                    Rect.fromLTRB(
                      widget.x + details.delta.dx,
                      widget.y + details.delta.dy,
                      widget.x + widget.width,
                      widget.y + widget.height,
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.teal.shade600, width: 1.5),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 2),
                    ],
                  ),
                ),
              ),
            ),

            // Top Right
            Positioned(
              right: 0,
              top: 0,
              width: handleSize,
              height: handleSize,
              child: GestureDetector(
                onPanUpdate: (details) {
                  widget.onRectChanged(
                    Rect.fromLTRB(
                      widget.x,
                      widget.y + details.delta.dy,
                      widget.x + widget.width + details.delta.dx,
                      widget.y + widget.height,
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.teal.shade600, width: 1.5),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 2),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Left
            Positioned(
              left: 0,
              bottom: 0,
              width: handleSize,
              height: handleSize,
              child: GestureDetector(
                onPanUpdate: (details) {
                  widget.onRectChanged(
                    Rect.fromLTRB(
                      widget.x + details.delta.dx,
                      widget.y,
                      widget.x + widget.width,
                      widget.y + widget.height + details.delta.dy,
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.teal.shade600, width: 1.5),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 2),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Right
            Positioned(
              right: 0,
              bottom: 0,
              width: handleSize,
              height: handleSize,
              child: GestureDetector(
                onPanUpdate: (details) {
                  widget.onRectChanged(
                    Rect.fromLTWH(
                      widget.x,
                      widget.y,
                      widget.width + details.delta.dx,
                      widget.height + details.delta.dy,
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.teal.shade600, width: 1.5),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 2),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

