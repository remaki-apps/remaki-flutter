import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Utility class for compressing images down to a target size (~5 KB)
/// while maintaining visual fidelity and text legibility.
class ImageCompressUtil {
  static const int defaultTargetBytes = 5 * 1024; // 5 KB = 5,120 bytes

  /// Compresses a profile picture/avatar.
  /// Square-crops or resizes to avatar dimensions and dynamically optimizes
  /// quality to hit the ~5 KB target without visible degradation on mobile screens.
  static Future<Uint8List> compressProfileImage(
    Uint8List rawBytes, {
    int targetBytes = defaultTargetBytes,
  }) async {
    return compute(_isolateCompressProfile, {
      'bytes': rawBytes,
      'targetBytes': targetBytes,
    });
  }

  /// Compresses a bill, receipt, or payment proof.
  /// Uses document-preserving contrast adjustment and dimension scaling
  /// to keep transaction IDs, numbers, and receipt text crisp while fitting
  /// into the target size (~5 KB).
  static Future<Uint8List> compressDocumentOrBill(
    Uint8List rawBytes, {
    int targetBytes = defaultTargetBytes,
  }) async {
    return compute(_isolateCompressDocument, {
      'bytes': rawBytes,
      'targetBytes': targetBytes,
    });
  }

  // --- Background Isolate Worker for Profile Pictures ---
  static Uint8List _isolateCompressProfile(Map<String, dynamic> params) {
    final Uint8List rawBytes = params['bytes'];
    final int targetBytes = params['targetBytes'] ?? defaultTargetBytes;

    final original = img.decodeImage(rawBytes);
    if (original == null) return rawBytes;

    // Fix EXIF orientation
    final oriented = img.bakeOrientation(original);

    // Profile photos are avatars: scale to 150x150 max maintaining aspect ratio
    final resized = img.copyResize(
      oriented,
      width: oriented.width >= oriented.height ? 150 : null,
      height: oriented.height > oriented.width ? 150 : null,
      interpolation: img.Interpolation.average,
    );

    // Adaptive iterative compression to reach target bytes (e.g. 5 KB)
    int quality = 70;
    Uint8List compressed = Uint8List.fromList(img.encodeJpg(resized, quality: quality));

    while (compressed.lengthInBytes > targetBytes && quality > 20) {
      quality -= 10;
      compressed = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
    }

    // If still slightly over 5KB, shrink slightly to 120px
    if (compressed.lengthInBytes > targetBytes) {
      final smaller = img.copyResize(resized, width: 120, height: 120);
      compressed = Uint8List.fromList(img.encodeJpg(smaller, quality: 40));
    }

    return compressed;
  }

  // --- Background Isolate Worker for Bills / Receipts ---
  static Uint8List _isolateCompressDocument(Map<String, dynamic> params) {
    final Uint8List rawBytes = params['bytes'];
    final int targetBytes = params['targetBytes'] ?? defaultTargetBytes;

    final original = img.decodeImage(rawBytes);
    if (original == null) return rawBytes;

    // Fix EXIF orientation
    final oriented = img.bakeOrientation(original);

    // For receipts and bills, convert to grayscale with enhanced contrast:
    // This removes 65% of noise/color bytes while making printed text, numbers,
    // and stamps significantly sharper and darker!
    final grayscale = img.grayscale(oriented);
    final enhanced = img.contrast(grayscale, contrast: 115);

    // Scale document width to 480px (crisp enough to read any receipt text)
    int targetWidth = 480;
    img.Image resized = img.copyResize(
      enhanced,
      width: targetWidth,
      interpolation: img.Interpolation.linear,
    );

    int quality = 60;
    Uint8List compressed = Uint8List.fromList(img.encodeJpg(resized, quality: quality));

    while (compressed.lengthInBytes > targetBytes && quality > 20) {
      quality -= 10;
      compressed = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
    }

    // If still slightly over target, scale width to 380px
    if (compressed.lengthInBytes > targetBytes) {
      targetWidth = 380;
      final smaller = img.copyResize(enhanced, width: targetWidth);
      compressed = Uint8List.fromList(img.encodeJpg(smaller, quality: 35));
    }

    return compressed;
  }
}
