import '../../../domain/calendar/entities/calendar_entity.dart';

class CalendarModel extends CalendarEntity {
  const CalendarModel({
    required int id,
    required String name,
    String? description,
    required bool isDefault,
  }) : super(
         id: id,
         name: name,
         description: description,
         isDefault: isDefault,
       );

  factory CalendarModel.fromJson(Map<String, dynamic> json) {
    return CalendarModel(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      isDefault: json['isDefault'] ?? false,
    );
  }

  factory CalendarModel.fromDb(Map<String, dynamic> map) {
    return CalendarModel(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      isDefault: map['is_default'] == 1,
    );
  }

  Map<String, dynamic> toDbMap({bool isSynced = true}) {
    return {
      'id': id,
      'name': name,
      'description': description,
      'is_default': isDefault ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
    };
  }
}
