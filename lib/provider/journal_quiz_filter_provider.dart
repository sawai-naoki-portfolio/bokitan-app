import 'package:flutter_riverpod/legacy.dart';

import '../notifier/journal_quiz_filter_notifier.dart';

/// 仕訳問題の出題範囲フィルターを共有する Provider
final journalQuizFilterProvider =
    StateNotifierProvider<JournalQuizFilterNotifier, Set<String>>(
  (ref) => JournalQuizFilterNotifier(),
);
