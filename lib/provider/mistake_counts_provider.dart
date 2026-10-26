// プロバイダー定義：アプリ全体でミス回数の状態を共有するための Provider
import 'package:flutter_riverpod/legacy.dart';

import '../notifier/mistake_count_notifier.dart';

final mistakeCountsProvider =
    StateNotifierProvider<MistakeCountNotifier, Map<String, int>>(
  (ref) => MistakeCountNotifier(),
);
