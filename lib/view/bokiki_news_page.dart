// lib/view/bokiki_news_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../ads/ad_manager.dart';
import '../utility/responsive_sizes.dart';
import 'news_web_view_page.dart';

/// 簿記ニュースの 1 記事
class Article {
  final String title;
  final String link;
  final String pubDate;
  final String? thumbnail;
  final String? source; // 発行元

  Article({
    required this.title,
    required this.link,
    required this.pubDate,
    this.thumbnail,
    this.source,
  });
}

/// Google ニュースの RSS から記事一覧を取得する。
///
/// FutureProvider にしているため、画面の再描画のたびに再取得されることはない
/// （build 内で future を組み立てると毎回リクエストが飛んでしまう）。
final newsArticlesProvider =
    FutureProvider.family<List<Article>, String>((ref, query) async {
  final uri = Uri.parse('https://news.google.com/rss/search'
      '?q=${Uri.encodeComponent(query)}&hl=ja&gl=JP&ceid=JP:ja');
  // 応答が返らないまま画面が固まるのを防ぐためタイムアウトを設ける
  final res = await http.get(uri).timeout(const Duration(seconds: 10));
  if (res.statusCode != 200) {
    throw Exception('ニュースの取得に失敗しました (HTTP ${res.statusCode})');
  }

  final doc = XmlDocument.parse(res.body);
  final articles = doc
      .findAllElements('item')
      .map((node) {
        final thumbnails = node.findElements('media:thumbnail');
        return Article(
          title: node.getElement('title')?.innerText ?? '',
          link: node.getElement('link')?.innerText ?? '',
          pubDate: node.getElement('pubDate')?.innerText ?? '',
          thumbnail: thumbnails.isEmpty
              ? null
              : _safeImageUrl(thumbnails.first.getAttribute('url')),
          source: node.getElement('source')?.innerText,
        );
      })
      // 外部由来のリンクは https/http のものだけを扱う
      .where((a) => _isHttpUrl(a.link))
      .toList();

  // 毎回同じ記事ばかりにならないよう、取得時に一度だけシャッフルして15件に絞る
  articles.shuffle();
  return articles.length > 15 ? articles.sublist(0, 15) : articles;
});

/// 記事ページの og:image を取得する（サムネイルが RSS に無い場合の補完）
final ogImageProvider =
    FutureProvider.family<String?, String>((ref, url) async {
  if (!_isHttpUrl(url)) return null;
  try {
    final res =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 3));
    if (res.statusCode != 200) return null;
    // 巨大なページを丸ごと正規表現に掛けないよう、先頭部分（<head> 相当）だけを見る
    final head = res.body.length > 200000
        ? res.body.substring(0, 200000)
        : res.body;
    final match = RegExp(r'<meta\s+property="og:image"\s+content="([^"]+)"',
            caseSensitive: false)
        .firstMatch(head);
    return _safeImageUrl(match?.group(1));
  } catch (_) {
    return null;
  }
});

/// http / https 以外のスキーム（javascript: や file: など）を弾く
bool _isHttpUrl(String? url) {
  if (url == null || url.isEmpty) return false;
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return false;
  final scheme = uri.scheme.toLowerCase();
  return scheme == 'https' || scheme == 'http';
}

/// 画像として読み込んでよい URL のみを返す
String? _safeImageUrl(String? url) => _isHttpUrl(url) ? url : null;

class BokikiNewsPage extends ConsumerStatefulWidget {
  const BokikiNewsPage({super.key});

  @override
  ConsumerState<BokikiNewsPage> createState() => _BokikiNewsPageState();
}

class _BokikiNewsPageState extends ConsumerState<BokikiNewsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = ['簿記３級', '簿記２級', '簿記１級', '会計関連'];
  static const _queries = ['簿記+3級', '簿記+2級', '簿記+1級', '会計'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    AdManager.loadAd(AdType.interstitial);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openArticle(Article article) {
    // 広告表示には AdManager 側で表示間隔のキャップが掛かっている
    AdManager.showInterstitialAd(onComplete: () {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NewsWebViewPage(url: article.link)),
      );
    });
  }

  Widget _buildTab(int index) {
    final articlesAsync = ref.watch(newsArticlesProvider(_queries[index]));

    return articlesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('取得エラー: $error', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(newsArticlesProvider(_queries[index])),
                child: const Text('再読み込み'),
              ),
            ],
          ),
        ),
      ),
      data: (articles) {
        if (articles.isEmpty) {
          return const Center(child: Text('記事が見つかりませんでした'));
        }
        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(newsArticlesProvider(_queries[index])),
          child: ListView.builder(
            itemCount: articles.length,
            itemBuilder: (context, i) => _ArticleCard(
              article: articles[i],
              onTap: () => _openArticle(articles[i]),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('簿記ニュース'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
          isScrollable: true,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: List.generate(_tabs.length, _buildTab),
      ),
    );
  }
}

/// 記事カード
class _ArticleCard extends ConsumerWidget {
  final Article article;
  final VoidCallback onTap;

  const _ArticleCard({required this.article, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      clipBehavior: Clip.hardEdge,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildThumbnail(context, ref, theme),
            // タイトル
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                article.title,
                style: TextStyle(
                  fontSize: context.fontSizeMedium,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 日付＋発行元
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                '${article.source ?? ''} ・ ${article.pubDate}',
                style: TextStyle(
                  fontSize: context.fontSizeSmall,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context, WidgetRef ref, ThemeData theme) {
    final thumbnail = article.thumbnail;
    if (thumbnail != null) {
      return Image.network(
        thumbnail,
        width: double.infinity,
        height: 180,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(context, theme),
      );
    }

    // RSS にサムネイルが無い場合は記事ページの og:image を試す
    final ogImage = ref.watch(ogImageProvider(article.link));
    return ogImage.maybeWhen(
      data: (url) => url == null
          ? _placeholder(context, theme)
          : Image.network(
              url,
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(context, theme),
            ),
      orElse: () => Container(
        width: double.infinity,
        height: 180,
        color: theme.colorScheme.surfaceContainerHighest,
      ),
    );
  }

  Widget _placeholder(BuildContext context, ThemeData theme) {
    return Container(
      width: double.infinity,
      height: 180,
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Text(
        article.source ?? '',
        style: TextStyle(
          fontSize: context.fontSizeMedium,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
