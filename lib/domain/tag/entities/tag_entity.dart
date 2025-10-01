import 'package:equatable/equatable.dart';

class TagEntity extends Equatable {
  final int id;
  final String name;
  final String? color;

  const TagEntity({required this.id, required this.name, this.color});

  @override
  List<Object?> get props => [id, name, color];
}
