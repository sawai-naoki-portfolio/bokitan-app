import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sorting_problems_provider.dart';

/// ---------------------------------------------------------------------------
/// accountOptionsProvider
/// ─ 全仕訳問題に登場する勘定科目のマスタ一覧。
///   クイズの誤答候補（ダミーの選択肢）を作るために使う。
/// ---------------------------------------------------------------------------
final accountOptionsProvider = Provider<List<String>>((ref) {
  final problems = ref.watch(sortingProblemsProvider).value ?? const [];
  final accounts = <String>{};
  for (final problem in problems) {
    for (final entry in problem.entries) {
      accounts.add(entry.account);
    }
  }
  final list = accounts.toList()..sort();
  return List.unmodifiable(list);
});

/// 勘定科目の選択肢を組み立てる。
///
/// 正解の勘定科目（[correctAccounts]）に加えて、[master] からランダムに
/// 誤答候補を混ぜ、最低 [minOptions] 件になるまで水増しする。
/// 返り値は五十音（コード順）でソートされるため、並び順から正解を推測できない。
///
/// [master] が空、または十分な数が集まらない場合は、集まった分だけを返す。
List<String> buildAccountChoices({
  required Iterable<String> correctAccounts,
  required List<String> master,
  int minOptions = 10,
  Random? random,
}) {
  final choices = <String>{...correctAccounts};
  final distractors = master.where((a) => !choices.contains(a)).toList();
  if (distractors.isNotEmpty) {
    distractors.shuffle(random ?? Random());
    for (final account in distractors) {
      if (choices.length >= minOptions) break;
      choices.add(account);
    }
  }
  final list = choices.toList()..sort();
  return list;
}
