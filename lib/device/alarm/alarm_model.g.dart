// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'alarm_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AlarmModelAdapter extends TypeAdapter<AlarmModel> {
  @override
  final int typeId = 0;

  @override
  AlarmModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AlarmModel(
      hour: fields[0] as int,
      minute: fields[1] as int,
      repeatDays: (fields[2] as List).cast<String>(),
      alarmSound: fields[3] as bool,
      vibration: fields[4] as bool,
      snooze: fields[5] as bool,
      isEnabled: fields.containsKey(6) && fields[6] != null ? fields[6] as bool : true, // ✅ null-safe
    );
  }

  @override
  void write(BinaryWriter writer, AlarmModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.hour)
      ..writeByte(1)
      ..write(obj.minute)
      ..writeByte(2)
      ..write(obj.repeatDays)
      ..writeByte(3)
      ..write(obj.alarmSound)
      ..writeByte(4)
      ..write(obj.vibration)
      ..writeByte(5)
      ..write(obj.snooze)
      ..writeByte(6)
      ..write(obj.isEnabled);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlarmModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
