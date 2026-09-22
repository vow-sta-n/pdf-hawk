/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:community_material_icon/community_material_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfhawk/data/class/p_d_f_hawk_icons_icons.dart';
import 'package:pdfhawk/data/models/writer_document_model.dart';
import 'package:pdfhawk/data/res/theme.dart';
import 'package:path/path.dart' as p;
import 'package:pdfhawk/interface/pages/home/recent_files.dart';
import 'package:pdfhawk/interface/pages/home/settings_page.dart';
import 'package:pdfhawk/interface/bottomsheets/create_prompt_bottom_sheet.dart';
import 'package:pdfhawk/interface/bottomsheets/edit_tools_bottom_sheet.dart';
import 'package:pdfhawk/interface/widgets/glass_grid_tile_button.dart';
import 'package:pdfhawk/data/res/utils.dart';
import 'package:pdfhawk/logic/services/hawk_crypto_service.dart';
import 'package:pdfhawk/interface/pages/home/quick_access_view.dart';
import 'package:pdfhawk/interface/widgets/tutorial_card_widget.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:pdfhawk/data/res/constants.dart';
import 'package:pdfhawk/interface/pages/home/all_documents_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _keySettings = GlobalKey();
  final GlobalKey _keyHelp = GlobalKey();
  final GlobalKey _keyScan = GlobalKey();
  final GlobalKey _keyEdit = GlobalKey();
  final GlobalKey _keyAllDocs = GlobalKey();
  final GlobalKey _keyQuickAccess = GlobalKey();
  final GlobalKey _keyRecentFiles = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoSavedWriterSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: isDark ? Colors.black : white, //Colors.grey.shade100,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // _buildBottomNavBar(isDark, theme),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Gap(20.h),
                      header(isDark),
                      Gap(30.h),

                      pdfToolsMenu(theme, isDark),
                      Gap(10),
                      AllDocumentsCard(key: _keyAllDocs),
                      Gap(30.h),
                      // Folders Section (Header + Horizontal List)
                      QuickAccessView(key: _keyQuickAccess),
                      Gap(30.h),
                      RecentFilesView(key: _keyRecentFiles, isEmbedded: true),
                      Gap(16.h),
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

  Widget header(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                'My',
                style: GoogleFonts.outfit(
                  height: 1,
                  fontSize: 37.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Gap(8),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Documents',
                style: GoogleFonts.outfit(
                  height: 1,
                  fontSize: 37.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  InkWell(
                    key: _keySettings,
                    onTap: () {
                      bottomSheet(
                        context,
                        SettingsPage(
                          ctx: context,
                          onUpdateCompare: (hj, cls) {},
                        ),
                      );
                    },
                    borderRadius: allradius(25),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isDark ? Colors.white70 : Colors.black54,
                          width: 2,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          PDFHawkIcons.cog,
                          color: isDark ? Colors.white70 : Colors.black54,
                          size: 16.sp,
                        ),
                      ),
                    ),
                  ),
                  Gap(8),
                  InkWell(
                    key: _keyHelp,
                    onTap: _showTutorial,
                    child: Icon(
                      Icons.help_outline_rounded,
                      size: 30.r,

                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  GridView pdfToolsMenu(ThemeData theme, bool isDark) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 15.w,
      mainAxisSpacing: 15.h,
      childAspectRatio: 1.4,
      children: [
        GlassGridTileButton(
          key: _keyScan,
          icon: PDFHawkIcons.scan,
          title: "Scan/Create",
          description: "Documents, ID cards...",
          onTap: () => bottomSheet(
            context,
            CreatePromptBottomSheet(theme: theme, isDark: isDark),
          ),
          theme: theme,
          isDark: isDark,
        ),

        GlassGridTileButton(
          key: _keyEdit,
          icon: CommunityMaterialIcons.file_edit_outline,
          title: "Edit",
          description: "Split, Merge, Convert & more",
          onTap: () => bottomSheet(
            context,
            EditToolsBottomSheet(theme: theme, isDark: isDark),
          ),
          theme: theme,
          isDark: isDark,
        ),
      ],
    );
  }

  void _showTutorial() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    showAppTutorial(
      context: context,
      steps: [
        TutorialStep(
          identify: "help",
          keyTarget: _keyHelp,
          shape: ShapeLightFocus.Circle,
          align: ContentAlign.bottom,
          title: "Help & Quick Tour",
          description:
              "Tap this Help icon anytime to replay this interactive feature tour and explore how to get the most out of PDF Hawk.",
          icon: Icons.help_outline_rounded,
        ),
        TutorialStep(
          identify: "settings",
          keyTarget: _keySettings,
          shape: ShapeLightFocus.Circle,
          align: ContentAlign.bottom,
          title: "App Settings & Themes",
          description:
              "Switch between Dark, Light, and System themes, choose custom accent colors, manage storage permissions, and explore app info.",
          icon: PDFHawkIcons.cog,
        ),
        TutorialStep(
          identify: "scan_create",
          keyTarget: _keyScan,
          shape: ShapeLightFocus.RRect,
          radius: 20.r,
          align: ContentAlign.bottom,
          title: "Scan & Create Documents",
          description:
              "Scan physical documents and ID cards using your camera, or compose a fresh PDF document using the rich text PDF Writer.",
          icon: PDFHawkIcons.scan,
        ),
        TutorialStep(
          identify: "edit_tools",
          keyTarget: _keyEdit,
          shape: ShapeLightFocus.RRect,
          radius: 20.r,
          align: ContentAlign.bottom,
          title: "PDF Editing Suite",
          description:
              "Split PDFs into custom parts, merge multiple files together, convert images or Word files into PDF, and reorder pages.",
          icon: CommunityMaterialIcons.file_edit_outline,
        ),
        TutorialStep(
          identify: "all_docs",
          keyTarget: _keyAllDocs,
          shape: ShapeLightFocus.RRect,
          radius: 20.r,
          align: ContentAlign.top,
          title: "Document Hub & Storage",
          description:
              "Overview of all documents on your device categorized by PDF, Word, Excel, and PowerPoint with real-time storage metrics.",
          icon: CommunityMaterialIcons.folder_text_outline,
        ),
        TutorialStep(
          identify: "quick_access",
          keyTarget: _keyQuickAccess,
          shape: ShapeLightFocus.RRect,
          radius: 16.r,
          align: ContentAlign.top,
          title: "Quick Access Folders",
          description:
              "Bookmark your favorite device folders to quickly browse, open, and manage their documents in one dedicated place.",
          icon: PDFHawkIcons.folder,
        ),
        TutorialStep(
          identify: "recent_files",
          keyTarget: _keyRecentFiles,
          shape: ShapeLightFocus.RRect,
          radius: 16.r,
          align: ContentAlign.top,
          title: "Recent Files",
          description:
              "Quickly access, search, filter, and share your recently viewed and edited documents whenever you need them.",
          icon: Icons.history_rounded,
        ),
      ],
    );
  }

  Future<void> _checkAutoSavedWriterSession() async {
    try {
      Map<String, dynamic>? jsonMap;
      final box = Hive.box('pdfhawk_box');
      final draftData = box.get('ongoing_writer_session');
      if (draftData != null) {
        if (draftData is Map) {
          jsonMap = Map<String, dynamic>.from(draftData);
        } else if (draftData is String) {
          jsonMap = jsonDecode(draftData) as Map<String, dynamic>;
        }
      }

      final dir = await getApplicationDocumentsDirectory();
      final legacyFile = File("${dir.path}/auto_save_writer.json");
      if (jsonMap == null && await legacyFile.exists()) {
        final jsonStr = await legacyFile.readAsString();
        jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
      }

      if (jsonMap != null) {
        final doc = WriterDocumentModel.fromJson(jsonMap);
        final bool hasContent =
            doc.overlays.isNotEmpty ||
            (doc.quillDeltaJson.isNotEmpty &&
                doc.quillDeltaJson != "[]" &&
                doc.quillDeltaJson != '[{"insert":"\\n"}]');

        if (hasContent) {
          final docName = "AutoSaved_${DateTime.now().millisecondsSinceEpoch}";
          final savedHawkFile = await HawkCryptoService.saveHawkFile(
            docName,
            jsonMap,
          );

          await box.delete('ongoing_writer_session');
          if (await legacyFile.exists()) {
            await legacyFile.delete();
          }

          plainToast(
            msg:
                "Saved unsaved session to storage as '${p.basename(savedHawkFile.path)}'",
          );
        } else {
          await box.delete('ongoing_writer_session');
          if (await legacyFile.exists()) {
            await legacyFile.delete();
          }
        }
      }
    } catch (e) {
      debugPrint("Failed auto-save background recovery: $e");
    }
  }
}

/*
 // Search Bar Trigger Button
            GestureDetector(
              key: _keySearch,
              onTap: () {
                setState(() {
                  _isSearchExpanded = true;
                  _searchAllDeviceFiles = true;
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _searchFocusNode.requestFocus();
                });
              },
              child: Container(
                height: 50.h,
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: allradius(56.r),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      color: theme.colorScheme.primary.withAlpha(155),
                      size: 22.r,
                    ),
                    Gap(10.w),
                    Expanded(
                      child: Text(
                        "Search all documents...",
                        style: GoogleFonts.outfit(
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade600,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
 */
