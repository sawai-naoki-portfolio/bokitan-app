# テスト報告書

`test/` 配下の自動テストの内容と、実行結果を記録します。

## 1. 実行結果

| 項目 | 結果 |
| --- | --- |
| 実行日 | 2026-10-25 |
| 実行環境 | Linux コンテナ / Flutter 3.47.8（stable）/ Dart 3.13.7 |
| 対象コミット | `af18ff7`（master の先頭。本報告書の追加前） |
| `flutter test` | **34 件すべて成功**（失敗 0、スキップ 0） |
| `flutter analyze` | **No issues found!** |
| 公開版での再実行 | 2026-10-26 / Linux コンテナ / Flutter 3.47.8（stable）。公開版（履歴なし移植）の作業ツリーで `flutter pub get` → `flutter analyze`（No issues found）→ `flutter test`（**34 件すべて成功**）。移植元 master（`7f1fd07`）と同一のソースで、件数は上記と一致 |
| 再実行 | Windows / macOS / Linux のプラットフォームフォルダを削除した後（`f4a6cbf` に変更を加えた状態）にも実行し、`flutter test` 34 件成功・`flutter analyze` 指摘 0 |

補足:

- 実行時の `flutter pub get` で、SDK 側に合わせて推移的依存 4 件のバージョンが `pubspec.lock` と異なって解決されました（直接依存は変わらず）。報告書の作成にあたり `pubspec.lock` は変更していません。
- 「壊れた保存データがあっても空のリストとして起動できる」のテストでは、意図的に壊した JSON に対する復元失敗のログ（`リストの復元に失敗しました: FormatException`）が出力されます。テスト自体は成功です。
- 実機・エミュレーターでの手動テストは、この報告書の範囲では実施していません（広告・ニュース・共有・WebView は自動テストの対象外）。

再実行の手順:

```bash
flutter pub get
flutter test --reporter expanded
flutter analyze
```

## 2. テストの内訳

| ファイル | 種別 | 件数 | 対象 |
| --- | --- | ---: | --- |
| `test/widget_test.dart` | ウィジェット | 3 | ホーム画面の表示と検索 |
| `test/provider/asset_parsing_test.dart` | ユニット | 5 | アセット JSON → モデルの変換 |
| `test/provider/bundled_data_test.dart` | ユニット（データ検証） | 5 | 同梱の `products.json` / `siwake.json` の整合性 |
| `test/provider/account_options_provider_test.dart` | ユニット | 6 | 仕訳問題の勘定科目の選択肢生成 |
| `test/utility/generate_quiz_questions_test.dart` | ユニット | 5 | 4 択クイズの生成と正誤判定 |
| `test/utility/schedule_item_test.dart` | ユニット | 3 | スケジュールの JSON 変換・`copyWith` |
| `test/notifier/persisted_notifiers_test.dart` | ユニット | 7 | 永続化 Notifier の読み込み競合・重複拒否・破損データ |
| **合計** | | **34** | |

## 3. テストケース一覧

### ホーム画面（`widget_test.dart`）

| # | テスト名 | 関連要件 |
| --- | --- | --- |
| 1 | ホーム画面が表示され、単語の一覧が並ぶ | FR-02 |
| 2 | 検索語を入力すると一致する単語だけが残る | FR-01 |
| 3 | 一致しない検索語では該当なしの案内を出す | FR-01 |

### アセットのパース（`asset_parsing_test.dart`）

| # | テスト名 |
| --- | --- |
| 4 | parseProducts: JSON から Product を組み立てる |
| 5 | parseProducts: yomigana と category が無くても既定値で復元できる |
| 6 | parseSortingProblems: JSON から SortingProblem を組み立てる |
| 7 | parseSortingProblems: 借方・貸方が正しく振り分けられる |
| 8 | parseSortingProblems: filterKey は「級-種別」の形式になる |

### 同梱データの整合性（`bundled_data_test.dart`）

