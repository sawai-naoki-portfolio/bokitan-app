// ============================================================================
// JournalEntry
// -----------------------------------------------------------------------------
// JournalEntry クラスは、1 件の仕訳エントリーを表現します。
// ・side: 「借方」または「貸方」
// ・account: 対象となる勘定科目名
// ・amount: 仕訳の金額（整数）
// ============================================================================
class JournalEntry {
  /// 仕訳の側面を表す定数（JSON 中の表記と一致させること）
  static const String debit = '借方';
  static const String credit = '貸方';

  final String side; // 仕訳の側面（"借方" / "貸方"）
  final String account; // 対象の勘定科目
  final int amount; // 金額

  JournalEntry({
    required this.side,
    required this.account,
    required this.amount,
  });

  // JSON 形式の Map から JournalEntry インスタンスへ変換
  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      side: json['side'] as String,
      account: json['account'] as String,
      amount: json['amount'] as int,
    );
  }
}
