import 'package:hive/hive.dart';

part 'monthly_report.g.dart';

@HiveType(typeId: 3)
class MonthlyReport extends HiveObject {
  @HiveField(0)
  final int year;

  @HiveField(1)
  final int month;

  @HiveField(2)
  final double monthlyIncome;

  @HiveField(3)
  final double fixedExpenses;

  @HiveField(4)
  final double savingsGoal;

  @HiveField(5)
  final double effectiveBudget;

  @HiveField(6)
  final double totalSpent;

  @HiveField(7)
  final double remainingBalance;

  @HiveField(8)
  final bool carriedForward;

  @HiveField(9)
  final double carryForwardAmount;

  @HiveField(10)
  final String currencyCode;

  @HiveField(11)
  final DateTime cycleStart;

  @HiveField(12)
  final DateTime cycleEnd;

  MonthlyReport({
    required this.year,
    required this.month,
    required this.monthlyIncome,
    required this.fixedExpenses,
    required this.savingsGoal,
    required this.effectiveBudget,
    required this.totalSpent,
    required this.remainingBalance,
    required this.carriedForward,
    required this.carryForwardAmount,
    required this.currencyCode,
    required this.cycleStart,
    required this.cycleEnd,
  });
}