実際に配布する `assets/` の JSON を読み込んで検証します。2026-10 にこのテストを追加した際、貸借が一致せず正しく答えても不正解になる問題など、仕訳データの誤りを見つけて修正しました。

| # | テスト名 |
| --- | --- |
| 9 | assets/siwake.json: 問題 ID が重複していない |
| 10 | assets/siwake.json: すべての問題で借方合計と貸方合計が一致する |
| 11 | assets/siwake.json: 仕訳は借方・貸方の両方を持ち、金額は正の数 |
| 12 | assets/siwake.json: 出題範囲フィルターのいずれかに属する |
| 13 | assets/products.json: 単語名が空でなく、重複していない |

### 勘定科目の選択肢（`account_options_provider_test.dart`）

| # | テスト名 | 関連要件 |
| --- | --- | --- |
| 14 | 正解の勘定科目は必ず選択肢に含まれる | FR-25 |
| 15 | 誤答候補が混ざり、最低件数まで水増しされる | FR-25 |
| 16 | 選択肢はソートされ、正解の位置から答えを推測できない | FR-25 |
| 17 | 選択肢に重複はない | FR-25 |
| 18 | マスタが空でも正解だけは返す（クイズが壊れない） | FR-25 |
| 19 | マスタが最低件数に満たない場合は集まった分だけ返す | FR-25 |

### 4 択クイズの生成（`generate_quiz_questions_test.dart`）

| # | テスト名 | 関連要件 |
| --- | --- | --- |
| 20 | 指定した問題数だけ生成される | FR-20 |
| 21 | 出題数が母数を超える場合は母数までしか生成しない | FR-21 |
| 22 | 各問題は4択で、正解が必ず選択肢に含まれる | FR-20 |
| 23 | 誤答候補が足りない場合でも4択になる | FR-20 |
| 24 | 未回答なら isCorrect は false、正解を選ぶと true になる | FR-20 |

### スケジュール（`schedule_item_test.dart`）

| # | テスト名 | 関連要件 |
| --- | --- | --- |
| 25 | toJson / fromJson で内容が保たれる | FR-31 |
| 26 | 古い形式（isExamDate なし）でも復元できる | FR-30 |
| 27 | copyWith は指定した項目だけを差し替える | FR-33 |

### 永続化 Notifier（`persisted_notifiers_test.dart`）

| # | テスト名 | 確認していること |
| --- | --- | --- |
| 28 | 読み込み完了前の更新 / SavedItemsNotifier: 保存済みの単語に追加される | 起動直後の操作で保存済みデータが消えない |
| 29 | 読み込み完了前の更新 / CheckedQuestionsNotifier: 保存済みのチェックが消えない | 同上 |
| 30 | 読み込み完了前の更新 / ThemeNotifier: 変更したテーマが読み込み結果で巻き戻らない | 同上 |
| 31 | CategoriesNotifier: 既存のリスト名には変更できない | FR-10 |
| 32 | CategoriesNotifier: 重複しない名前には変更でき、所属単語は引き継がれる | FR-10 |
| 33 | CategoriesNotifier: 壊れた保存データがあっても空のリストとして起動できる | 破損データの読み飛ばし |
| 34 | CustomProductsNotifier: 同じ名前のカスタム単語は追加されない | FR-13 |

## 4. 自動テストの対象外

次は自動テストを書いていません。確認する場合は実機で行う必要があります。

| 対象 | 理由 |
| --- | --- |
| AdMob 広告の表示・表示間隔 | 広告 SDK がテスト環境で動かない |
| 簿記ニュースの取得・WebView | 外部通信と WebView に依存する |
| 画像共有・アプリ再起動（キャッシュクリア後） | OS の共有シート・`Phoenix.rebirth` に依存する |
| 仕訳問題の採点 UI、スケジュール画面 | ウィジェットテスト未作成（採点ロジックはクイズ画面のウィジェット内にある） |
