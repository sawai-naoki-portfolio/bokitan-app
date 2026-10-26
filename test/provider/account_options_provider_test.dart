import 'dart:math';

import 'package:bookkeeping_vocabulary_notebook/provider/account_options_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildAccountChoices', () {
    final master = List.generate(30, (i) => '勘定科目${i.toString().padLeft(2, '0')}');

    test('正解の勘定科目は必ず選択肢に含まれる', () {
      final choices = buildAccountChoices(
        correctAccounts: ['仕入', '買掛金'],
        master: master,
        random: Random(0),
      );

      expect(choices, containsAll(['仕入', '買掛金']));
    });

    test('誤答候補が混ざり、最低件数まで水増しされる', () {
      final choices = buildAccountChoices(
        correctAccounts: ['仕入', '買掛金'],
        master: master,
        minOptions: 10,
        random: Random(0),
      );

      expect(choices, hasLength(10));
      // 正解2件以外はマスタから選ばれている
      final distractors =
          choices.where((c) => c != '仕入' && c != '買掛金').toList();
      expect(distractors, hasLength(8));
      expect(master, containsAll(distractors));
    });

    test('選択肢はソートされ、正解の位置から答えを推測できない', () {
      final choices = buildAccountChoices(
        correctAccounts: ['仕入'],
        master: master,
        random: Random(1),
      );

      final sorted = [...choices]..sort();
      expect(choices, equals(sorted));
    });

    test('選択肢に重複はない', () {
      final choices = buildAccountChoices(
        // 正解側に重複があっても選択肢は一意になる
        correctAccounts: ['仕入', '仕入', '買掛金'],
        master: master,
        random: Random(2),
      );

      expect(choices.toSet(), hasLength(choices.length));
    });

    test('マスタが空でも正解だけは返す（クイズが壊れない）', () {
      final choices = buildAccountChoices(
        correctAccounts: ['仕入', '買掛金'],
        master: const [],
      );

      expect(choices, hasLength(2));
      expect(choices, containsAll(['仕入', '買掛金']));
    });

    test('マスタが最低件数に満たない場合は集まった分だけ返す', () {
      final choices = buildAccountChoices(
        correctAccounts: ['仕入'],
        master: const ['現金', '売上'],
        minOptions: 10,
        random: Random(3),
      );

      expect(choices, hasLength(3));
    });
  });
}
