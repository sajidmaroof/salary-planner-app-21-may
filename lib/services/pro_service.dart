import 'package:shared_preferences/shared_preferences.dart';

class ProService {
  static const _key = 'is_pro';

  static bool _isPro = false;
  static bool get isPro => _isPro;

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isPro = prefs.getBool(_key) ?? false;
  }

  static Future<void> upgradeToPro() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
    _isPro = true;
  }

  static Future<void> revokePro() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, false);
    _isPro = false;
  }
}
