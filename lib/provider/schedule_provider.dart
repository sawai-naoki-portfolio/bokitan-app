import 'package:flutter_riverpod/legacy.dart';

import '../notifier/schedule_notifier.dart';
import '../utility/schedule_item.dart';

/// 学習スケジュールの状態を管理する Provider
final scheduleProvider =
    StateNotifierProvider<ScheduleNotifier, List<ScheduleItem>>(
  (ref) => ScheduleNotifier(),
);
