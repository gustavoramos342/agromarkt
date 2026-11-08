import 'package:sembast_web/sembast_web.dart';

import '../models/product_model.dart';

class LocalStorageService {
  static const String _databaseName = 'agromarkt.db';

  static final StoreRef<int, Map<String, Object?>> _productStore =
      intMapStoreFactory.store('products');

  static final StoreRef<String, Map<String, Object?>> _cacheStore =
      stringMapStoreFactory.store('private_cache');

  Database? _database;

  Future<Database> get _db async {
    _database ??= await databaseFactoryWeb.openDatabase(_databaseName);
    return _database!;
  }

  /// Salva ou atualiza o catálogo recebido da API.
  Future<void> saveProducts(List<ProductModel> products) async {
    final database = await _db;

    await database.transaction((transaction) async {
      await _productStore.delete(transaction);

      for (final product in products) {
        await _productStore.record(product.id).put(transaction, {
          'id': product.id,
          'name': product.name,
          'category': product.category,
          'unit': product.unit,
          'price': product.price,
          'supplier': product.supplier,
          'location': product.location,
        });
      }
    });
  }

  /// Recupera os produtos armazenados no navegador.
  Future<List<ProductModel>> getProducts() async {
    final database = await _db;
    final records = await _productStore.find(database);

    return records
        .map((record) => ProductModel.fromJson(record.value))
        .toList();
  }

  /// Informa se existe catálogo salvo.
  Future<bool> hasProducts() async {
    final database = await _db;
    return await _productStore.count(database) > 0;
  }

  /// Salva uma lista de dados comerciais com uma chave específica.
  ///
  /// A chave deve identificar o perfil e o usuário.
  /// Exemplo: produtor_12_history.
  Future<void> saveCachedList({
    required String cacheKey,
    required List<Map<String, dynamic>> items,
  }) async {
    final database = await _db;

    await _cacheStore.record(cacheKey).put(database, {
      'items': items,
      'savedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Recupera uma lista comercial salva.
  ///
  /// Retorna uma lista vazia quando ainda não existe cache.
  Future<List<Map<String, dynamic>>> getCachedList({
    required String cacheKey,
  }) async {
    final database = await _db;
    final record = await _cacheStore.record(cacheKey).get(database);

    if (record == null) {
      return [];
    }

    final items = record['items'];

    if (items is! List) {
      return [];
    }

    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  /// Informa quando a lista foi salva pela última vez.
  Future<DateTime?> getCacheSavedAt({required String cacheKey}) async {
    final database = await _db;
    final record = await _cacheStore.record(cacheKey).get(database);

    if (record == null || record['savedAt'] == null) {
      return null;
    }

    return DateTime.tryParse(record['savedAt'].toString());
  }

  /// Remove uma lista comercial específica do cache.
  Future<void> removeCachedList({required String cacheKey}) async {
    final database = await _db;
    await _cacheStore.record(cacheKey).delete(database);
  }

  /// Fecha o banco local.
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
