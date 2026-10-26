import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ---------------------------------------------------------------------------
/// JournalQuizFilterNotifier
/// ─ 仕訳問題の出題範囲（級 × 商業/工業）の選択状態を管理する。
///   状態は「簿記3級-商業簿記」のような SortingProblem.filterKey の集合。
/// ---------------------------------------------------------------------------
class JournalQuizFilterNotifier extends StateNotifier<Set<String>> {
  JournalQuizFilterNotifier() : super(defaultFilters) {
    _loaded = _loadFilters();
  }

  /// 保存済みデータの読み込み。更新系の処理は必ずこの完了を待ってから行う
  /// （読み込み前に更新すると、遅れて届いた読み込み結果で上書きされてしまうため）
  late final Future<void> _loaded;

  static const _storageKey = 'journal_quiz_filters';

  /// 選択可能な出題範囲（画面の表示順もこの順に従う）
  static const availableFilters = <String>[
    '簿記3級-商業簿記',
    '簿記2級-商業簿記',
    '簿記2級-工業簿記',
  ];

  /// 初期状態は全範囲を有効にする
  static final defaultFilters = availableFilters.toSet();

  Future<void> _loadFilters() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);
    if (jsonStr == null || !mounted) return;
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      // 将来フィルターの種類が変わっても、存在しないキーは読み捨てる
      state = list
          .map((e) => e.toString())
          .where(availableFilters.contains)
          .toSet();
    } catch (error) {
      debugPrint('出題範囲の復元に失敗しました: $error');
    }
  }

  Future<void> updateFilters(Set<String> newFilters) async {
    await _loaded;
    state = newFilters;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(state.toList()));
  }

  Future<void> toggleFilter(String key, bool isSelected) async {
    await _loaded;
    final newFilters = {...state};
    if (isSelected) {
      newFilters.add(key);
    } else {
      newFilters.remove(key);
    }
    await updateFilters(newFilters);
  }
}
