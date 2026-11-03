import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class SharedMediaService {
  SharedMediaService._();
  static final SharedMediaService instance = SharedMediaService._();

  static const _channel = MethodChannel('com.remaki.app/media_channel');

  StreamSubscription? _intentSub;
  final ValueNotifier<Uint8List?> pendingSharedImage = ValueNotifier<Uint8List?>(null);

  void init() {
    if (kIsWeb) return;

    try {
      // 1. Listen for intents while app is running / resumed from background
      _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
        (List<SharedMediaFile> value) {
          debugPrint('[SharedMediaService] getMediaStream received: ${value.map((f) => f.path).toList()}');
          _processFiles(value);
        },
        onError: (err) {
          debugPrint('[SharedMediaService] getMediaStream error: $err');
        },
      );

      // 2. Cold-start intent when app was completely launched via share
      ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
        debugPrint('[SharedMediaService] getInitialMedia received: ${value.map((f) => f.path).toList()}');
        _processFiles(value);
        ReceiveSharingIntent.instance.reset();
      }).catchError((err) {
        debugPrint('[SharedMediaService] getInitialMedia error: $err');
      });
    } catch (e) {
      debugPrint('[SharedMediaService] init error: $e');
    }
  }

  Future<void> _processFiles(List<SharedMediaFile> files) async {
    if (files.isEmpty) return;
    try {
      final imageFile = files.firstWhere(
        (f) =>
            f.type == SharedMediaType.image ||
            f.path.toLowerCase().endsWith('.png') ||
            f.path.toLowerCase().endsWith('.jpg') ||
            f.path.toLowerCase().endsWith('.jpeg'),
        orElse: () => files.first,
      );

      debugPrint('[SharedMediaService] Selected image file path: ${imageFile.path}');

      Uint8List? bytes;
      if (imageFile.path.startsWith('content://')) {
        // Android content:// URI shared by apps like GPay, WhatsApp, etc.
        try {
          final res = await _channel.invokeMethod<dynamic>('readUriBytes', {'uri': imageFile.path});
          if (res is Uint8List) {
            bytes = res;
          } else if (res is List) {
            bytes = Uint8List.fromList(res.cast<int>());
          }
        } catch (e) {
          debugPrint('[SharedMediaService] Error reading content URI: $e');
        }
      } else {
        final cleanPath = imageFile.path.startsWith('file://')
            ? imageFile.path.replaceFirst('file://', '')
            : imageFile.path;
        final file = File(cleanPath);
        if (await file.exists()) {
          bytes = await file.readAsBytes();
        } else {
          debugPrint('[SharedMediaService] File does not exist at path: $cleanPath');
        }
      }

      if (bytes != null && bytes.isNotEmpty) {
        debugPrint('[SharedMediaService] Successfully loaded shared image (${bytes.length} bytes)');
        pendingSharedImage.value = bytes;
      }
    } catch (e, stack) {
      debugPrint('[SharedMediaService] _processFiles error: $e\n$stack');
    }
  }

  Uint8List? consumePendingImage() {
    final image = pendingSharedImage.value;
    pendingSharedImage.value = null;
    return image;
  }

  void dispose() {
    _intentSub?.cancel();
  }
}
