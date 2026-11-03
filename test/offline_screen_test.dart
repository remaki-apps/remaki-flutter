import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunshine_pg_app/providers/network_provider.dart';
import 'package:sunshine_pg_app/screens/offline_screen.dart';
import 'package:sunshine_pg_app/widgets/offline_wrapper.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NetworkProvider.instance.setOffline(false);
  });

  tearDown(() {
    NetworkProvider.instance.setOffline(false);
  });

  group('Simple Offline Screen Tests', () {
    testWidgets('OfflineScreen renders clean no-internet UI with retry button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OfflineScreen(),
        ),
      );

      await tester.pump();

      expect(find.text('No Internet Connection'), findsOneWidget);
      expect(find.text('Please check your network connection and try again.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    });

    testWidgets('OfflineWrapper shows child when online, OfflineScreen when offline', (WidgetTester tester) async {
      final provider = NetworkProvider.instance;
      provider.setOffline(false);

      await tester.pumpWidget(
        const MaterialApp(
          home: OfflineWrapper(
            child: Scaffold(
              body: Text('Active Normal Screen'),
            ),
          ),
        ),
      );

      await tester.pump();

      // Normal screen is shown
      expect(find.text('Active Normal Screen'), findsOneWidget);
      expect(find.text('No Internet Connection'), findsNothing);

      // Internet turns off
      provider.setOffline(true);
      await tester.pump();

      // OfflineScreen is immediately shown
      expect(find.text('No Internet Connection'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Active Normal Screen'), findsNothing);

      // Internet turns back on
      provider.setOffline(false);
      await tester.pump();

      // Returns to normal screen
      expect(find.text('Active Normal Screen'), findsOneWidget);
      expect(find.text('No Internet Connection'), findsNothing);
    });
  });
}
