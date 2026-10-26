// *****************************************************************************
// AdManager
// -----------------------------------------------------------------------------
// AdMob 広告のロード・表示を一手に引き受けるクラス。
// ・広告ユニット ID はビルドモード（リリース／デバッグ）とプラットフォームで自動切替
// ・インタースティシャル広告には表示間隔のキャップを設けている
// ・App Open 広告は AdMob の推奨に沿い、初回起動では出さず、
//   起動直後（読み込みが間に合った場合のみ）とアプリが前面に戻ったときに表示する
// ・バナーは画面ごとに独立したインスタンスを持つ BannerAdView として提供する
//   （同一の Ad インスタンスを複数の AdWidget に渡すと例外になるため）
// *****************************************************************************

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_config.dart';

/// 使いたい広告の種類
enum AdType {
  appOpen, // アプリ起動時広告（App Open Ad）
  banner, // バナー広告
  rewarded, // リワード広告
  interstitial, // インタースティシャル広告
}

class AdManager {
  AdManager._();

  // ---------------------------------------------------------------------------
  // 広告ユニット ID
  // ---------------------------------------------------------------------------
  // 実際の ID は AdConfig（--dart-define-from-file で注入）が保持している。
  // デバッグビルドでは常にテスト用 ID を使い、誤クリックによるポリシー違反を防ぐ。

  /// 広告 SDK が動作するプラットフォームか（Web / デスクトップでは動作しない）
  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// 本番 ID を使ってよいか（リリースビルドのみ）
  static bool get _useProdIds => kReleaseMode && isSupported;

  static bool get _isIOS => !kIsWeb && Platform.isIOS;

  static String get _appOpenAdUnitId => !_useProdIds
      ? TestAdUnitIds.appOpen
      : (_isIOS ? AdConfig.iosAppOpen : AdConfig.androidAppOpen);

  static String get _bannerAdUnitId => !_useProdIds
      ? TestAdUnitIds.banner
      : (_isIOS ? AdConfig.iosBanner : AdConfig.androidBanner);

  static String get _rewardedAdUnitId => !_useProdIds
      ? TestAdUnitIds.rewarded
      : (_isIOS ? AdConfig.iosRewarded : AdConfig.androidRewarded);

  static String get _interstitialAdUnitId => !_useProdIds
      ? TestAdUnitIds.interstitial
      : (_isIOS ? AdConfig.iosInterstitial : AdConfig.androidInterstitial);

  // ---------------------------------------------------------------------------
  // 保持しているインスタンス
  // ---------------------------------------------------------------------------
  static RewardedAd? _rewardedAd;
  static InterstitialAd? _interstitialAd;
  static AppOpenAd? _appOpenAd;
  static DateTime? _appOpenAdLoadedAt;
  static bool _isLoadingAppOpenAd = false;

  /// インタースティシャルの最短表示間隔。
  /// 記事タップのたびに全画面広告が出るとユーザー体験を損ない、
  /// AdMob のポリシー（過度な広告表示）にも抵触しうるため必ずキャップを掛ける。
  static const _interstitialCapInterval = Duration(minutes: 3);
  static const _interstitialCapKey = 'last_interstitial_ad';

  /// App Open 広告の最短表示間隔
  static const _appOpenCapInterval = Duration(hours: 2);
  static const _appOpenCapKey = 'last_app_open_ad';

  /// 起動時の App Open 広告は、この時間内に読み込めた場合だけ表示する。
  /// 使い始めてから突然全画面広告が割り込むのを防ぐため。
  static const _coldStartShowWindow = Duration(seconds: 5);

  /// 読み込んだ App Open 広告の有効期限（AdMob の仕様で 4 時間を超えると表示できない）
  static const _appOpenAdExpiry = Duration(hours: 4);

  /// 全画面広告を閉じた直後の復帰イベントを無視する時間。
  /// 広告を閉じるとアプリが「前面に戻った」扱いになり、広告が連続してしまうため。
  static const _resumeGuardAfterAd = Duration(seconds: 2);

  static bool _initialized = false;
  static DateTime? _startedAt;

  /// 何らかの全画面広告を表示中か
  static bool _isShowingFullScreenAd = false;
  static DateTime? _lastFullScreenAdClosedAt;

