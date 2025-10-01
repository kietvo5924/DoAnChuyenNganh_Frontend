import 'package:equatable/equatable.dart';
import '../../../../domain/tag/entities/tag_entity.dart';

abstract class TagState extends Equatable {
  const TagState();
  @override
  List<Object> get props => [];
}

class TagInitial extends TagState {}

class TagLoading extends TagState {}

class TagLoaded extends TagState {
  final List<TagEntity> tags;
  const TagLoaded({required this.tags});
}

class TagOperationSuccess extends TagState {
  final String message;
  const TagOperationSuccess({required this.message});
}

class TagError extends TagState {
  final String message;
  const TagError({required this.message});
}
