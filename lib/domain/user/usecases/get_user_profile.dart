import 'package:dartz/dartz.dart';
import '../../../core/error/failures.dart';
import '../entities/user_profile.dart';
import '../repositories/user_repository.dart';

class GetUserProfile {
  final UserRepository repository;
  GetUserProfile(this.repository);

  Future<Either<Failure, UserProfile>> call() async {
    return await repository.getMyProfile();
  }
}
