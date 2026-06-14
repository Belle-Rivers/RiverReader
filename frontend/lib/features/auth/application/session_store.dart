import 'package:shared_preferences/shared_preferences.dart';

class SessionStore {
  static const String userIdKey = 'session_user_id';
  static const String backupHintKey = 'backup_hint_shown';

  static Future<String?> loadUserId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(userIdKey);
  }

  static Future<void> saveUserId(String id) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(userIdKey, id);
  }

  static Future<void> clearUserId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(userIdKey);
  }

  static Future<bool> shouldShowBackupHint() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(backupHintKey) ?? false);
  }

  static Future<void> markBackupHintShown() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(backupHintKey, true);
  }
}
