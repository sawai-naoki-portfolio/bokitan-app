# 5. 広告・外部連携設計

[目次へ戻る](README.md)

## 5.1 広告の種類と表示箇所

広告は Google AdMob（`google_mobile_ads`）で配信し、`lib/ads/ad_manager.dart` の `AdManager` がすべての読み込みと表示を担います。
広告 SDK が動くのは Android と iOS だけで、それ以外（Web・デスクトップ）では何もしません（`AdManager.isSupported`）。

| 種類 | 表示する場面 | 表示間隔の上限 | 先読み |
| --- | --- | --- | --- |
| バナー | 単語検索（ホーム）の画面下部 | なし | 表示するウィジェット（`BannerAdView`）ごとに読み込む |
| インタースティシャル | 単語テスト・チェック問題テスト・仕訳テストの終了時、ニュース記事を開くとき、キャッシュクリアの実行時 | 前回表示から 3 分 | 起動時、各画面を開いたとき、広告を閉じた直後 |
| リワード | テスト結果画面の「もう一度」（単語テスト・仕訳問題） | なし（ユーザーの操作でのみ表示） | 起動時と、広告を閉じた直後 |
| App Open | 起動時（読み込みが 5 秒以内に終わった場合）と、アプリが前面に戻ったとき | 前回表示から 2 時間。初回起動では表示しない | 起動時と、前面に戻ったとき |

設計上の方針:

- **広告が無くても機能を止めない。** 未読み込み・読み込み失敗・表示失敗のときは、広告を出さずにすぐ次の処理（画面遷移や再挑戦）へ進みます。
- **全画面広告を連続させない。** 全画面広告の表示中と、閉じてから 2 秒間は App Open 広告を出しません（広告を閉じるとアプリが「前面に戻った」扱いになるため）。
- **表示時刻は端末に保存する。** 上限の判定に使う最終表示時刻は SharedPreferences（`last_interstitial_ad` / `last_app_open_ad`）に保存し、アプリを再起動しても間隔を守ります。

## 5.2 広告ユニット ID の決定

```mermaid
flowchart TD
    start([広告ユニット ID が必要]) --> supported{"Android / iOS?"}
    supported -->|いいえ| none["広告を扱わない"]
    supported -->|はい| release{"リリースビルド?"}
    release -->|いいえ| test["Google のテスト用 ID<br/>（TestAdUnitIds）"]
    release -->|はい| platform{"iOS?"}
    platform -->|はい| ios["AdConfig.ios*"]
    platform -->|いいえ| android["AdConfig.android*"]
    ios --> define{"ビルド時に --dart-define で<br/>ID を注入した?"}
    android --> define
    define -->|はい| prod["注入した本番 ID"]
    define -->|いいえ| fallback["テスト用 ID<br/>（起動時に警告ログ）"]
```

| 設定 | 渡し方 | ファイル（Git 管理外） |
| --- | --- | --- |
| 広告ユニット ID（8 種類） | `flutter build ... --dart-define-from-file=dart_defines.json` | `dart_defines.json`（雛形: `dart_defines.example.json`） |
| AdMob アプリ ID（Android） | `android/app/build.gradle` が読み、`AndroidManifest.xml` の `${admobAppId}` に差し込む | `android/admob.properties`（雛形: `android/admob.properties.example`） |
| AdMob アプリ ID（iOS） | `ios/Runner/Info.plist` の `GADApplicationIdentifier` | 現在はテスト用 ID のまま |

## 5.3 App Open 広告の状態遷移

```mermaid
stateDiagram-v2
    [*] --> 未読み込み

    未読み込み --> 読み込み中 : 起動時 / 前面に戻った（表示間隔の上限を過ぎている）
    未読み込み --> 未読み込み : 初回起動（起点の時刻だけ記録）/ 上限内

    読み込み中 --> 表示中 : 読み込み完了（起動から 5 秒以内）
    読み込み中 --> 読み込み済み : 読み込み完了（起動から 5 秒以降）
    読み込み中 --> 未読み込み : 読み込み失敗

    読み込み済み --> 表示中 : 前面に戻った（全画面広告の表示中・直後でない、上限を過ぎている）
    読み込み済み --> 未読み込み : 読み込みから 4 時間経過（期限切れ）

    表示中 --> 未読み込み : 閉じた / 表示失敗（最終表示時刻を保存）
```

## 5.4 インタースティシャル広告の表示

