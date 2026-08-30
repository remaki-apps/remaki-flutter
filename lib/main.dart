import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'providers/app_provider.dart';
import 'theme/app_theme.dart';
import 'screens/main_shell.dart';
import 'screens/dashboard_screen.dart';
import 'screens/rooms_screen.dart';
import 'screens/room_details_screen.dart';
import 'screens/add_room_bill_screen.dart';
import 'screens/add_tenant_screen.dart';
import 'screens/tenants_screen.dart';
import 'screens/tenant_profile_screen.dart';
import 'screens/record_payment_screen.dart';
import 'screens/rent_screen.dart';
import 'screens/more_screen.dart';
import 'screens/success_screens.dart';
import 'screens/available_beds_screen.dart';
import 'screens/unpaid_tenants_screen.dart';
import 'screens/add_room_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: const SunshinePGApp(),
    ),
  );
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/add_room',
      builder: (context, state) => const AddRoomScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/room_details/:roomId',
      builder: (context, state) => RoomDetailsScreen(roomId: state.pathParameters['roomId']!),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/add_room_bill/:roomId',
      builder: (context, state) => AddRoomBillScreen(roomId: state.pathParameters['roomId']!),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/tenant_profile/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return TenantProfileScreen(tenantId: id);
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/record_payment/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return RecordPaymentScreen(tenantId: id);
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/add_tenant',
      builder: (context, state) {
        final roomId = state.uri.queryParameters['roomId'];
        final bedId = state.uri.queryParameters['bedId'];
        return AddTenantScreen(initialRoomId: roomId, initialBedId: bedId);
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/tenant_added_success',
      builder: (context, state) {
        return TenantAddedSuccessScreen(
          name: state.uri.queryParameters['name'] ?? '',
          roomBed: state.uri.queryParameters['roomBed'] ?? '',
          rent: state.uri.queryParameters['rent'] ?? '',
          moveIn: state.uri.queryParameters['moveIn'] ?? '',
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/payment_success',
      builder: (context, state) {
        return PaymentSuccessScreen(
          amount: state.uri.queryParameters['amount'] ?? '',
          name: state.uri.queryParameters['name'] ?? '',
          roomBed: state.uri.queryParameters['roomBed'] ?? '',
          dateMethod: state.uri.queryParameters['dateMethod'] ?? '',
        );
      },
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return MainShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/unpaid_tenants',
          builder: (context, state) => const UnpaidTenantsScreen(),
        ),
        GoRoute(
          path: '/available_beds',
          builder: (context, state) => const AvailableBedsScreen(),
        ),
        GoRoute(
          path: '/rooms',
          builder: (context, state) => const RoomsScreen(),
        ),
        GoRoute(
          path: '/tenants',
          builder: (context, state) => const TenantsScreen(),
        ),
        GoRoute(
          path: '/rent',
          builder: (context, state) => const RentScreen(),
        ),
        GoRoute(
          path: '/more',
          builder: (context, state) => const MoreScreen(),
        ),
      ],
    ),
  ],
);

class SunshinePGApp extends StatelessWidget {
  const SunshinePGApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Sunshine PG',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

