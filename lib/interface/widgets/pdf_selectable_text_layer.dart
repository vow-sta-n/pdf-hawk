/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfhawk/data/res/theme.dart';
import 'package:pdfhawk/data/res/utils.dart';
import 'package:pdfhawk/logic/helpers/pdf_helper.dart';

/// An interactive overlay widget that provides word-accurate PDF text selection,
/// interactive draggable start/end handles to adjust text selection, and a floating
/// quick-action pill positioned comfortably above the selected text.
class PdfSelectableTextLayer extends StatefulWidget {
  final File? pdfFile;
  final int pageNumber;
  final double pageWidth;
  final double pageHeight;
  final double scaleX;
  final double scaleY;
  final bool isSelectionEnabled;
  final TransformationController? transformationController;
  final Function(Rect bounds, String text)? onHighlightText;
  final VoidCallback? onOpenExtractText;

  const PdfSelectableTextLayer({
    super.key,
    required this.pdfFile,
    required this.pageNumber,
    required this.pageWidth,
    required this.pageHeight,
    required this.scaleX,
    required this.scaleY,
    required this.isSelectionEnabled,
    this.transformationController,
    this.onHighlightText,
    this.onOpenExtractText,
  });

  @override
  State<PdfSelectableTextLayer> createState() => PdfSelectableTextLayerState();
}

/// Model representing an individual character in the PDF document
class PdfTextCharModel {
  final String char;
  final Rect bounds;
  final int lineIndex;
  final int charIndexInLine;
  final int globalIndex;
  final int wordIndex;

  const PdfTextCharModel({
    required this.char,
    required this.bounds,
    required this.lineIndex,
    required this.charIndexInLine,
    required this.globalIndex,
    this.wordIndex = -1,
  });
}

class PdfSelectableTextLayerState extends State<PdfSelectableTextLayer> {
  List<PdfTextLineModel>? _textLines;
  final List<PdfTextCharModel> _allChars = [];
  final Map<int, List<PdfTextCharModel>> _lineCharsMap = {};
  bool _isLoading = false;

  int _startIndex = -1;
  int _endIndex = -1;
  Rect? _selectionBoundsInWidgetPx;

  bool _isDraggingHandle = false;
  Offset _touchOffsetPdf = Offset.zero;

  static final Map<String, List<double>> _charWidthCache = {};

  bool get hasSelection =>
      _startIndex >= 0 &&
      _endIndex >= 0 &&
      _startIndex < _allChars.length &&
      _endIndex < _allChars.length;

  String get selectedText {
    if (!hasSelection) return '';
    final from = _startIndex <= _endIndex ? _startIndex : _endIndex;
    final to = _startIndex <= _endIndex ? _endIndex : _startIndex;

    final buffer = StringBuffer();
    int? lastLineIndex;
    for (int i = from; i <= to && i < _allChars.length; i++) {
      final ch = _allChars[i];
      if (lastLineIndex != null && ch.lineIndex != lastLineIndex) {
        buffer.write('\n');
      }
      buffer.write(ch.char);
      lastLineIndex = ch.lineIndex;
    }
    return buffer.toString();
  }

  @override
  void initState() {
    super.initState();
    _loadTextLines();
  }

