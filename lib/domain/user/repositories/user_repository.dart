import 'package:dartz/dartz.dart';
import '../../../core/error/failures.dart';
import '../entities/user_profile.dart';

abstract class UserRepository {
  Future<Either<Failure, UserProfile>> getMyProfile();

  Future<Either<Failure, String>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmationPassword,
  });
}
