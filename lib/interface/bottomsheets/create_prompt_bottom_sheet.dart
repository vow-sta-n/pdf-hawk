import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:pdfhawk/data/models/writer_document_model.dart';
import 'package:pdfhawk/data/res/constants.dart';
import 'package:pdfhawk/data/res/utils.dart';
import 'package:pdfhawk/interface/pages/pdf_writer_page.dart';
import 'package:pdfhawk/logic/services/hawk_crypto_service.dart';

class CreatePromptBottomSheet extends StatefulWidget {
  final ThemeData theme;
  final bool isDark;
  final VoidCallback onDocxTap;
  final VoidCallback onBlankTap;

  const CreatePromptBottomSheet({
    super.key,
    required this.theme,
    required this.isDark,
    required this.onDocxTap,
    required this.onBlankTap,
  });

  @override
  State<CreatePromptBottomSheet> createState() =>
      _CreatePromptBottomSheetState();
}

class _CreatePromptBottomSheetState extends State<CreatePromptBottomSheet> {
  bool _isLoading = true;
  List<File> _savedHawkFiles = [];
  Map<String, dynamic>? _ongoingDraft;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    try {
      final files = await HawkCryptoService.getSavedHawkFiles();
      Map<String, dynamic>? draft;
      final box = Hive.box('pdfhawk_box');
      final draftData = box.get('ongoing_writer_session');
      if (draftData != null) {
        if (draftData is Map) {
          draft = Map<String, dynamic>.from(draftData);
        } else if (draftData is String) {
          draft = jsonDecode(draftData) as Map<String, dynamic>;
        }
      }

      if (mounted) {
        setState(() {
          _savedHawkFiles = files;
          _ongoingDraft = draft;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading saved Hawk documents: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openHawkFile(File file) async {
    try {
      final jsonMap = await HawkCryptoService.readHawkFile(file);
      final doc = WriterDocumentModel.fromJson(jsonMap);

      if (!mounted) return;
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfWriterPage(
            initialDeltaJson: doc.quillDeltaJson,
            initialOverlays: doc.overlays,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to decrypt .hawk file: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _pickExternalHawkFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['hawk'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        await _openHawkFile(file);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error opening .hawk file: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _openOngoingDraft() {
    if (_ongoingDraft == null) return;
    try {
      final doc = WriterDocumentModel.fromJson(_ongoingDraft!);
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfWriterPage(
            initialDeltaJson: doc.quillDeltaJson,
            initialOverlays: doc.overlays,
          ),
        ),
      );
    } catch (e) {
      debugPrint("Error opening ongoing draft: $e");
    }
  }

  Future<void> _deleteHawkFile(File file) async {
    await HawkCryptoService.deleteHawkFile(file);
    await _loadSavedData();
  }

  @override
  Widget build(BuildContext context) {
    double w = getWidth(context);
    final isDark = widget.isDark;
    final theme = widget.theme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.r),
          topRight: Radius.circular(20.r),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: w,
            child: Center(child: uihandle(top: 0)),
          ),
          Gap(10.h),
          Text(
            "Open Saved & Progress",
            style: GoogleFonts.outfit(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          Gap(2.h),
          Text(
            "Select how you would like to start creating or resume your document",
            style: GoogleFonts.instrumentSans(
              fontSize: 12.sp,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          Gap(16.h),

          // Top Action Grid: Start Blank, Import DOCX, Open External .hawk
          Row(
            children: [
              Expanded(
                child: _buildActionTile(
                  icon: Icons.add_circle_outline_rounded,
                  title: "Start Blank",
                  subtitle: "Empty doc",
                  onTap: widget.onBlankTap,
                ),
              ),
              Gap(10.w),
              Expanded(
                child: _buildActionTile(
                  icon: Icons.upload_file_rounded,
                  title: "Import DOCX",
                  subtitle: "Word template",
                  onTap: widget.onDocxTap,
                ),
              ),
              Gap(10.w),
              Expanded(
                child: _buildActionTile(
                  icon: Icons.folder_open_rounded,
                  title: "Browse .hawk",
                  subtitle: "Encrypted file",
                  onTap: _pickExternalHawkFile,
                ),
              ),
            ],
          ),
          Gap(18.h),

          // Saved & Ongoing Documents Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "SAVED & DRAFTS (.HAWK)",
                style: GoogleFonts.outfit(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: theme.colorScheme.primary,
                ),
              ),
              if (_savedHawkFiles.isNotEmpty)
                Text(
                  "${_savedHawkFiles.length} Saved",
                  style: GoogleFonts.instrumentSans(
                    fontSize: 11.sp,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                  ),
                ),
            ],
          ),
          Gap(8.h),

          // Flexible list of Ongoing draft & Saved .hawk files
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : (_ongoingDraft == null && _savedHawkFiles.isEmpty)
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 36.r,
                          color: isDark ? Colors.white30 : Colors.black26,
                        ),
                        Gap(8.h),
                        Text(
                          "No saved .hawk documents yet",
                          style: GoogleFonts.instrumentSans(
                            fontSize: 13.sp,
                            color: isDark
                                ? Colors.grey.shade500
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // Ongoing Draft Item (If present in Hive)
                      if (_ongoingDraft != null) ...[
                        Container(
                          margin: EdgeInsets.only(bottom: 8.h),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(14.r),
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.3,
                              ),
                              width: 1.2,
                            ),
                          ),
                          child: ListTile(
                            dense: true,
                            leading: Container(
                              padding: EdgeInsets.all(8.r),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.edit_note_rounded,
                                color: Colors.white,
                                size: 18.r,
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  "Ongoing Session Draft",
                                  style: GoogleFonts.outfit(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                Gap(8.w),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6.w,
                                    vertical: 2.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    borderRadius: BorderRadius.circular(6.r),
                                  ),
                                  child: Text(
                                    "REALTIME",
                                    style: GoogleFonts.instrumentSans(
                                      fontSize: 9.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              "Unsaved progress stored in Hive DB",
                              style: GoogleFonts.instrumentSans(
                                fontSize: 11.sp,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade700,
                              ),
                            ),
                            trailing: Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14.r,
                              color: theme.colorScheme.primary,
                            ),
                            onTap: _openOngoingDraft,
                          ),
                        ),
                      ],

                      // Saved .hawk files
                      ..._savedHawkFiles.map((file) {
                        final name = p.basename(file.path);
                        final bytes = file.lengthSync();
                        final sizeStr =
                            "${(bytes / 1024).toStringAsFixed(1)} KB";

                        return Container(
                          margin: EdgeInsets.only(bottom: 8.h),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.grey.shade900
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(14.r),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.06),
                            ),
                          ),
                          child: ListTile(
                            dense: true,
                            leading: Container(
                              padding: EdgeInsets.all(8.r),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: Icon(
                                Icons.lock_clock_rounded,
                                color: theme.colorScheme.primary,
                                size: 18.r,
                              ),
                            ),
                            title: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            subtitle: Text(
                              "Encrypted .hawk document • $sizeStr",
                              style: GoogleFonts.instrumentSans(
                                fontSize: 11.sp,
                                color: isDark
                                    ? Colors.grey.shade500
                                    : Colors.grey.shade600,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18.r,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () => _deleteHawkFile(file),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 12.r,
                                  color: Colors.grey.shade600,
                                ),
                              ],
                            ),
                            onTap: () => _openHawkFile(file),
                          ),
                        );
                      }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = widget.isDark;
    final theme = widget.theme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 22.r, color: theme.colorScheme.primary),
            ),
            Gap(8.h),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 13.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Gap(2.h),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.instrumentSans(
                fontSize: 10.sp,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
