import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pdf_types;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfhawk/interface/pages/ReadWrite/pdf_reader_page.dart';
import 'package:pdfhawk/interface/pages/Scan/scan_edit_page.dart';

class ScanRearrangePage extends StatefulWidget {
  final List<String> imagePaths;

  const ScanRearrangePage({super.key, required this.imagePaths});

  @override
  State<ScanRearrangePage> createState() => _ScanRearrangePageState();
}

class _ScanRearrangePageState extends State<ScanRearrangePage> {
  late List<String> _paths;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _paths = List<String>.from(widget.imagePaths);
  }

  void _moveLeft(int index) {
    if (index <= 0) return;
    setState(() {
      final temp = _paths[index];
      _paths[index] = _paths[index - 1];
      _paths[index - 1] = temp;
    });
  }

  void _moveRight(int index) {
    if (index >= _paths.length - 1) return;
    setState(() {
      final temp = _paths[index];
      _paths[index] = _paths[index + 1];
      _paths[index + 1] = temp;
    });
  }

  void _deleteImage(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Page?"),
        content: const Text(
          "Are you sure you want to delete this scanned page?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                final deletedPath = _paths.removeAt(index);
                final file = File(deletedPath);
                if (file.existsSync()) {
                  file.deleteSync();
                }
              });
              Navigator.pop(context);
              if (_paths.isEmpty) {
                Navigator.pop(context); // Go back to camera if no pages left
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToPdf() async {
    if (_paths.isEmpty) return;

    setState(() {
      _isExporting = true;
    });

    try {
      final pdf = pw.Document();

      for (final path in _paths) {
        final file = File(path);
        if (file.existsSync()) {
          final imageBytes = file.readAsBytesSync();
          final image = pw.MemoryImage(imageBytes);

          pdf.addPage(
            pw.Page(
              pageFormat: pdf_types.PdfPageFormat.a4,
              margin: const pw.EdgeInsets.all(0),
              build: (pw.Context context) {
                return pw.Center(
                  child: pw.Image(image, fit: pw.BoxFit.contain),
                );
              },
            ),
          );
        }
      }

      // Save PDF to Documents Directory
      final outputDir = await getApplicationDocumentsDirectory();
      final outputFile = File(
        "${outputDir.path}/Scanned_${DateTime.now().millisecondsSinceEpoch}.pdf",
      );
      await outputFile.writeAsBytes(await pdf.save());

      // Add to Hive recently opened files
      final box = Hive.box('pdfhawk_box');
      List<String> recentList = List<String>.from(
        box.get('recent_files') ?? [],
      );
      recentList.remove(outputFile.path);
      recentList.insert(0, outputFile.path);
      if (recentList.length > 50) {
        recentList = recentList.sublist(0, 50);
      }
      await box.put('recent_files', recentList);

      // Clean up temporary scanned JPEGs
      for (final path in _paths) {
        final file = File(path);
        if (file.existsSync()) {
          file.deleteSync();
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("PDF Exported and saved successfully!"),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to Editor
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => PDFReaderPage(pdfFile: outputFile),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to export PDF: $e")));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        iconTheme: IconThemeData(color: theme.appBarTheme.foregroundColor),
        title: Text(
          "Organize & Export",
          style: GoogleFonts.outfit(
            color: theme.appBarTheme.foregroundColor,
            fontSize: 18.sp,
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Info description header
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                child: Text(
                  "Tap a thumbnail to edit/crop. Reorder scans using the arrows below.",
                  style: GoogleFonts.instrumentSans(
                    fontSize: 13.sp,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ),

              // Image Thumbnail Cards Grid
              Expanded(
                child: GridView.builder(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 10.h,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16.w,
                    mainAxisSpacing: 16.h,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: _paths.length,
                  itemBuilder: (context, index) {
                    final path = _paths[index];
                    return Card(
                      color: isDark ? Colors.grey.shade900 : Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                        side: BorderSide(
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Interactive Thumbnail
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ScanEditPage(
                                      imagePath: path,
                                      onSave: (newPath) {
                                        setState(() {
                                          _paths[index] = newPath;
                                        });
                                      },
                                    ),
                                  ),
                                );
                              },
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.file(File(path), fit: BoxFit.cover),
                                  Positioned(
                                    top: 8.h,
                                    left: 8.w,
                                    child: CircleAvatar(
                                      radius: 12.r,
                                      backgroundColor:
                                          theme.colorScheme.primary,
                                      child: Text(
                                        "${index + 1}",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Control Buttons
                          Container(
                            height: 48.h,
                            color: isDark
                                ? Colors.black26
                                : Colors.grey.shade50,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // Move Left
                                IconButton(
                                  icon: const Icon(
                                    Icons.arrow_back_rounded,
                                    size: 18,
                                  ),
                                  onPressed: index > 0
                                      ? () => _moveLeft(index)
                                      : null,
                                  color: theme.colorScheme.primary,
                                  disabledColor: Colors.grey.shade400,
                                ),
                                // Delete
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _deleteImage(index),
                                ),
                                // Move Right
                                IconButton(
                                  icon: const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 18,
                                  ),
                                  onPressed: index < _paths.length - 1
                                      ? () => _moveRight(index)
                                      : null,
                                  color: theme.colorScheme.primary,
                                  disabledColor: Colors.grey.shade400,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Export Button row
              Container(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0D0D0D) : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52.h,
                  child: ElevatedButton.icon(
                    onPressed: _isExporting ? null : _exportToPdf,
                    icon: const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Colors.white,
                    ),
                    label: Text(
                      "Export to PDF (${_paths.length} Pages)",
                      style: GoogleFonts.outfit(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Loading cover
          if (_isExporting)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
