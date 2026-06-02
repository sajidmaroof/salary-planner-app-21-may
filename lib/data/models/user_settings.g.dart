// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserSettingsAdapter extends TypeAdapter<UserSettings> {
  @override
  final int typeId = 0;

  @override
  UserSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserSettings(
      monthlyIncome: fields[0] as double,
      nextSalaryDate: fields[1] as DateTime,
      fixedExpenses: fields[2] as double,
      savingsGoal: fields[3] as double,
      currencyCode: fields[4] as String,
      expensesBreakdown: fields[5] as String?,
      lastSalaryDate: fields[6] as DateTime?,
      carryForwardAmount: (fields[7] as double?) ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, UserSettings obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.monthlyIncome)
      ..writeByte(1)
      ..write(obj.nextSalaryDate)
      ..writeByte(2)
      ..write(obj.fixedExpenses)
      ..writeByte(3)
      ..write(obj.savingsGoal)
      ..writeByte(4)
      ..write(obj.currencyCode)
      ..writeByte(5)
      ..write(obj.expensesBreakdown)
      ..writeByte(6)
      ..write(obj.lastSalaryDate)
      ..writeByte(7)
      ..write(obj.carryForwardAmount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
