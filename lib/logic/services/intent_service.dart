/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:async';
import 'package:flutter/services.dart';

/// Service to handle opening PDF files when clicked from external file managers or share sheets
class IntentService {
  static const MethodChannel _channel =
      MethodChannel('com.novaturients.pdfhawk/intent');
  static final StreamController<String> _pdfStreamController =
      StreamController<String>.broadcast();

  /// Stream emitting file paths when a PDF is opened via external intent while the app is running
  static Stream<String> get onPdfReceived => _pdfStreamController.stream;

  /// Initialize MethodChannel listener for incoming intents
  static void initialize() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPdfOpened') {
        final String? path = call.arguments as String?;
        if (path != null && path.isNotEmpty) {
          _pdfStreamController.add(path);
        }
      }
    });
  }

  /// Check if the app was launched by tapping a PDF from an external file manager (cold start)
  static Future<String?> getInitialPdf() async {
    try {
      final String? path =
          await _channel.invokeMethod<String>('getInitialPdfPath');
      return path;
    } catch (e) {
      return null;
    }
  }
}
