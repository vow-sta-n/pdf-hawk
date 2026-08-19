/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:convert';
import 'dart:io';
import 'package:community_material_icon/community_material_icon.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:pdfhawk/data/class/p_d_f_hawk_icons_icons.dart';
import 'package:pdfhawk/data/models/writer_document_model.dart';
import 'package:pdfhawk/data/res/theme.dart';
import 'package:pdfhawk/interface/pages/pdf_writer_page.dart';
import 'package:pdfhawk/interface/widgets/bubble_button.dart';
import 'package:pdfhawk/interface/widgets/glass_grid_tile_button.dart';
import 'package:pdfhawk/logic/services/hawk_crypto_service.dart';

class CreatePromptBottomSheet extends StatefulWidget {
  final ThemeData theme;
  final bool isDark;
  final VoidCallback onBlankTap;
  final VoidCallback? onDocxTap;

  const CreatePromptBottomSheet({
    super.key,
    required this.theme,
    required this.isDark,
    required this.onBlankTap,
    this.onDocxTap,
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
      final isAuto = p
          .basename(file.path)
          .toLowerCase()
          .startsWith('autosaved_');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfWriterPage(
            initialDeltaJson: doc.quillDeltaJson,
            initialOverlays: doc.overlays,
            sourceHawkFile: file,
            isAutoSaved: isAuto,
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

  Future<void> _pickExternalFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['docx', 'hawk'],
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final file = File(filePath);
        final ext = p.extension(filePath).toLowerCase();

        if (ext == '.hawk') {
          await _openHawkFile(file);
        } else if (ext == '.docx') {
          final deltaJson = PdfWriterPage.parseDocxToDeltaJson(file);
          if (!mounted) return;
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PdfWriterPage(initialDeltaJson: deltaJson),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error opening file: $e"),
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
            isAutoSaved: true,
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
    final isDark = widget.isDark;
    final theme = widget.theme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(10.r),
          topRight: Radius.circular(10.r),
        ),
      ),
      padding: EdgeInsets.symmetric(vertical: 14.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              BubbleButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.pop(context),
              ),

            ],
          ),
          Gap(10.h),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Create a PDF",
                  style: GoogleFonts.outfit(
                    fontSize: 37.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Gap(2.h),
                Text(
                  "Select how you would like to start creating or resume your document",
                  style: GoogleFonts.instrumentSans(
                    fontSize: 14.sp,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Gap(16.h),

          // Top Action Buttons: Start Blank & Open (DOCX / .hawk)
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: GlassGridTileButton(
                    icon: Icons.edit,
                    title: "Start Blank",
                    description: "Empty document",
                    onTap: widget.onBlankTap,
                    theme: theme,
                    space: 10,
                    isDark: isDark,
                  ),
                ),
                Gap(12.w),
                Expanded(
                  child: GlassGridTileButton(
                    icon: PDFHawkIcons.folder_open,
                    title: "Open",
                    description: "DOCX or .hawk file",
                    onTap: _pickExternalFile,
                    space: 10,
                    theme: theme,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
          Gap(18.h),

          // Saved & Ongoing Documents Header
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Saved & Drafts",
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
                      color: isDark
                          ? Colors.grey.shade500
                          : Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
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
                    padding: EdgeInsets.symmetric(horizontal: 8),
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
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(14.r),
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

                          child: ListTile(
                            dense: true,
                            leading: Icon(
                              CommunityMaterialIcons.lock_check_outline,
                              color: theme.colorScheme.primary,
                              size: 34.r,
                            ),
                            title: Text(
                              name.replaceAll('.hawk', ''),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            subtitle: Text(
                              "Encrypted (Hawk) • $sizeStr",
                              style: GoogleFonts.instrumentSans(
                                fontSize: 11.sp,
                                color: grey,
                              ),
                            ),
                            trailing: PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_vert_rounded,
                                size: 20.r,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                              onSelected: (action) {
                                if (action == 'open') {
                                  _openHawkFile(file);
                                } else if (action == 'delete') {
                                  _deleteHawkFile(file);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'open',
                                  child: Row(
                                    children: [
                                      Icon(Icons.open_in_new_rounded, size: 18),
                                      Gap(8),
                                      Text("Open"),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18,
                                        color: Colors.red,
                                      ),
                                      Gap(8),
                                      Text(
                                        "Delete",
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            contentPadding: EdgeInsets.all(0),
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
}
