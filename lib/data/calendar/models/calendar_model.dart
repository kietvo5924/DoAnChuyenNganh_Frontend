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

  // NEW: helper parse bool an toàn
  static bool _asBool(dynamic v) {
    if (v is bool) return v;
    if (v is int) return v == 1;
    if (v is String) {
      final s = v.toLowerCase().trim();
      return s == 'true' || s == '1';
    }
    return false;
  }

  factory CalendarModel.fromJson(Map<String, dynamic> json) {
    return CalendarModel(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      // CHANGED: nhận cả 'isDefault' và 'default' từ backend
      isDefault: _asBool(json['isDefault'] ?? json['default'] ?? false),
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
