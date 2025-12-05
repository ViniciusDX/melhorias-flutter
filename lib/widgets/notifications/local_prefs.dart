import 'package:shared_preferences/shared_preferences.dart';

class LocalPrefs {
  static const _deviceValidatedKey = 'deviceValidated';

  static Future<void> setDeviceValidated(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_deviceValidatedKey, value);
  }

  static Future<bool> isDeviceValidated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_deviceValidatedKey) ?? false;
  }
}
