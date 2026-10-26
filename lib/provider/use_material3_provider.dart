import 'package:flutter_riverpod/legacy.dart';

import '../notifier/material3_notifier.dart';

/// Material 3 の利用状態を管理するシンプルなプロバイダー
final useMaterial3Provider = StateNotifierProvider<Material3Notifier, bool>(
  (ref) => Material3Notifier(),
);
