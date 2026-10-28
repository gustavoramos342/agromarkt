import 'dart:async';

import 'package:flutter/foundation.dart';

import '../adapters/api_service.dart';
import '../models/product_model.dart';

class CatalogController extends ChangeNotifier {
  final ApiService api;

  CatalogController(this.api);

  Timer? _debounce;

  List<ProductModel> products = [];
  bool loading = false;
  String? error;
  String query = '';

  List<ProductModel> get sortedProducts {
    final result = List<ProductModel>.from(products);
    result.sort((a, b) => a.unitPrice.compareTo(b.unitPrice));
    return result;
  }

  ProductModel? get cheapestProduct =>
      sortedProducts.isEmpty ? null : sortedProducts.first;

  void search(String value) {
    query = value;
    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 300), () => loadProducts());
  }

  Future<void> loadProducts() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      products = await api.getProducts(query: query);
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
