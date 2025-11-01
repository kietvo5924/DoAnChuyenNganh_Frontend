import 'package:equatable/equatable.dart';

class CalendarEntity extends Equatable {
  final int id;
  final String name;
  final String? description;
  final bool isDefault;
  // NEW: optional permission level for shared calendars: "VIEW_ONLY" | "EDIT"
  final String? permissionLevel;

  const CalendarEntity({
    required this.id,
    required this.name,
    this.description,
    required this.isDefault,
    this.permissionLevel,
  });

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    isDefault,
    permissionLevel,
  ];
}
