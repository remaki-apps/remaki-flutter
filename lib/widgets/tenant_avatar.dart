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

  void _showImagePreview(BuildContext context, String avatarUrl, String initial) {
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
                    // Image Container with Zoom support
                    Container(
                      width: double.infinity,
                      height: 340,
                      color: const Color(0xFFF1F5F9),
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4.0,
                        child: Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 40,
                                    backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                                    child: Text(
                                      initial,
                                      style: const TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
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
                          },
                        ),
                      ),
                    ),
                    // Floating Overlay Close Button
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

  @override
  Widget build(BuildContext context) {
    final effectiveBg = backgroundColor ?? AppTheme.primaryColor.withValues(alpha: 0.1);
    final effectiveFg = textColor ?? AppTheme.primaryColor;
    final initial = name.trim().isNotEmpty ? name.trim().substring(0, 1).toUpperCase() : 'T';

    final avatarUrl = (imageUrl != null && imageUrl!.trim().isNotEmpty)
        ? imageUrl!.trim()
        : 'https://i.pravatar.cc/300?u=${Uri.encodeComponent(name)}';

    Widget avatarContent = CircleAvatar(
      radius: radius,
      backgroundColor: effectiveBg,
      child: ClipOval(
        child: Image.network(
          avatarUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: radius * 2,
              height: radius * 2,
              color: effectiveBg,
              alignment: Alignment.center,
              child: Text(
                initial,
                style: TextStyle(
                  color: effectiveFg,
                  fontWeight: FontWeight.bold,
                  fontSize: radius * 0.85,
                ),
              ),
            );
          },
        ),
      ),
    );

    if (!enablePreview) return avatarContent;

    return GestureDetector(
      onTap: () => _showImagePreview(context, avatarUrl, initial),
      child: avatarContent,
    );
  }
}
