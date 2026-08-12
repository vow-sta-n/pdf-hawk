/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/services.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:pdfhawk/data/res/constants.dart';
import 'package:pdfhawk/data/res/theme.dart';

Widget uihandle({double? top, double? bottom}) {
  return Container(
    height: 5,
    margin: EdgeInsets.only(top: top ?? 10, bottom: bottom ?? 10),
    width: 100.w,
    decoration: BoxDecoration(color: offgrey, borderRadius: allradius(8)),
  );
}

OutlineInputBorder defaultborder() {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(5),
    borderSide: BorderSide(color: grey.withValues(alpha: 0.2)),
  );
}

void bottomSheet(
  BuildContext context,
  Widget widget, {
  bool? drag,
  dynamic onClose,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  showCupertinoModalBottomSheet(
    backgroundColor: transparent,
    context: context,
    clipBehavior: Clip.antiAliasWithSaveLayer,
    topRadius: const Radius.circular(10),
    barrierColor: isDark ? black.withAlpha(160) : black.withAlpha(100),
    overlayStyle: isDark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark,
    enableDrag: drag ?? true,
    transitionBackgroundColor: isDark ? black : silver,
    bounce: false,
    duration: const Duration(milliseconds: 700),
    shadow: const BoxShadow(blurRadius: 0, color: transparent, spreadRadius: 0),
    animationCurve: Curves.ease,
    expand: false,
    previousRouteAnimationCurve: Curves.ease,
    elevation: 0,
    useRootNavigator: true,
    isDismissible: true,
    builder: (context) {
      return widget;
    },
  ).then((_) {
    if (onClose != null) {
      onClose();
    }
  });
}

AppBar noAppbar() {
  return AppBar(
    toolbarHeight: 0,
    bottomOpacity: 1.0,
    elevation: 0,
    foregroundColor: transparent,
    scrolledUnderElevation: 0,
    shadowColor: transparent,
    automaticallyImplyLeading: false,
    leadingWidth: 0,
  );
}

Future<bool?> plainToast({required String msg}) {
  return Fluttertoast.showToast(
    msg: msg,
    toastLength: Toast.LENGTH_SHORT,
    gravity: ToastGravity.BOTTOM,
    timeInSecForIosWeb: 4,
    backgroundColor: darkbg,
    textColor: white,
    fontSize: 13.sp,
  );
}
