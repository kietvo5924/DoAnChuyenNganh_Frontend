import 'package:equatable/equatable.dart';
import '../../../../domain/user/entities/user_entity.dart';

abstract class UserState extends Equatable {
  const UserState();
  @override
  List<Object?> get props => [];
}

class UserInitial extends UserState {}

class UserLoading extends UserState {}

class UserLoaded extends UserState {
  final UserEntity profile;
  const UserLoaded({required this.profile});

  @override
  List<Object?> get props => [profile];
}

class UserOperationSuccess extends UserState {
  final String message;
  const UserOperationSuccess({required this.message});
}

class UserError extends UserState {
  final String message;
  const UserError({required this.message});
}
