import 'package:dartz/dartz.dart';
import 'package:planmate_app/domain/user/entities/user_entity.dart';
import '../../../core/error/failures.dart';

abstract class UserRepository {
  // Đồng bộ profile từ server về cache
  Future<Either<Failure, Unit>> syncUserProfile({bool forceRemote = false});

  // Lấy profile từ cache
  Future<Either<Failure, UserEntity?>> getCachedUser();

  // Xóa cache khi đăng xuất
  Future<Either<Failure, Unit>> clearCachedUser();

  Future<Either<Failure, String>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmationPassword,
  });
}
