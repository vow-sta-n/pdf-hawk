import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfhawk/logic/helpers/pdf_helper.dart';

class MergePage extends StatefulWidget {
  final List<String> pdfPaths;
  final String? folderUri;

  const MergePage({super.key, required this.pdfPaths, this.folderUri});

  @override
  State<MergePage> createState() => _MergePageState();
}

class _MergePageState extends State<MergePage> {
  // Track selected PDF paths
  final Set<String> _selectedPaths = {};

  // Track the actual order of selected paths to merge
  final List<String> _orderedSelections = [];

  final TextEditingController _fileNameController = TextEditingController();
  bool _isMerging = false;

  @override
  void dispose() {
    _fileNameController.dispose();
    super.dispose();
  }

  void _toggleSelection(String path) {
    setState(() {
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
        _orderedSelections.remove(path);
      } else {
        _selectedPaths.add(path);
        _orderedSelections.add(path);
      }
    });
  }

  Future<void> _mergePdfs() async {
    if (_orderedSelections.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select at least 2 PDFs to merge."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isMerging = true;
    });

    try {
      final pdfFiles = _orderedSelections.map((path) => File(path)).toList();
      String? customName;
      if (_fileNameController.text.trim().isNotEmpty) {
        customName = _fileNameController.text.trim();
        if (!customName.endsWith('.pdf')) {
          customName += '.pdf';
        }
      }

      final outputFile = await PdfHelper.mergePdfs(
        pdfFiles: pdfFiles,
        safDirectoryUri: widget.folderUri,
        outputName: customName,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "PDFs merged successfully: ${outputFile.path.split('/').last}",
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error merging PDFs: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() {
        _isMerging = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        iconTheme: IconThemeData(color: theme.appBarTheme.foregroundColor),
        title: Text(
          "Merge PDFs",
          style: GoogleFonts.outfit(
            color: theme.appBarTheme.foregroundColor,
            fontSize: 18.sp,
          ),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.all(16.r),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Custom file naming field
                          Text(
                            "Output File Name (Optional)",
                            style: GoogleFonts.outfit(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          TextField(
                            controller: _fileNameController,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              hintText: "Enter custom file name...",
                              hintStyle: TextStyle(color: Colors.grey.shade600),
                              filled: true,
                              fillColor: isDark
                                  ? Colors.white.withValues(alpha: 0.03)
                                  : Colors.black.withValues(alpha: 0.03),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 12.h,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.1)
                                      : Colors.black.withValues(alpha: 0.1),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 24.h),

                          // Document Selection Checklist
                          Text(
                            "Select PDFs to Merge",
                            style: GoogleFonts.outfit(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: widget.pdfPaths.length,
                            itemBuilder: (context, index) {
                              final path = widget.pdfPaths[index];
                              final name = path.split('/').last;
                              final isSelected = _selectedPaths.contains(path);

                              return Container(
                                margin: EdgeInsets.only(bottom: 8.h),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.02)
                                      : Colors.black.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(
                                    color: isSelected
                                        ? theme.colorScheme.primary.withValues(
                                            alpha: 0.4,
                                          )
                                        : (isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.05,
                                                )
                                              : Colors.black.withValues(
                                                  alpha: 0.05,
                                                )),
                                  ),
                                ),
                                child: CheckboxListTile(
                                  title: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.instrumentSans(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  activeColor: theme.colorScheme.primary,
                                  checkColor: Colors.white,
                                  value: isSelected,
                                  onChanged: (_) => _toggleSelection(path),
                                ),
                              );
                            },
                          ),
                          SizedBox(height: 24.h),

                          // Merge Sequence Ordering List
                          if (_orderedSelections.isNotEmpty) ...[
                            Text(
                              "Merge Order (Drag to Reorder)",
                              style: GoogleFonts.outfit(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            ReorderableListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _orderedSelections.length,
                              onReorderItem: (oldIndex, newIndex) {
                                setState(() {
                                  final item = _orderedSelections.removeAt(
                                    oldIndex,
                                  );
                                  _orderedSelections.insert(newIndex, item);
                                });
                              },
                              itemBuilder: (context, index) {
                                final path = _orderedSelections[index];
                                final name = path.split('/').last;
                                return ListTile(
                                  key: ValueKey(path),
                                  leading: CircleAvatar(
                                    backgroundColor: theme.colorScheme.primary
                                        .withValues(alpha: 0.2),
                                    child: Text(
                                      "${index + 1}",
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                  trailing: Icon(
                                    Icons.drag_handle,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // Trigger Button
                Padding(
                  padding: EdgeInsets.all(20.r),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52.h,
                    child: ElevatedButton.icon(
                      onPressed: _orderedSelections.length >= 2
                          ? _mergePdfs
                          : null,
                      icon: const Icon(Icons.merge_type_rounded),
                      label: Text(
                        "Merge ${_orderedSelections.length} PDFs",
                        style: GoogleFonts.outfit(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: isDark
                            ? Colors.white10
                            : Colors.black12,
                        disabledForegroundColor: isDark
                            ? Colors.white24
                            : Colors.black26,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Loading overlay
          if (_isMerging)
            Positioned.fill(
              child: Container(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.76)
                    : Colors.white.withValues(alpha: 0.85),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: theme.colorScheme.primary,
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        "Rendering pages and compiling PDF...",
                        style: GoogleFonts.instrumentSans(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 14.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
