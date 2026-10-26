import 'package:flutter_riverpod/legacy.dart';

import '../notifier/checked_questions_notifier.dart';

/// Providerを通じて、アプリ内でチェックされた単語の状態を共有します。
final checkedQuestionsProvider =
    StateNotifierProvider<CheckedQuestionsNotifier, Set<String>>(
        (ref) => CheckedQuestionsNotifier());
