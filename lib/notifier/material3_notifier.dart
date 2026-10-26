import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Material3Notifier extends StateNotifier<bool> {
  Material3Notifier() : super(false) {
    _loaded = _loadMaterial3();
  }

  /// 保存済みデータの読み込み。更新系の処理は必ずこの完了を待ってから行う
  /// （読み込み前に更新すると、遅れて届いた読み込み結果で上書きされてしまうため）
  late final Future<void> _loaded;

  // SharedPreferencesからMaterial3の利用設定を読み込む
  Future<void> _loadMaterial3() async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('use_material3') ?? false;
    if (!mounted) return;
    state = isEnabled;
  }

  // Material3の利用設定を更新し、SharedPreferencesにも保存する
  Future<void> setMaterial3(bool value) async {
    await _loaded;
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_material3', value);
  }
}
