# 4. 処理設計

[目次へ戻る](README.md)

主要な処理の流れを、シーケンス図・アクティビティ図（フローチャート）・状態遷移図で示します。

## 4.1 単語検索

```mermaid
sequenceDiagram
    autonumber
    actor U as 学習者
    participant P as SearchPage
    participant Q as searchQueryProvider
    participant L as _SearchResultList
    participant H as SearchHistoryNotifier
    participant D as 単語詳細ダイアログ

    U->>P: 検索欄に入力
    alt 入力が空になった
        P->>Q: state = ''（即時）
    else 文字が入力された
        P->>P: 250ms のタイマーを再設定（デバウンス）
        P->>Q: 250ms 入力が止まったら state = 入力文字列
    end
    Q-->>L: 変更を通知
    alt 検索語が空
        L->>L: randomProductsProvider のおすすめ 15 件を表示
    else 検索語あり
        L->>L: 収録単語＋カスタム単語から、名前または読みガナに<br/>検索語を含むもの（小文字化して部分一致）を表示
    end
    U->>L: 単語をタップ
    L->>H: addProduct(単語名)
    H->>H: 重複を除いて先頭に追加し、15 件に切り詰めて保存
    L->>D: showProductDialog(単語)
```

## 4.2 4 択クイズの生成

`generateQuizQuestions(quizPool, distractorPool, quizCount)`（`lib/utility/generate_quiz_questions.dart`）は、
単語テストとチェック問題テストで共通に使う、UI に依存しない関数です。

| 引数 | 単語テスト | チェック問題テスト |
| --- | --- | --- |
| `quizPool`（出題対象） | 収録単語すべて | 収録単語のうちチェック問題に登録したもの |
| `distractorPool`（誤答候補） | 収録単語すべて | 収録単語すべて |
| `quizCount` | 10（リワード獲得で＋10） | 10 |

```mermaid
flowchart TD
    start([開始]) --> shuffle["quizPool をシャッフルし、<br/>先頭から min(quizCount, 件数) 件を出題対象にする"]
    shuffle --> names["distractorPool の単語名一覧を作る（1 回だけ）"]
    names --> loop{"出題対象の<br/>単語が残っている?"}
    loop -->|はい| init["選択肢の集合 = { 正解の単語名 }"]
    init --> enough{"誤答候補が<br/>2 件以上ある?"}
    enough -->|はい| pick["候補から無作為に 1 件追加<br/>（集合なので重複は自動で除かれる）"]
    pick --> four{"4 件になった、または<br/>試行回数が 候補数×3 に達した?"}
    four -->|いいえ| pick
    four -->|はい| fill
    enough -->|いいえ| fill{"4 件未満?"}
    fill -->|はい| dummy["「選択肢なしN」で埋める"]
    dummy --> fill
    fill -->|いいえ| make["選択肢をシャッフルして<br/>WordTestQuestion を作る"]
    make --> loop
    loop -->|いいえ| done([問題リストを返す])
```

性質（`test/utility/generate_quiz_questions_test.dart` で検証）:

- 問題数は `min(quizCount, quizPool の件数)`
- 各問題の選択肢はちょうど 4 件で重複がなく、正解を必ず含む
- 誤答候補が足りなくても 4 択になる（ダミーで埋める）

## 4.3 単語テストの進行

`WordTestPage`（チェック問題テストの `CheckboxTestPage` も同じ流れ）の状態遷移です。

```mermaid
stateDiagram-v2
    [*] --> 読み込み中
    読み込み中 --> 出題不可 : 出題できる単語が 0 件
    読み込み中 --> 未回答 : 問題を生成（以降は固定）

    未回答 --> 回答済み : 選択肢をタップ
    note right of 回答済み
        正解を緑・誤答を赤で表示
        不正解ならミス回数を +1
    end note
    回答済み --> 未回答 : 1 秒後（次の問題がある）
    回答済み --> 広告表示 : 1 秒後（最終問題）
    広告表示 --> 結果画面 : 広告を閉じた / 広告なし
    結果画面 --> [*] : ホームに戻る
    結果画面 --> 読み込み中 : もう一度（画面を置き換えて再開）
    出題不可 --> [*]
```

