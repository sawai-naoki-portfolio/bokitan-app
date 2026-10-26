// 単語検索画面（アプリのホーム）が正しく描画され、検索が絞り込めることを確認する
// スモークテスト。アセット読み込みや広告に依存しないよう、
// 単語リストの Provider をテスト用データで差し替えている。

import 'package:bookkeeping_vocabulary_notebook/main.dart';
import 'package:bookkeeping_vocabulary_notebook/provider/products_provider.dart';
import 'package:bookkeeping_vocabulary_notebook/utility/product.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _testProducts = [
  Product(
    name: '売掛金',
    yomigana: 'うりかけきん',
    description: '商品を掛けで販売したときの債権',
    category: '資産',
  ),
  Product(
    name: '買掛金',
    yomigana: 'かいかけきん',
    description: '商品を掛けで仕入れたときの債務',
    category: '負債',
  ),
];

Widget _buildApp() {
  return ProviderScope(
    overrides: [
      productsProvider.overrideWith((ref) => _testProducts),
    ],
    child: const MyApp(),
  );
}

void main() {
  setUp(() {
    // 各 Notifier が SharedPreferences を読むため、空の値でモックしておく
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('ホーム画面が表示され、単語の一覧が並ぶ', (WidgetTester tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.text('単語検索'), findsOneWidget);
    expect(find.text('単語名を入力'), findsOneWidget);
    expect(find.text('売掛金'), findsOneWidget);
    expect(find.text('買掛金'), findsOneWidget);
  });

  testWidgets('検索語を入力すると一致する単語だけが残る', (WidgetTester tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'うりかけ');
    // 入力は 250ms デバウンスしてから反映される
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('売掛金'), findsOneWidget);
    expect(find.text('買掛金'), findsNothing);
  });

  testWidgets('一致しない検索語では該当なしの案内を出す', (WidgetTester tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'そんな単語はない');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('一致する単語がありません'), findsOneWidget);
  });
}
