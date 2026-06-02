import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';
import '../data/models/user_settings.dart';
import '../data/models/expense.dart';
import '../data/models/planned_expense.dart';
import '../core/utils/currency_formatter.dart';
import '../data/models/currency.dart';
import 'notification_service.dart';

const kDailyNotificationTask = 'dailySpendingNotification';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await Hive.initFlutter();
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(UserSettingsAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(ExpenseAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(PlannedExpenseAdapter());
      }

      final settingsBox =
          await Hive.openBox<UserSettings>('user_settings');
      final expensesBox = await Hive.openBox<Expense>('expenses');

      final settings = settingsBox.get('settings');
      if (settings == null) return Future.value(true);

      final now = DateTime.now();
      final nextPay = settings.nextSalaryDate;
      final todayStart = DateTime(now.year, now.month, now.day);
      final payStart = DateTime(nextPay.year, nextPay.month, nextPay.day);
      int daysLeft = payStart.difference(todayStart).inDays;
      if (daysLeft <= 0) daysLeft = 1;

      final allExpenses = expensesBox.values.toList();
      final spentToday = allExpenses
          .where((e) =>
              e.date.year == now.year &&
              e.date.month == now.month &&
              e.date.day == now.day)
          .fold(0.0, (sum, e) => sum + e.amount);
      final totalSpent =
          allExpenses.fold(0.0, (sum, e) => sum + e.amount);
      final spentBeforeToday = totalSpent - spentToday;

      final available = settings.monthlyIncome -
          settings.fixedExpenses -
          settings.savingsGoal;
      final balanceBeforeToday = available - spentBeforeToday;
      double dailyLimit = balanceBeforeToday / daysLeft;
      if (dailyLimit < 0) dailyLimit = 0;

      final symbol =
          AppCurrency.fromCode(settings.currencyCode).symbol;

      await NotificationService.initialize();
      await NotificationService.scheduleDailyNotification(
        dailyLimit: dailyLimit,
        currencySymbol: symbol,
      );
    } catch (e) {
      debugPrint('BackgroundService error: $e');
    }
    return Future.value(true);
  });
}

Future<void> registerDailyNotificationTask() async {
  await Workmanager().cancelByUniqueName(kDailyNotificationTask);
  await Workmanager().registerPeriodicTask(
    kDailyNotificationTask,
    kDailyNotificationTask,
    frequency: const Duration(hours: 24),
    initialDelay: _timeUntilNextNineAM(),
    constraints: Constraints(networkType: NetworkType.not_required),
    existingWorkPolicy: ExistingWorkPolicy.replace,
  );
}

Future<void> cancelDailyNotificationTask() async {
  await Workmanager().cancelByUniqueName(kDailyNotificationTask);
  await NotificationService.cancelAll();
}

Duration _timeUntilNextNineAM() {
  final now = DateTime.now();
  var next = DateTime(now.year, now.month, now.day, 9, 0);
  if (next.isBefore(now)) next = next.add(const Duration(days: 1));
  return next.difference(now);
}
