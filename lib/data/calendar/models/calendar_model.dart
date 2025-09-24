import '../../../domain/calendar/entities/calendar_entity.dart';

class CalendarModel extends CalendarEntity {
  const CalendarModel({
    required super.id,
    required super.name,
    super.description,
    required super.isDefault,
  });

  factory CalendarModel.fromJson(Map<String, dynamic> json) {
    return CalendarModel(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      isDefault: json['isDefault'] ?? false,
    );
  }
}
