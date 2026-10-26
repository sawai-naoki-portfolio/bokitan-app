import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ---------------------------------------------------------------------------
/// SavedItemsNotifier
/// ─ ユーザーが保存した単語の名前を管理し、SharedPreferences に保存する
/// ---------------------------------------------------------------------------
class SavedItemsNotifier extends StateNotifier<List<String>> {
  SavedItemsNotifier() : super([]) {
    _loaded = _loadSavedItems();
  }

  /// 保存済みデータの読み込み。更新系の処理は必ずこの完了を待ってから行う
  /// （読み込み前に更新すると、遅れて届いた読み込み結果で上書きされてしまうため）
  late final Future<void> _loaded;

  Future<void> _loadSavedItems() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('saved_items') ?? [];
    if (!mounted) return;
    state = saved;
  }

  Future<void> saveItem(String productName) async {
    await _loaded;
    if (!state.contains(productName)) {
      state = [...state, productName];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('saved_items', state);
    }
  }

  Future<void> removeItem(String productName) async {
    await _loaded;
    if (state.contains(productName)) {
      state = state.where((e) => e != productName).toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('saved_items', state);
    }
  }

  Future<void> reorderItems(List<String> newOrder) async {
    await _loaded;
    state = newOrder;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('saved_items', state);
  }
}
