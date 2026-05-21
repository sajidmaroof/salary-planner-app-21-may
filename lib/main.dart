import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'data/models/user_settings.dart';
import 'data/models/expense.dart';
import 'data/models/planned_expense.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await Hive.initFlutter();
  Hive.registerAdapter(UserSettingsAdapter());
  Hive.registerAdapter(ExpenseAdapter());
  Hive.registerAdapter(PlannedExpenseAdapter());
  await Hive.openBox<UserSettings>('user_settings');
  await Hive.openBox<Expense>('expenses');
  await Hive.openBox<PlannedExpense>('planned_expenses');

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