- 出題内容は、データが届いた最初の描画で 1 度だけ生成し（`_quiz ??= …`）、再描画では作り直しません。
- 画面を開いたときにインタースティシャル広告を先読みします（`AdManager.loadAd(AdType.interstitial)`）。

## 4.4 仕訳問題の出題

```mermaid
flowchart TD
    start([仕訳テスト画面を開く]) --> watch["sortingProblemsProvider と<br/>journalQuizFilterProvider を watch"]
    watch --> loaded{"問題データの<br/>読み込み完了?"}
    loaded -->|いいえ| wait["読み込み中を表示"] --> loaded
    loaded -->|はい| first{"出題内容は<br/>確定済み?"}
    first -->|はい| show
    first -->|いいえ| filter["filterKey が出題範囲に含まれる問題に絞る"]
    filter --> shuffle["シャッフルして先頭から quizCount 件（既定 10）"]
    shuffle --> empty{"0 件?"}
    empty -->|はい| none["「選択された条件に一致する問題はありません」"]
    empty -->|いいえ| show["現在の問題を表示"]
    show --> choices["解答欄を作る<br/>（借方・貸方とも正解の行数ぶん）"]
    choices --> build["buildAccountChoices で勘定科目の選択肢を作る"]
```

`buildAccountChoices(correctAccounts, master, minOptions = 10)`（`lib/provider/account_options_provider.dart`）:

1. 正解の勘定科目を集合に入れる（重複は除く）
2. 勘定科目マスタ（`accountOptionsProvider`: 全問題の勘定科目、165 種類）から正解以外を取り出してシャッフルする
3. 集合が `minOptions` 件になるまで誤答候補を追加する（マスタが足りなければ集まった分だけ）
4. 五十音（文字コード順）に並べて返す

並び順で正解が推測できないよう、正解と誤答を混ぜたうえでソートしています。
正解の科目しか並ばないと消去法で解けてしまうため、誤答候補を必ず混ぜます。

## 4.5 仕訳問題の採点

`JournalEntryQuizWidget._submitAnswer` の処理です。

```mermaid
flowchart TD
    submit([回答を提出]) --> collectD["借方の入力を集める"]
    collectD --> checkD{"科目・金額が<br/>すべて入力済み?"}
    checkD -->|いいえ| errD["「借方のすべての項目を入力してください」"] --> stop([採点しない])
    checkD -->|はい| numD{"金額がカンマを除いて<br/>整数に変換できる?"}
    numD -->|いいえ| errN["「借方：金額は数字で入力してください」"] --> stop
    numD -->|はい| collectC["貸方の入力を同様に集める・検証する"]
    collectC --> compare["借方・貸方それぞれで _isSameEntries を判定"]
    compare --> result{"両方とも一致?"}
    result -->|はい| ok["正解"]
    result -->|いいえ| ng["不正解"]
    ok --> lock["入力欄をロックし、結果を親画面へ通知（onSubmitted）"]
    ng --> lock
```

`_isSameEntries(ユーザーの入力, 正解)` は**並び順を問わない完全一致**です。

1. 行数が異なれば不一致
2. ユーザーの各行について、正解の残りから「科目と金額が両方一致する行」を探し、見つかれば取り除く。見つからなければ不一致
3. 最後に正解の残りが空なら一致

## 4.6 再挑戦とリワード広告

テスト結果画面の「もう一度」の処理です（単語テストと仕訳問題で共通の考え方）。

```mermaid
sequenceDiagram
    autonumber
    actor U as 学習者
    participant R as 結果画面
    participant Ad as AdManager
    participant SDK as RewardedAd

    U->>R: 「もう一度」をタップ
    R->>Ad: showRewardedAd(onUserEarned, onAdClosedWithoutReward)
    alt リワード広告を読み込み済み
        Ad->>SDK: show()
        SDK-->>U: 広告を表示
        opt 最後まで視聴した
            SDK-->>Ad: onUserEarnedReward
            Ad->>R: onUserEarned()
            R->>U: 「報酬ゲット！問題数が＋N問増量されました！」
            R->>R: 問題数 + N でテスト画面に置き換え
        end
        SDK-->>Ad: 広告を閉じた
        Ad->>Ad: 次のリワード広告を読み込む
        Ad->>R: 報酬なしなら onAdClosedWithoutReward()
        R->>R: 同じ問題数でテスト画面に置き換え
    else 未読み込み・表示失敗
        Ad->>R: onAdClosedWithoutReward()
        R->>R: 同じ問題数でテスト画面に置き換え
    end
```

