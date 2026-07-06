import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfhawk/logic/pdf_helper.dart';

class MergePage extends StatefulWidget {
  final List<String> pdfPaths;
  final String? folderUri;

  const MergePage({
    super.key,
    required this.pdfPaths,
    this.folderUri,
  });

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
          content: Text("PDFs merged successfully: ${outputFile.path.split('/').last}"),
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
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16151B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "Merge PDFs",
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 18.sp),
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
                              color: Colors.white70,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          TextField(
                            controller: _fileNameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: "Enter custom file name...",
                              hintStyle: TextStyle(color: Colors.grey.shade600),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.03),
                              contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: const BorderSide(color: Colors.purpleAccent),
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
                              color: Colors.white,
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
                                  color: Colors.white.withValues(alpha: 0.02),
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.purpleAccent.withValues(alpha: 0.4)
                                        : Colors.white.withValues(alpha: 0.05),
                                  ),
                                ),
                                child: CheckboxListTile(
                                  title: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.instrumentSans(
                                      color: Colors.white,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  activeColor: Colors.purpleAccent,
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
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            ReorderableListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _orderedSelections.length,
                              onReorderItem: (oldIndex, newIndex) {
                                setState(() {
                                  final item = _orderedSelections.removeAt(oldIndex);
                                  _orderedSelections.insert(newIndex, item);
                                });
                              },
                              itemBuilder: (context, index) {
                                final path = _orderedSelections[index];
                                final name = path.split('/').last;
                                return ListTile(
                                  key: ValueKey(path),
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.purple.withValues(alpha: 0.2),
                                    child: Text(
                                      "${index + 1}",
                                      style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  trailing: const Icon(Icons.drag_handle, color: Colors.white70),
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
                      onPressed: _orderedSelections.length >= 2 ? _mergePdfs : null,
                      icon: const Icon(Icons.merge_type_rounded),
                      label: Text(
                        "Merge ${_orderedSelections.length} PDFs",
                        style: GoogleFonts.outfit(fontSize: 16.sp, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purpleAccent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.white10,
                        disabledForegroundColor: Colors.white24,
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
                color: Colors.black.withValues(alpha: 0.76),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Colors.purpleAccent),
                      SizedBox(height: 16.h),
                      Text(
                        "Rendering pages and compiling PDF...",
                        style: GoogleFonts.instrumentSans(color: Colors.white, fontSize: 14.sp),
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
