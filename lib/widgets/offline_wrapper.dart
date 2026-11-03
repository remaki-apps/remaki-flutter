import 'package:flutter/material.dart';
import '../providers/network_provider.dart';
import '../screens/offline_screen.dart';

/// Wraps the entire app. When internet is lost, displays the simple OfflineScreen.
/// When internet returns, automatically restores normal app screens.
class OfflineWrapper extends StatelessWidget {
  final Widget child;

  const OfflineWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: NetworkProvider.instance,
      builder: (context, _) {
        final isOffline = NetworkProvider.instance.isOffline;
        return Stack(
          fit: StackFit.expand,
          children: [
            Offstage(
              offstage: isOffline,
              child: child,
            ),
            if (isOffline)
              const Positioned.fill(
                child: OfflineScreen(),
              ),
          ],
        );
      },
    );
  }
}
