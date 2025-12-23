import 'package:flutter/material.dart';
import 'package:planmate_app/core/services/database_service.dart';
import 'package:planmate_app/core/services/navigation_service.dart';
import 'package:planmate_app/data/auth/repositories/auth_repository_impl.dart';
import 'package:planmate_app/presentation/features/auth/pages/signin_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kForcedLogoutReasonKey = 'forced_logout_reason';

class SessionInvalidationService {
  final SharedPreferences _prefs;
  final DatabaseService _db;

  bool _inProgress = false;

  SessionInvalidationService({
    required SharedPreferences prefs,
    required DatabaseService db,
  }) : _prefs = prefs,
       _db = db;

  bool get hasAuthToken {
    final t = _prefs.getString(kAuthTokenKey);
    return t != null && t.isNotEmpty;
  }

  Future<void> forceLogout({required String reason}) async {
    if (_inProgress) return;
    _inProgress = true;

    try {
      // Persist one-time message for UI.
      await _prefs.setString(kForcedLogoutReasonKey, reason);
      await _prefs.remove(kAuthTokenKey);
      await _db.clearAllTables();

      final nav = NavigationService.navigatorKey.currentState;
      if (nav != null) {
        nav.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SignInPage()),
          (route) => false,
        );
      }
    } finally {
      _inProgress = false;
    }
  }
}