| テスト | 増える問題数 N | 広告 |
| --- | --- | --- |
| 単語テスト | ＋10 問 | リワード広告 |
| 仕訳問題 | ＋5 問 | リワード広告 |
| チェック問題テスト | — | 広告なしで同じ条件で再挑戦 |

## 4.7 スケジュール

### 予定の状態遷移

```mermaid
stateDiagram-v2
    [*] --> 未完了 : 追加（SC-31 で保存）
    未完了 --> 完了 : 長押し →「完了とする」
    完了 --> 未完了 : 長押し →「未完了に戻す」
    未完了 --> [*] : 削除
    完了 --> [*] : 削除

    state 未完了 {
        [*] --> 判定
        判定 --> 過去 : 開始日 < 今日
        判定 --> 本日 : 開始日 = 今日
        判定 --> 未来 : 開始日 > 今日
    }
```

タスク一覧タブでは、未完了の予定を開始日で「過去 / 本日 / 未来」に分け、完了した予定は「完了タスク」にまとめます。

### 予定からタスク行への展開

1 件の `ScheduleItem` を、一覧表示用のタスク行（`_TaskEntry`）に展開します。

| 予定の内容 | 表示するタスク行 |
| --- | --- |
| `tasks` が 1 件以上 | `tasks` の各要素を 1 行ずつ |
| `tasks` が空の勉強予定 | 「勉強予定」1 行 |
| 受験日（`isExamDate = true`） | 上記に加えて「受験日」1 行 |

タスク行の削除:

```mermaid
flowchart TD
    del([タスクを削除]) --> kind{"削除する行は?"}
    kind -->|受験日| examTasks{"予定に tasks がある?"}
    examTasks -->|いいえ| rmAll1["予定ごと削除"]
    examTasks -->|はい| unflag["受験日フラグだけ外す"]
    kind -->|勉強予定| rmAll2["予定ごと削除"]
    kind -->|tasks の 1 件| rmTask["tasks からその名前を取り除いて更新"]
```

### 受験日の制約と残り日数

