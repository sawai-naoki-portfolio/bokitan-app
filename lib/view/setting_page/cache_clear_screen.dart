import 'dart:async';

import 'package:bookkeeping_vocabulary_notebook/utility/responsive_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bookkeeping_vocabulary_notebook/ads/ad_manager.dart';

class CacheClearScreen extends StatefulWidget {
  const CacheClearScreen({super.key});

  @override
  CacheClearScreenState createState() => CacheClearScreenState();
}

class CacheClearScreenState extends State<CacheClearScreen> {
  // キャッシュ削除対象のキーと初期選択状態
  // 'memo_list' は「メモ一覧」に対応し、削除時は "memo_" で始まるキーをすべて削除します。
  // 'schedule_list' は「スケジュール」に対応し、削除時は "schedule_items" キーを削除します。
  final Map<String, bool> _selected = {
    'search_history': false,
    'mistake_counts': false,
    'saved_categories': false,
    'saved_items': false,
    'checked_questions': false,
    'custom_products': false,
    'memo_list': false,
    'schedule_list': false,
  };

  // 各キーの表示用ラベル
  final Map<String, String> _labels = {
    'search_history': '検索履歴',
    'mistake_counts': 'ミス回数',
    'saved_categories': 'リスト',
    'saved_items': '保存単語一覧',
    'checked_questions': '単語チェック問題',
    'custom_products': '自分で追加した単語',
    'memo_list': 'メモ一覧',
    'schedule_list': 'スケジュール',
  };

  // 「すべて削除」チェックボックスの状態
  bool _allSelected = false;

  /// 「すべて削除」チェックボックスの更新処理
  void _toggleAll(bool? val) {
    setState(() {
      _allSelected = val ?? false;
      _selected.updateAll((key, value) => _allSelected);
    });
  }

  /// 個別チェックボックス更新時の処理
  void _toggleItem(String key, bool? val) {
    setState(() {
      _selected[key] = val ?? false;
      // すべてが true なら _allSelected を true、1つでも false があれば false に
      _allSelected = !_selected.values.contains(false);
    });
  }

  /// 選択されたキーを SharedPreferences から削除する
  Future<void> _removeSelectedKeys() async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in _selected.entries) {
      if (!entry.value) continue;
      switch (entry.key) {
        case 'memo_list':
          // メモは "memo_<単語名>" というキーで個別に保存されている
          for (final k in prefs.getKeys().toList()) {
            if (k.startsWith("memo_")) {
              await prefs.remove(k);
            }
          }
        case 'schedule_list':
          await prefs.remove("schedule_items");
        default:
          await prefs.remove(entry.key);
      }
    }
  }

  /// 削除確認ダイアログ後、選択対象のキャッシュキーを削除して再起動
  Future<void> _clearCache() async {
    if (!_selected.values.contains(true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("削除する項目を選択してください")),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("確認"),
        content: const Text("削除してよろしいですか？\nこの操作は取り消せません。"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("キャンセル"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("削除"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // インタースティシャル広告を表示し、閉じられたらキャッシュ削除＆再起動
    AdManager.showInterstitialAd(onComplete: () async {
      await _removeSelectedKeys();
      if (!mounted) return;
      await _showRestartDialog();
    });
  }

  /// 完了ダイアログを出して、少し待ってからアプリを再起動する
  Future<void> _showRestartDialog() async {
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                color: Theme.of(dialogContext).colorScheme.primary, size: 64),
            const SizedBox(height: 16),
            Text('キャッシュがクリアされました。',
                style: TextStyle(fontSize: dialogContext.fontSizeMedium)),
            Text('再起動します。',
                style: TextStyle(fontSize: dialogContext.fontSizeMedium)),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    ));

    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    Phoenix.rebirth(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("キャッシュクリア"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 「すべて削除」チェックボックス
            CheckboxListTile(
              title: Text("すべて削除",
                  style: TextStyle(fontSize: context.fontSizeMedium)),
              value: _allSelected,
              onChanged: _toggleAll,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            // 個別のチェック項目 (リスト形式)
            ListView(
              shrinkWrap: true,
              children: _selected.keys.map((key) {
                return CheckboxListTile(
                  title: Text(
                    _labels[key] ?? key,
                    style: TextStyle(fontSize: context.fontSizeMedium),
                  ),
                  value: _selected[key],
                  onChanged: (val) => _toggleItem(key, val),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),

            const SizedBox(height: 8),
            // 「削除」ボタンでキャッシュ削除処理を実行
            ElevatedButton(
              onPressed: _clearCache,
              child: const Text("削除"),
            )
          ],
        ),
      ),
    );
  }
}
