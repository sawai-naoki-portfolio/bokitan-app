import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../ads/ad_manager.dart';
import '../../../utility/responsive_sizes.dart';
import '../../../utility/sorting_problem.dart';
import 'journal_entry_quiz_page.dart';
import 'journal_problem_detail_page.dart';

final _yen = NumberFormat('#,###');

/// リワード広告を見たときに増える問題数
const _rewardBonusCount = 5;

/// ─────────────────────────────────────────────
/// SortingQuizResultPage
/// 各問題の結果と総合得点を表示する画面
/// ─────────────────────────────────────────────
class SortingQuizResultPage extends StatelessWidget {
  final List<SortingProblem> quizProblems;
  final List<bool> answers; // 各問題の正誤結果

  const SortingQuizResultPage({
    super.key,
    required this.quizProblems,
    required this.answers,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final correctCount = answers.where((isCorrect) => isCorrect).length;

    return Scaffold(
      appBar: AppBar(title: const Text("結果画面")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // 総合成績表示
            Text(
              "結果：$correctCount / ${quizProblems.length} 問正解",
              style: TextStyle(
                fontSize: context.fontSizeExtraLarge,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            // 各問題の結果をカード形式で表示
            Expanded(
              child: ListView.separated(
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 16),
                itemCount: quizProblems.length,
                itemBuilder: (context, index) {
                  // 途中で中断した場合に備え、範囲外は未回答（不正解）扱いにする
                  final isCorrect =
                      index < answers.length ? answers[index] : false;
                  return _ResultCard(
                    problem: quizProblems[index],
                    index: index,
                    isCorrect: isCorrect,
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 「ホームに戻る」ボタン：トップに戻る
                ElevatedButton.icon(
                  onPressed: () =>
                      Navigator.popUntil(context, (route) => route.isFirst),
                  icon: const Icon(Icons.home),
                  label: Text("ホームに戻る",
                      style: TextStyle(fontSize: context.fontSizeMedium)),
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                // 「もう一度」ボタン：クイズを再挑戦
                ElevatedButton.icon(
                  onPressed: () => _retry(context),
                  icon: const Icon(Icons.refresh),
                  label: Text("もう一度",
                      style: TextStyle(fontSize: context.fontSizeMedium)),
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// リワード広告を挟んで再挑戦する。報酬を得られた場合のみ問題数を増やす。
  void _retry(BuildContext context) {
    final currentCount = quizProblems.length;

    void restart(int quizCount) {
      if (!context.mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => JournalEntryQuizPage(quizCount: quizCount),
        ),
      );
    }

    AdManager.showRewardedAd(
      onUserEarned: () async {
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text("報酬ゲット！"),
            content: const Text("問題数が＋$_rewardBonusCount問増量されました！"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("OK"),
              ),
            ],
          ),
        );
        restart(currentCount + _rewardBonusCount);
      },
      // 広告を閉じただけ／未ロード時は元の問題数で再挑戦
      onAdClosedWithoutReward: () => restart(currentCount),
    );
  }
}

/// 1問分の結果カード
class _ResultCard extends StatelessWidget {
  final SortingProblem problem;
  final int index;
  final bool isCorrect;

  const _ResultCard({
    required this.problem,
    required this.index,
    required this.isCorrect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent =
        isCorrect ? theme.colorScheme.primary : theme.colorScheme.error;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 6,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: accent.withValues(alpha: 0.08),
              border: Border.all(color: accent.withValues(alpha: 0.4)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "問題 ${index + 1}",
                  style: TextStyle(
                    fontSize: context.fontSizeLarge,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(problem.description,
                    style: TextStyle(fontSize: context.fontSizeMedium)),
                const SizedBox(height: 12),
                Text(
                  isCorrect ? "正解" : "不正解",
                  style: TextStyle(
                    fontSize: context.fontSizeMedium,
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 12),
                const Text("正解仕訳【借方】",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ...problem.debitEntries.map(
                    (e) => Text("${e.account}  ¥${_yen.format(e.amount)}")),
                const SizedBox(height: 4),
                const Text("正解仕訳【貸方】",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ...problem.creditEntries.map(
                    (e) => Text("${e.account}  ¥${_yen.format(e.amount)}")),
                const SizedBox(height: 12),
                const Text("解説：",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(problem.feedback),
              ],
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.arrow_forward),
              tooltip: "この問題をもう一度解く",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => JournalProblemDetailPage(problem: problem),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
