import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'models/models.dart';
import 'providers/app_provider.dart';
import 'providers/notification_provider.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';
import 'screens/main_shell.dart';
import 'screens/dashboard_screen.dart';
import 'screens/rooms_screen.dart';
import 'screens/room_details_screen.dart';
import 'screens/add_room_bill_screen.dart';
import 'screens/electricity_calculator_screen.dart';
import 'screens/electricity_step1_calculator_screen.dart';
import 'screens/enter_split_amount_screen.dart';
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
import 'screens/setup_security_pin_screen.dart';
import 'screens/tenant_home_screen.dart';
import 'screens/pending_approvals_screen.dart';
import 'screens/announcements_screen.dart';
import 'screens/about_remaki_screen.dart';
import 'screens/terms_of_service_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/help_support_screen.dart';
import 'screens/payment_history_screen.dart';
import 'screens/splash_screen.dart';
import 'config/env_config.dart';
import 'screens/pg_owners_screen.dart';
import 'screens/tenant_complaints_screen.dart';
import 'screens/admin_complaints_screen.dart';
import 'screens/platform_fee_summary_screen.dart';
import 'screens/configuration_screen.dart';
import 'services/shared_media_service.dart';
import 'services/fcm_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'widgets/offline_wrapper.dart';
import 'widgets/keyboard_responsive_layout.dart';
import 'models/organization_models.dart';
import 'providers/organization_provider.dart';
import 'screens/organization/org_shell.dart';
import 'screens/organization/org_dashboard_screen.dart';
import 'screens/organization/org_admins_screen.dart';
import 'screens/organization/org_create_admin_screen.dart';
import 'screens/organization/org_admin_details_screen.dart';
import 'screens/organization/org_edit_admin_screen.dart';
import 'screens/organization/org_properties_screen.dart';
import 'screens/organization/org_more_screen.dart';
import 'screens/organization/org_admin_success_screen.dart';
import 'screens/organization/org_property_form_screen.dart';
import 'screens/organization/org_property_details_screen.dart';
import 'screens/organization/org_platform_fee_screen.dart';
import 'screens/organization/org_stepwise_delete_screen.dart';

