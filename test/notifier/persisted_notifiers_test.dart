// SharedPreferences に永続化する Notifier の振る舞いを検証する。
// 特に「保存済みデータの読み込みが終わる前に更新しても、保存済みデータが消えない」ことを確認する。

import 'package:bookkeeping_vocabulary_notebook/notifier/categories_notifier.dart';
import 'package:bookkeeping_vocabulary_notebook/notifier/checked_questions_notifier.dart';
import 'package:bookkeeping_vocabulary_notebook/notifier/custom_products_notifier.dart';
import 'package:bookkeeping_vocabulary_notebook/notifier/saved_items_notifier.dart';
import 'package:bookkeeping_vocabulary_notebook/notifier/theme_notifier.dart';
import 'package:bookkeeping_vocabulary_notebook/utility/product.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Product _product(String name) => Product(
      name: name,
      yomigana: '',
      description: '',
      category: 'カスタム単語',
    );

void main() {
  group('読み込み完了前の更新', () {
    test('SavedItemsNotifier: 保存済みの単語に追加される', () async {
      SharedPreferences.setMockInitialValues({
        'saved_items': ['売掛金'],
      });
      final notifier = SavedItemsNotifier();
      // 生成直後（読み込み完了前）に更新する
      await notifier.saveItem('買掛金');

      expect(notifier.state, ['売掛金', '買掛金']);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('saved_items'), ['売掛金', '買掛金']);
    });

    test('CheckedQuestionsNotifier: 保存済みのチェックが消えない', () async {
      SharedPreferences.setMockInitialValues({
        'checked_questions': ['売掛金'],
      });
      final notifier = CheckedQuestionsNotifier();
      await notifier.add('買掛金');

      expect(notifier.state, {'売掛金', '買掛金'});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('checked_questions')!.toSet(),
          {'売掛金', '買掛金'});
    });

    test('ThemeNotifier: 変更したテーマが読み込み結果で巻き戻らない', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
      final notifier = ThemeNotifier();
      await notifier.setTheme(ThemeMode.dark);
      // 読み込みが後から完了しても上書きされないこと
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state, ThemeMode.dark);
    });
  });

  group('CategoriesNotifier', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('既存のリスト名には変更できない', () async {
      final notifier = CategoriesNotifier();
      await notifier.addCategory('苦手');
      await notifier.addCategory('復習');

      final renamed = await notifier.updateCategory('復習', '苦手');

      expect(renamed, isFalse);
      expect(notifier.state.map((c) => c.name), ['苦手', '復習']);
    });

    test('重複しない名前には変更でき、所属単語は引き継がれる', () async {
      final notifier = CategoriesNotifier();
      await notifier.addCategory('苦手');
      await notifier.updateProductAssignment('苦手', '売掛金', true);

      final renamed = await notifier.updateCategory('苦手', '要復習');

      expect(renamed, isTrue);
      expect(notifier.state.single.name, '要復習');
      expect(notifier.state.single.products, ['売掛金']);
    });

    test('壊れた保存データがあっても空のリストとして起動できる', () async {
      SharedPreferences.setMockInitialValues({'saved_categories': '{壊れたJSON'});
      final notifier = CategoriesNotifier();
      await notifier.addCategory('苦手');

      expect(notifier.state.map((c) => c.name), ['苦手']);
    });
  });

  group('CustomProductsNotifier', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('同じ名前のカスタム単語は追加されない', () async {
      final notifier = CustomProductsNotifier();

      expect(await notifier.addProduct(_product('独自用語')), isTrue);
      expect(await notifier.addProduct(_product('独自用語')), isFalse);
      expect(notifier.state, hasLength(1));
    });
  });
}
