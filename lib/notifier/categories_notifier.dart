import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utility/category.dart';

/// ---------------------------------------------------------------------------
/// CategoriesNotifier
/// ─ リストの作成、更新、削除および単語の所属更新、並び替えを管理する
/// ---------------------------------------------------------------------------
class CategoriesNotifier extends StateNotifier<List<Category>> {
  CategoriesNotifier() : super([]) {
    _loaded = _loadCategories();
  }

  /// 保存済みデータの読み込み。更新系の処理は必ずこの完了を待ってから行う
  /// （読み込み前に更新すると、遅れて届いた読み込み結果で上書きされてしまうため）
  late final Future<void> _loaded;

  Future<void> reorderProducts(
      String categoryName, int oldIndex, int newIndex) async {
    await _loaded;
    state = state.map((c) {
      if (c.name == categoryName) {
        List<String> newProducts = List.from(c.products);
        final item = newProducts.removeAt(oldIndex);
        newProducts.insert(newIndex, item);
        return Category(name: c.name, products: newProducts);
      }
      return c;
    }).toList();
    await _saveCategories();
  }

  Future<void> _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString('saved_categories');
    if (data == null || !mounted) return;
    try {
      final List decoded = jsonDecode(data);
      state = decoded
          .map((e) => Category.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (error) {
      debugPrint('リストの復元に失敗しました: $error');
    }
  }

  Future<void> _saveCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(state.map((c) => c.toJson()).toList());
    await prefs.setString('saved_categories', data);
  }

  Future<void> addCategory(String name) async {
    await _loaded;
    if (state.any((c) => c.name == name)) return;
    final newCategory = Category(name: name);
    state = [...state, newCategory];
    await _saveCategories();
  }

  /// リスト名を変更する。リストは名前で識別しているため、
  /// 既に同じ名前のリストがある場合は変更せず false を返す。
  Future<bool> updateCategory(String oldName, String newName) async {
    await _loaded;
    if (oldName == newName) return true;
    if (state.any((c) => c.name == newName)) return false;
    state = state.map((c) {
      if (c.name == oldName) {
        return Category(name: newName, products: c.products);
      }
      return c;
    }).toList();
    await _saveCategories();
    return true;
  }

  Future<void> deleteCategory(String name) async {
    await _loaded;
    state = state.where((c) => c.name != name).toList();
    await _saveCategories();
  }

  Future<void> reorderCategories(int oldIndex, int newIndex) async {
    await _loaded;
    List<Category> updated = List.from(state);
    final Category item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    state = updated;
    await _saveCategories();
  }

  Future<void> updateProductAssignment(
      String categoryName, String productName, bool assigned) async {
    await _loaded;
    state = state.map((c) {
      if (c.name == categoryName) {
        List<String> updatedProducts = List.from(c.products);
        if (assigned) {
          if (!updatedProducts.contains(productName)) {
            updatedProducts.add(productName);
          }
        } else {
          updatedProducts.remove(productName);
        }
        return Category(name: c.name, products: updatedProducts);
      }
      return c;
    }).toList();
    await _saveCategories();
  }
}