- 受験日は「今日より後の受験日」が 3 件まで（`_maxExamDates = 3`）。編集中の予定自体は数えない。
- 受験日として保存すると、終了日時は開始の 7 日後、`tasks` は空になります。
- 残り日数は `startTime.difference(現在時刻).inDays + 1` です（[既知の課題 #1](01_architecture.md#110-既知の課題)）。
- スケジュール管理画面の上部の受験日カードには、今後の受験日を日付順に最大 3 件表示します。

## 4.8 キャッシュクリア

```mermaid
sequenceDiagram
    autonumber
    actor U as 学習者
    participant C as CacheClearScreen
    participant Ad as AdManager
    participant SP as SharedPreferences
    participant Ph as Phoenix

    U->>C: 削除する項目を選ぶ（「すべて削除」あり）
    U->>C: 「削除」をタップ
    alt 1 つも選んでいない
        C-->>U: 「削除する項目を選択してください」
    else 選んでいる
        C->>U: 確認ダイアログ（取り消せない旨）
        U->>C: 削除を確定
        C->>Ad: showInterstitialAd(onComplete)
        Ad-->>C: 広告を閉じた / 表示しなかった（表示間隔の上限内・未読み込み）
        loop 選んだ項目
            alt メモ一覧
                C->>SP: memo_ で始まるキーをすべて削除
            else スケジュール
                C->>SP: schedule_items を削除
            else その他
                C->>SP: 項目と同名のキーを削除
            end
        end
        C-->>U: 「キャッシュがクリアされました。再起動します。」（1 秒）
        C->>Ph: Phoenix.rebirth(context)
        Ph->>Ph: ウィジェットツリーと ProviderScope を作り直す
        Note over Ph: 全 Notifier が SharedPreferences から読み直し、<br/>ホーム画面から再開する
    end
```

テーマ・Material 3・出題範囲・広告の表示時刻は削除の対象外です（[3.4](03_data_and_state.md#34-永続化データ設計sharedpreferences)）。

## 4.9 永続化 Notifier の読み込みと更新

起動直後、保存済みデータの読み込みが終わる前にユーザーが操作した場合の動きです（`SavedItemsNotifier` の例）。

```mermaid
sequenceDiagram
    autonumber
    participant UI as 画面
    participant N as SavedItemsNotifier
    participant SP as SharedPreferences

    UI->>N: 生成（最初の watch / read）
    N->>N: state = []（初期値）
    N->>SP: _loaded = 読み込み開始
    UI->>N: saveItem("買掛金")（読み込み完了前）
    N->>N: await _loaded（読み込み完了まで待つ）
    SP-->>N: ["売掛金"]
    N->>N: state = ["売掛金"]
    N->>N: 待ちが解除される
    N->>N: state = ["売掛金", "買掛金"]
    N->>SP: setStringList("saved_items", state)
    N-->>UI: 状態の変更を通知（再描画）
```

読み込みを待たずに更新すると、次のどちらかの不具合が起きます（`test/notifier/persisted_notifiers_test.dart` で回帰を防止）。

- 読み込み前の空の状態を基に保存してしまい、保存済みデータを消す
- 更新した状態を、後から届いた読み込み結果で上書きしてしまう（テーマ変更が元に戻るなど）

## 4.10 単語カードの画像共有

```mermaid
sequenceDiagram
    autonumber
    actor U as 学習者
    participant D as 単語詳細ダイアログ
    participant RB as RepaintBoundary
    participant FS as 一時ディレクトリ
    participant CB as クリップボード
    participant SH as 共有シート

    U->>D: 共有ボタンをタップ
    D->>RB: toImage(端末のピクセル比)
    RB-->>D: ダイアログの画像
    D->>D: PNG に変換
    D->>FS: dialog_<時刻>.png として書き出す
    D->>CB: 「【単語名】説明 #簿記単」をコピー
    D->>SH: 画像ファイルと共有テキストを渡す
    alt 失敗した
        D-->>U: 「画像のキャプチャ/共有に失敗しました」
    end
```

## 4.11 リストへの割り当て

単語の操作メニューの「保存する」で開くボトムシート（SC-06）の処理です。

```mermaid
sequenceDiagram
    autonumber
    actor U as 学習者
    participant S as CategoryAssignmentSheet
    participant C as CategoriesNotifier
    participant V as SavedItemsNotifier

    S->>C: 現在のリスト一覧を読む
    S->>S: 各リストのチェック = その単語が含まれているか<br/>「保存単語一覧」のチェック = ON
    U->>S: チェックを切り替える（この時点では保存しない）
    opt 新規リスト追加
        U->>S: リスト名を入力
        S->>C: addCategory(名前)
    end
    U->>S: 完了
    loop 各リスト
        S->>C: updateProductAssignment(リスト名, 単語名, チェック状態)
    end
    alt 保存単語一覧が ON
        S->>V: saveItem(単語名)
    else OFF
        S->>V: removeItem(単語名)
    end
```

## 4.12 カスタム単語の追加

```mermaid
flowchart TD
    open([単語一覧の＋]) --> dialog["新規単語追加ダイアログ"]
    dialog --> input["単語・読みガナ・説明を入力"]
    input --> empty{"単語が空?"}
    empty -->|はい| err1["「単語を入力してください」"] --> input
    empty -->|いいえ| ret["Product(category = カスタム単語) を返す"]
    ret --> dupe{"収録単語・カスタム単語に<br/>同じ名前がある?"}
    dupe -->|はい| err2["「同じ名前の単語が既に登録されています。」"]
    dupe -->|いいえ| save["CustomProductsNotifier.addProduct で保存"]
    save --> ok["「〇〇を追加しました。」"]
```

`CustomProductsNotifier.addProduct` 自身もカスタム単語同士の重複を確認し、重複時は `false` を返して保存しません。
