import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/category.dart';
import '../database_repository.dart';
import '../supabase_repository.dart';

/// Adapter สำหรับจัดการข้อมูลหมวดหมู่ (Category) บน Supabase
class SupabaseCategoryAdapter implements CategoryRepositoryInterface {
  final SupabaseRepository repo;

  SupabaseCategoryAdapter(this.repo);

  SupabaseClient get client => repo.client;
  String? get currentUserId => repo.currentUserId;

  void _requireAuth() {
    if (currentUserId == null) {
      throw StateError('User not authenticated. Please login first.');
    }
  }

  Map<String, dynamic> _categoryToSupabase(Category category) {
    return {
      'id': category.id,
      'user_id': currentUserId,
      'name': category.name,
      'type': category.type.name,
      'icon': category.icon.codePoint,
      'color': SupabaseRepository.colorToSupabase(category.color.toARGB32()),
      'parent_id': category.parentId,
      'note': category.note ?? '',
      'sort_order': category.sortOrder,
    };
  }

  Category _categoryFromSupabase(Map<String, dynamic> row) {
    final normalized = Map<String, dynamic>.from(row);
    if (normalized['color'] is int) {
      normalized['color'] = SupabaseRepository.colorFromSupabase(
        normalized['color'] as int,
      );
    }
    return Category.fromMap(normalized);
  }

  @override
  Future<List<Category>> getCategories() async {
    _requireAuth();
    repo.log('Fetching categories for user: $currentUserId');
    final response = await client
        .from('categories')
        .select()
        .eq('user_id', currentUserId!)
        .order('sort_order');
    return (response as List).map((row) => _categoryFromSupabase(row)).toList();
  }

  @override
  Future<void> insertCategory(Category category) async {
    _requireAuth();
    repo.log('Inserting category: ${category.id} for user: $currentUserId');
    await client.from('categories').insert(_categoryToSupabase(category));
    await repo.updateSyncLog('categories');
  }

  @override
  Future<void> updateCategory(Category category) async {
    _requireAuth();
    repo.log('Updating category: ${category.id} for user: $currentUserId');
    await client
        .from('categories')
        .update(_categoryToSupabase(category))
        .eq('id', category.id)
        .eq('user_id', currentUserId!);
    await repo.updateSyncLog('categories');
  }

  @override
  Future<void> updateCategorySortOrder(String id, int sortOrder) async {
    _requireAuth();
    repo.log('Updating category sort order: $id -> $sortOrder');
    try {
      final response = await client
          .from('categories')
          .update({'sort_order': sortOrder})
          .eq('id', id)
          .eq('user_id', currentUserId!)
          .select();

      if ((response as List).isEmpty) {
        throw Exception(
          'Failed to update category sort order: No rows affected',
        );
      }
      repo.log('Updated category sort order successfully: $id');
      await repo.updateSyncLog('categories');
    } catch (e) {
      repo.logError('Error updating category sort order', e);
      rethrow;
    }
  }

  @override
  Future<void> deleteCategory(String id) async {
    _requireAuth();
    repo.log('Deleting category: $id for user: $currentUserId');
    await client
        .from('categories')
        .delete()
        .eq('id', id)
        .eq('user_id', currentUserId!);
    await repo.updateSyncLog('categories');
  }

  @override
  Future<Set<String>> getExistingCategoryIds() async {
    _requireAuth();
    final response = await client
        .from('categories')
        .select('id')
        .eq('user_id', currentUserId!);
    return (response as List).map((r) => r['id'] as String).toSet();
  }

  @override
  Future<void> bulkInsertCategories(List<Category> categories) async {
    _requireAuth();
    repo.log(
      'Bulk inserting ${categories.length} categories for user: $currentUserId',
    );
    await repo.batchInsert(
      'categories',
      categories.map((c) => _categoryToSupabase(c)).toList(),
    );
  }
}
