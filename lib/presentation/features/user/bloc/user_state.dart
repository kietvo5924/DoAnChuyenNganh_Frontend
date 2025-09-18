import 'package:planmate_app/domain/user/entities/user_profile.dart';

abstract class UserState {}

class UserInitial extends UserState {}

class UserLoading extends UserState {}

class UserProfileLoaded extends UserState {
  final UserProfile profile;
  UserProfileLoaded({required this.profile});
}

class UserOperationSuccess extends UserState {
  final String message;
  UserOperationSuccess({required this.message});
}

class UserOperationFailure extends UserState {
  final String message;
  UserOperationFailure({required this.message});
}
