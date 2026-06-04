import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:workmanager/workmanager.dart';

import 'core/theme/app_theme.dart';
import 'data/models/user_settings.dart';
import 'data/models/expense.dart';
import 'data/models/planned_expense.dart';
import 'data/models/monthly_report.dart';
import 'firebase_options.dart';
import 'core/auth/app_auth_notifier.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/setup/setup_wizard_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/expense/add_expense_screen.dart';
import 'features/history/history_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/auth/social_login_screen.dart';
import 'features/analytics/analytics_screen.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/auth/create_account_screen.dart';
import 'features/splash/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/background_service.dart';
import 'services/ad_service.dart';
import 'services/pro_service.dart';

Future<void> _initHive() async {
  await Hive.initFlutter();
  Hive.registerAdapter(UserSettingsAdapter());
  Hive.registerAdapter(ExpenseAdapter());
  Hive.registerAdapter(PlannedExpenseAdapter());
  Hive.registerAdapter(MonthlyReportAdapter());
  await Future.wait([
    Hive.openBox<UserSettings>('user_settings'),
    Hive.openBox<Expense>('expenses'),
    Hive.openBox<PlannedExpense>('planned_expenses'),
    Hive.openBox<MonthlyReport>('monthly_reports'),
  ]);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    debugPrint('FLUTTER_ERROR: ${details.exceptionAsString()}');
    debugPrint('FLUTTER_STACK: ${details.stack}');
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('PLATFORM_ERROR: $error');
    debugPrint('PLATFORM_STACK: $stack');
    return false;
  };

  // Run Firebase and Hive in parallel — biggest startup win
  await Future.wait([
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    _initHive(),
  ]);

  // These are fast and need Hive/Firebase ready
  await Future.wait([
    NotificationService.initialize(),
    ProService.initialize(),
  ]);

  // Fire-and-forget: don't block app start for these
  Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  AdService.initialize();

  runApp(
    const ProviderScope(
      child: SalaryPlannerApp(),
    ),
  );
}

final _router = GoRouter(
  initialLocation: '/splash',
  refreshListenable: appAuthNotifier,
  redirect: (context, state) {
    final loc = state.matchedLocation;

    // Splash manages its own navigation — never redirect away from it
    if (loc == '/splash') return null;

    if (appAuthNotifier.isLoading) return null;

    final isLoggedIn = appAuthNotifier.user != null;
    final setupComplete = appAuthNotifier.setupComplete;

    final isAuthRoute = loc == '/' ||
        loc == '/signin' ||
        loc == '/signup' ||
        loc.startsWith('/social-login');

    if (!isLoggedIn) {
      return isAuthRoute ? null : '/';
    }

    final isEditMode = state.uri.queryParameters['edit'] == 'true';

    if (!setupComplete) {
      return loc == '/setup' ? null : '/setup';
    }

    // Allow /setup in edit mode even when setup is already complete
    if (loc == '/setup' && isEditMode) return null;

    if (isAuthRoute || loc == '/setup') return '/dashboard';

    return null;
  },
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/setup',
      builder: (context, state) => SetupWizardScreen(
        editMode: state.uri.queryParameters['edit'] == 'true',
      ),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/add-expense',
      builder: (context, state) => const AddExpenseScreen(),
    ),
    GoRoute(
      path: '/history',
      builder: (context, state) => const HistoryScreen(),
    ),
    GoRoute(
      path: '/analytics',
      builder: (context, state) => const AnalyticsScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/signin',
      builder: (context, state) => const SignInScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const CreateAccountScreen(),
    ),
    GoRoute(
      path: '/social-login/:provider',
      builder: (context, state) => SocialLoginScreen(
        provider: state.pathParameters['provider'] ?? 'Google',
      ),
    ),
  ],
);

class SalaryPlannerApp extends StatelessWidget {
  const SalaryPlannerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFDDD5F5),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: MaterialApp.router(
            title: 'Salary Planner',
            theme: AppTheme.lightTheme,
            routerConfig: _router,
            debugShowCheckedModeBanner: false,
          ),
        ),
      ),
    );
  }
}