  @override
  void didUpdateWidget(covariant PdfSelectableTextLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pdfFile?.path != widget.pdfFile?.path ||
        oldWidget.pageNumber != widget.pageNumber) {
      clearSelection();
      _loadTextLines();
    } else if (oldWidget.scaleX != widget.scaleX ||
        oldWidget.scaleY != widget.scaleY) {
      _recalculateBounds();
    }
  }

  Future<void> _loadTextLines() async {
    if (widget.pdfFile == null) {
      if (mounted) {
        setState(() {
          _textLines = [];
          _allChars.clear();
          _lineCharsMap.clear();
        });
      }
      return;
    }

    if (_isLoading) return;
    _isLoading = true;

    try {
      final lines = await PdfHelper.extractPageTextLines(
        pdfFile: widget.pdfFile!,
        pageNumber: widget.pageNumber,
      );
      if (mounted) {
        final allChars = <PdfTextCharModel>[];
        final lineMap = <int, List<PdfTextCharModel>>{};

        for (int lineIdx = 0; lineIdx < lines.length; lineIdx++) {
          final l = lines[lineIdx];
          final lineChars = <PdfTextCharModel>[];

          for (int wordIdx = 0; wordIdx < l.words.length; wordIdx++) {
            final w = l.words[wordIdx];

            // If there was a previous word on this line, check for whitespace gap
            if (wordIdx > 0) {
              final prevWord = l.words[wordIdx - 1];
              final gap = w.bounds.left - prevWord.bounds.right;
              if (gap > 0.5) {
                final spaceBounds = Rect.fromLTRB(
                  prevWord.bounds.right,
                  prevWord.bounds.top,
                  w.bounds.left,
                  prevWord.bounds.bottom,
                );
                final spaceModel = PdfTextCharModel(
                  char: ' ',
                  bounds: spaceBounds,
                  lineIndex: lineIdx,
                  charIndexInLine: lineChars.length,
                  globalIndex: allChars.length,
                  wordIndex: -1,
                );
                allChars.add(spaceModel);
                lineChars.add(spaceModel);
              }
            }

            final wordText = w.text;
            if (wordText.length <= 1) {
              final charModel = PdfTextCharModel(
                char: wordText,
                bounds: w.bounds,
                lineIndex: lineIdx,
                charIndexInLine: lineChars.length,
                globalIndex: allChars.length,
                wordIndex: wordIdx,
              );
              allChars.add(charModel);
              lineChars.add(charModel);
            } else {
              final charWidths = _estimateCharWidths(wordText, l.fontSize);
              final totalEst = charWidths.fold<double>(0.0, (a, b) => a + b);
              final scale = totalEst > 0 ? w.bounds.width / totalEst : 1.0;

              double curX = w.bounds.left;
              for (int ci = 0; ci < wordText.length; ci++) {
                final isLast = ci == wordText.length - 1;
                final charW = charWidths[ci] * scale;
                final charBounds = Rect.fromLTWH(
                  curX,
                  w.bounds.top,
                  isLast
                      ? (w.bounds.right - curX).clamp(0.0, double.infinity)
                      : charW,
                  w.bounds.height,
                );
                curX += charW;

                final charModel = PdfTextCharModel(
                  char: wordText[ci],
                  bounds: charBounds,
                  lineIndex: lineIdx,
                  charIndexInLine: lineChars.length,
                  globalIndex: allChars.length,
                  wordIndex: wordIdx,
                );
                allChars.add(charModel);
                lineChars.add(charModel);
              }
            }
          }

          lineMap[lineIdx] = lineChars;
        }

        setState(() {
          _textLines = lines;
          _allChars.clear();
          _allChars.addAll(allChars);
          _lineCharsMap.clear();
          _lineCharsMap.addAll(lineMap);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _textLines = [];
          _allChars.clear();
          _lineCharsMap.clear();
          _isLoading = false;
        });
      }
    }
  }

  static List<double> _estimateCharWidths(String text, double fontSize) {
    if (_charWidthCache.containsKey(text)) {
      return _charWidthCache[text]!;
    }
    final size = fontSize > 0 ? fontSize : 12.0;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: size),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final widths = <double>[];
    for (int i = 0; i < text.length; i++) {
      final boxes = painter.getBoxesForSelection(
        TextSelection(baseOffset: i, extentOffset: i + 1),
      );
      if (boxes.isNotEmpty) {
        widths.add(boxes.first.toRect().width);
      } else {
        widths.add(size * 0.5);
      }
    }
    _charWidthCache[text] = widths;
    return widths;
  }

  int _findClosestCharIndex(Offset pdfPoint, {required bool isStart}) {
    if (_allChars.isEmpty || _textLines == null || _textLines!.isEmpty) {
      return -1;
    }

    int bestLineIndex = 0;
    double bestScore = double.infinity;

    for (int i = 0; i < _textLines!.length; i++) {
      final line = _textLines![i];
      final lineChars = _lineCharsMap[i];
      if (lineChars == null || lineChars.isEmpty) continue;

      // Vertical distance: 0 if within line top..bottom
      double vDist = 0.0;
      if (pdfPoint.dy < line.bounds.top) {
        vDist = line.bounds.top - pdfPoint.dy;
      } else if (pdfPoint.dy > line.bounds.bottom) {
        vDist = pdfPoint.dy - line.bounds.bottom;
      }

      // Horizontal distance: 0 if within line left..right
      double hDist = 0.0;
      if (pdfPoint.dx < line.bounds.left) {
        hDist = line.bounds.left - pdfPoint.dx;
      } else if (pdfPoint.dx > line.bounds.right) {
        hDist = pdfPoint.dx - line.bounds.right;
      }

      // Heavily penalize vertical distance so dragging stays on the active line
      final score = (vDist * 5.0) + hDist;
      if (score < bestScore) {
        bestScore = score;
        bestLineIndex = i;
      }
    }

    final lineChars = _lineCharsMap[bestLineIndex];
    if (lineChars == null || lineChars.isEmpty) {
      return 0;
    }

    if (pdfPoint.dx <= lineChars.first.bounds.left) {
      return lineChars.first.globalIndex;
    }
    if (pdfPoint.dx >= lineChars.last.bounds.right) {
      return lineChars.last.globalIndex;
    }

    int closestCharGlobal = lineChars.first.globalIndex;
    double minDistanceX = double.infinity;

    for (final ch in lineChars) {
      final anchorX = isStart ? ch.bounds.left : ch.bounds.right;
      final dX = (anchorX - pdfPoint.dx).abs();
      if (dX < minDistanceX) {
        minDistanceX = dX;
        closestCharGlobal = ch.globalIndex;
      }
    }

    return closestCharGlobal;
  }

  /// Handles a long-press at widget-local coordinates to hit-test and select a word
  bool handleLongPress(Offset localPosition) {
    if (!widget.isSelectionEnabled) return false;

    if (_allChars.isEmpty) {
      plainToast(
        msg: "This page is an image scan with no selectable digital text.",
      );
      return false;
    }

    final sx = widget.scaleX;
    final sy = widget.scaleY;
    if (sx <= 0 || sy <= 0) return false;

    // Convert local screen position to PDF document coordinates
    final pdfPoint = Offset(localPosition.dx / sx, localPosition.dy / sy);

    int hitCharIdx = -1;
    for (int i = 0; i < _allChars.length; i++) {
      if (_allChars[i].bounds.inflate(4.0).contains(pdfPoint)) {
        hitCharIdx = i;
        break;
      }
    }

    if (hitCharIdx == -1) {
      final candidateIdx = _findClosestCharIndex(pdfPoint, isStart: true);
      if (candidateIdx != -1) {
        final dist =
            (_allChars[candidateIdx].bounds.center - pdfPoint).distance;
        if (dist <= 35.0) {
          hitCharIdx = candidateIdx;
        }
      }
    }

    if (hitCharIdx != -1) {
      final hitChar = _allChars[hitCharIdx];
      int startIdx = hitCharIdx;
      int endIdx = hitCharIdx;

      // Expand to select the full word if the hit character belongs to a word
      if (hitChar.wordIndex != -1) {
        while (startIdx > 0 &&
            _allChars[startIdx - 1].wordIndex == hitChar.wordIndex &&
            _allChars[startIdx - 1].lineIndex == hitChar.lineIndex) {
          startIdx--;
        }
        while (endIdx < _allChars.length - 1 &&
            _allChars[endIdx + 1].wordIndex == hitChar.wordIndex &&
            _allChars[endIdx + 1].lineIndex == hitChar.lineIndex) {
          endIdx++;
        }
      }

      HapticFeedback.mediumImpact();
      setState(() {
        _startIndex = startIdx;
        _endIndex = endIdx;
        _isDraggingHandle = false;
        _recalculateBounds();
      });
      return true;
    }

    return false;
  }

  void clearSelection() {
    if (hasSelection || _selectionBoundsInWidgetPx != null) {
      setState(() {
        _startIndex = -1;
        _endIndex = -1;
        _selectionBoundsInWidgetPx = null;
        _isDraggingHandle = false;
      });
    }
  }

  void _recalculateBounds() {
    if (_startIndex < 0 || _endIndex < 0 || _allChars.isEmpty) {
      _selectionBoundsInWidgetPx = null;
      return;
    }

    final from = _startIndex <= _endIndex ? _startIndex : _endIndex;
    final to = _startIndex <= _endIndex ? _endIndex : _startIndex;
    final sx = widget.scaleX;
    final sy = widget.scaleY;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;

    for (int i = from; i <= to && i < _allChars.length; i++) {
      final b = _allChars[i].bounds;
      if (b.left < minX) minX = b.left;
      if (b.top < minY) minY = b.top;
      if (b.right > maxX) maxX = b.right;
      if (b.bottom > maxY) maxY = b.bottom;
    }

    _selectionBoundsInWidgetPx = Rect.fromLTRB(
      minX * sx,
      minY * sy,
      maxX * sx,
      maxY * sy,
    );
  }

  void _onStartHandlePanStart(DragStartDetails details) {
    if (_startIndex < 0 || _startIndex >= _allChars.length) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final sx = widget.scaleX;
    final sy = widget.scaleY;
    if (sx <= 0 || sy <= 0) return;

    final localTouch = renderBox.globalToLocal(details.globalPosition);
    final touchPdf = Offset(localTouch.dx / sx, localTouch.dy / sy);

    final startChar = _allChars[_startIndex];
    final handleAnchorPdf =
        Offset(startChar.bounds.left, startChar.bounds.center.dy);

    _touchOffsetPdf = touchPdf - handleAnchorPdf;
    _isDraggingHandle = true;
    setState(() {});
  }

  void _onStartHandlePanUpdate(DragUpdateDetails details) {
    if (_startIndex < 0 || _allChars.isEmpty) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final sx = widget.scaleX;
    final sy = widget.scaleY;
    if (sx <= 0 || sy <= 0) return;

    final localTouch = renderBox.globalToLocal(details.globalPosition);
    final touchPdf = Offset(localTouch.dx / sx, localTouch.dy / sy);
    final targetPdf = touchPdf - _touchOffsetPdf;

    int newIdx = _findClosestCharIndex(targetPdf, isStart: true);
    if (newIdx > _endIndex) newIdx = _endIndex;

    if (newIdx != _startIndex) {
      HapticFeedback.selectionClick();
      setState(() {
        _startIndex = newIdx;
        _recalculateBounds();
      });
    }
  }

  void _onStartHandlePanEnd(DragEndDetails details) {
    setState(() {
      _isDraggingHandle = false;
    });
  }

  void _onEndHandlePanStart(DragStartDetails details) {
    if (_endIndex < 0 || _endIndex >= _allChars.length) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final sx = widget.scaleX;
    final sy = widget.scaleY;
    if (sx <= 0 || sy <= 0) return;

    final localTouch = renderBox.globalToLocal(details.globalPosition);
    final touchPdf = Offset(localTouch.dx / sx, localTouch.dy / sy);

    final endChar = _allChars[_endIndex];
    final handleAnchorPdf =
        Offset(endChar.bounds.right, endChar.bounds.center.dy);

    _touchOffsetPdf = touchPdf - handleAnchorPdf;
    _isDraggingHandle = true;
    setState(() {});
  }

  void _onEndHandlePanUpdate(DragUpdateDetails details) {
    if (_endIndex < 0 || _allChars.isEmpty) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final sx = widget.scaleX;
    final sy = widget.scaleY;
    if (sx <= 0 || sy <= 0) return;

    final localTouch = renderBox.globalToLocal(details.globalPosition);
    final touchPdf = Offset(localTouch.dx / sx, localTouch.dy / sy);
    final targetPdf = touchPdf - _touchOffsetPdf;

    int newIdx = _findClosestCharIndex(targetPdf, isStart: false);
    if (newIdx < _startIndex) newIdx = _startIndex;

    if (newIdx != _endIndex) {
      HapticFeedback.selectionClick();
      setState(() {
        _endIndex = newIdx;
        _recalculateBounds();
      });
    }
  }

  void _onEndHandlePanEnd(DragEndDetails details) {
    setState(() {
      _isDraggingHandle = false;
    });
  }

  void _copySelectedText() {
    final text = selectedText.trim();
    if (text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
      HapticFeedback.selectionClick();
      plainToast(msg: "Copied to clipboard");
    }
    clearSelection();
  }

  void _highlightSelectedText() {
    if (hasSelection && widget.onHighlightText != null) {
      final from = _startIndex <= _endIndex ? _startIndex : _endIndex;
      final to = _startIndex <= _endIndex ? _endIndex : _startIndex;

      double minX = double.infinity;
      double minY = double.infinity;
      double maxX = -double.infinity;
      double maxY = -double.infinity;

      for (int i = from; i <= to && i < _allChars.length; i++) {
        final b = _allChars[i].bounds;
        if (b.left < minX) minX = b.left;
        if (b.top < minY) minY = b.top;
        if (b.right > maxX) maxX = b.right;
        if (b.bottom > maxY) maxY = b.bottom;
      }

      final text = selectedText.trim();
      final bounds = Rect.fromLTRB(minX, minY, maxX, maxY);
      widget.onHighlightText!(bounds, text);
      HapticFeedback.mediumImpact();
      plainToast(msg: "Text highlighted");
    }
    clearSelection();
  }

  void _selectAll() {
    if (_allChars.isNotEmpty) {
      HapticFeedback.selectionClick();
      setState(() {
        _startIndex = 0;
        _endIndex = _allChars.length - 1;
        _recalculateBounds();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_textLines == null || _textLines!.isEmpty) {
      return const SizedBox.shrink();
    }

    final sx = widget.scaleX;
    final sy = widget.scaleY;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final selectedLineHighlights = <Rect>[];
    if (hasSelection) {
      final from = _startIndex <= _endIndex ? _startIndex : _endIndex;
      final to = _startIndex <= _endIndex ? _endIndex : _startIndex;

      int curLine = -1;
      double lLeft = double.infinity;
      double lRight = -double.infinity;
      double lTop = double.infinity;
      double lBottom = -double.infinity;

      for (int i = from; i <= to && i < _allChars.length; i++) {
        final ch = _allChars[i];
        if (ch.lineIndex != curLine) {
          if (curLine != -1 && lLeft < lRight) {
            selectedLineHighlights
                .add(Rect.fromLTRB(lLeft, lTop, lRight, lBottom));
          }
          curLine = ch.lineIndex;
          lLeft = ch.bounds.left;
          lRight = ch.bounds.right;
          lTop = ch.bounds.top;
          lBottom = ch.bounds.bottom;
        } else {
          if (ch.bounds.left < lLeft) lLeft = ch.bounds.left;
          if (ch.bounds.right > lRight) lRight = ch.bounds.right;
          if (ch.bounds.top < lTop) lTop = ch.bounds.top;
          if (ch.bounds.bottom > lBottom) lBottom = ch.bounds.bottom;
        }
      }
      if (curLine != -1 && lLeft < lRight) {
        selectedLineHighlights
            .add(Rect.fromLTRB(lLeft, lTop, lRight, lBottom));
      }
    }

    final firstChar = hasSelection ? _allChars[_startIndex] : null;
    final lastChar = hasSelection ? _allChars[_endIndex] : null;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 1. Transparent text layout representation (ignored so touches pass through when not selecting)
        IgnorePointer(
          ignoring: true,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final line in _textLines!)
                Positioned(
                  left: line.bounds.left * sx,
                  top: line.bounds.top * sy,
                  width: (line.bounds.width * sx).clamp(1.0, double.infinity),
                  height: (line.bounds.height * sy).clamp(1.0, double.infinity),
                  child: SizedBox(
                    width: line.bounds.width * sx,
                    height: line.bounds.height * sy,
                    child: FittedBox(
                      fit: BoxFit.fill,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        line.text,
                        style: TextStyle(
                          fontSize: line.fontSize * sy > 0
                              ? line.fontSize * sy
                              : 14.0,
                          color: Colors.transparent,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // 2. When text is selected: Tap-outside listener to dismiss selection cleanly
        if (hasSelection)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: clearSelection,
            ),
          ),

        // 3. Visual highlight overlays for selected lines
        if (hasSelection) ...[
          for (final rect in selectedLineHighlights)
            Positioned(
              left: rect.left * sx - 1.0,
              top: rect.top * sy - 0.5,
              width: (rect.width * sx + 2.0).clamp(1.0, double.infinity),
              height: (rect.height * sy + 1.0).clamp(1.0, double.infinity),
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: royalblue.withValues(alpha: 0.32),
                  ),
                ),
              ),
            ),

          // 4. Start Handle (Draggable cursor bar + pin handle)
          if (firstChar != null) _buildStartHandle(firstChar, sx, sy),

          // 5. End Handle (Draggable cursor bar + pin handle)
          if (lastChar != null) _buildEndHandle(lastChar, sx, sy),

          // 6. Floating Quick-Action Pill (Copy, Highlight, Select All)
          if (_selectionBoundsInWidgetPx != null && !_isDraggingHandle)
            widget.transformationController != null
                ? AnimatedBuilder(
                    animation: widget.transformationController!,
                    builder: (context, _) =>
                        _buildFloatingActionPill(context, isDark),
                  )
                : _buildFloatingActionPill(context, isDark),
        ],
      ],
    );
  }

  Widget _buildStartHandle(PdfTextCharModel firstChar, double sx, double sy) {
    final startX = firstChar.bounds.left * sx;
    final startY = firstChar.bounds.top * sy;
    final lineH = (firstChar.bounds.height * sy).clamp(12.0, 42.0);

    const double handleWidth = 44.0;
    const double handleCenter = 22.0;

    return Positioned(
      left: startX - handleCenter,
      top: startY - 8.h,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: _onStartHandlePanStart,
        onPanUpdate: _onStartHandlePanUpdate,
        onPanEnd: _onStartHandlePanEnd,
        child: SizedBox(
          width: handleWidth,
          height: lineH + 22.h,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              // Vertical cursor bar at startX
              Positioned(
                left: handleCenter - 0.75,
                top: 4.h,
                child: Container(
                  width: 1.5,
                  height: lineH + 5,
                  decoration: BoxDecoration(
                    color: royalblue,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              // Teardrop / circular pin handle at top
              Positioned(
                left: handleCenter - 4.0,
                top: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: royalblue,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEndHandle(PdfTextCharModel lastChar, double sx, double sy) {
    final endX = lastChar.bounds.right * sx;
    final endY = lastChar.bounds.top * sy;
    final lineH = (lastChar.bounds.height * sy).clamp(12.0, 42.0);

    const double handleWidth = 44.0;
    const double handleCenter = 22.0;

    return Positioned(
      left: endX - handleCenter,
      top: endY,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: _onEndHandlePanStart,
        onPanUpdate: _onEndHandlePanUpdate,
        onPanEnd: _onEndHandlePanEnd,
        child: SizedBox(
          width: handleWidth,
          height: lineH + 20.h,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              // Vertical cursor bar at endX
              Positioned(
                left: handleCenter - 0.75,
                top: 0,
                child: Container(
                  width: 1.5,
                  height: lineH,
                  decoration: BoxDecoration(
                    color: royalblue,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              // Teardrop / circular pin handle at bottom
              Positioned(
                left: handleCenter - 4.0,
                top: lineH,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: royalblue,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionPill(BuildContext context, bool isDark) {
    final sel = _selectionBoundsInWidgetPx!;
    final totalW = widget.pageWidth * widget.scaleX;

    final matrix = widget.transformationController?.value;
    final zoom = (matrix != null ? matrix.getMaxScaleOnAxis() : 1.0).clamp(
      1.0,
      100.0,
    );
    final counterScale = 1.0 / zoom;

    const double basePillWidth = 245.0;
    const double basePillHeight = 38.0;
    const double baseClearance = 14.0;

    final pillWidthLocal = basePillWidth.w * counterScale;
    final pillHeightLocal = basePillHeight.h * counterScale;
    final clearanceLocal = baseClearance.h * counterScale;

    // Viewport boundaries in local coordinates if transformation matrix is available
    double minLeft = 8.0.w * counterScale;
    double maxLeft = totalW - pillWidthLocal - (8.0.w * counterScale);
    double viewportTopLocal = 10.0.h * counterScale;

    if (matrix != null) {
      final tx = matrix.storage[12];
      final ty = matrix.storage[13];
      final mediaQuery = MediaQuery.of(context);
      final screenW = mediaQuery.size.width;

      final visibleLeftLocal = (8.0.w - tx) / zoom;
      final visibleRightLocal = (screenW - 8.0.w - tx) / zoom;
      final visibleTopLocal = (mediaQuery.padding.top + 10.0.h - ty) / zoom;

      if (visibleLeftLocal > minLeft) {
        minLeft = visibleLeftLocal;
      }
      if (visibleRightLocal - pillWidthLocal < maxLeft) {
        maxLeft = visibleRightLocal - pillWidthLocal;
      }
      viewportTopLocal = visibleTopLocal;
    }

    double pillLeft = sel.center.dx - (pillWidthLocal / 2);
    if (maxLeft >= minLeft) {
      pillLeft = pillLeft.clamp(minLeft, maxLeft);
    } else {
      pillLeft = minLeft;
    }

    // Position above selection, or below if too close to the top of the viewport or page
    double pillTop = sel.top - pillHeightLocal - clearanceLocal;
    if (pillTop < viewportTopLocal || pillTop < 8.0.h * counterScale) {
      pillTop = sel.bottom + clearanceLocal;
    }

    return Positioned(
      left: pillLeft,
      top: pillTop,
      child: Transform.scale(
        scale: counterScale,
        alignment: Alignment.topLeft,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E24) : Colors.white,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActionBtn(
                  icon: Icons.copy_rounded,
                  label: "Copy",
                  onTap: _copySelectedText,
                  isDark: isDark,
                ),
                Gap(8),
                _buildActionBtn(
                  icon: null,
                  label: "Highlight",
                  onTap: _highlightSelectedText,
                  isDark: isDark,
                  iconColor: Colors.amber.shade600,
                ),
                Gap(8),
                _buildActionBtn(
                  icon: Icons.select_all_rounded,
                  label: "Select All",
                  onTap: _selectAll,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData? icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
    Color? iconColor,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12.r),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 4.h),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Icon(
                icon,
                size: 13.sp,
                color: iconColor ?? (isDark ? Colors.white : Colors.black87),
              ),

            Padding(
              padding: const EdgeInsets.only(left: 3),
              child: Text(
                label,
                style: GoogleFonts.lato(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
