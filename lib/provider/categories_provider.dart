import 'package:flutter_riverpod/legacy.dart';

import '../notifier/categories_notifier.dart';
import '../utility/category.dart';

final categoriesProvider =
    StateNotifierProvider<CategoriesNotifier, List<Category>>(
        (ref) => CategoriesNotifier());
