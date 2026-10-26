/// ---------------------------------------------------------------------------
/// Product クラス
/// ─ 単語のデータモデル。名前、読みガナ、説明、分類カテゴリを保持します。
/// ---------------------------------------------------------------------------
class Product {
  final String name;
  final String yomigana;
  final String description;
  final String category;

  Product({
    required this.name,
    required this.yomigana,
    required this.description,
    required this.category,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      name: json['name'] as String,
      yomigana: json['yomigana'] as String? ?? "",
      description: json['description'] as String? ?? "",
      category: json['category'] as String? ?? '未分類',
    );
  }

  /// カスタム単語を SharedPreferences に保存するときに使う
  Map<String, dynamic> toJson() => {
        'name': name,
        'yomigana': yomigana,
        'description': description,
        'category': category,
      };
}
