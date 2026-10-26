import 'package:flutter_riverpod/legacy.dart';

import '../notifier/custom_products_notifier.dart';
import '../utility/product.dart';

/// プロバイダー定義：ユーザーが追加したカスタム単語を管理する
final customProductsProvider =
    StateNotifierProvider<CustomProductsNotifier, List<Product>>(
        (ref) => CustomProductsNotifier());
