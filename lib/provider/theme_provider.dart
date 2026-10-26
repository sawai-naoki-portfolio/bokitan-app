import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../notifier/theme_notifier.dart';

/// テーマの状態を管理する StateNotifier とプロバイダー
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>(
  (ref) => ThemeNotifier(),
);
