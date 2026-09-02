import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'providers/app_provider.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';
import 'screens/main_shell.dart';
import 'screens/dashboard_screen.dart';
import 'screens/rooms_screen.dart';
import 'screens/room_details_screen.dart';
import 'screens/add_room_bill_screen.dart';
import 'screens/add_tenant_screen.dart';
import 'screens/allocate_tenant_screen.dart';
import 'screens/tenants_screen.dart';
import 'screens/tenant_profile_screen.dart';
import 'screens/record_payment_screen.dart';
import 'screens/rent_screen.dart';
import 'screens/more_screen.dart';
import 'screens/success_screens.dart';
import 'screens/available_beds_screen.dart';
import 'screens/unpaid_tenants_screen.dart';
import 'screens/add_room_screen.dart';
import 'screens/login_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/tenant_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.initToken();
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
  initialLocation: ApiService.isLoggedIn ? '/' : '/login',
  routes: [
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/forgot_password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/tenant_home',
      builder: (context, state) => const TenantHomeScreen(),
    ),
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
      path: '/allocate_tenant',
      builder: (context, state) {
        final roomId = state.uri.queryParameters['roomId'];
        final bedId = state.uri.queryParameters['bedId'];
        if (roomId == null || bedId == null) {
          return const Scaffold(body: Center(child: Text('Error: Missing room or bed ID')));
        }
        return AllocateTenantScreen(roomId: roomId, bedId: bedId);
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/tenant_added_success',
      builder: (context, state) {
        return TenantAddedSuccessScreen(
          tenantId: state.uri.queryParameters['tenantId'],
          password: state.uri.queryParameters['password'],
          name: state.uri.queryParameters['name'] ?? '',
          phone: state.uri.queryParameters['phone'] ?? '',
          roomNumber: state.uri.queryParameters['roomNumber'],
          floor: state.uri.queryParameters['floor'],
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
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/unpaid_tenants',
          builder: (context, state) => UnpaidTenantsScreen(filter: state.uri.queryParameters['filter']),
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
      title: 'Remaki',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

