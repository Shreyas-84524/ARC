// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit_entry_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HabitEntryAdapter extends TypeAdapter<HabitEntry> {
  @override
  final int typeId = 2;

  @override
  HabitEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HabitEntry(
      id: fields[0] as String,
      habitId: fields[1] as String,
      dateStr: fields[2] as String,
      completed: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, HabitEntry obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.habitId)
      ..writeByte(2)
      ..write(obj.dateStr)
      ..writeByte(3)
      ..write(obj.completed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HabitEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
