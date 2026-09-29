import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
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
      barrierColor: Colors.transparent,
      builder: (ctx) => Stack(
        children: [
          // Immersive Dark Frosted Glass Backdrop (tappable to dismiss)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(ctx).pop(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.86),
                ),
              ),
            ),
          ),
          Center(
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Row: User Name & Glassmorphic Close Button
                  Container(
                    constraints: const BoxConstraints(maxWidth: 300),
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Profile Photo',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => Navigator.of(ctx).pop(),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                            ),
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Floating Avatar Hero Presentation (modern rounded squircle, no ugly white box)
                  Container(
                    constraints: const BoxConstraints(maxWidth: 300, maxHeight: 300),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.20), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.65),
                          blurRadius: 36,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: Container(
                        width: 300,
                        height: 300,
                        color: const Color(0xFF0F172A),
                        child: InteractiveViewer(
                          minScale: 0.8,
                          maxScale: 3.5,
                          child: _buildLargeImage(context, initial),
                        ),
                      ),
                    ),
                  ),

                  // Subtle Pinch-to-Zoom Hint
                  Container(
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pinch_outlined, color: Colors.white70, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'Pinch or drag to inspect photo',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLargeImage(BuildContext context, String initial) {
    if (!_hasImage) return _buildInitialLarge(initial);

    if (_isBase64) {
      final bytes = _base64Bytes;
      if (bytes == null) return _buildInitialLarge(initial);
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => _buildInitialLarge(initial),
      );
    }

    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => _buildInitialLarge(initial),
    );
  }

  Widget _buildInitialLarge(String initial) {
    return Container(
      color: const Color(0xFF1E293B),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 56,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.25),
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
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
                  filterQuality: FilterQuality.high,
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
