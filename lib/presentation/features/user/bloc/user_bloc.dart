import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../domain/user/usecases/change_password.dart';
import '../../../../domain/user/usecases/get_cached_user.dart';
import '../../../../domain/user/usecases/sync_user_profile.dart';
import 'user_event.dart';
import 'user_state.dart';

class UserBloc extends Bloc<UserEvent, UserState> {
  final GetCachedUser _getCachedUser;
  final SyncUserProfile _syncUserProfile;
  final ChangePassword _changePassword;

  UserBloc({
    required GetCachedUser getCachedUser,
    required SyncUserProfile syncUserProfile,
    required ChangePassword changePassword,
  }) : _getCachedUser = getCachedUser,
       _syncUserProfile = syncUserProfile,
       _changePassword = changePassword,
       super(UserInitial()) {
    on<FetchCachedUserProfile>((event, emit) async {
      emit(UserLoading());
      final result = await _getCachedUser();
      result.fold(
        (failure) => emit(
          const UserError(message: 'Không thể tải thông tin người dùng'),
        ),
        (user) {
          if (user != null) {
            emit(UserLoaded(profile: user));
          } else {
            emit(
              const UserError(
                message: 'Không tìm thấy thông tin người dùng trong cache',
              ),
            );
          }
        },
      );
    });

    on<SyncRemoteUserProfile>((event, emit) async {
      // ép gọi remote thật sự
      await _syncUserProfile(forceRemote: true);
      add(FetchCachedUserProfile());
    });

    on<ChangePasswordSubmitted>((event, emit) async {
      emit(UserLoading());
      final result = await _changePassword(
        currentPassword: event.currentPassword,
        newPassword: event.newPassword,
        confirmationPassword: event.confirmationPassword,
      );
      result.fold(
        (failure) => emit(const UserError(message: 'Đổi mật khẩu thất bại')),
        (successMessage) => emit(UserOperationSuccess(message: successMessage)),
      );
    });
  }
}