```mermaid
sequenceDiagram
    autonumber
    participant S as 画面（テスト・ニュース等）
    participant Ad as AdManager
    participant SP as SharedPreferences
    participant SDK as InterstitialAd

    S->>Ad: showInterstitialAd(onComplete)
    alt 非対応プラットフォーム / 未読み込み
        Ad->>S: onComplete()（すぐに次へ進む）
    else 読み込み済み
        Ad->>SP: last_interstitial_ad を取得
        alt 前回表示から 3 分以内
            Ad->>S: onComplete()
        else 3 分以上経過
            Ad->>SP: last_interstitial_ad = 現在時刻
            Ad->>SDK: show()
            SDK-->>Ad: 閉じた / 表示失敗
            Ad->>S: onComplete()
            Ad->>Ad: 次の広告を読み込む
        end
    end
```

## 5.5 簿記ニュース

### 記事一覧の取得

```mermaid
sequenceDiagram
    autonumber
    actor U as 学習者
    participant P as BokikiNewsPage
    participant NP as newsArticlesProvider(検索語)
    participant RSS as Google ニュース RSS
    participant OG as ogImageProvider(記事 URL)
    participant Site as 記事サイト

    U->>P: タブを選ぶ
    P->>NP: watch(検索語)
    NP->>RSS: GET /rss/search?q=検索語&hl=ja&gl=JP&ceid=JP:ja（10 秒でタイムアウト）
    RSS-->>NP: RSS（XML）
    NP->>NP: item ごとに title / link / pubDate / source / media:thumbnail を取り出す
    NP->>NP: link が http(s) の記事だけ残す
    NP->>NP: シャッフルして 15 件に絞る
    NP-->>P: List<Article>
    loop サムネイルが無い記事
        P->>OG: watch(記事 URL)
        OG->>Site: GET 記事 URL（3 秒でタイムアウト）
        Site-->>OG: HTML
        OG->>OG: 先頭 200,000 文字から og:image を正規表現で抽出（http(s) のみ）
        OG-->>P: 画像 URL または null
    end
```

| 状況 | 動作 |
| --- | --- |
| HTTP ステータスが 200 以外・通信エラー・タイムアウト | エラー文と「再読み込み」ボタンを表示（Riverpod 3 の既定で自動再試行もされる） |
| 引っ張って更新 / 再読み込み | `ref.invalidate(newsArticlesProvider(検索語))` で取得し直す |
| `og:image` の取得失敗 | 例外を外に出さず `null`（サムネイルなし）として扱う |

### 記事の閲覧（WebView）

```mermaid
flowchart TD
    tap([記事をタップ]) --> ad["インタースティシャル広告（上限あり）"]
    ad --> open["NewsWebViewPage を開く"]
    open --> scheme{"URL のスキームが<br/>http / https?"}
    scheme -->|いいえ| blocked["「この記事のURLは開けません。」<br/>（読み込まない）"]
    scheme -->|はい| load["WebView で読み込む<br/>（JavaScript 有効）"]
    load --> nav{"ページ内の遷移先が<br/>http / https?"}
    nav -->|いいえ| prevent["遷移を拒否"]
    nav -->|はい| navigate["遷移する（タイトル下のドメイン表示を更新）"]
    load --> perm["カメラ・マイク・位置情報の要求 → 常に拒否<br/>メディアの自動再生 → しない"]
    load --> err{"メインフレームの<br/>読み込み失敗?"}
    err -->|はい| msg["「記事を読み込めませんでした。」と<br/>「ブラウザで開く」ボタン"]
    blocked --> browser["「ブラウザで開く」で外部ブラウザへ"]
    msg --> browser
```

## 5.6 外部リンク

| 機能 | 開く先 | 開き方 | 失敗時 |
| --- | --- | --- | --- |
| フィードバック（SC-58） | Google フォーム（`https://forms.gle/…`） | `url_launcher`（外部アプリ） | 「フィードバックフォームを開けませんでした」 |
| 仕訳問題の問い合わせ（SC-25 / SC-28） | Google フォーム | 問題 ID をコピーしてからでないとボタンが押せない（どの問題か特定するため） | 同上 |
| 記事をブラウザで開く（SC-41） | 記事 URL | `url_launcher`（外部アプリ） | 「ブラウザを開けませんでした」 |
| 単語カードの共有（SC-03） | 端末の共有シート | `share_plus` | 「画像のキャプチャ/共有に失敗しました」 |

## 5.7 Web 公開物

プライバシーポリシーの Web ページと `app-ads.txt`（AdMob の認定販売者の宣言）は、アプリとは別に静的ファイルとして Web 上で公開しています。
実際の販売者 ID を含むため、これらのファイルとデプロイ設定は本リポジトリ（公開版）に含めていません。
アプリ内に同梱するプライバシーポリシーの本文は `assets/privacypolicy.txt` です。
