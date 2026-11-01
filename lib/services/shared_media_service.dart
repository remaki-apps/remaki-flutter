import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class SharedMediaService {
  SharedMediaService._();
  static final SharedMediaService instance = SharedMediaService._();

  StreamSubscription? _intentSub;
  final ValueNotifier<Uint8List?> pendingSharedImage = ValueNotifier<Uint8List?>(null);

  void init() {
    if (kIsWeb) return;

    try {
      // 1. Listen for intents while app is running / in background
      _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
        (List<SharedMediaFile> value) {
          _processFiles(value);
        },
        onError: (err) {
          debugPrint('[SharedMediaService] getMediaStream error: $err');
        },
      );

      // 2. Cold-start intent
      ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
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

      final file = File(imageFile.path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        pendingSharedImage.value = bytes;
      }
    } catch (e) {
      debugPrint('[SharedMediaService] _processFiles error: $e');
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
