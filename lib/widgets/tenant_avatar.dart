import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TenantAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;
  final bool enablePreview;

  const TenantAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 20,
    this.backgroundColor,
    this.textColor,
    this.enablePreview = true,
  });

  bool get _isBase64 => imageUrl != null && imageUrl!.startsWith('data:');
  bool get _hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;

  Uint8List? get _base64Bytes {
    if (!_isBase64) return null;
    try {
      final commaIndex = imageUrl!.indexOf(',');
      if (commaIndex == -1) return null;
      return base64Decode(imageUrl!.substring(commaIndex + 1));
    } catch (_) {
      return null;
    }
  }

  void _showImagePreview(BuildContext context, String initial) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 360),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 24, offset: Offset(0, 8))
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 340,
                      color: const Color(0xFFF1F5F9),
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4.0,
                        child: _buildLargeImage(context, initial),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: GestureDetector(
                        onTap: () => Navigator.of(ctx).pop(),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLargeImage(BuildContext context, String initial) {
    if (!_hasImage) return _buildInitialWidget(initial, 40);

    if (_isBase64) {
      final bytes = _base64Bytes;
      if (bytes == null) return _buildInitialWidget(initial, 40);
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildInitialWidget(initial, 40),
      );
    }

    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildInitialWidget(initial, 40),
    );
  }

  Widget _buildInitialWidget(String initial, double size) {
    final bg = backgroundColor ?? AppTheme.primaryColor.withValues(alpha: 0.1);
    final fg = textColor ?? AppTheme.primaryColor;
    return Container(
      color: bg,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: size,
            backgroundColor: bg,
            child: Text(
              initial,
              style: TextStyle(
                fontSize: size * 0.9,
                fontWeight: FontWeight.bold,
                color: fg,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBg = backgroundColor ?? AppTheme.primaryColor.withValues(alpha: 0.1);
    final effectiveFg = textColor ?? AppTheme.primaryColor;
    final initial = name.trim().isNotEmpty ? name.trim().substring(0, 1).toUpperCase() : 'T';

    Widget avatarContent;

    if (!_hasImage) {
      avatarContent = CircleAvatar(
        radius: radius,
        backgroundColor: effectiveBg,
        child: Text(
          initial,
          style: TextStyle(
            color: effectiveFg,
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.85,
          ),
        ),
      );
    } else if (_isBase64) {
      final bytes = _base64Bytes;
      avatarContent = CircleAvatar(
        radius: radius,
        backgroundColor: effectiveBg,
        child: ClipOval(
          child: bytes != null
              ? Image.memory(
                  bytes,
                  width: radius * 2,
                  height: radius * 2,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Text(
                    initial,
                    style: TextStyle(
                      color: effectiveFg,
                      fontWeight: FontWeight.bold,
                      fontSize: radius * 0.85,
                    ),
                  ),
                )
              : Text(
                  initial,
                  style: TextStyle(
                    color: effectiveFg,
                    fontWeight: FontWeight.bold,
                    fontSize: radius * 0.85,
                  ),
                ),
        ),
      );
    } else {
      avatarContent = CircleAvatar(
        radius: radius,
        backgroundColor: effectiveBg,
        child: ClipOval(
          child: Image.network(
            imageUrl!,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Text(
              initial,
              style: TextStyle(
                color: effectiveFg,
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.85,
              ),
            ),
          ),
        ),
      );
    }

    if (!enablePreview) return avatarContent;

    return GestureDetector(
      onTap: () => _showImagePreview(context, initial),
      child: avatarContent,
    );
  }
}
