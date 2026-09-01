
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart';

class ImageEditParams {
  final String inputPath;
  final String outputPath;
  final double cropLeft;
  final double cropTop;
  final double cropRight;
  final double cropBottom;
  final bool isCropActive;
  final double rotationAngle;
  final bool flipHorizontal;
  final bool flipVertical;
  final double contrast;
  final double saturation;
  final double brightness;
  final Uint8List? shaderProcessedBytes;

  ImageEditParams({
    required this.inputPath,
    required this.outputPath,
    required this.cropLeft,
    required this.cropTop,
    required this.cropRight,
    required this.cropBottom,
    required this.isCropActive,
    required this.rotationAngle,
    required this.flipHorizontal,
    required this.flipVertical,
    required this.contrast,
    required this.saturation,
    required this.brightness,
    this.shaderProcessedBytes,
  });
}



Future<bool> processImageEditsIsolate(ImageEditParams params) async {
  try {
    Uint8List bytes;
    if (params.shaderProcessedBytes != null) {
      bytes = params.shaderProcessedBytes!;
    } else {
      final inputFile = File(params.inputPath);
      if (!inputFile.existsSync()) return false;
      bytes = await inputFile.readAsBytes();
    }

    img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) return false;

    // 1. Crop
    if (params.isCropActive &&
        (params.cropLeft > 0.01 ||
            params.cropTop > 0.01 ||
            params.cropRight < 0.99 ||
            params.cropBottom < 0.99)) {
      final x = (decoded.width * params.cropLeft).round();
      final y = (decoded.height * params.cropTop).round();
      final w = (decoded.width * (params.cropRight - params.cropLeft)).round();
      final h = (decoded.height * (params.cropBottom - params.cropTop)).round();
      if (w > 10 && h > 10) {
        decoded = img.copyCrop(
          decoded,
          x: x.clamp(0, decoded.width - 1),
          y: y.clamp(0, decoded.height - 1),
          width: w.clamp(1, decoded.width - x),
          height: h.clamp(1, decoded.height - y),
        );
      }
    }

    // 2. Rotate
    if (params.rotationAngle != 0.0) {
      decoded = img.copyRotate(decoded, angle: params.rotationAngle);
    }

    // 3. Flips
    if (params.flipHorizontal) {
      decoded = img.flipHorizontal(decoded);
    }
    if (params.flipVertical) {
      decoded = img.flipVertical(decoded);
    }

    // 4. Adjustments
    if (params.contrast != 0.0) {
      final contrastVal = 100.0 + params.contrast;
      decoded = img.contrast(decoded, contrast: contrastVal);
    }
    if (params.saturation != 0.0 || params.brightness != 0.0) {
      final satVal = 1.0 + (params.saturation / 50.0);
      final amountVal = params.brightness / 50.0;
      decoded = img.adjustColor(decoded, saturation: satVal, amount: amountVal);
    }

    final encoded = img.encodeJpg(decoded, quality: 90);
    final outputFile = File(params.outputPath);
    await outputFile.writeAsBytes(encoded);
    return true;
  } catch (e) {
    debugPrint("Isolate image processing error: $e");
    return false;
  }
}
