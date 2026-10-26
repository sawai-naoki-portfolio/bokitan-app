import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../provider/account_options_provider.dart';
import '../../../utility/journal_entry.dart';
import '../../../utility/responsive_sizes.dart';
import '../../../utility/sorting_problem.dart';
import '../../../utility/thousands_separator_input_formatter.dart';
import '../../widget/calculator_widget.dart';

final _yen = NumberFormat('#,###');

/// ─────────────────────────────────────────────
/// JournalEntryQuizWidget
/// ユーザーが仕訳問題に解答するウィジェット【左：借方／右：貸方】
///
/// 勘定科目の選択肢は「その問題の正解」だけを並べると消去法で解けてしまうため、
/// 全問題から作った勘定科目マスタ（accountOptionsProvider）から
/// 誤答候補を混ぜたうえで提示する。
/// ─────────────────────────────────────────────
class JournalEntryQuizWidget extends ConsumerStatefulWidget {
  final SortingProblem problem;
  final ValueChanged<bool> onSubmitted; // 正誤結果のコールバック

  const JournalEntryQuizWidget({
    super.key,
    required this.problem,
    required this.onSubmitted,
  });

  @override
  ConsumerState<JournalEntryQuizWidget> createState() =>
      _JournalEntryQuizWidgetState();
}