Future<void> bootstrapApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'AIzaSyCaLBY8wjDpL4EQVu1AtWIpjhtk1ZaxcuQ',
          appId: '1:260854340023:web:9bf29859f0bb5c87723032',
          messagingSenderId: '260854340023',
          projectId: 'remaki-apps',
          storageBucket: 'remaki-apps.firebasestorage.app',
        ),
      );
    } else {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }
  } catch (e) {
    debugPrint('[Firebase] Init skipped or error: $e');
  }
  SharedMediaService.instance.init();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  await ApiService.initToken();
  ApiService.warmupServer();
  await FcmService.instance.init(
    onNavigate: (route) => router.go(route),
    navigatorKey: _rootNavigatorKey,
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => OrganizationProvider()),
      ],
      child: const RemakiApp(),
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (appFlavor == 'qa') {
    EnvConfig.initialize(Environment.qa);
  } else if (appFlavor == 'prod') {
    EnvConfig.initialize(Environment.prod);
  }
  await bootstrapApp();
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();
final _orgShellNavigatorKey = GlobalKey<NavigatorState>();

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
  refreshListenable: ApiService.authNotifier,
  initialLocation: '/splash',
  redirect: (context, state) {
    final location = state.matchedLocation;
    if (location == '/splash') return null;

    final isLoggedIn = ApiService.isLoggedIn;
    final isLoggingIn = location == '/login' || location == '/forgot_password';

    if (!isLoggedIn) {
      return isLoggingIn ? null : '/login';
    }

    // Compulsory 4-digit Security Recovery PIN setup for tenants
    if (ApiService.role == 'TENANT' && !ApiService.hasSecurityPin) {
      return location == '/setup_security_pin' ? null : '/setup_security_pin';
    }

    if (isLoggingIn || location == '/setup_security_pin') {
      if (ApiService.role == 'ORGANIZATION') {
        return '/org_dashboard';
      }
      return ApiService.role == 'TENANT' ? '/tenant_home' : '/';
    }

    // Role-Based Access Control
    if (ApiService.role == 'TENANT') {
      const allowedTenantRoutes = {
        '/tenant_home',
        '/tenant_my_profile',
        '/tenant_complaints',
        '/announcements',
        '/setup_security_pin',
        '/about',
        '/terms',
        '/privacy',
        '/help_support',
      };
      if (!allowedTenantRoutes.contains(location)) {
        return '/tenant_home';
      }
    } else if (ApiService.role == 'ADMIN') {
      if (location == '/tenant_home' || location == '/tenant_my_profile' || location.startsWith('/org_')) {
        return '/';
      }
    } else if (ApiService.role == 'ORGANIZATION') {
      const allowedOrgRoutes = {
        '/org_dashboard',
        '/org_admins',
        '/org_create_admin',
        '/org_admin_success',
        '/org_properties',
        '/org_property_form',
        '/org_platform_fee',
        '/org_stepwise_delete',
        '/org_more',
        '/about',
        '/terms',
        '/privacy',
        '/help_support',
      };
      if (location.startsWith('/org_admin_details') ||
          location.startsWith('/org_edit_admin') ||
          location.startsWith('/org_property_details')) {
        return null;
      }
      if (!allowedOrgRoutes.contains(location)) {
        return '/org_dashboard';
      }
    }

    return null;
  },
  routes: [
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
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
      path: '/setup_security_pin',
      pageBuilder: (context, state) => _buildPageWithTransition(
        context: context,
        state: state,
        child: const SetupSecurityPinScreen(),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/tenant_home',
      pageBuilder: (context, state) {
        final tabStr = state.uri.queryParameters['tab'];
        final tab = int.tryParse(tabStr ?? '') ?? 0;
        return _buildPageWithTransition(
          context: context,
          state: state,
          child: TenantHomeScreen(initialTab: tab),
        );
      },
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
      path: '/enter_split_amount/:roomId',
      pageBuilder: (context, state) => _buildPageWithTransition(
        context: context,
        state: state,
        child: EnterSplitAmountScreen(roomId: state.pathParameters['roomId']!),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/add_room_bill',
      pageBuilder: (context, state) {
        final draft = state.extra as ElectricitySplitDraft?;
        return _buildPageWithTransition(
          context: context,
          state: state,
          child: AddRoomBillScreen(
            roomId: draft?.roomId,
            roomIds: draft?.roomIds,
            initialAmount: draft?.totalAmount,
            electricityDraft: draft,
          ),
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/add_room_bill/:roomId',
      pageBuilder: (context, state) {
        final amountStr = state.uri.queryParameters['amount'];
        final initialAmount = amountStr != null ? double.tryParse(amountStr) : (state.extra as double?);
        return _buildPageWithTransition(
          context: context,
          state: state,
          child: AddRoomBillScreen(
            roomId: state.pathParameters['roomId']!,
            initialAmount: initialAmount,
          ),
        );
      },
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
      path: '/tenant_profile',
      pageBuilder: (context, state) {
        final tenant = state.extra as Tenant?;
        final id = tenant?.id ?? state.uri.queryParameters['id'] ?? '';
        return _buildPageWithTransition(
          context: context,
          state: state,
          child: TenantProfileScreen(tenantId: id),
        );
      },
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
        final extraMap = state.extra is Map ? (state.extra as Map) : null;
        final fromSuccess = state.uri.queryParameters['fromSuccess'] == 'true' ||
            state.uri.queryParameters['from'] == 'success' ||
            extraMap?['fromSuccess'] == true;
        final returnTo = state.uri.queryParameters['returnTo'] ??
            (extraMap?['returnTo'] as String?);
        return AddTenantScreen(
          initialRoomId: roomId,
          initialBedId: bedId,
          fromSuccess: fromSuccess,
          returnTo: returnTo,
        );
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
      path: '/pg_owners',
      builder: (context, state) => const PgOwnersScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/tenant_complaints',
      pageBuilder: (context, state) => _buildPageWithTransition(
        context: context,
        state: state,
        child: const TenantComplaintsScreen(),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/admin_complaints',
      builder: (context, state) => const AdminComplaintsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/unpaid_tenants',
      builder: (context, state) => UnpaidTenantsScreen(filter: state.uri.queryParameters['filter']),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/platform_fee_summary',
      builder: (context, state) => const PlatformFeeSummaryScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/configuration',
      pageBuilder: (context, state) => _buildPageWithTransition(
        context: context,
        state: state,
        child: const ConfigurationScreen(),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/electricity_calculator',
      pageBuilder: (context, state) => _buildPageWithTransition(
        context: context,
        state: state,
        child: ElectricityCalculatorScreen(
          propertyId: state.uri.queryParameters['propertyId'],
        ),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/electricity_step1',
      pageBuilder: (context, state) => _buildPageWithTransition(
        context: context,
        state: state,
        child: ElectricityStep1CalculatorScreen(
          propertyId: state.uri.queryParameters['propertyId'],
          roomId: state.uri.queryParameters['roomId'],
          groupId: state.uri.queryParameters['groupId'],
        ),
      ),
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
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/org_create_admin',
      pageBuilder: (context, state) => _buildPageWithTransition(
        context: context,
        state: state,
        child: const OrgCreateAdminScreen(),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/org_admin_details/:id',
      pageBuilder: (context, state) => _buildPageWithTransition(
        context: context,
        state: state,
        child: OrgAdminDetailsScreen(adminId: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/org_edit_admin/:id',
      pageBuilder: (context, state) => _buildPageWithTransition(
        context: context,
        state: state,
        child: OrgEditAdminScreen(adminId: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/org_admin_success',
      pageBuilder: (context, state) {
        final extra = state.extra is Map ? (state.extra as Map) : {};
        final payload = extra['payload'] as AdminCreatedPayload?;
        if (payload == null) {
          return _buildPageWithTransition(
            context: context,
            state: state,
            child: const OrgAdminsScreen(),
          );
        }
        return _buildPageWithTransition(
          context: context,
          state: state,
          child: OrgAdminSuccessScreen(
            payload: payload,
            propertyName: (extra['propertyName'] as String?) ?? '',
          ),
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/org_property_form',
      pageBuilder: (context, state) => _buildPageWithTransition(
        context: context,
        state: state,
        child: OrgPropertyFormScreen(
          propertyId: state.uri.queryParameters['propertyId'],
          initialAdminId: state.uri.queryParameters['adminId'],
        ),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/org_property_details/:id',
      pageBuilder: (context, state) => _buildPageWithTransition(
        context: context,
        state: state,
        child: OrgPropertyDetailsScreen(
          propertyId: state.pathParameters['id']!,
          initialTab: int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0,
        ),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/org_platform_fee',
      pageBuilder: (context, state) => _buildPageWithTransition(
        context: context,
        state: state,
        child: const OrgPlatformFeeScreen(),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/org_stepwise_delete',
      pageBuilder: (context, state) => _buildPageWithTransition(
        context: context,
        state: state,
        child: OrgStepwiseDeleteScreen(
          targetId: state.uri.queryParameters['targetId'] ?? '',
          isAdmin: state.uri.queryParameters['isAdmin'] == 'true',
          targetName: state.uri.queryParameters['name'] ?? 'Item',
        ),
      ),
    ),
    ShellRoute(
      navigatorKey: _orgShellNavigatorKey,
      builder: (context, state, child) {
        return OrgShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/org_dashboard',
          builder: (context, state) => const OrgDashboardScreen(),
        ),
        GoRoute(
          path: '/org_admins',
          builder: (context, state) => const OrgAdminsScreen(),
        ),
        GoRoute(
          path: '/org_properties',
          builder: (context, state) => const OrgPropertiesScreen(),
        ),
        GoRoute(
          path: '/org_more',
          builder: (context, state) => const OrgMoreScreen(),
        ),
      ],
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

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    // Return child directly to prevent Android's StretchingOverscrollIndicator (_StretchController)
    // from triggering a synchronous setState() during performLayout when keyboards or bottom sheets resize.
    return child;
  }
}

class RemakiApp extends StatelessWidget {
  const RemakiApp({super.key});

  @override
  Widget build(BuildContext context) {
    Widget app = MaterialApp.router(
      title: EnvConfig.appName,
      theme: AppTheme.lightTheme,
      scrollBehavior: const AppScrollBehavior(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => OfflineWrapper(
        child: KeyboardDismissOnTap(
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );

    if (EnvConfig.isQa) {
      app = Directionality(
        textDirection: TextDirection.ltr,
        child: Banner(
          message: 'QA',
          location: BannerLocation.topEnd,
          color: const Color(0xFFEAB308),
          textStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1.0,
          ),
          child: app,
        ),
      );
    }

    return app;
  }
}


