import 'package:flutter_riverpod/legacy.dart';

import '../notifier/saved_items_notifier.dart';

final savedItemsProvider =
    StateNotifierProvider<SavedItemsNotifier, List<String>>(
  (ref) => SavedItemsNotifier(),
);
