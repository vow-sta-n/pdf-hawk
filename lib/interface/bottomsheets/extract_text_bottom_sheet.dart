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
import 'package:path/path.dart' as p;
import 'package:pdfhawk/data/res/constants.dart';
import 'package:pdfhawk/data/res/theme.dart';
import 'package:pdfhawk/data/res/utils.dart';
import 'package:pdfhawk/interface/widgets/bubble_button.dart';
import 'package:pdfhawk/logic/helpers/pdf_helper.dart';
import 'package:share_plus/share_plus.dart';

enum ExtractScope { currentPage, entireDocument }

class ExtractTextBottomSheet extends StatefulWidget {
  final File pdfFile;
  final int currentPageIndex; // 0-based
  final int totalPages;

  const ExtractTextBottomSheet({
    super.key,
    required this.pdfFile,
    required this.currentPageIndex,
    required this.totalPages,
  });

  @override
  State<ExtractTextBottomSheet> createState() => _ExtractTextBottomSheetState();
}

class _ExtractTextBottomSheetState extends State<ExtractTextBottomSheet> {
  ExtractScope _scope = ExtractScope.currentPage;
  String _pageText = "";
  String _documentText = "";
  bool _isLoading = true;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadText();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadText() async {
    setState(() => _isLoading = true);

    try {
      final pageNumber = widget.currentPageIndex + 1;
      final pageTxt = await PdfHelper.extractTextContent(
        pdfFile: widget.pdfFile,
        pageNumber: pageNumber,
      );

      final docTxt = await PdfHelper.extractTextContent(
        pdfFile: widget.pdfFile,
      );

      if (mounted) {
        setState(() {
          _pageText = pageTxt;
          _documentText = docTxt;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String get _activeText {
    return _scope == ExtractScope.currentPage ? _pageText : _documentText;
  }

  int get _wordCount {
    final text = _activeText.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  int get _charCount => _activeText.length;

  int get _lineCount {
    final text = _activeText.trim();
    if (text.isEmpty) return 0;
    return text.split('\n').length;
  }

  void _copyToClipboard() {
    final text = _activeText;
    if (text.trim().isEmpty) {
      plainToast(msg: "No text available to copy");
      return;
    }

    HapticFeedback.mediumImpact();
    Clipboard.setData(ClipboardData(text: text));
    plainToast(msg: "Text copied to clipboard!");
  }

  Future<void> _shareText() async {
    final text = _activeText;
    if (text.trim().isEmpty) {
      plainToast(msg: "No text available to share");
      return;
    }

    try {
      final docName = p.basenameWithoutExtension(widget.pdfFile.path);
      final label = _scope == ExtractScope.currentPage
          ? "$docName - Page ${widget.currentPageIndex + 1}"
          : "$docName - Full Document";
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: label,
        ),
      );
    } catch (e) {
      plainToast(msg: "Failed to share text: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeText = _activeText;
    final hasText = activeText.trim().isNotEmpty;

    return Container(
      height: 0.88.sh,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161618) : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.r),
          topRight: Radius.circular(20.r),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Top Grabber Handle
            Gap(12.h),
            Center(
              child: Container(
                width: 38.w,
                height: 4.5.h,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: allradius(10.r),
                ),
              ),
            ),
            Gap(10.h),

            // Top App Bar / Actions Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  BubbleButton(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  Text(
                    "Extract Text",
                    style: GoogleFonts.outfit(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: "Share text",
                        onPressed: hasText ? _shareText : null,
                        icon: Icon(
                          Icons.share_rounded,
                          size: 20.r,
                          color: hasText
                              ? (isDark ? Colors.white70 : Colors.black87)
                              : Colors.grey.withValues(alpha: 0.4),
                        ),
                      ),
                      IconButton(
                        tooltip: "Copy text",
                        onPressed: hasText ? _copyToClipboard : null,
                        icon: Icon(
                          Icons.copy_rounded,
                          size: 20.r,
                          color: hasText
                              ? royalblue
                              : Colors.grey.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Gap(12.h),

            // Scope Selector Tabs
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Container(
                padding: EdgeInsets.all(4.r),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: allradius(14.r),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black12,
                    width: 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _scope = ExtractScope.currentPage);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          decoration: BoxDecoration(
                            color: _scope == ExtractScope.currentPage
                                ? royalblue
                                : Colors.transparent,
                            borderRadius: allradius(10.r),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "Page ${widget.currentPageIndex + 1} of ${widget.totalPages}",
                            style: GoogleFonts.instrumentSans(
                              fontSize: 13.sp,
                              fontWeight: _scope == ExtractScope.currentPage
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: _scope == ExtractScope.currentPage
                                  ? Colors.white
                                  : (isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade700),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Gap(6.w),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _scope = ExtractScope.entireDocument);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          decoration: BoxDecoration(
                            color: _scope == ExtractScope.entireDocument
                                ? royalblue
                                : Colors.transparent,
                            borderRadius: allradius(10.r),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "Full Document (${widget.totalPages} Pages)",
                            style: GoogleFonts.instrumentSans(
                              fontSize: 13.sp,
                              fontWeight: _scope == ExtractScope.entireDocument
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: _scope == ExtractScope.entireDocument
                                  ? Colors.white
                                  : (isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade700),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Gap(12.h),

            // Text Statistics Chips Bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                children: [
                  _buildStatChip(
                    icon: Icons.text_snippet_rounded,
                    label: "$_charCount chars",
                    isDark: isDark,
                  ),
                  Gap(8.w),
                  _buildStatChip(
                    icon: Icons.sort_by_alpha_rounded,
                    label: "$_wordCount words",
                    isDark: isDark,
                  ),
                  Gap(8.w),
                  _buildStatChip(
                    icon: Icons.format_list_numbered_rounded,
                    label: "$_lineCount lines",
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            Gap(12.h),

            // Search Filter inside Extracted Text
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Container(
                height: 38.h,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: allradius(10.r),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  style: GoogleFonts.instrumentSans(
                    fontSize: 13.sp,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 8.h,
                    ),
                    isDense: true,
                    border: InputBorder.none,
                    hintText: "Search in text...",
                    hintStyle: GoogleFonts.instrumentSans(
                      fontSize: 13.sp,
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 17.r,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() => _searchQuery = "");
                            },
                            child: Icon(
                              Icons.clear_rounded,
                              size: 16.r,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ),
            Gap(12.h),

            // Main Text Display Area
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F0F12)
                        : const Color(0xFFF9F9FB),
                    borderRadius: allradius(14.r),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12,
                      width: 1.0,
                    ),
                  ),
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: royalblue,
                            strokeWidth: 2.5,
                          ),
                        )
                      : !hasText
                          ? _buildEmptyState(isDark)
                          : SingleChildScrollView(
                              padding: EdgeInsets.all(16.r),
                              physics: const BouncingScrollPhysics(),
                              child: SelectableText.rich(
                                _buildHighlightedText(activeText, isDark),
                                style: GoogleFonts.instrumentSans(
                                  fontSize: 14.sp,
                                  height: 1.6,
                                  color: isDark
                                      ? Colors.grey.shade200
                                      : Colors.grey.shade900,
                                ),
                              ),
                            ),
                ),
              ),
            ),
            Gap(14.h),

            // Bottom Primary Copy Button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: hasText ? _copyToClipboard : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: royalblue,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: isDark
                            ? Colors.white10
                            : Colors.grey.shade300,
                        disabledForegroundColor: isDark
                            ? Colors.white24
                            : Colors.grey.shade500,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: allradius(14.r),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: Text(
                        _scope == ExtractScope.currentPage
                            ? "Copy Page Text"
                            : "Copy All Document Text",
                        style: GoogleFonts.outfit(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Gap(12.h),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: allradius(8.r),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12.sp,
            color: royalblue,
          ),
          Gap(4.w),
          Text(
            label,
            style: GoogleFonts.instrumentSans(
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: royalblue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.text_fields_rounded,
                color: royalblue,
                size: 32.r,
              ),
            ),
            Gap(14.h),
            Text(
              "No Text Found",
              style: GoogleFonts.outfit(
                fontSize: 17.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Gap(6.h),
            Text(
              "This page might contain only scanned images or illustrations without digital text streams.",
              textAlign: TextAlign.center,
              style: GoogleFonts.instrumentSans(
                fontSize: 13.sp,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextSpan _buildHighlightedText(String text, bool isDark) {
    if (_searchQuery.isEmpty) {
      return TextSpan(text: text);
    }

    final query = _searchQuery.toLowerCase();
    final lowerText = text.toLowerCase();
    final List<TextSpan> spans = [];
    int start = 0;

    while (start < text.length) {
      final matchIndex = lowerText.indexOf(query, start);
      if (matchIndex == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }

      if (matchIndex > start) {
        spans.add(TextSpan(text: text.substring(start, matchIndex)));
      }

      final matchedText = text.substring(matchIndex, matchIndex + query.length);
      spans.add(
        TextSpan(
          text: matchedText,
          style: TextStyle(
            backgroundColor: Colors.amber.withValues(alpha: 0.45),
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      start = matchIndex + query.length;
    }

    return TextSpan(children: spans);
  }
}
