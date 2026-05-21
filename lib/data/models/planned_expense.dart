import 'package:hive/hive.dart';

part 'planned_expense.g.dart';

@HiveType(typeId: 2)
class PlannedExpense extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  double estimatedAmount;

  @HiveField(2)
  DateTime targetDate;

  @HiveField(3)
  bool isPaid;

  PlannedExpense({
    required this.name,
    required this.estimatedAmount,
    required this.targetDate,
    this.isPaid = false,
  });
}
