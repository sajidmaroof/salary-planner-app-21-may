import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    final prefs = await SharedPreferences.getInstance();
    final lastUid = prefs.getString('last_user_uid');
    if (lastUid != null && lastUid != uid) {
      // Different account — wipe ALL local Hive data so previous user's data is not reused
      await Hive.box<UserSettings>('user_settings').clear();
      await Hive.box('expenses').clear();
      await Hive.box('planned_expenses').clear();
      await Hive.box<MonthlyReport>('monthly_reports').clear();
    }
    await prefs.setString('last_user_uid', uid);
  }

  Future<void> _fetchSetupStatus(String uid) async {
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
        return;
      }
    } catch (_) {}

    // Firestore unavailable or not marked complete — check Hive as fallback
    final box = Hive.box<UserSettings>('user_settings');
    final settings = box.get('settings');
    if (settings != null && settings.monthlyIncome > 0) {
      _setupComplete = true;
      // Push setupComplete to Firestore in background so other devices sync
      _pushSetupCompleteToFirestore(uid, settings);
    } else {
      _setupComplete = false;
    }
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
  }

  void markSetupIncomplete() {
    _setupComplete = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get setupComplete => _setupComplete;
}
