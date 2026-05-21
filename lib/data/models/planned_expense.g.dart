// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'planned_expense.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PlannedExpenseAdapter extends TypeAdapter<PlannedExpense> {
  @override
  final int typeId = 2;

  @override
  PlannedExpense read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PlannedExpense(
      name: fields[0] as String,
      estimatedAmount: fields[1] as double,
      targetDate: fields[2] as DateTime,
      isPaid: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, PlannedExpense obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.estimatedAmount)
      ..writeByte(2)
      ..write(obj.targetDate)
      ..writeByte(3)
      ..write(obj.isPaid);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlannedExpenseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
