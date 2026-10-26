import 'package:flutter_riverpod/legacy.dart';

import '../notifier/search_history_notifier.dart';

final searchHistoryProvider =
    StateNotifierProvider<SearchHistoryNotifier, List<String>>(
        (ref) => SearchHistoryNotifier());
