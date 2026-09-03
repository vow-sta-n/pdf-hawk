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
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfhawk/data/res/theme.dart';
import 'package:pdfhawk/data/res/utils.dart';
import 'package:pdfhawk/logic/helpers/pdf_helper.dart';
import 'package:share_plus/share_plus.dart';

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
    this.onHighlightText,
    this.onOpenExtractText,
  });

  @override
  State<PdfSelectableTextLayer> createState() => PdfSelectableTextLayerState();
}

class PdfSelectableTextLayerState extends State<PdfSelectableTextLayer> {
  List<PdfTextLineModel>? _textLines;
  List<PdfTextWordModel> _allWords = [];
  bool _isLoading = false;

  int _startIndex = -1;
  int _endIndex = -1;
  final List<PdfTextWordModel> _selectedWords = [];
  Rect? _selectionBoundsInWidgetPx;

  bool _isDraggingHandle = false;
  Offset _dragHandlePdfPos = Offset.zero;

  bool get hasSelection => _selectedWords.isNotEmpty;
  String get selectedText => _selectedWords.map((w) => w.text).join(' ');

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
    } else if (oldWidget.scaleX != widget.scaleX || oldWidget.scaleY != widget.scaleY) {
      _recalculateBounds();
    }
  }

  Future<void> _loadTextLines() async {
    if (widget.pdfFile == null) {
      if (mounted) {
        setState(() {
          _textLines = [];
          _allWords = [];
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
        final words = <PdfTextWordModel>[];
        for (final l in lines) {
          words.addAll(l.words);
        }
        setState(() {
          _textLines = lines;
          _allWords = words;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _textLines = [];
          _allWords = [];
          _isLoading = false;
        });
      }
    }
  }

  /// Handles a long-press at widget-local coordinates to hit-test and select a word
  bool handleLongPress(Offset localPosition) {
    if (!widget.isSelectionEnabled) return false;

    if (_textLines == null || _textLines!.isEmpty || _allWords.isEmpty) {
      plainToast(msg: "This page is an image scan with no selectable digital text.");
      return false;
    }

    final sx = widget.scaleX;
    final sy = widget.scaleY;
    if (sx <= 0 || sy <= 0) return false;

    // Convert local screen position to PDF document coordinates
    final pdfPoint = Offset(localPosition.dx / sx, localPosition.dy / sy);

    int hitIdx = -1;
    for (int i = 0; i < _allWords.length; i++) {
      if (_allWords[i].bounds.inflate(4.0).contains(pdfPoint)) {
        hitIdx = i;
        break;
      }
    }

    // Fallback: Check if near any word within 30 points
    if (hitIdx == -1) {
      double minDist = 30.0;
      for (int i = 0; i < _allWords.length; i++) {
        final dist = (_allWords[i].bounds.center - pdfPoint).distance;
        if (dist < minDist) {
          minDist = dist;
          hitIdx = i;
        }
      }
    }

    if (hitIdx != -1) {
      HapticFeedback.mediumImpact();
      setState(() {
        _startIndex = hitIdx;
        _endIndex = hitIdx;
        _isDraggingHandle = false;
        _updateSelectedWords();
      });
      return true;
    }

    return false;
  }

  void clearSelection() {
    if (_selectedWords.isNotEmpty || _selectionBoundsInWidgetPx != null) {
      setState(() {
        _startIndex = -1;
        _endIndex = -1;
        _selectedWords.clear();
        _selectionBoundsInWidgetPx = null;
        _isDraggingHandle = false;
      });
    }
  }

  void _updateSelectedWords() {
    if (_startIndex < 0 || _endIndex < 0 || _allWords.isEmpty) {
      _selectedWords.clear();
      _selectionBoundsInWidgetPx = null;
      return;
    }

    final from = _startIndex <= _endIndex ? _startIndex : _endIndex;
    final to = _startIndex <= _endIndex ? _endIndex : _startIndex;

    _selectedWords.clear();
    for (int i = from; i <= to && i < _allWords.length; i++) {
      _selectedWords.add(_allWords[i]);
    }

    _recalculateBounds();
  }

  void _recalculateBounds() {
    if (_selectedWords.isEmpty) {
      _selectionBoundsInWidgetPx = null;
      return;
    }

    final sx = widget.scaleX;
    final sy = widget.scaleY;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;

    for (final word in _selectedWords) {
      if (word.bounds.left < minX) minX = word.bounds.left;
      if (word.bounds.top < minY) minY = word.bounds.top;
      if (word.bounds.right > maxX) maxX = word.bounds.right;
      if (word.bounds.bottom > maxY) maxY = word.bounds.bottom;
    }

    _selectionBoundsInWidgetPx = Rect.fromLTRB(
      minX * sx,
      minY * sy,
      maxX * sx,
      maxY * sy,
    );
  }

  void _onStartHandlePanStart(DragStartDetails details) {
    if (_startIndex < 0 || _startIndex >= _allWords.length) return;
    _isDraggingHandle = true;
    _dragHandlePdfPos = _allWords[_startIndex].bounds.center;
    setState(() {});
  }

  void _onStartHandlePanUpdate(DragUpdateDetails details) {
    final sx = widget.scaleX;
    final sy = widget.scaleY;
    if (sx <= 0 || sy <= 0 || _allWords.isEmpty) return;

    _dragHandlePdfPos += Offset(details.delta.dx / sx, details.delta.dy / sy);

    int closestIdx = _startIndex;
    double minDist = double.infinity;
    for (int i = 0; i < _allWords.length; i++) {
      final d = (_allWords[i].bounds.center - _dragHandlePdfPos).distance;
      if (d < minDist) {
        minDist = d;
        closestIdx = i;
      }
    }

    if (closestIdx != _startIndex) {
      HapticFeedback.selectionClick();
      setState(() {
        _startIndex = closestIdx;
        _updateSelectedWords();
      });
    }
  }

  void _onStartHandlePanEnd(DragEndDetails details) {
    setState(() {
      _isDraggingHandle = false;
    });
  }

  void _onEndHandlePanStart(DragStartDetails details) {
    if (_endIndex < 0 || _endIndex >= _allWords.length) return;
    _isDraggingHandle = true;
    _dragHandlePdfPos = _allWords[_endIndex].bounds.center;
    setState(() {});
  }

  void _onEndHandlePanUpdate(DragUpdateDetails details) {
    final sx = widget.scaleX;
    final sy = widget.scaleY;
    if (sx <= 0 || sy <= 0 || _allWords.isEmpty) return;

    _dragHandlePdfPos += Offset(details.delta.dx / sx, details.delta.dy / sy);

    int closestIdx = _endIndex;
    double minDist = double.infinity;
    for (int i = 0; i < _allWords.length; i++) {
      final d = (_allWords[i].bounds.center - _dragHandlePdfPos).distance;
      if (d < minDist) {
        minDist = d;
        closestIdx = i;
      }
    }

    if (closestIdx != _endIndex) {
      HapticFeedback.selectionClick();
      setState(() {
        _endIndex = closestIdx;
        _updateSelectedWords();
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
    if (_selectedWords.isNotEmpty && widget.onHighlightText != null) {
      double minX = double.infinity;
      double minY = double.infinity;
      double maxX = -double.infinity;
      double maxY = -double.infinity;

      for (final word in _selectedWords) {
        if (word.bounds.left < minX) minX = word.bounds.left;
        if (word.bounds.top < minY) minY = word.bounds.top;
        if (word.bounds.right > maxX) maxX = word.bounds.right;
        if (word.bounds.bottom > maxY) maxY = word.bounds.bottom;
      }

      final text = selectedText.trim();
      final bounds = Rect.fromLTRB(minX, minY, maxX, maxY);
      widget.onHighlightText!(bounds, text);
      HapticFeedback.mediumImpact();
      plainToast(msg: "Text highlighted");
    }
    clearSelection();
  }

  void _selectLine() {
    if (_selectedWords.isEmpty || _textLines == null) return;
    final first = _selectedWords.first;

    PdfTextLineModel? foundLine;
    for (final line in _textLines!) {
      if (line.words.contains(first)) {
        foundLine = line;
        break;
      }
    }

    if (foundLine != null && foundLine.words.isNotEmpty) {
      HapticFeedback.selectionClick();
      setState(() {
        _startIndex = _allWords.indexOf(foundLine!.words.first);
        _endIndex = _allWords.indexOf(foundLine.words.last);
        _updateSelectedWords();
      });
    }
  }

  void _selectAll() {
    if (_allWords.isNotEmpty) {
      HapticFeedback.selectionClick();
      setState(() {
        _startIndex = 0;
        _endIndex = _allWords.length - 1;
        _updateSelectedWords();
      });
    }
  }

  void _shareSelectedText() {
    final text = selectedText.trim();
    if (text.isNotEmpty) {
      SharePlus.instance.share(ShareParams(text: text));
    }
    clearSelection();
  }

  @override
  Widget build(BuildContext context) {
    if (_textLines == null || _textLines!.isEmpty) {
      return const SizedBox.shrink();
    }

    final sx = widget.scaleX;
    final sy = widget.scaleY;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final firstWord = _selectedWords.isNotEmpty ? _selectedWords.first : null;
    final lastWord = _selectedWords.isNotEmpty ? _selectedWords.last : null;

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
                          fontSize: line.fontSize * sy > 0 ? line.fontSize * sy : 14.0,
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

        // 3. Visual highlight overlays for each selected word
        if (hasSelection) ...[
          for (final word in _selectedWords)
            Positioned(
              left: word.bounds.left * sx - 1.5,
              top: word.bounds.top * sy - 1.0,
              width: word.bounds.width * sx + 3.0,
              height: word.bounds.height * sy + 2.0,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: royalblue.withValues(alpha: 0.32),
                    borderRadius: BorderRadius.circular(2.r),
                    border: Border.all(
                      color: royalblue.withValues(alpha: 0.6),
                      width: 0.8,
                    ),
                  ),
                ),
              ),
            ),

          // 4. Start Handle (Draggable cursor bar + pin handle)
          if (firstWord != null)
            _buildStartHandle(firstWord, sx, sy),

          // 5. End Handle (Draggable cursor bar + pin handle)
          if (lastWord != null)
            _buildEndHandle(lastWord, sx, sy),

          // 6. Floating Quick-Action Pill (Copy, Highlight, Line, All, Share)
          // Hidden while dragging handles to keep the text completely visible!
          if (_selectionBoundsInWidgetPx != null && !_isDraggingHandle)
            _buildFloatingActionPill(context, isDark),
        ],
      ],
    );
  }

  Widget _buildStartHandle(PdfTextWordModel firstWord, double sx, double sy) {
    final startX = firstWord.bounds.left * sx;
    final startY = firstWord.bounds.top * sy;
    final lineH = (firstWord.bounds.height * sy).clamp(12.0, 42.0);

    return Positioned(
      left: startX - 22.w,
      top: startY - 8.h,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: _onStartHandlePanStart,
        onPanUpdate: _onStartHandlePanUpdate,
        onPanEnd: _onStartHandlePanEnd,
        child: SizedBox(
          width: 44.w,
          height: lineH + 20.h,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              // Vertical cursor bar at startX
              Positioned(
                left: 22.w - 1.25,
                top: 8.h,
                child: Container(
                  width: 2.5,
                  height: lineH,
                  decoration: BoxDecoration(
                    color: royalblue,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              // Teardrop / circular pin handle at top
              Positioned(
                left: 22.w - 6.w,
                top: 0,
                child: Container(
                  width: 12.w,
                  height: 12.w,
                  decoration: const BoxDecoration(
                    color: royalblue,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEndHandle(PdfTextWordModel lastWord, double sx, double sy) {
    final endX = lastWord.bounds.right * sx;
    final endY = lastWord.bounds.top * sy;
    final lineH = (lastWord.bounds.height * sy).clamp(12.0, 42.0);

    return Positioned(
      left: endX - 22.w,
      top: endY,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: _onEndHandlePanStart,
        onPanUpdate: _onEndHandlePanUpdate,
        onPanEnd: _onEndHandlePanEnd,
        child: SizedBox(
          width: 44.w,
          height: lineH + 20.h,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              // Vertical cursor bar at endX
              Positioned(
                left: 22.w - 1.25,
                top: 0,
                child: Container(
                  width: 2.5,
                  height: lineH,
                  decoration: BoxDecoration(
                    color: royalblue,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              // Teardrop / circular pin handle at bottom
              Positioned(
                left: 22.w - 6.w,
                top: lineH,
                child: Container(
                  width: 12.w,
                  height: 12.w,
                  decoration: const BoxDecoration(
                    color: royalblue,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
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

    // Position well ABOVE the selection with generous 18.h clearance
    const double pillHeight = 40.0;
    const double clearance = 18.0;

    double pillTop = sel.top - (pillHeight + clearance).h;

    // If near the extreme top of the page (< 62.h), position safely below
    if (pillTop < 8.h) {
      pillTop = sel.bottom + clearance.h + 6.h;
    }

    const double pillWidth = 275.0;
    final pillLeft = (sel.center.dx - (pillWidth.w / 2)).clamp(
      8.w,
      (totalW - pillWidth.w - 8.w).clamp(8.w, totalW),
    );

    return Positioned(
      left: pillLeft,
      top: pillTop,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.5.h),
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
              _buildDivider(isDark),
              _buildActionBtn(
                icon: Icons.brush_rounded,
                label: "Highlight",
                onTap: _highlightSelectedText,
                isDark: isDark,
                iconColor: Colors.amber.shade600,
              ),
              _buildDivider(isDark),
              _buildActionBtn(
                icon: Icons.horizontal_rule_rounded,
                label: "Line",
                onTap: _selectLine,
                isDark: isDark,
              ),
              _buildDivider(isDark),
              _buildActionBtn(
                icon: Icons.select_all_rounded,
                label: "All",
                onTap: _selectAll,
                isDark: isDark,
              ),
              _buildDivider(isDark),
              _buildActionBtn(
                icon: Icons.share_rounded,
                label: "Share",
                onTap: _shareSelectedText,
                isDark: isDark,
              ),
              _buildDivider(isDark),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 26.w, minHeight: 26.h),
                icon: Icon(
                  Icons.close_rounded,
                  size: 14.sp,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
                onPressed: clearSelection,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
    Color? iconColor,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12.r),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 6.5.w, vertical: 4.h),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13.sp,
              color: iconColor ?? (isDark ? Colors.white : Colors.black87),
            ),
            SizedBox(width: 4.w),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      width: 1,
      height: 14.h,
      margin: EdgeInsets.symmetric(horizontal: 2.w),
      color: isDark ? Colors.white10 : Colors.black12,
    );
  }
}
