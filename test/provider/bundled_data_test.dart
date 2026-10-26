// アプリに同梱している JSON データ（assets/）そのものの整合性を検証する。
// 正解データの誤りはユーザーが正しく解答しても不正解になる不具合に直結するため、
// データを編集したら必ずこのテストを通すこと。

import 'dart:io';

import 'package:bookkeeping_vocabulary_notebook/notifier/journal_quiz_filter_notifier.dart';
import 'package:bookkeeping_vocabulary_notebook/provider/products_provider.dart';
import 'package:bookkeeping_vocabulary_notebook/provider/sorting_problems_provider.dart';
import 'package:bookkeeping_vocabulary_notebook/utility/journal_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('assets/siwake.json', () {
    final problems =
        parseSortingProblems(File('assets/siwake.json').readAsStringSync());

    test('問題 ID が重複していない', () {
      final ids = problems.map((p) => p.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('すべての問題で借方合計と貸方合計が一致する', () {
      final unbalanced = <String>[];
      for (final p in problems) {
        final debit = p.debitEntries.fold<int>(0, (sum, e) => sum + e.amount);
        final credit =
            p.creditEntries.fold<int>(0, (sum, e) => sum + e.amount);
        if (debit != credit) {
          unbalanced.add('${p.id}（借方 $debit / 貸方 $credit）');
        }
      }
      expect(unbalanced, isEmpty);
    });

    test('仕訳は借方・貸方の両方を持ち、金額は正の数', () {
      for (final p in problems) {
        expect(p.debitEntries, isNotEmpty, reason: p.id);
        expect(p.creditEntries, isNotEmpty, reason: p.id);
        for (final e in p.entries) {
          expect([JournalEntry.debit, JournalEntry.credit], contains(e.side),
              reason: p.id);
          expect(e.account.trim(), isNotEmpty, reason: p.id);
          expect(e.amount, greaterThan(0), reason: p.id);
        }
      }
    });

    test('出題範囲フィルターのいずれかに属する', () {
      for (final p in problems) {
        expect(JournalQuizFilterNotifier.availableFilters, contains(p.filterKey),
            reason: p.id);
      }
    });
  });

  group('assets/products.json', () {
    final products =
        parseProducts(File('assets/products.json').readAsStringSync());

    test('単語名が空でなく、重複していない', () {
      final names = products.map((p) => p.name).toList();
      expect(names.where((n) => n.trim().isEmpty), isEmpty);
      expect(names.toSet(), hasLength(names.length));
    });
  });
}
