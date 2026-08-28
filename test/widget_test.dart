import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sunshine_pg_app/main.dart';
import 'package:sunshine_pg_app/providers/app_provider.dart';

void main() {
  testWidgets('Sunshine PG App smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppProvider()),
        ],
        child: const SunshinePGApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
  });
}

