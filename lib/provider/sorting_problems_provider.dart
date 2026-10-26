// ============================================================================
// sortingProblemsProvider
// -----------------------------------------------------------------------------
// assets/siwake.json から仕訳問題のリストを非同期で読み込み、
// SortingProblem インスタンスのリストとして返す FutureProvider。
// パースは compute() で別 isolate に逃がしている。
// ============================================================================
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utility/sorting_problem.dart';

final sortingProblemsProvider =
    FutureProvider<List<SortingProblem>>((ref) async {
  final data = await rootBundle.loadString('assets/siwake.json');
  return compute(parseSortingProblems, data);
});

/// JSON 文字列を SortingProblem のリストへ変換する。
/// compute() へ渡すためトップレベル関数として定義している。
List<SortingProblem> parseSortingProblems(String raw) {
  final jsonResult = jsonDecode(raw) as List;
  return jsonResult
      .map((json) => SortingProblem.fromJson(json as Map<String, dynamic>))
      .toList();
}
