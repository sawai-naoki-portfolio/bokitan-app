import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ads/ad_manager.dart';
import '../../../provider/journal_quiz_filter_provider.dart';
import '../../../provider/sorting_problems_provider.dart';
import '../../../utility/responsive_sizes.dart';
import '../../../utility/sorting_problem.dart';
import 'journal_entry_quiz_widget.dart';
import 'journal_inquiry_button.dart';
import 'sorting_quiz_result_page.dart';

/// ---------------------------------------------------------------------------
/// JournalEntryQuizPage
/// ─ 仕訳問題を 1 問ずつ出題するクイズ画面
/// ---------------------------------------------------------------------------
class JournalEntryQuizPage extends ConsumerStatefulWidget {
  final int quizCount;

  const JournalEntryQuizPage({
    super.key,
    this.quizCount = 10, // デフォルト10問
  });

  @override
  ConsumerState<JournalEntryQuizPage> createState() =>
      _JournalEntryQuizPageState();
}

class _JournalEntryQuizPageState extends ConsumerState<JournalEntryQuizPage> {
  int _currentIndex = 0;
  bool? _lastAnswerCorrect;
  final List<bool> _answers = [];

  /// 出題対象。問題データの読み込みが終わるまでは null。
  List<SortingProblem>? _quizProblems;

  @override
  void initState() {
    super.initState();
    AdManager.loadAd(AdType.interstitial);
  }

  void _onQuizSubmitted(bool isCorrect) {
    setState(() {
      _lastAnswerCorrect = isCorrect;
      _answers.add(isCorrect);
    });
  }

  void _nextQuestion() {
    final problems = _quizProblems;
    if (problems == null) return;

    if (_currentIndex < problems.length - 1) {
      setState(() {
        _currentIndex++;
        _lastAnswerCorrect = null;
      });
      return;
    }

    AdManager.showInterstitialAd(onComplete: () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SortingQuizResultPage(
            quizProblems: problems,
            answers: List<bool>.from(_answers),
          ),
        ),
      );
    });
  }

  /// フィルター条件に合う問題からランダムに出題分だけ抜き出す
  List<SortingProblem> _pickProblems(
      List<SortingProblem> problems, Set<String> allowedFilters) {
    final available = problems
        .where((p) => allowedFilters.contains(p.filterKey))
        .toList()
      ..shuffle();
    if (available.length <= widget.quizCount) return available;
    return available.take(widget.quizCount).toList();
  }

  @override
  Widget build(BuildContext context) {
    final problemsAsync = ref.watch(sortingProblemsProvider);
    // 条件付きで watch すると Riverpod の依存関係が壊れるため、必ず先頭で watch する
    final allowedFilters = ref.watch(journalQuizFilterProvider);
    final problems = _quizProblems;

    return Scaffold(
      appBar: AppBar(
        title: const Text("仕訳テスト"),
        actions: [
          // 問題が確定するまでは押せないようにする（未初期化アクセス防止）
          if (problems != null && problems.isNotEmpty)
            JournalInquiryButton(problemId: problems[_currentIndex].id),
        ],
      ),
      body: problemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text("エラー: $error")),
        data: (allProblems) {
          // 初回のデータ到着時にだけ出題内容を確定させる
          final quizProblems =
              _quizProblems ??= _pickProblems(allProblems, allowedFilters);

          if (quizProblems.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "選択された条件に一致する問題はありません。\n設定から出題範囲を見直してください。",
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final currentProblem = quizProblems[_currentIndex];
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 問題番号と問題の種別を表示
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        "問題 ${_currentIndex + 1} / ${quizProblems.length} (${currentProblem.bookkeepingType})",
                        style: TextStyle(
                            fontSize: context.fontSizeMedium,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (_lastAnswerCorrect != null)
                      ElevatedButton(
                        onPressed: _nextQuestion,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                            _currentIndex < quizProblems.length - 1
                                ? "次の問題へ"
                                : "結果を見る",
                            style: TextStyle(fontSize: context.fontSizeMedium)),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                JournalEntryQuizWidget(
                  key: ValueKey(currentProblem.id),
                  problem: currentProblem,
                  onSubmitted: _onQuizSubmitted,
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}
