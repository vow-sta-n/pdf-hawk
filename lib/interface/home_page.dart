import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfhawk/interface/pdf_editor_page.dart';
import 'package:path/path.dart' as p;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<String> _recentFiles = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRecentFiles();
  }

  Future<void> _loadRecentFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('recent_files') ?? [];
    setState(() {
      _recentFiles = list;
    });
  }

  Future<void> _addRecentFile(String path) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> list = prefs.getStringList('recent_files') ?? [];

    // Remove duplicate if it exists and insert at index 0
    list.remove(path);
    list.insert(0, path);

    // Limit to 6 recent files
    if (list.length > 6) {
      list = list.sublist(0, 6);
    }

    await prefs.setStringList('recent_files', list);
    setState(() {
      _recentFiles = list;
    });
  }

  Future<void> _removeRecentFile(String path) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> list = prefs.getStringList('recent_files') ?? [];
    list.remove(path);
    await prefs.setStringList('recent_files', list);
    setState(() {
      _recentFiles = list;
    });
  }

  Future<void> _pickPdf() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final file = File(path);

        await _addRecentFile(path);
        if (!mounted) return;

        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (context) => PdfEditorPage(pdfFile: file),
              ),
            )
            .then((_) => _loadRecentFiles());
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error opening PDF: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _openRecentFile(String path) {
    final file = File(path);
    if (file.existsSync()) {
      _addRecentFile(path);
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (context) => PdfEditorPage(pdfFile: file),
            ),
          )
          .then((_) => _loadRecentFiles());
    } else {
      // File no longer exists, remove it and warn user
      _removeRecentFile(path);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("File no longer exists: ${p.basename(path)}"),
          backgroundColor: Colors.amber.shade800,
        ),
      );
    }
  }

  String _getFileSizeString(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        final bytes = file.lengthSync();
        return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
      }
    } catch (_) {}
    return "-- MB";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F0F10), Color(0xFF16151B), Color(0xFF0D0C0E)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "PDF Hawk",
                          style: GoogleFonts.outfit(
                            fontSize: 32.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.8,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          "Professional PDF Editor & Compiler",
                          style: GoogleFonts.instrumentSans(
                            fontSize: 14.sp,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 44.r,
                      height: 44.r,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Colors.deepPurpleAccent,
                            Colors.purpleAccent,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      child: Icon(
                        Icons.picture_as_pdf,
                        color: Colors.white,
                        size: 24.r,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 40.h),

                // Welcome / Primary Action Card
                Center(
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(28.r),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.06),
                          Colors.white.withValues(alpha: 0.02),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(28.r),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 80.r,
                          height: 80.r,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.deepPurple.withValues(alpha: 0.15),
                            border: Border.all(
                              color: Colors.deepPurpleAccent.withValues(
                                alpha: 0.3,
                              ),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            Icons.upload_file_rounded,
                            size: 40.r,
                            color: Colors.deepPurpleAccent,
                          ),
                        ),
                        SizedBox(height: 20.h),
                        Text(
                          "Edit Your PDF",
                          style: GoogleFonts.outfit(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          "Select a document from your device to annotate, add/delete/rearrange pages, or merge PDFs.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.instrumentSans(
                            fontSize: 14.sp,
                            color: Colors.grey.shade400,
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: 28.h),
                        _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.deepPurpleAccent,
                              )
                            : ElevatedButton.icon(
                                onPressed: _pickPdf,
                                icon: const Icon(
                                  Icons.folder_open_rounded,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  "Open PDF Document",
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15.sp,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurpleAccent,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 28.w,
                                    vertical: 14.h,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16.r),
                                  ),
                                  elevation: 5,
                                  shadowColor: Colors.deepPurpleAccent
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 40.h),

                // Recent Documents Section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Recent Documents",
                        style: GoogleFonts.outfit(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Expanded(
                        child: _recentFiles.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.history_rounded,
                                      size: 40.r,
                                      color: Colors.grey.shade700,
                                    ),
                                    SizedBox(height: 12.h),
                                    Text(
                                      "No recently opened PDFs",
                                      style: GoogleFonts.instrumentSans(
                                        fontSize: 14.sp,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                itemCount: _recentFiles.length,
                                itemBuilder: (context, index) {
                                  final filePath = _recentFiles[index];
                                  final fileName = p.basename(filePath);
                                  final fileSize = _getFileSizeString(filePath);

                                  return Container(
                                    margin: EdgeInsets.only(bottom: 12.h),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.02,
                                      ),
                                      borderRadius: BorderRadius.circular(16.r),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.04,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    child: ListTile(
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16.w,
                                        vertical: 6.h,
                                      ),
                                      leading: Container(
                                        padding: EdgeInsets.all(10.r),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12.r,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.picture_as_pdf_rounded,
                                          color: Colors.redAccent,
                                          size: 24.r,
                                        ),
                                      ),
                                      title: Text(
                                        fileName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.instrumentSans(
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      subtitle: Padding(
                                        padding: EdgeInsets.only(top: 4.h),
                                        child: Text(
                                          fileSize,
                                          style: GoogleFonts.instrumentSans(
                                            fontSize: 12.sp,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ),
                                      trailing: Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        color: Colors.grey.shade600,
                                        size: 14.r,
                                      ),
                                      onTap: () => _openRecentFile(filePath),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
