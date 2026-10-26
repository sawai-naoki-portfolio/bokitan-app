import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utility/schedule_item.dart';

/// ---------------------------------------------------------------------------
/// ScheduleNotifier
/// ─ スケジュール一覧を SharedPreferences 経由で管理する
/// ---------------------------------------------------------------------------
class ScheduleNotifier extends StateNotifier<List<ScheduleItem>> {
  ScheduleNotifier() : super([]) {
    _loaded = _loadScheduleItems();
  }

  /// 保存済みデータの読み込み。更新系の処理は必ずこの完了を待ってから行う
  /// （読み込み前に更新すると、遅れて届いた読み込み結果で上書きされてしまうため）
  late final Future<void> _loaded;

  static const _storageKey = 'schedule_items';

  Future<void> _loadScheduleItems() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_storageKey) ?? [];
    final items = <ScheduleItem>[];
    for (final e in data) {
      try {
        items.add(ScheduleItem.fromJson(jsonDecode(e) as Map<String, dynamic>));
      } catch (error) {
        // 壊れたレコードは読み飛ばす（1件の破損で全件が消えるのを防ぐ）
        debugPrint('ScheduleItem の復元に失敗しました: $error');
      }
    }
    if (!mounted) return;
    state = items;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final data = state.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList(_storageKey, data);
  }

  Future<void> addSchedule(ScheduleItem item) async {
    await _loaded;
    state = [...state, item];
    await _save();
  }

  Future<void> updateSchedule(ScheduleItem item) async {
    await _loaded;
    state = state.map((e) => e.id == item.id ? item : e).toList();
    await _save();
  }

  Future<void> removeSchedule(String id) async {
    await _loaded;
    state = state.where((e) => e.id != id).toList();
    await _save();
  }
}
