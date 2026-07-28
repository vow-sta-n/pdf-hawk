import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfhawk/logic/helpers/pdf_helper.dart';

class RearrangePage extends StatefulWidget {
  final PdfEditSession session;

  const RearrangePage({super.key, required this.session});

  @override
  State<RearrangePage> createState() => _RearrangePageState();
}

class _RearrangePageState extends State<RearrangePage> {
  // Add a blank page
  void _addBlankPage(int insertIndex) {
    setState(() {
      widget.session.pages.insert(
        insertIndex,
        PdfPageModel(
          originalPageIndex: null,
          drawings: [],
          width: 595.0,
          height: 842.0,
        ),
      );
    });
  }

  // Add a page from image
  Future<void> _addImagePage(int insertIndex) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      final imageFile = File(result.files.single.path!);
      final decodedImage = await decodeImageFromList(await imageFile.readAsBytes());
      setState(() {
        widget.session.pages.insert(
          insertIndex,
          PdfPageModel(
            originalPageIndex: null,
            newImageFilePath: imageFile.path,
            drawings: [],
            width: decodedImage.width.toDouble(),
            height: decodedImage.height.toDouble(),
          ),
        );
      });
    }
  }

  void _showAddPageSheet(int insertIndex) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.note_add_outlined, color: isDark ? Colors.white : Colors.black87),
                title: Text("Add Blank A4 Page", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                onTap: () {
                  Navigator.of(context).pop();
                  _addBlankPage(insertIndex);
                },
              ),
              ListTile(
                leading: Icon(Icons.image_outlined, color: isDark ? Colors.white : Colors.black87),
                title: Text("Add Page from Image", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                onTap: () {
                  Navigator.of(context).pop();
                  _addImagePage(insertIndex);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThumbnailCard(PdfPageModel page, int index, {bool isDragging = false}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDragging ? theme.colorScheme.primary : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1)),
          width: isDragging ? 2.r : 1.r,
        ),
      ),
      child: Stack(
        children: [
          // Content Preview
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15.r),
              child: page.newImageFilePath != null
                  ? Image.file(File(page.newImageFilePath!), fit: BoxFit.cover)
                  : (page.cachedImagePath != null
                      ? Image.file(File(page.cachedImagePath!), fit: BoxFit.cover)
                      : Container(color: Colors.white)),
            ),
          ),

          // Translucent gradient overlay for readability
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15.r),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.5),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
          ),

          // Delete button (Top Right)
          Positioned(
            top: 4.r,
            right: 4.r,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  widget.session.pages.removeAt(index);
                });
              },
              child: Container(
                padding: EdgeInsets.all(6.r),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  size: 16.r,
                  color: Colors.redAccent,
                ),
              ),
            ),
          ),

          // Page Number Badge (Bottom Left)
          Positioned(
            bottom: 8.r,
            left: 8.r,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                "Page ${index + 1}",
                style: GoogleFonts.instrumentSans(
                  color: Colors.white,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // Drag Indicator Handles
          Positioned(
            bottom: 8.r,
            right: 8.r,
            child: Icon(
              Icons.drag_indicator_rounded,
              size: 16.r,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageCard(int index) {
    final page = widget.session.pages[index];

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != index,
      onAcceptWithDetails: (details) {
        setState(() {
          final draggedIndex = details.data;
          final temp = widget.session.pages.removeAt(draggedIndex);
          widget.session.pages.insert(index, temp);
        });
      },
      builder: (context, candidateData, rejectedData) {
        return LongPressDraggable<int>(
          data: index,
          feedback: Material(
            elevation: 8,
            color: Colors.transparent,
            child: SizedBox(
              width: 100.w,
              height: 140.h,
              child: _buildThumbnailCard(page, index, isDragging: true),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: _buildThumbnailCard(page, index),
          ),
          child: _buildThumbnailCard(page, index),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = widget.session.pages.length;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        iconTheme: IconThemeData(color: theme.appBarTheme.foregroundColor),
        title: Text(
          "Rearrange Pages",
          style: GoogleFonts.outfit(color: theme.appBarTheme.foregroundColor, fontSize: 18.sp),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () => _showAddPageSheet(pageCount),
            tooltip: "Add Page to End",
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(widget.session);
            },
            child: Text(
              "Done",
              style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: pageCount == 0
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.file_copy_outlined, size: 64.r, color: Colors.grey.shade600),
                  SizedBox(height: 16.h),
                  Text("No pages left", style: TextStyle(color: theme.colorScheme.onSurface)),
                  SizedBox(height: 16.h),
                  ElevatedButton(
                    onPressed: () => _showAddPageSheet(0),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Add a page"),
                  ),
                ],
              ),
            )
          : Padding(
              padding: EdgeInsets.all(16.r),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12.w,
                  mainAxisSpacing: 12.h,
                  childAspectRatio: 0.72,
                ),
                itemCount: pageCount,
                itemBuilder: (context, index) {
                  return _buildPageCard(index);
                },
              ),
            ),
    );
  }
}
