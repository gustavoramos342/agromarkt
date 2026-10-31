
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../adapters/api_service.dart';
import '../models/product_model.dart';

class CatalogController extends ChangeNotifier {
  final ApiService api;

  CatalogController(this.api);

  Timer? _debounce;

  List<ProductModel> products = [];

  // IDs dos produtos selecionados para comparação.
  final Set<int> _selectedProductIds = {};

  bool loading = false;
  String? error;
  String query = '';

  // Produtos ordenados pelo menor preço.
  List<ProductModel> get sortedProducts {
    final result = List<ProductModel>.from(products);
    result.sort((a, b) => a.unitPrice.compareTo(b.unitPrice));
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

    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => loadProducts(),
    );
  }

  // Carrega os produtos pela API.
  Future<void> loadProducts() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      products = await api.getProducts(query: query);

      // Remove seleções de produtos que não existem mais
      // na lista carregada.
      final availableIds = products.map((product) => product.id).toSet();

      _selectedProductIds.removeWhere(
        (id) => !availableIds.contains(id),
      );
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    } finally {
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
