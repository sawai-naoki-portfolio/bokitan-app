# Google Play リリース手順

対象アプリ: 簿記単 (`com.bokitan.bookkeeping_vocabulary_notebook`)

---

## 1. 事前に用意するファイル（すべて Git 管理外）

| ファイル | 内容 | 雛形 | 無い場合の挙動 |
| --- | --- | --- | --- |
| `android/key.properties` | アップロード鍵の情報 | – | **デバッグ署名になり Play にアップロードできない** |
| `android/admob.properties` | AdMob アプリ ID | `android/admob.properties.example` | テスト広告になる（収益ゼロ） |
| `dart_defines.json` | AdMob 広告ユニット ID | `dart_defines.example.json` | テスト広告になる（収益ゼロ） |

`android/key.properties` の書式:

```properties
storePassword=<キーストアのパスワード>
keyPassword=<鍵のパスワード>
keyAlias=<エイリアス>
storeFile=<キーストア(.jks)への絶対パス、または android/ からの相対パス>
```

> **重要**
> 既に Play で公開済みのアプリを更新するには、**初回リリース時と同じアップロード鍵**が必要です。
> 新しく作った鍵では既存アプリの更新として受け付けられません。
> 鍵を紛失した場合は、Play Console の「アプリの整合性 > アプリの署名」からアップロード鍵のリセットを Google に申請してください
> （Play アプリ署名を有効にしている場合のみ可能）。

---

## 2. バージョンを上げる

`pubspec.yaml` の `version:` を更新します。`+` の後ろ（versionCode）は
**Play にアップロード済みの最大値より大きい整数**にする必要があります。

```yaml
version: 1.1.0+14   # 1.1.0 = 表示用 / 14 = versionCode
```

| リリース | versionName | versionCode |
| --- | --- | --- |
| 公開済み | 1.0.0 | 13 |
| 次回 | 1.1.0 | 14 |

---

## 3. ビルド

```bash
flutter clean
flutter pub get
flutter test
flutter analyze
flutter build appbundle --release --dart-define-from-file=dart_defines.json
```

出力先: `build/app/outputs/bundle/release/app-release.aab`

`--dart-define-from-file` を付け忘れるとテスト広告のまま公開され、収益が発生しません。
付け忘れた場合はビルドログとアプリ起動時に警告が出ます。

### 署名できているかの確認（アップロード前に必須）

```bash
# keytool は PATH に無いため、Android Studio 同梱の JDK を使う
"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" \
  -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
```

所有者が `CN=Android Debug` と表示された場合は**デバッグ署名**です。
`android/key.properties` が読み込まれていないので、アップロードせずに設定を見直してください。
正しく設定されていれば、自分のキーストアの所有者情報が表示されます。

---

## 4. Play Console で申告する内容

### データセーフティ（データの安全性）

本アプリは AdMob を利用しているため、以下の申告が必要です。

| 項目 | 申告内容 |
| --- | --- |
| 収集するデータ | **アプリのアクティビティ / デバイス ID** |
| 具体的には | 広告 ID（AAID）、おおよその位置情報、端末情報 ※すべて Google AdMob SDK による収集 |
| 目的 | 広告またはマーケティング |
| 第三者との共有 | あり（Google AdMob） |
| データの暗号化 | 転送時に暗号化される（はい） |
| データ削除のリクエスト | 可能（アプリ内「設定 > キャッシュクリア」で端末内データを削除可能） |
| ユーザーが作成したデータ | メモ・マイリスト・学習スケジュールは**端末内にのみ保存**され、サーバーへ送信されない（＝収集していない） |

### 広告 ID の宣言

マニフェストに `com.google.android.gms.permission.AD_ID` が含まれます（AdMob SDK が付与）。
Play Console の「広告 ID」の申告で **「使用する」** を選択してください。

### 広告の有無

「アプリに広告が含まれますか？」→ **はい**

