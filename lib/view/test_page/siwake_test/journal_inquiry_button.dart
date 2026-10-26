import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../utility/responsive_sizes.dart';

/// 仕訳問題の誤りを報告してもらう Google フォーム
const journalFeedbackFormUrl =
    'https://docs.google.com/forms/d/e/1FAIpQLSevGyY5tye6g36xIz6CW25iBi4BJfHk70ss7l3_S0O6HyYmiA/viewform?usp=dialog';

/// ---------------------------------------------------------------------------
/// JournalInquiryButton
/// ─ 表示中の仕訳問題について問い合わせるためのボタン。
///   問題 ID をコピーしてからでないとフォームへ進めないようにしている。
/// ---------------------------------------------------------------------------
class JournalInquiryButton extends StatelessWidget {
  final String problemId;

  const JournalInquiryButton({super.key, required this.problemId});

  Future<void> _launchFeedbackForm(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await launchUrl(
      Uri.parse(journalFeedbackFormUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text("フィードバックフォームを開けませんでした")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.contact_support),
      tooltip: "お問い合わせ",
      onPressed: () => _showInquiryDialog(context),
    );
  }

  void _showInquiryDialog(BuildContext context) {
    bool isCopied = false;
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (dialogContext, setState) {
          return AlertDialog(
            title: const Text("お問い合わせ"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "クイズに誤りがある場合は、以下フォームに「問題ID」と「正しい回答」を記載してください。",
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(dialogContext)
                        .colorScheme
                        .secondaryContainer
                        .withValues(alpha: 0.5),
                    border: Border.all(
                        color: Theme.of(dialogContext).colorScheme.secondary),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Theme.of(dialogContext).colorScheme.secondary),
                      const SizedBox(width: 5),
                      Expanded(
                        child: SelectableText(
                          "問題ID: $problemId",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: dialogContext.fontSizeMedium,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        tooltip: "コピー",
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: problemId));
                          setState(() => isCopied = true);
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(content: Text("問題IDをコピーしました")),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed:
                      isCopied ? () => _launchFeedbackForm(dialogContext) : null,
                  child: Text(
                    isCopied ? "仕訳問題お問い合わせフォームへ移動" : "問題IDをコピーしてください",
                    style: TextStyle(fontSize: dialogContext.fontSizeMedium),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("閉じる"),
              ),
            ],
          );
        });
      },
    );
  }
}
