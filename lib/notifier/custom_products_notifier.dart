import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utility/product.dart';

/// ---------------------------------------------------------------------------
/// CustomProductsNotifier
/// ---------------------------------------------------------------------------
/// ユーザーがアプリ上で追加したカスタム単語（Productオブジェクト）のリストを管理する
/// StateNotifier。インスタンス化時に SharedPreferences からデータをロードし、
/// addProduct() / removeProduct() で更新すると同時にストレージへ保存します。
class CustomProductsNotifier extends StateNotifier<List<Product>> {
  CustomProductsNotifier() : super([]) {
    _loaded = _loadCustomProducts();
  }

  /// 保存済みデータの読み込み。更新系の処理は必ずこの完了を待ってから行う
  /// （読み込み前に更新すると、遅れて届いた読み込み結果で上書きされてしまうため）
  late final Future<void> _loaded;

  static const _storageKey = 'custom_products';

  /// _loadCustomProducts()
  /// SharedPreferences から保存済みのカスタム単語リストを読み込んで状態を初期化する
  Future<void> _loadCustomProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final productJsonList = prefs.getStringList(_storageKey);
    if (productJsonList == null || !mounted) return;

    final products = <Product>[];
    for (final jsonStr in productJsonList) {
      try {
        products
            .add(Product.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>));
      } catch (error) {
        // 壊れたレコードは読み飛ばす（1件の破損で全件が消えるのを防ぐ）
        debugPrint('カスタム単語の復元に失敗しました: $error');
      }
    }
    state = products;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final productJsonList = state.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList(_storageKey, productJsonList);
  }

  /// addProduct()
  /// 新しいカスタム単語を状態に追加し、最新のリストを SharedPreferences に保存する。
  /// 単語は名前で識別しているため、同名のカスタム単語が既にある場合は追加せず false を返す。
  Future<bool> addProduct(Product product) async {
    await _loaded;
    if (state.any((p) => p.name == product.name)) return false;
    state = [...state, product];
    await _save();
    return true;
  }

  /// removeProduct()
  /// 指定した名前のカスタム単語を削除する
  Future<void> removeProduct(String name) async {
    await _loaded;
    state = state.where((p) => p.name != name).toList();
    await _save();
  }
}
