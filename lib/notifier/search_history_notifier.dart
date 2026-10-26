import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryNotifier extends StateNotifier<List<String>> {
  SearchHistoryNotifier() : super([]) {
    _loaded = _loadHistory();
  }

  /// 保存済みデータの読み込み。更新系の処理は必ずこの完了を待ってから行う
  /// （読み込み前に更新すると、遅れて届いた読み込み結果で上書きされてしまうため）
  late final Future<void> _loaded;

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('search_history') ?? [];
    if (!mounted) return;
    state = list;
  }

  Future<void> addProduct(String productName) async {
    await _loaded;
    final prefs = await SharedPreferences.getInstance();
    List<String> newHistory = List.from(state);
    newHistory.remove(productName); // 重複があれば削除
    newHistory.insert(0, productName); // 最新を先頭に追加
    if (newHistory.length > 15) {
      newHistory = newHistory.sublist(0, 15);
    }
    state = newHistory;
    await prefs.setStringList('search_history', state);
  }

  Future<void> clearHistory() async {
    await _loaded;
    state = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('search_history', state);
  }
}
