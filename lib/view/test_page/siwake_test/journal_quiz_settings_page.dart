import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../notifier/journal_quiz_filter_notifier.dart';
import '../../../provider/journal_quiz_filter_provider.dart';
import 'journal_entry_quiz_page.dart';

/// ---------------------------------------------------------------------------
/// JournalQuizSettingsPage
/// ─ 仕訳問題の出題範囲を選び、そのままクイズを開始する画面
/// ---------------------------------------------------------------------------
class JournalQuizSettingsPage extends ConsumerWidget {
  const JournalQuizSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(journalQuizFilterProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text("仕訳問題設定"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        children: [
          for (final filter in JournalQuizFilterNotifier.availableFilters)
            CheckboxListTile(
              title: Text(filter),
              value: filters.contains(filter),
              onChanged: (val) {
                ref
                    .read(journalQuizFilterProvider.notifier)
                    .toggleFilter(filter, val ?? false);
              },
            ),
          const SizedBox(height: 20),
          ElevatedButton(
            // 1つも選択されていないと出題できないため、ボタンを無効化する
            onPressed: filters.isEmpty
                ? null
                : () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const JournalEntryQuizPage()),
                    );
                  },
            child: const Text("問題出題"),
          ),
          if (filters.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                "出題範囲を1つ以上選択してください。",
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