  /// SDK 初期化。main() から一度だけ呼ぶ。
  static Future<void> initialize() async {
    if (!isSupported || _initialized) return;
    _initialized = true;
    _startedAt = DateTime.now();
    if (kReleaseMode && !AdConfig.hasProductionIds) {
      // リリースビルドなのにテスト用 ID のままだと収益が発生しない
      debugPrint('[AdManager] 本番の広告ユニットIDが未設定です。'
          'ビルド時に --dart-define-from-file=dart_defines.json を指定してください。');
    }
    await MobileAds.instance.initialize();
    // アプリが前面に戻ったときに App Open 広告を出す。
    // リスナーは生成時に WidgetsBinding へ登録され、アプリの終了まで有効。
    AppLifecycleListener(onResume: _onAppResumed);
  }

  /// 任意のタイミングで呼ぶだけでOK
  static void loadAd(AdType type) {
    if (!isSupported) return;
    switch (type) {
      case AdType.appOpen:
        _loadAppOpenAd();
      case AdType.banner:
        // バナーは BannerAdView が各画面で自前にロードするため、ここでは何もしない。
        break;
      case AdType.rewarded:
        _loadRewardedAd();
      case AdType.interstitial:
        _loadInterstitialAd();
    }
  }

  static void _loadInterstitialAd() {
    if (_interstitialAd != null) return; // ロード済みなら二重取得しない
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (err) {
          debugPrint('InterstitialAd load failed: $err');
          _interstitialAd = null;
        },
      ),
    );
  }

  /// App Open 広告を出してよいか。
  /// 初回起動では出さず（起点の時刻だけ記録する）、以降は前回表示から
  /// [_appOpenCapInterval] が経つまで出さない。
  static Future<bool> _appOpenCapAllows() async {
    final prefs = await SharedPreferences.getInstance();
    final lastShown = prefs.getInt(_appOpenCapKey);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (lastShown == null) {
      await prefs.setInt(_appOpenCapKey, now);
      return false;
    }
    return now - lastShown >= _appOpenCapInterval.inMilliseconds;
  }

  static bool get _hasValidAppOpenAd {
    final loadedAt = _appOpenAdLoadedAt;
    return _appOpenAd != null &&
        loadedAt != null &&
        DateTime.now().difference(loadedAt) < _appOpenAdExpiry;
  }

  /// App Open 広告をロードする。起動直後に読み込めた場合はそのまま表示する。
  static Future<void> _loadAppOpenAd() async {
    if (_isLoadingAppOpenAd || _hasValidAppOpenAd) return;
    // 起動時の読み込みと復帰時の読み込みが重ならないよう、await より前に立てる
    _isLoadingAppOpenAd = true;
    if (!await _appOpenCapAllows()) {
      _isLoadingAppOpenAd = false;
      return;
    }
    AppOpenAd.load(
      adUnitId: _appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _isLoadingAppOpenAd = false;
          _appOpenAd?.dispose();
          _appOpenAd = ad;
          _appOpenAdLoadedAt = DateTime.now();
          final startedAt = _startedAt;
          if (startedAt != null &&
              DateTime.now().difference(startedAt) < _coldStartShowWindow) {
            _showAppOpenAdIfAvailable();
          }
        },
        onAdFailedToLoad: (err) {
          _isLoadingAppOpenAd = false;
          debugPrint('AppOpenAd load failed: $err');
        },
      ),
    );
  }

  static void _onAppResumed() {
    if (_isShowingFullScreenAd) return;
    final closedAt = _lastFullScreenAdClosedAt;
    if (closedAt != null &&
        DateTime.now().difference(closedAt) < _resumeGuardAfterAd) {
      return;
    }
    if (_hasValidAppOpenAd) {
      _showAppOpenAdIfAvailable();
    } else {
      // 手元に無ければ次回の復帰に備えて読み込んでおく
      _loadAppOpenAd();
    }
  }

  static Future<void> _showAppOpenAdIfAvailable() async {
    if (_isShowingFullScreenAd || !_hasValidAppOpenAd) return;
    if (!await _appOpenCapAllows()) return;
    final ad = _appOpenAd;
    if (ad == null || _isShowingFullScreenAd) return;
    _appOpenAd = null;
    _appOpenAdLoadedAt = null;
    _isShowingFullScreenAd = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_appOpenCapKey, DateTime.now().millisecondsSinceEpoch);
    ad
      ..fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _markFullScreenAdClosed();
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          ad.dispose();
          _markFullScreenAdClosed();
        },
      )
      ..show();
  }

  static void _markFullScreenAdClosed() {
    _isShowingFullScreenAd = false;
    _lastFullScreenAdClosedAt = DateTime.now();
  }

  /// リワード広告をロード（表示は showRewardedAd() で）
  static void _loadRewardedAd() {
    if (_rewardedAd != null) return;
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewardedAd = ad,
        onAdFailedToLoad: (err) => debugPrint('RewardedAd failed: $err'),
      ),
    );
  }

  /// バナー用 Widget を返す。
  /// 画面ごとに独立した BannerAd を保持するため、複数画面で同時に使っても安全。
  static Widget bannerAdWidget() {
    if (!isSupported) return const SizedBox.shrink();
    return BannerAdView(adUnitId: _bannerAdUnitId);
  }

  /// リワード広告を表示
  /// [onUserEarned] 報酬を得たとき / [onAdClosedWithoutReward] 報酬なしで閉じたとき
  static void showRewardedAd({
    required VoidCallback onUserEarned,
    required VoidCallback onAdClosedWithoutReward,
  }) {
    final ad = _rewardedAd;
    if (ad == null) {
      // 広告未ロード or ネットワークエラー時は報酬ナシ扱い
      onAdClosedWithoutReward();
      return;
    }
    _rewardedAd = null;
    _isShowingFullScreenAd = true;
    bool earned = false;
    ad
      ..fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _markFullScreenAdClosed();
          if (!earned) onAdClosedWithoutReward();
          loadAd(AdType.rewarded);
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          ad.dispose();
          _markFullScreenAdClosed();
          onAdClosedWithoutReward();
          loadAd(AdType.rewarded);
        },
      )
      ..show(onUserEarnedReward: (ad, reward) {
        earned = true;
        onUserEarned();
      });
  }

  /// インタースティシャル広告を表示し、閉じられたら [onComplete] を呼ぶ。
  /// 未ロード時・表示間隔のキャップ内のときは広告を出さず即座に [onComplete] を呼ぶ。
  static void showInterstitialAd({required VoidCallback onComplete}) {
    if (!isSupported || _interstitialAd == null) {
      onComplete();
      return;
    }
    _showInterstitialAd(onComplete);
  }

  static Future<void> _showInterstitialAd(VoidCallback onComplete) async {
    final prefs = await SharedPreferences.getInstance();
    final lastShown = prefs.getInt(_interstitialCapKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final ad = _interstitialAd;
    if (ad == null || now - lastShown < _interstitialCapInterval.inMilliseconds) {
      onComplete();
      return;
    }
    _interstitialAd = null;
    _isShowingFullScreenAd = true;
    await prefs.setInt(_interstitialCapKey, now);
    ad
      ..fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _markFullScreenAdClosed();
          onComplete();
          loadAd(AdType.interstitial);
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          ad.dispose();
          _markFullScreenAdClosed();
          onComplete();
          loadAd(AdType.interstitial);
        },
      )
      ..show();
  }
}

/// ---------------------------------------------------------------------------
/// BannerAdView
/// ─ 自分専用の BannerAd をロードし、破棄まで面倒を見るバナー表示ウィジェット。
///   AdWidget は 1 つの Ad インスタンスにつき 1 つしかツリーに置けないため、
///   静的インスタンスを共有せず画面ごとに生成する。
/// ---------------------------------------------------------------------------
class BannerAdView extends StatefulWidget {
  final String adUnitId;

  const BannerAdView({super.key, required this.adUnitId});

  @override
  State<BannerAdView> createState() => _BannerAdViewState();
}

class _BannerAdViewState extends State<BannerAdView> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _bannerAd = BannerAd(
      adUnitId: widget.adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('BannerAd failed: $error');
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _bannerAd = null;
            _isLoaded = false;
          });
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _bannerAd;
    if (ad == null || !_isLoaded) return const SizedBox.shrink();
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