### プライバシーポリシー URL

Play Console には、Web で公開したプライバシーポリシーの URL を登録します。
アップロード前に URL が実際に開けることを必ず確認してください。

※ プライバシーポリシーの Web ページ、`app-ads.txt` とそのデプロイ設定は、実際の販売者 ID を含むため
公開版リポジトリには含めていません。アプリ内に同梱する本文は `assets/privacypolicy.txt` です。

### app-ads.txt

AdMob 管理画面の「アプリ > app-ads.txt」で、デベロッパーサイトの URL が正しく設定されていること、
その URL 直下の `app-ads.txt` が開けることを確認してください。

---

## 5. リリース前チェックリスト

- [ ] `android/key.properties` を配置し、**アップロード鍵で署名**されていることを確認した
- [ ] `android/admob.properties` と `dart_defines.json` を配置した
- [ ] `pubspec.yaml` の versionCode を 13 より大きい値に上げた
- [ ] `flutter test` / `flutter analyze` が通る
- [ ] 実機で動作確認した（特にダークモード、仕訳クイズ、スケジュール、ニュース閲覧）
- [ ] **targetSdk が Play の要件を満たしているか確認した**（下記の注意を参照）
- [ ] プライバシーポリシー URL が公開されていて開ける
- [ ] データセーフティの申告を上表の内容で更新した
- [ ] 内部テストトラックで先に配信し、広告が本番 ID で表示されることを確認した

---

## 6. ビルド環境について

`flutter build appbundle` は、生成した AAB からネイティブライブラリのデバッグシンボルが
除去されているかを `apkanalyzer` で検証します。このツールは Android SDK の
**cmdline-tools** に含まれており、未インストールだと検証に失敗して
`Release app bundle failed to strip debug symbols from native libraries.`
というエラーでビルドが止まります（ビルド自体は成功しています）。

インストール状況は `flutter doctor` で確認できます。不足している場合は
Android Studio の SDK Manager > SDK Tools > 「Android SDK Command-line Tools」から導入してください。

現在のツールチェーン:

| 項目 | バージョン |
| --- | --- |
| Gradle | 8.14.3 |
| Android Gradle Plugin | 8.11.1 |
| Kotlin | 2.2.20 |
| compileSdk | 36（Flutter 既定） |
| targetSdk | 36 |
| minSdk | 24（Flutter 既定） |

---

## 7. 注意事項

### targetSdk について

現在の設定は `targetSdk = 36`（Android 16）です。
Google Play は「最新の Android メジャーリリースから約 1 年」を target API の下限としており、
2026 年 8 月 31 日以降の新規アプリ・アップデートは API 36 以上が必要です。
要件は毎年上がるため、アップロード前に Play Console の警告、または
[Target API level requirements](https://developer.android.com/google/play/requirements/target-sdk)
で現在の要件を確認してください。

API 36 では次の挙動が強制されるため、**実機（Android 16）で確認してから公開してください**。

- **エッジツーエッジ表示**: システムバーの裏までコンテンツが描画される。
  本アプリは API 35 の時点でオプトアウトしていないため既に有効だが、念のため各画面で
  ステータスバー・ナビゲーションバーと UI が重なっていないかを見る。
- **予測型「戻る」ジェスチャー**: 戻る操作のアニメーションが既定で有効になる。
  ダイアログ・ボトムシート・WebView（ニュース記事）で戻る操作が期待どおり動くかを見る。
- **大画面での向き・サイズ制限の無視**: 幅 600dp 以上のタブレット等では
  画面の向き・リサイズの制限が無視される。

### iOS について

`ios/Runner/Info.plist` の `GADApplicationIdentifier` は Google のテスト用アプリ ID のままです。
App Store へ出す場合は、AdMob で iOS 用アプリを作成して差し替え、
`dart_defines.json` の `ADMOB_IOS_*` も本番の広告ユニット ID に更新してください。
