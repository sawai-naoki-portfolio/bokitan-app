import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.light) {
    _loaded = _loadTheme();
  }

  /// 保存済みデータの読み込み。更新系の処理は必ずこの完了を待ってから行う
  /// （読み込み前に更新すると、遅れて届いた読み込み結果で上書きされてしまうため）
  late final Future<void> _loaded;

  // SharedPreferencesから "theme_mode" キーで保存されたテーマを読み込む
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString("theme_mode") ?? "light";
    if (!mounted) return;
    if (themeStr == "system") {
      state = ThemeMode.system;
    } else if (themeStr == "dark") {
      state = ThemeMode.dark;
    } else {
      state = ThemeMode.light;
    }
  }

  // テーマ変更時に SharedPreferences へ保存も行う
  Future<void> setTheme(ThemeMode mode) async {
    await _loaded;
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    // シンプルに文字列として保存します（"light", "dark", "system"）
    String modeStr;
    if (mode == ThemeMode.system) {
      modeStr = "system";
    } else if (mode == ThemeMode.dark) {
      modeStr = "dark";
    } else {
      modeStr = "light";
    }
    await prefs.setString("theme_mode", modeStr);
  }

  // 現在の状態が light なら dark に、そうでなければ light に切り替える
  // （system 状態の場合は light に切り替えます）
  Future<void> toggleTheme() async {
    await _loaded;
    if (state == ThemeMode.light) {
      await setTheme(ThemeMode.dark);
    } else {
      await setTheme(ThemeMode.light);
    }
  }
}
