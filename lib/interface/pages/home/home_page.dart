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
import 'package:pdfhawk/interface/pages/home/widgets/recent_files.dart';
import 'package:pdfhawk/interface/pages/home/Sheets/settings_page.dart';
import 'package:pdfhawk/interface/pages/home/Sheets/create_prompt_bottom_sheet.dart';
import 'package:pdfhawk/interface/pages/home/Sheets/edit_tools_bottom_sheet.dart';
import 'package:pdfhawk/interface/globals/glass_grid_tile_button.dart';
import 'package:pdfhawk/data/res/utils.dart';
import 'package:pdfhawk/logic/services/hawk_crypto_service.dart';
import 'package:pdfhawk/interface/pages/home/widgets/quick_access_view.dart';
import 'package:pdfhawk/interface/pages/home/widgets/all_documents_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scrollController = ScrollController();

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
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Gap(30.h),
              header(isDark),
              Gap(30.h),
              pdfToolsMenu(theme, isDark),
              Gap(10),
              AllDocumentsCard(),
              Gap(30.h),
              // Folders Section (Header + Horizontal List)
              QuickAccessView(),
              Gap(30.h),
              RecentFilesView(isEmbedded: true),
              Gap(16.h),
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
              InkWell(
                onTap: () {
                  bottomSheet(
                    context,
                    SettingsPage(ctx: context, onUpdateCompare: (hj, cls) {}),
                  );
                },
                borderRadius: allradius(25),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(shape: BoxShape.circle),
                  child: Center(
                    child: Icon(
                      CommunityMaterialIcons.cog,
                      color: isDark ? Colors.white70 : Colors.black54,
                      size: 25.sp,
                    ),
                  ),
                ),
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
