// ============================================================================
// SortingProblem
// -----------------------------------------------------------------------------
// SortingProblem クラスは、仕訳問題の 1 件を表現します。
// ・id: 問題の識別子
// ・level: 難易度（例: "簿記3級" / "簿記2級"）
// ・transactionDate: 仕訳伝票の日付（文字列）
// ・description: 仕訳伝票の説明（問題文）
// ・entries: この問題に対する正解の仕訳エントリー（JournalEntry のリスト）
// ・feedback: 解説（テキスト）
// ・bookkeepingType: 関連する簿記の種別（例: "商業簿記" / "工業簿記"）
//
// JSON から SortingProblem インスタンスを生成するファクトリも提供します。
// ============================================================================
import 'journal_entry.dart';

class SortingProblem {
  final String id;
  final String level;
  final String transactionDate;
  final String description;
  final List<JournalEntry> entries;
  final String feedback;
  final String bookkeepingType;

  SortingProblem({
    required this.id,
    required this.level,
    required this.transactionDate,
    required this.description,
    required this.entries,
    required this.feedback,
    required this.bookkeepingType,
  });

  /// 出題フィルターで使う「簿記3級-商業簿記」形式のキー
  String get filterKey => '$level-$bookkeepingType';

  /// 借方のエントリー
  List<JournalEntry> get debitEntries =>
      entries.where((e) => e.side == JournalEntry.debit).toList();

  /// 貸方のエントリー
  List<JournalEntry> get creditEntries =>
      entries.where((e) => e.side == JournalEntry.credit).toList();

  // JSON の Map から SortingProblem インスタンスへ変換
  factory SortingProblem.fromJson(Map<String, dynamic> json) {
    final entriesJson = json['entries'] as List;
    return SortingProblem(
      id: json['id'] as String,
      level: json['level'] as String,
      transactionDate: json['transaction_date'] as String,
      description: json['description'] as String,
      entries: entriesJson
          .map((e) => JournalEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      feedback: json['feedback'] as String,
      bookkeepingType: json['bookkeepingType'] as String,
    );
  }
}
