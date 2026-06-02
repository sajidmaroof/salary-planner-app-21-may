// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'monthly_report.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MonthlyReportAdapter extends TypeAdapter<MonthlyReport> {
  @override
  final int typeId = 3;

  @override
  MonthlyReport read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MonthlyReport(
      year: fields[0] as int,
      month: fields[1] as int,
      monthlyIncome: fields[2] as double,
      fixedExpenses: fields[3] as double,
      savingsGoal: fields[4] as double,
      effectiveBudget: fields[5] as double,
      totalSpent: fields[6] as double,
      remainingBalance: fields[7] as double,
      carriedForward: fields[8] as bool,
      carryForwardAmount: fields[9] as double,
      currencyCode: fields[10] as String,
      cycleStart: fields[11] as DateTime,
      cycleEnd: fields[12] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, MonthlyReport obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.year)
      ..writeByte(1)
      ..write(obj.month)
      ..writeByte(2)
      ..write(obj.monthlyIncome)
      ..writeByte(3)
      ..write(obj.fixedExpenses)
      ..writeByte(4)
      ..write(obj.savingsGoal)
      ..writeByte(5)
      ..write(obj.effectiveBudget)
      ..writeByte(6)
      ..write(obj.totalSpent)
      ..writeByte(7)
      ..write(obj.remainingBalance)
      ..writeByte(8)
      ..write(obj.carriedForward)
      ..writeByte(9)
      ..write(obj.carryForwardAmount)
      ..writeByte(10)
      ..write(obj.currencyCode)
      ..writeByte(11)
      ..write(obj.cycleStart)
      ..writeByte(12)
      ..write(obj.cycleEnd);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonthlyReportAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
