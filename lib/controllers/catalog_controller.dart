import 'dart:async';

import 'package:flutter/foundation.dart';

import '../adapters/api_service.dart';
import '../adapters/local_storage_service.dart';
import '../models/product_model.dart';

class CatalogController extends ChangeNotifier {
  final ApiService api;
  final LocalStorageService localStorage;

  CatalogController(this.api, this.localStorage);

  Timer? _debounce;

  List<ProductModel> products = [];

  // IDs dos produtos selecionados para comparação.
  final Set<int> _selectedProductIds = {};

  bool loading = false;
  String? error;
  String query = '';

  // Produtos com preço unitário calculável, ordenados do menor para o maior.
  List<ProductModel> get sortedProducts {
    final result = products
        .where((product) => product.unitPrice != null)
        .toList();

    result.sort((a, b) => a.unitPrice!.compareTo(b.unitPrice!));

    return result;
  }

  // Produtos escolhidos pelo usuário para comparar.
  List<ProductModel> get selectedProducts {
    return products
        .where((product) => _selectedProductIds.contains(product.id))
        .toList();
  }

  // Quantidade de produtos selecionados.
  int get selectedCount => _selectedProductIds.length;

  // Verifica se um produto está selecionado.
  bool isSelected(ProductModel product) {
    return _selectedProductIds.contains(product.id);
  }

  // Adiciona ou remove um produto da comparação.
  void toggleProductSelection(ProductModel product) {
    if (isSelected(product)) {
      _selectedProductIds.remove(product.id);
    } else {
      _selectedProductIds.add(product.id);
    }

    notifyListeners();
  }

  // Limpa todos os produtos selecionados.
  void clearSelection() {
    _selectedProductIds.clear();
    notifyListeners();
  }

  // Retorna o produto mais barato.
  ProductModel? get cheapestProduct =>
      sortedProducts.isEmpty ? null : sortedProducts.first;

  // Pesquisa produtos com atraso de 300 ms.
  void search(String value) {
    query = value;
    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 300), () => loadProducts());
  }

  // Carrega os produtos pela API ou pelo armazenamento local.
  Future<void> loadProducts() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      // Tenta carregar os produtos pela API.
      final onlineProducts = await api.getProducts(query: query);

      products = onlineProducts;

      // Atualiza o cache somente quando recebe o catálogo completo.
      if (query.trim().isEmpty) {
        await localStorage.saveProducts(onlineProducts);
      }
    } catch (e) {
      // Se a API falhar, recupera os produtos salvos localmente.
      try {
        final cachedProducts = await localStorage.getProducts();

        final normalizedQuery = query.trim().toLowerCase();

        products = cachedProducts.where((product) {
          return product.name.toLowerCase().contains(normalizedQuery) ||
              product.category.toLowerCase().contains(normalizedQuery) ||
              product.supplier.toLowerCase().contains(normalizedQuery);
        }).toList();

        if (cachedProducts.isEmpty) {
          error =
              'Sem conexão e ainda não há produtos salvos neste dispositivo.';
        } else {
          error = 'Você está offline. Exibindo os últimos produtos salvos.';
        }
      } catch (_) {
        products = [];
        error = 'Não foi possível carregar os produtos da API nem do armazenamento local.';
      }
    } finally {
      // Remove seleções de produtos que não existem mais na lista.
      final availableIds = products.map((product) => product.id).toSet();

      _selectedProductIds.removeWhere((id) => !availableIds.contains(id));

      loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
