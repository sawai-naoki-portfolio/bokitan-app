import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../utility/responsive_sizes.dart';
import '../../../utility/sorting_problem.dart';
import 'journal_entry_quiz_widget.dart';
import 'journal_inquiry_button.dart';

final _yen = NumberFormat('#,###');

/// ---------------------------------------------------------------------------
/// JournalProblemDetailPage
/// ─ 1件の仕訳問題を「解く」タブと「解説」タブで表示する画面。
///   解答 UI は JournalEntryQuizWidget を再利用している。
/// ---------------------------------------------------------------------------
class JournalProblemDetailPage extends StatelessWidget {
  final SortingProblem problem;

  const JournalProblemDetailPage({super.key, required this.problem});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("仕訳問題詳細"),
          actions: [JournalInquiryButton(problemId: problem.id)],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.edit), text: "問題内容"),
              Tab(icon: Icon(Icons.visibility), text: "解説"),
            ],
          ),
        ),
        body: Column(
          children: [
            // 上部：基本情報カード
            Padding(
              padding: EdgeInsets.all(context.paddingSmall),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _InfoCard(title: "等級", value: problem.level),
                  _InfoCard(title: "種別", value: problem.bookkeepingType),
                  _InfoCard(title: "日付", value: _formatDate(problem)),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // タブ1：解答 UI（クイズと同じウィジェットを再利用）
                  SingleChildScrollView(
                    padding: EdgeInsets.all(context.paddingSmall),
                    child: JournalEntryQuizWidget(
                      key: ValueKey(problem.id),
                      problem: problem,
                      onSubmitted: (_) {},
                    ),
                  ),
                  // タブ2：解説
                  _ExplanationTab(problem: problem),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(SortingProblem problem) {
    try {
      return DateFormat('yyyy/MM/dd')
          .format(DateTime.parse(problem.transactionDate));
    } catch (_) {
      return problem.transactionDate;
    }
  }
}

/// 上部に並ぶ小さな情報カード
class _InfoCard extends StatelessWidget {
  final String title;
  final String value;

  const _InfoCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
      ),
    );
  }
}

/// 解説タブの中身
class _ExplanationTab extends StatelessWidget {
  final SortingProblem problem;

  const _ExplanationTab({required this.problem});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final headingStyle =
        textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);

    return SingleChildScrollView(
      padding: EdgeInsets.all(context.paddingSmall),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("問題", style: headingStyle),
          const SizedBox(height: 8),
          Text(problem.description, style: textTheme.bodyMedium),
          const SizedBox(height: 16),
          Text("正解の仕訳エントリー", style: headingStyle),
          const SizedBox(height: 16),
          if (problem.debitEntries.isNotEmpty) ...[
            Text("【借方】",
                style:
                    textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...problem.debitEntries.map((entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text("${entry.account} : ¥${_yen.format(entry.amount)}",
                      style: textTheme.bodyMedium),
                )),
            const SizedBox(height: 16),
          ],
          if (problem.creditEntries.isNotEmpty) ...[
            Text("【貸方】",
                style:
                    textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...problem.creditEntries.map((entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text("${entry.account} : ¥${_yen.format(entry.amount)}",
                      style: textTheme.bodyMedium),
                )),
            const SizedBox(height: 16),
          ],
          Text("解説", style: headingStyle),
          const SizedBox(height: 8),
          Text(problem.feedback, style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}
