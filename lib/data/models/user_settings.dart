import 'package:hive/hive.dart';

part 'user_settings.g.dart';

@HiveType(typeId: 0)
class UserSettings extends HiveObject {
  @HiveField(0)
  double monthlyIncome;

  @HiveField(1)
  DateTime nextSalaryDate;

  @HiveField(2)
  double fixedExpenses;

  @HiveField(3)
  double savingsGoal;

  @HiveField(4)
  String currencyCode;

  @HiveField(5)
  String? expensesBreakdown; // JSON-encoded Map<String, double>

  UserSettings({
    required this.monthlyIncome,
    required this.nextSalaryDate,
    required this.fixedExpenses,
    required this.savingsGoal,
    this.currencyCode = 'PKR',
    this.expensesBreakdown,
  });
}
