import 'package:equatable/equatable.dart';

class CalendarEntity extends Equatable {
  final int id;
  final String name;
  final String? description;
  final bool isDefault;

  const CalendarEntity({
    required this.id,
    required this.name,
    this.description,
    required this.isDefault,
  });

  @override
  List<Object?> get props => [id, name, description, isDefault];
}
