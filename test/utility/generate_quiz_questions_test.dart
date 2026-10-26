import 'dart:math';

import 'package:bookkeeping_vocabulary_notebook/utility/generate_quiz_questions.dart';
import 'package:bookkeeping_vocabulary_notebook/utility/product.dart';
import 'package:flutter_test/flutter_test.dart';

List<Product> _products(int count) => List.generate(
      count,
      (i) => Product(
        name: '単語$i',
        yomigana: 'たんご$i',
        description: '説明$i',
        category: 'カテゴリ',
      ),
    );

void main() {
  group('generateQuizQuestions', () {
    test('指定した問題数だけ生成される', () {
      final pool = _products(30);
      final quiz = generateQuizQuestions(pool, pool,
          quizCount: 10, random: Random(0));

      expect(quiz, hasLength(10));
    });

    test('出題数が母数を超える場合は母数までしか生成しない', () {
      final pool = _products(3);
      final quiz =
          generateQuizQuestions(pool, pool, quizCount: 10, random: Random(0));

      expect(quiz, hasLength(3));
    });

    test('各問題は4択で、正解が必ず選択肢に含まれる', () {
      final pool = _products(30);
      final quiz =
          generateQuizQuestions(pool, pool, quizCount: 10, random: Random(1));

      for (final question in quiz) {
        expect(question.options, hasLength(4));
        expect(question.options, contains(question.product.name));
        // 選択肢に重複がないこと
        expect(question.options.toSet(), hasLength(4));
      }
    });

    test('誤答候補が足りない場合でも4択になる', () {
      final pool = _products(2);
      final quiz =
          generateQuizQuestions(pool, pool, quizCount: 2, random: Random(2));

      for (final question in quiz) {
        expect(question.options, hasLength(4));
        expect(question.options, contains(question.product.name));
      }
    });

    test('未回答なら isCorrect は false、正解を選ぶと true になる', () {
      final pool = _products(10);
      final quiz =
          generateQuizQuestions(pool, pool, quizCount: 1, random: Random(3));
      final question = quiz.single;

      expect(question.isCorrect, isFalse);

      question.userAnswer = question.product.name;
      expect(question.isCorrect, isTrue);
    });
  });
}
