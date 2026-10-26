import 'package:flutter_riverpod/legacy.dart';

/// 検索クエリの状態を管理するProvider
final searchQueryProvider = StateProvider<String>((ref) => '');
