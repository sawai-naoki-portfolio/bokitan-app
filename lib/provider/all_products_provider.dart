import 'package:bookkeeping_vocabulary_notebook/provider/products_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utility/product.dart';
import 'custom_products_provider.dart';

/// ---------------------------------------------------------------------------
/// allProductsProvider
/// ---------------------------------------------------------------------------
/// アセット(JSON)からロードした単語とカスタム単語（ユーザー追加）を統合して返すシンプルなプロバイダー
final allProductsProvider = Provider<List<Product>>((ref) {
  final assetProductsAsync = ref.watch(productsProvider);
  final customProducts = ref.watch(customProductsProvider);
  List<Product> assetProducts = [];

  // FutureProvider の状態に合わせてアセット単語リストを抽出
  assetProductsAsync.when(
    data: (products) => assetProducts = products,
    loading: () {},
    error: (_, __) {},
  );
  // 両方のリストを統合して返す
  return [...assetProducts, ...customProducts];
});
