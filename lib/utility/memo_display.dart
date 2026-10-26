import 'package:bookkeeping_vocabulary_notebook/utility/responsive_sizes.dart';
import 'package:flutter/material.dart';

import 'product.dart';
import 'load_memo.dart';

/// ---------------------------------------------------------------------------
/// MemoDisplay
/// ─ このウィジェットは、各Productに対応するメモ内容を表示します（非キャッシュ）。
/// ---------------------------------------------------------------------------
class MemoDisplay extends StatelessWidget {
  final Product product;

  const MemoDisplay({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      // 最低50pxの高さを確保
      constraints: const BoxConstraints(minHeight: 50),
      child: FutureBuilder<String>(
        future: loadMemo(product),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox();
          }
          if (snapshot.hasError) return const SizedBox();
          final memo = snapshot.data ?? "";
          if (memo.isNotEmpty) {
            return Text(
              "メモ: $memo",
              style: TextStyle(
                fontSize: context.fontSizeExtraSmall,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            );
          }
          return const SizedBox();
        },
      ),
    );
  }
}
