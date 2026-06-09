import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../data/models/user_settings.dart';
import '../../data/models/monthly_report.dart';
import '../../services/background_service.dart';

final appAuthNotifier = AppAuthNotifier();

class AppAuthNotifier extends ChangeNotifier {
  User? _user;
  bool _isLoading = true;
  bool _setupComplete = false;

  AppAuthNotifier() {
    // Safety net: never stay in loading state longer than 8 seconds.
    Future.delayed(const Duration(seconds: 8), () {
      if (_isLoading) {
        _isLoading = false;
        notifyListeners();
      }
    });
    FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  // Metadata that must persist reliably across launches. Stored in Hive
  // because SharedPreferences writes can silently fail on aggressive OEMs
  // (e.g. ColorOS/HANS freezing the app before the async save flushes).
  Box get _meta => Hive.box('app_meta');

  Future<void> _onAuthChanged(User? user) async {
    _user = user;
    if (user != null) {
      await _clearLocalDataIfUserChanged(user.uid);
      await _fetchSetupStatus(user.uid);
      await registerDailyNotificationTask();
    } else {
      _setupComplete = false;
      await cancelDailyNotificationTask();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _clearLocalDataIfUserChanged(String uid) async {
    final lastUid = _meta.get('last_user_uid') as String?;
    if (lastUid != null && lastUid != uid) {
      // Different account — wipe local Hive data so previous user's data is
      // not reused. (app_meta is intentionally NOT cleared.)
      await Hive.box<UserSettings>('user_settings').clear();
      await Hive.box('expenses').clear();
      await Hive.box('planned_expenses').clear();
      await Hive.box<MonthlyReport>('monthly_reports').clear();
    }
    await _meta.put('last_user_uid', uid);
  }

  static String _localFlagKey(String uid) => 'setup_complete_$uid';

  Future<void> _fetchSetupStatus(String uid) async {
    // Local flag is the most reliable signal that THIS device finished setup.
    final localComplete = _meta.get(_localFlagKey(uid)) as bool? ?? false;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 5));
      final data = doc.data();
      final remoteComplete = data?['setupComplete'] as bool? ?? false;

      if (remoteComplete && data != null) {
        // Sync Firestore settings into local Hive so any device gets data
        await _loadSettingsFromFirestore(data);
        _setupComplete = true;
        await _meta.put(_localFlagKey(uid), true);
        return;
      }
    } catch (_) {}

    // Firestore unavailable or not marked complete — check Hive as fallback
    final box = Hive.box<UserSettings>('user_settings');
    final settings = box.get('settings');
    if (settings != null && settings.monthlyIncome > 0) {
      _setupComplete = true;
      await _meta.put(_localFlagKey(uid), true);
      // Push setupComplete to Firestore in background so other devices sync
      _pushSetupCompleteToFirestore(uid, settings);
      return;
    }

    // Last resort: trust the local flag so a finished user is never bounced
    // back to setup just because Firestore/Hive lookups came up empty.
    _setupComplete = localComplete;
  }

  Future<void> _loadSettingsFromFirestore(Map<String, dynamic> data) async {
    try {
      final box = Hive.box<UserSettings>('user_settings');
      final existing = box.get('settings');
      final income = (data['monthlyIncome'] as num?)?.toDouble() ??
          existing?.monthlyIncome ?? 0;
      final nextSalary = data['nextSalaryDate'] != null
          ? (data['nextSalaryDate'] as Timestamp).toDate()
          : existing?.nextSalaryDate ??
              DateTime.now().add(const Duration(days: 30));
      final fixed =
          (data['fixedExpenses'] as num?)?.toDouble() ?? existing?.fixedExpenses ?? 0;
      final savings =
          (data['savingsGoal'] as num?)?.toDouble() ?? existing?.savingsGoal ?? 0;
      final currency =
          data['currencyCode'] as String? ?? existing?.currencyCode ?? 'PKR';
      final breakdown = data['expensesBreakdown'] as String?;

      // Preserve cycle fields — prefer Firestore value, fall back to local Hive
      final lastSalaryDate = data['lastSalaryDate'] != null
          ? (data['lastSalaryDate'] as Timestamp).toDate()
          : existing?.lastSalaryDate;
      final carryForwardAmount =
          (data['carryForwardAmount'] as num?)?.toDouble() ??
              existing?.carryForwardAmount ?? 0;

      final settings = UserSettings(
        monthlyIncome: income,
        nextSalaryDate: nextSalary,
        fixedExpenses: fixed,
        savingsGoal: savings,
        currencyCode: currency,
        expensesBreakdown: breakdown,
        lastSalaryDate: lastSalaryDate,
        carryForwardAmount: carryForwardAmount,
      );
      await box.put('settings', settings);
    } catch (_) {}
  }

  Future<void> _pushSetupCompleteToFirestore(
      String uid, UserSettings settings) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'monthlyIncome': settings.monthlyIncome,
        'nextSalaryDate': Timestamp.fromDate(settings.nextSalaryDate),
        'fixedExpenses': settings.fixedExpenses,
        'savingsGoal': settings.savingsGoal,
        'currencyCode': settings.currencyCode,
        'expensesBreakdown': settings.expensesBreakdown,
        'setupComplete': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> reloadUserData() async {
    if (_user != null) {
      await _fetchSetupStatus(_user!.uid);
      notifyListeners();
    }
  }

  void markSetupComplete() {
    _setupComplete = true;
    notifyListeners();
    final uid = _user?.uid;
    if (uid != null) {
      _meta.put(_localFlagKey(uid), true);
    }
  }

  void markSetupIncomplete() {
    _setupComplete = false;
    notifyListeners();
    final uid = _user?.uid;
    if (uid != null) {
      _meta.delete(_localFlagKey(uid));
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get setupComplete => _setupComplete;
}
