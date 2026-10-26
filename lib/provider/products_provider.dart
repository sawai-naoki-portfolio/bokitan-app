import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utility/product.dart';

/// ---------------------------------------------------------------------------
/// productsProvider
/// ─ アセットのJSONファイル（約500KB）から単語リストを非同期で読み込むProvider。
///   パースは compute() で別 isolate に逃がし、起動直後のカクつきを防ぐ。
/// ---------------------------------------------------------------------------
final productsProvider = FutureProvider<List<Product>>((ref) async {
  final data = await rootBundle.loadString('assets/products.json');
  return compute(parseProducts, data);
});

/// JSON 文字列を Product のリストへ変換する。
/// compute() へ渡すためトップレベル関数として定義している。
List<Product> parseProducts(String raw) {
  final jsonResult = jsonDecode(raw) as List;
  return jsonResult
      .map((json) => Product.fromJson(json as Map<String, dynamic>))
      .toList();
}