class _JournalEntryQuizWidgetState
    extends ConsumerState<JournalEntryQuizWidget> {
  // 正解の仕訳を「借方」と「貸方」に分割
  late final List<JournalEntry> _debitAnswers;
  late final List<JournalEntry> _creditAnswers;

  // 借方・貸方共通の勘定科目の選択肢（正解＋誤答候補）
  late final List<String> _accountChoices;

  // ユーザー入力
  late final List<String?> _userDebitAccounts;
  late final List<TextEditingController> _debitAmountControllers;
  late final List<String?> _userCreditAccounts;
  late final List<TextEditingController> _creditAmountControllers;

  bool? _isAnswerCorrect;

  @override
  void initState() {
    super.initState();
    _debitAnswers = widget.problem.debitEntries;
    _creditAnswers = widget.problem.creditEntries;

    _accountChoices = buildAccountChoices(
      correctAccounts: widget.problem.entries.map((e) => e.account),
      master: ref.read(accountOptionsProvider),
    );

    _userDebitAccounts = List<String?>.filled(_debitAnswers.length, null);
    _debitAmountControllers =
        List.generate(_debitAnswers.length, (_) => TextEditingController());

    _userCreditAccounts = List<String?>.filled(_creditAnswers.length, null);
    _creditAmountControllers =
        List.generate(_creditAnswers.length, (_) => TextEditingController());
  }

  @override
  void dispose() {
    for (final ctrl in _debitAmountControllers) {
      ctrl.dispose();
    }
    for (final ctrl in _creditAmountControllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _submitAnswer() {
    final userDebit = _collectAnswers(
      label: JournalEntry.debit,
      accounts: _userDebitAccounts,
      controllers: _debitAmountControllers,
    );
    if (userDebit == null) return;

    final userCredit = _collectAnswers(
      label: JournalEntry.credit,
      accounts: _userCreditAccounts,
      controllers: _creditAmountControllers,
    );
    if (userCredit == null) return;

    final correct = _isSameEntries(userDebit, _debitAnswers) &&
        _isSameEntries(userCredit, _creditAnswers);

    setState(() => _isAnswerCorrect = correct);
    widget.onSubmitted(correct);
  }

  /// 入力欄から解答を集める。未入力・不正な値があれば SnackBar を出して null を返す。
  List<({String account, int amount})>? _collectAnswers({
    required String label,
    required List<String?> accounts,
    required List<TextEditingController> controllers,
  }) {
    final result = <({String account, int amount})>[];
    for (var i = 0; i < accounts.length; i++) {
      final account = accounts[i];
      final rawAmount = controllers[i].text.trim();
      if (account == null || rawAmount.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$labelのすべての項目を入力してください")),
        );
        return null;
      }
      final amount = int.tryParse(rawAmount.replaceAll(',', ''));
      if (amount == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$label：金額は数字で入力してください")),
        );
        return null;
      }
      result.add((account: account, amount: amount));
    }
    return result;
  }

  /// 並び順を問わず、勘定科目と金額の組み合わせが一致するかを判定する
  bool _isSameEntries(
      List<({String account, int amount})> user, List<JournalEntry> correct) {
    if (user.length != correct.length) return false;
    final remaining = List<JournalEntry>.from(correct);
    for (final item in user) {
      final index = remaining.indexWhere(
          (e) => e.account == item.account && e.amount == item.amount);
      if (index == -1) return false;
      remaining.removeAt(index);
    }
    return remaining.isEmpty;
  }

  /// 借方・貸方どちらの入力欄も同じ形なので 1 つのビルダーで組み立てる
  Widget _buildEntryInput({
    required int index,
    required List<String?> accounts,
    required List<TextEditingController> controllers,
  }) {
    final theme = Theme.of(context);
    final locked = _isAnswerCorrect != null;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: "勘定科目",
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            initialValue: accounts[index],
            isExpanded: true,
            items: _accountChoices
                .map((account) => DropdownMenuItem(
                      value: account,
                      child: Text(
                        account,
                        style: TextStyle(fontSize: context.fontSizeMedium),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged:
                locked ? null : (val) => setState(() => accounts[index] = val),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controllers[index],
            enabled: !locked,
            decoration: InputDecoration(
              labelText: "金額",
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.calculate),
                tooltip: "電卓",
                onPressed:
                    locked ? null : () => _openCalculator(controllers[index]),
              ),
            ),
            inputFormatters: [ThousandsSeparatorInputFormatter()],
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }

  Future<void> _openCalculator(TextEditingController controller) async {
    // 現在入力されている内容（カンマを除去して数値に変換）を初期値にする
    final initialValue =
        double.tryParse(controller.text.replaceAll(',', '').trim()) ?? 0;
    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CalculatorWidget(initialValue: initialValue),
    );
    if (result == null) return;
    // 結果をカンマ区切りでフォーマットしてフィールドに反映
    controller.text = _yen.format(result);
  }

  Widget _buildSideColumn({
    required String title,
    required List<JournalEntry> answers,
    required List<String?> accounts,
    required List<TextEditingController> controllers,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: context.fontSizeMedium,
                  fontWeight: FontWeight.bold)),
          const Divider(thickness: 2),
          for (var i = 0; i < answers.length; i++)
            _buildEntryInput(
              index: i,
              accounts: accounts,
              controllers: controllers,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCorrect = _isAnswerCorrect;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          widget.problem.description,
          style: TextStyle(
              fontSize: context.fontSizeMedium, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSideColumn(
              title: JournalEntry.debit,
              answers: _debitAnswers,
              accounts: _userDebitAccounts,
              controllers: _debitAmountControllers,
            ),
            const SizedBox(width: 16),
            _buildSideColumn(
              title: JournalEntry.credit,
              answers: _creditAnswers,
              accounts: _userCreditAccounts,
              controllers: _creditAmountControllers,
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (isCorrect != null)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(context.paddingSmall),
            decoration: BoxDecoration(
              color: (isCorrect
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error)
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCorrect
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCorrect ? "正解です！" : "不正解です",
                  style: TextStyle(
                    fontSize: context.fontSizeMedium,
                    fontWeight: FontWeight.bold,
                    color: isCorrect
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 12),
                const Text("正解仕訳【借方】",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ..._debitAnswers.map((entry) =>
                    Text("${entry.account}  ¥${_yen.format(entry.amount)}")),
                const SizedBox(height: 4),
                const Text("正解仕訳【貸方】",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ..._creditAnswers.map((entry) =>
                    Text("${entry.account}  ¥${_yen.format(entry.amount)}")),
                const SizedBox(height: 12),
                const Text("解説", style: TextStyle(fontWeight: FontWeight.bold)),
                Text(widget.problem.feedback),
              ],
            ),
          ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: isCorrect == null
              ? () {
                  // キーボードを閉じてから採点する
                  FocusScope.of(context).unfocus();
                  _submitAnswer();
                }
              : null,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Center(
            child: Text(
              "回答を提出",
              style: TextStyle(fontSize: context.fontSizeMedium),
            ),
          ),
        ),
      ],
    );
  }
}
