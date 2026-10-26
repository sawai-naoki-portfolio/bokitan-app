import 'package:bookkeeping_vocabulary_notebook/provider/products_provider.dart';
import 'package:bookkeeping_vocabulary_notebook/provider/sorting_problems_provider.dart';
import 'package:bookkeeping_vocabulary_notebook/utility/journal_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseProducts', () {
    test('JSON から Product を組み立てる', () {
      const raw = '''
[
  {
    "name": "売掛金",
    "description": "商品を掛けで販売したときの債権",
    "yomigana": "うりかけきん",
    "category": "資産"
  }
]
''';

      final products = parseProducts(raw);

      expect(products, hasLength(1));
      expect(products.single.name, '売掛金');
      expect(products.single.yomigana, 'うりかけきん');
      expect(products.single.category, '資産');
    });

    test('yomigana と category が無くても既定値で復元できる', () {
      const raw = '[{"name": "現金", "description": "手元の通貨"}]';

      final product = parseProducts(raw).single;

      expect(product.yomigana, '');
      expect(product.category, '未分類');
    });
  });

  group('parseSortingProblems', () {
    const raw = '''
[
  {
    "id": "XYZ",
    "level": "簿記3級",
    "transaction_date": "2025-04-01",
    "description": "商品500,000円を仕入れ、代金は掛けとした。",
    "entries": [
      {"side": "借方", "account": "仕入", "amount": 500000},
      {"side": "貸方", "account": "買掛金", "amount": 500000}
    ],
    "bookkeepingType": "商業簿記",
    "feedback": "仕入は費用の増加です。"
  }
]
''';

    test('JSON から SortingProblem を組み立てる', () {
      final problem = parseSortingProblems(raw).single;

      expect(problem.id, 'XYZ');
      expect(problem.level, '簿記3級');
      expect(problem.bookkeepingType, '商業簿記');
      expect(problem.entries, hasLength(2));
    });

    test('借方・貸方が正しく振り分けられる', () {
      final problem = parseSortingProblems(raw).single;

      expect(problem.debitEntries.single.account, '仕入');
      expect(problem.debitEntries.single.side, JournalEntry.debit);
      expect(problem.creditEntries.single.account, '買掛金');
      expect(problem.creditEntries.single.amount, 500000);
    });

    test('filterKey は「級-種別」の形式になる', () {
      expect(parseSortingProblems(raw).single.filterKey, '簿記3級-商業簿記');
    });
  });
}
