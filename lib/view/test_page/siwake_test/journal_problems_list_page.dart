import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../provider/sorting_problems_provider.dart';
import '../../../utility/sorting_problem.dart';
import 'journal_problem_detail_page.dart';

/// ---------------------------------------------------------------------------
/// JournalProblemsListPage
/// ─ 収録されている仕訳問題を一覧で閲覧する画面
/// ---------------------------------------------------------------------------
class JournalProblemsListPage extends ConsumerWidget {
  const JournalProblemsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final problemsAsync = ref.watch(sortingProblemsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("仕訳問題一覧")),
      body: problemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('エラー: $error')),
        data: (problems) {
          if (problems.isEmpty) {
            return const Center(child: Text("問題が登録されていません"));
          }
          // 一覧は再描画のたびに並びが変わらないよう、収録順のまま表示する
          return ListView.separated(
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemCount: problems.length,
            itemBuilder: (context, index) {
              final problem = problems[index];
              return ListTile(
                title: Text(
                  problem.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                    '日付: ${_formatDate(problem)}  等級: ${problem.level}（${problem.bookkeepingType}）'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          JournalProblemDetailPage(problem: problem),
                    ),
                  );
                },
              );
            },
          );
        },
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
