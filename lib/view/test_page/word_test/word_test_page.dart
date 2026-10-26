import 'package:bookkeeping_vocabulary_notebook/utility/responsive_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bookkeeping_vocabulary_notebook/ads/ad_manager.dart';
import '../../../provider/mistake_counts_provider.dart';
import '../../../provider/products_provider.dart';
import '../../../utility/word_test_question.dart';
import '../../../utility/generate_quiz_questions.dart';
import 'word_test_result_page.dart';

/// ---------------------------------------------------------------------------
/// WordTestPage
/// ---------------------------------------------------------------------------
/// ユーザーがクイズ形式で単語テストに挑戦できる画面。各問題は単語の説明を基にして出題され、
/// 選択肢をタップすると正誤判定が行われ、最終的なテスト結果画面に遷移します。
class WordTestPage extends ConsumerStatefulWidget {
  final int quizCount; // ← 新たに追加
  const WordTestPage({super.key, this.quizCount = 10});

  @override
  ConsumerState<WordTestPage> createState() => _WordTestPageState();
}

/// _WordTestPageState
/// ---------------------------------------------------------------------------
/// 単語テスト（クイズ）の状態を管理するクラス。クイズの問題リスト生成、
/// ユーザーの選択に応じた正誤判定、次の問題への遷移などのロジックを内包しています。
class _WordTestPageState extends ConsumerState<WordTestPage> {
  List<WordTestQuestion>? _quiz; // 出題用の問題リスト（データ到着後に一度だけ生成）
  int currentQuestionIndex = 0; // 現在の問題番号を管理

  @override
  void initState() {
    super.initState();
    AdManager.loadAd(AdType.interstitial);
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text("単語テスト"),
      ),
      body: productsAsync.when(
        // データ読み込み中はプログレスインジケーターを表示
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text("データ読み込みエラー: $error")),
        data: (products) {
          // 初回のデータ到着時にだけ出題内容を確定させる
          final quiz = _quiz ??= generateQuizQuestions(products, products,
              quizCount: widget.quizCount);
          if (quiz.isEmpty) {
            return const Center(child: Text("出題できる単語がありません"));
          }
          final currentQuestion = quiz[currentQuestionIndex];
          return Padding(
            padding: EdgeInsets.all(context.paddingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 問題番号と総問題数の表示
                Text(
                  "問題 ${currentQuestionIndex + 1} / ${quiz.length}",
                  style: TextStyle(
                      fontSize: context.fontSizeExtraLarge,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                // 問題（単語の説明）の表示
                Text(
                  currentQuestion.product.description,
                  style: TextStyle(fontSize: context.fontSizeMedium),
                ),
                const SizedBox(height: 24),
                // 選択肢ボタン群：ユーザー選択後、正解・不正解の色分けを反映
                ...currentQuestion.options.map((option) {
                  Color? btnColor;
                  if (currentQuestion.userAnswer != null) {
                    if (option == currentQuestion.product.name) {
                      btnColor = Colors.green;
                    } else if (option == currentQuestion.userAnswer) {
                      btnColor = Colors.red;
                    }
                  }
                  return Container(
                    margin:
                        EdgeInsets.symmetric(vertical: context.paddingSmall),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: btnColor,
                      ),
                      onPressed: currentQuestion.userAnswer == null
                          ? () async {
                              setState(() {
                                currentQuestion.userAnswer = option;
                              });
                              // 正解でない場合、ミス回数もインクリメント
                              if (!currentQuestion.isCorrect) {
                                ref
                                    .read(mistakeCountsProvider.notifier)
                                    .increment(currentQuestion.product.name);
                              }
                              // 1秒後に次の問題または結果画面へ遷移
                              await Future.delayed(const Duration(seconds: 1));
                              if (currentQuestionIndex < quiz.length - 1) {
                                setState(() {
                                  currentQuestionIndex++;
                                });
                              } else {
                                if (!context.mounted) return;
                                AdManager.showInterstitialAd(onComplete: () {
                                  if (!context.mounted) return;
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            WordTestResultPage(quiz: quiz)),
                                  );
                                });
                              }
                            }
                          : null,
                      child: Text(
                        option,
                        style: TextStyle(fontSize: context.fontSizeMedium),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                // ユーザーの回答に応じたフィードバック表示
                if (currentQuestion.userAnswer != null)
                  Text(
                    currentQuestion.isCorrect
                        ? "正解！"
                        : "不正解。正解は ${currentQuestion.product.name} です。",
                    style: TextStyle(
                      fontSize: context.fontSizeMedium,
                      color:
                          currentQuestion.isCorrect ? Colors.green : Colors.red,
                    ),
                    textAlign: TextAlign.center,
                  ),
                const Spacer(),
              ],
            ),
          );
        },
      ),
    );
  }
}
