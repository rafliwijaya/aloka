import 'package:shared_preferences/shared_preferences.dart';

/// Profil pengguna lokal tanpa login/backend.
/// Sesuai spesifikasi desain.txt:
/// Default fullname = 'Pengguna', default username = 'user'.
class UserProfile {
  final String fullname;
  final String username;

  const UserProfile({
    this.fullname = 'Pengguna',
    this.username = 'user',
  });

  UserProfile copyWith({
    String? fullname,
    String? username,
  }) {
    return UserProfile(
      fullname: fullname ?? this.fullname,
      username: username ?? this.username,
    );
  }
}

/// Layanan penyimpanan preferensi aplikasi ringan menggunakan SharedPreferences.
class PreferencesService {
  PreferencesService._();
  static final PreferencesService instance = PreferencesService._();

  static const String _keyFullname = 'aloka_user_fullname';
  static const String _keyUsername = 'aloka_user_username';
  static const String _keyActivePlanId = 'aloka_active_plan_id';

  Future<UserProfile> getUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final rawFullname = prefs.getString(_keyFullname)?.trim();
    final rawUsername = prefs.getString(_keyUsername)?.trim();

    return UserProfile(
      fullname: (rawFullname == null || rawFullname.isEmpty)
          ? 'Pengguna'
          : rawFullname,
      username: (rawUsername == null || rawUsername.isEmpty)
          ? 'user'
          : rawUsername,
    );
  }

  Future<UserProfile> saveUserProfile({
    required String fullname,
    required String username,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanFullname =
        fullname.trim().isEmpty ? 'Pengguna' : fullname.trim();
    final cleanUsername =
        username.trim().isEmpty ? 'user' : username.trim();

    await prefs.setString(_keyFullname, cleanFullname);
    await prefs.setString(_keyUsername, cleanUsername);

    return UserProfile(
      fullname: cleanFullname,
      username: cleanUsername,
    );
  }

  Future<String?> getActivePlanId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyActivePlanId);
  }

  Future<void> setActivePlanId(String planId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyActivePlanId, planId);
  }
}
