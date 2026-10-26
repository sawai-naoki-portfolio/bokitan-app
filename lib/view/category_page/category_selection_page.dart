import 'package:bookkeeping_vocabulary_notebook/utility/responsive_sizes.dart';
import 'package:bookkeeping_vocabulary_notebook/view/widget/show_category_creation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../provider/categories_provider.dart';
import '../../utility/category.dart';
import '../../utility/swipe_to_delete_card.dart';
import '../saved_items_page.dart';
import 'category_items_page.dart';

//////////////////////////////////////////////
// CategorySelectionPage
//////////////////////////////////////////////
// 登録済みのリスト一覧を表示する画面です。
// ユーザーはリストごとに保存された単語のリストを見るため、
// 各リストカードをタップして CategoryItemsPage へ遷移できます。
class CategorySelectionPage extends ConsumerStatefulWidget {
  const CategorySelectionPage({super.key});

  @override
  CategorySelectionPageState createState() => CategorySelectionPageState();
}

// ============================================================================
// CategorySelectionPageState
// -----------------------------------------------------------------------------
// この状態クラスは「リスト一覧画面」内で表示するリストのリストを管理します。
// ・通常表示モードでは、各リストをリスト表示し、スワイプで削除や長押しでオプションを起動します。
// ・並び替えモードでは、ドラッグ＆ドロップでリストの順序を変更できるようにします。
// ============================================================================
class CategorySelectionPageState extends ConsumerState<CategorySelectionPage> {
  bool _isReordering = false;

  @override
  Widget build(BuildContext context) {
    // プロバイダーから現在のリスト一覧を取得
    final categories = ref.watch(categoriesProvider);

    // 固定の「保存単語一覧」タイル（デフォルト表示）
    final Widget defaultSavedItemsTile = ListTile(
      key: const ValueKey("saved_items_default"),
      leading: const Icon(Icons.bookmark),
      title: const Text("保存単語一覧"),
      subtitle: const Text("保存された単語を表示します"),
      trailing: const Icon(Icons.arrow_forward),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SavedItemsPage()),
        );
      },
    );

    Widget listWidget;
    if (_isReordering) {
      // 並び替えモードの場合、固定のタイルはリスト上部に固定表示し、
      // 以降のユーザー登録リストはReorderableListViewで管理する
      listWidget = Column(
        children: [
          defaultSavedItemsTile,
          Expanded(
            child: ReorderableListView.builder(
              padding: EdgeInsets.symmetric(vertical: context.paddingMedium),
              itemCount: categories.length,
              // onReorderItem は削除位置を考慮した newIndex を渡してくれる
              onReorderItem: (oldIndex, newIndex) async {
                await ref
                    .read(categoriesProvider.notifier)
                    .reorderCategories(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final cat = categories[index];
                return ListTile(
                  key: ValueKey(cat.name),
                  leading: ReorderableDragStartListener(
                    index: index,
                    child: const Icon(Icons.drag_handle),
                  ),
                  title: Text(cat.name),
                  subtitle: Text("登録済み単語数: ${cat.products.length}"),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => CategoryItemsPage(category: cat)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      );
    } else {
      // 通常モードの場合：固定の「保存単語一覧」タイルの後にリスト表示する
      listWidget = ListView(
        padding: EdgeInsets.symmetric(vertical: context.paddingMedium),
        children: [
          defaultSavedItemsTile,
          const Divider(),
          ...categories
              .map((cat) => SwipeToDeleteCard(
                    keyValue: ValueKey(cat.name),
                    onConfirm: () async {
                      return await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text("削除確認"),
                              content: Text("リスト『${cat.name}』を削除してよろしいですか？"),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text("キャンセル"),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text("削除"),
                                ),
                              ],
                            ),
                          ) ??
                          false;
                    },
                    onDismissed: () async {
                      await ref
                          .read(categoriesProvider.notifier)
                          .deleteCategory(cat.name);
                    },
                    child: ListTile(
                      title: Text(cat.name),
                      subtitle: Text("登録済み単語数: ${cat.products.length}"),
                      trailing: const Icon(Icons.arrow_forward),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => CategoryItemsPage(category: cat)),
                        );
                      },
                      onLongPress: () {
                        _showCategoryOptions(cat);
                      },
                    ),
                  )),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("リスト"),
        centerTitle: true,
        actions: [
          if (_isReordering)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () {
                setState(() {
                  _isReordering = false;
                });
              },
            )
        ],
      ),
      body: listWidget,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newCat = await showCategoryCreationDialog(
            context,
            existingNames: categories.map((c) => c.name),
          );
          if (newCat == null) return;
          await ref.read(categoriesProvider.notifier).addCategory(newCat);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  // ※既存の _showCategoryOptions(cat) メソッドはそのまま利用
  void _showCategoryOptions(Category cat) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text("リスト名の変更"),
                onTap: () {
                  Navigator.pop(context);
                  _showRenameCategoryDialog(cat);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text("リスト削除"),
                onTap: () async {
                  Navigator.pop(context);
                  bool? confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("リスト削除"),
                      content: Text("リスト『${cat.name}』を削除してよろしいですか？"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text("キャンセル"),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text("削除"),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await ref
                        .read(categoriesProvider.notifier)
                        .deleteCategory(cat.name);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.sort),
                title: const Text("並び替え"),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _isReordering = true;
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRenameCategoryDialog(Category cat) {
    final TextEditingController controller =
        TextEditingController(text: cat.name);
    String? errorText;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text("リスト名の変更"),
            content: TextField(
              controller: controller,
              maxLength: 30,
              decoration: InputDecoration(
                hintText: "新しいリスト名",
                errorText: errorText,
              ),
              onChanged: (_) {
                if (errorText != null) setDialogState(() => errorText = null);
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("キャンセル"),
              ),
              ElevatedButton(
                onPressed: () async {
                  String newName = controller.text.trim();
                  if (newName.isEmpty) {
                    setDialogState(() => errorText = "リスト名を入力してください");
                    return;
                  }
                  // リストは名前で識別しているため、既存の名前への変更は受け付けない
                  final renamed = await ref
                      .read(categoriesProvider.notifier)
                      .updateCategory(cat.name, newName);
                  if (!context.mounted) return;
                  if (!renamed) {
                    setDialogState(() => errorText = "同じ名前のリストが既にあります");
                    return;
                  }
                  Navigator.pop(context);
                },
                child: const Text("変更"),
              ),
            ],
          ),
        );
      },
    );
  }
}
