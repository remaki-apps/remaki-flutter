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
import 'screens/pending_approvals_screen.dart';
import 'screens/announcements_screen.dart';
import 'screens/about_remaki_screen.dart';
import 'screens/terms_of_service_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/help_support_screen.dart';
import 'screens/payment_history_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.initToken();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: const RemakiApp(),
    ),
  );
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

CustomTransitionPage<T> _buildPageWithTransition<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.04, 0.0);
      const end = Offset.zero;
      const curve = Curves.easeOutCubic;

      var slideTween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      var fadeTween = Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));

      return SlideTransition(
        position: animation.drive(slideTween),
        child: FadeTransition(
          opacity: animation.drive(fadeTween),
          child: child,
        ),
      );
    },
  );
}

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: ApiService.isLoggedIn ? (ApiService.role == 'TENANT' ? '/tenant_home' : '/') : '/login',
  routes: [
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/login',
      pageBuilder: (context, state) => _buildPageWithTransition(
        context: context,
        state: state,
        child: const LoginScreen(),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/forgot_password',
      pageBuilder: (context, state) => _buildPageWithTransition(
        context: context,
        state: state,
        child: const ForgotPasswordScreen(),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/tenant_home',
      pageBuilder: (context, state) => _buildPageWithTransition(
        context: context,
        state: state,
        child: const TenantHomeScreen(),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/tenant_my_profile',
      pageBuilder: (context, state) => _buildPageWithTransition(
        context: context,
        state: state,
        child: const TenantHomeScreen(initialTab: 2),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/add_room',
      pageBuilder: (context, state) => _buildPageWithTransition(
        context: context,
        state: state,
        child: const AddRoomScreen(),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/room_details/:roomId',
      pageBuilder: (context, state) => _buildPageWithTransition(
        context: context,
        state: state,
        child: RoomDetailsScreen(roomId: state.pathParameters['roomId']!),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/add_room_bill/:roomId',
      pageBuilder: (context, state) => _buildPageWithTransition(
        context: context,
        state: state,
        child: AddRoomBillScreen(roomId: state.pathParameters['roomId']!),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/tenant_profile/:id',
      pageBuilder: (context, state) => _buildPageWithTransition(
        context: context,
        state: state,
        child: TenantProfileScreen(tenantId: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/record_payment/:id',
      pageBuilder: (context, state) => _buildPageWithTransition(
        context: context,
        state: state,
        child: RecordPaymentScreen(tenantId: state.pathParameters['id']!),
      ),
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
          tenantId: state.uri.queryParameters['tenantId'],
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/approvals',
      builder: (context, state) => const PendingApprovalsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/announcements',
      builder: (context, state) => const AnnouncementsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/unpaid_tenants',
      builder: (context, state) => UnpaidTenantsScreen(filter: state.uri.queryParameters['filter']),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/available_beds',
      builder: (context, state) => const AvailableBedsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/payment_history',
      builder: (context, state) => const PaymentHistoryScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/about',
      builder: (context, state) => const AboutRemakiScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/terms',
      builder: (context, state) => const TermsOfServiceScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/privacy',
      builder: (context, state) => const PrivacyPolicyScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/help_support',
      builder: (context, state) => const HelpSupportScreen(),
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

class RemakiApp extends StatelessWidget {
  const RemakiApp({super.key});

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

