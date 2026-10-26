import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ---------------------------------------------------------------------------
/// CheckedQuestionsNotifier
/// ─────────────────────────────────────────────────────────
/// 単語チェック問題に登録した単語の名前をセットとして管理する状態クラスです。
/// ・初期化時に SharedPreferences から読み込み
/// ・add, remove, toggle の各操作で状態および永続化処理を実行
/// ---------------------------------------------------------------------------
class CheckedQuestionsNotifier extends StateNotifier<Set<String>> {
  CheckedQuestionsNotifier() : super({}) {
    _loaded = _load();
  }

  /// 保存済みデータの読み込み。更新系の処理は必ずこの完了を待ってから行う
  /// （読み込み前に保存すると、保存済みのデータを上書きして消してしまうため）
  late final Future<void> _loaded;

  /// [_load]
  /// SharedPreferencesから以前の登録済み単語のセットをロードします。
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('checked_questions') ?? [];
    if (!mounted) return;
    state = state.union(list.toSet());
  }

  /// [add]
  /// 指定された単語を状態に追加し、SharedPreferencesに保存します。
  Future<void> add(String productName) async {
    await _loaded;
    if (!state.contains(productName)) {
      state = {...state, productName};
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('checked_questions', state.toList());
    }
  }

  /// [remove]
  /// 指定された単語を状態から除外し、SharedPreferencesに反映します。
  Future<void> remove(String productName) async {
    await _loaded;
    if (state.contains(productName)) {
      state = state.where((name) => name != productName).toSet();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('checked_questions', state.toList());
    }
  }

  /// [toggle]
  /// 単語が状態に含まれていれば削除、なければ追加するトグル動作を実行します。
  Future<void> toggle(String productName) async {
    await _loaded;
    if (state.contains(productName)) {
      await remove(productName);
    } else {
      await add(productName);
    }
  }
}
