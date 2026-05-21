import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../data/models/user_settings.dart';
import '../data/models/expense.dart';
import '../data/models/planned_expense.dart';
import '../data/models/currency.dart';
import '../core/utils/currency_formatter.dart';

// Provides access to the UserSettings box
final userSettingsBoxProvider = Provider<Box<UserSettings>>((ref) {
  return Hive.box<UserSettings>('user_settings');
});

// Provides the current user settings. Null if not set up yet.
final userSettingsProvider = StateProvider<UserSettings?>((ref) {
  final box = ref.watch(userSettingsBoxProvider);
  return box.get('settings');
});

// Dedicated currency code provider — holds a plain String so Riverpod detects
// changes by value even when the UserSettings object reference stays the same.
final currencyCodeProvider = StateProvider<String>((ref) {
  return ref.read(userSettingsProvider)?.currencyCode ?? 'PKR';
});

// Provides the current currency symbol
final currencySymbolProvider = Provider<String>((ref) {
  final code = ref.watch(currencyCodeProvider);
  return AppCurrency.fromCode(code).symbol;
});

// Provides a formatting function that uses the current currency
final formatCurrencyProvider = Provider<String Function(double)>((ref) {
  final symbol = ref.watch(currencySymbolProvider);
  return (double amount) => CurrencyFormatter.format(amount, symbol: symbol);
});

// Provides access to the Expenses box
final expensesBoxProvider = Provider<Box<Expense>>((ref) {
  return Hive.box<Expense>('expenses');
});

// Provides a list of all expenses
final expensesProvider = StateProvider<List<Expense>>((ref) {
  final box = ref.watch(expensesBoxProvider);
  return box.values.toList()..sort((a, b) => b.date.compareTo(a.date)); // Newest first
});

// Planned Expenses providers
final plannedExpensesBoxProvider = Provider<Box<PlannedExpense>>((ref) {
  return Hive.box<PlannedExpense>('planned_expenses');
});

final plannedExpensesProvider = StateProvider<List<PlannedExpense>>((ref) {
  final box = ref.watch(plannedExpensesBoxProvider);
  return box.values.toList()..sort((a, b) => a.targetDate.compareTo(b.targetDate)); // Earliest first
});

// Derived provider for today's expenses
final todaysExpensesProvider = Provider<List<Expense>>((ref) {
  final allExpenses = ref.watch(expensesProvider);
  final now = DateTime.now();
  return allExpenses.where((e) {
    return e.date.year == now.year &&
           e.date.month == now.month &&
           e.date.day == now.day;
  }).toList();
});

// Derived provider for daily stats (Available, Daily Limit, Spent Today)
class DailyStats {
  final double monthlyIncome;
  final double fixedExpenses;
  final double savingsGoal;
  final double availableSpending;
  final double totalSpent;
  final double remainingBalance;
  final int daysLeft;
  final double dailyLimit;
  final double spentToday;
  final double remainingToday;

  DailyStats({
    required this.monthlyIncome,
    required this.fixedExpenses,
    required this.savingsGoal,
    required this.availableSpending,
    required this.totalSpent,
    required this.remainingBalance,
    required this.daysLeft,
    required this.dailyLimit,
    required this.spentToday,
    required this.remainingToday,
  });
}

final dailyStatsProvider = Provider<DailyStats?>((ref) {
  final settings = ref.watch(userSettingsProvider);
  if (settings == null) return null;

  final allExpenses = ref.watch(expensesProvider);
  final plannedExpenses = ref.watch(plannedExpensesProvider);
  final now = DateTime.now();
  final nextPay = settings.nextSalaryDate;
  
  // Calculate days left
  final todayStart = DateTime(now.year, now.month, now.day);
  final payDateStart = DateTime(nextPay.year, nextPay.month, nextPay.day);
  int daysLeft = payDateStart.difference(todayStart).inDays;
  if (daysLeft <= 0) daysLeft = 1;

  // Monthly breakdown
  final monthlyIncome = settings.monthlyIncome;
  final fixedExpenses = settings.fixedExpenses;
  final savingsGoal = settings.savingsGoal;

  // STEP 1: Available Monthly Spending = Income - Fixed Expenses - Savings Goal
  final availableSpending = monthlyIncome - fixedExpenses - savingsGoal;

  // STEP 2: Total spent (all expenses) for the REMAINING card
  final totalSpent = allExpenses.fold(0.0, (sum, item) => sum + item.amount);
  final remainingBalance = availableSpending - totalSpent;

  // STEP 3: Daily limit uses balance BEFORE today's spending so it stays
  // fixed throughout the day regardless of how much the user spends.
  final todaysExp = ref.watch(todaysExpensesProvider);
  final spentToday = todaysExp.fold(0.0, (sum, item) => sum + item.amount);
  final spentBeforeToday = totalSpent - spentToday;
  final balanceBeforeToday = availableSpending - spentBeforeToday;

  // Pending fixed expenses for today (from PlannedExpenses)
  final pendingToday = plannedExpenses.where((e) {
    return e.targetDate.year == now.year &&
           e.targetDate.month == now.month &&
           e.targetDate.day == now.day &&
           !e.isPaid;
  }).fold(0.0, (sum, item) => sum + item.estimatedAmount);

  double dailyLimit = (balanceBeforeToday / daysLeft) - pendingToday;
  if (dailyLimit < 0) dailyLimit = 0;

  final remainingToday = dailyLimit - spentToday;

  return DailyStats(
    monthlyIncome: monthlyIncome,
    fixedExpenses: fixedExpenses,
    savingsGoal: savingsGoal,
    availableSpending: availableSpending,
    totalSpent: totalSpent,
    remainingBalance: remainingBalance,
    daysLeft: daysLeft,
    dailyLimit: dailyLimit,
    spentToday: spentToday,
    remainingToday: remainingToday,
  );
});
