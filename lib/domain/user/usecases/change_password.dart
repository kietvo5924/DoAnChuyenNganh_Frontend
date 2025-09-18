import 'package:dartz/dartz.dart';
import '../../../core/error/failures.dart';
import '../repositories/user_repository.dart';

class ChangePassword {
  final UserRepository repository;
  ChangePassword(this.repository);

  Future<Either<Failure, String>> call({
    required String currentPassword,
    required String newPassword,
    required String confirmationPassword,
  }) async {
    return await repository.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
      confirmationPassword: confirmationPassword,
    );
  }
}
