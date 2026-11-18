class ProductModel {
  final int id;
  final String name;
  final String category;
  final String unit;

  // Preço total da embalagem.
  final double price;

  // Quantidade contida na embalagem, em kg, L ou unidades.
  final double? packageQuantity;

  final int supplierId;
  final String supplier;
  final String location;

  const ProductModel({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.price,
    required this.packageQuantity,
    required this.supplierId,
    required this.supplier,
    required this.location,
  });

  // Preço por kg, litro ou unidade.
  // Produtos antigos sem quantidade não possuem preço unitário calculável.
  double? get unitPrice {
    final quantity = packageQuantity;

    if (quantity == null || !quantity.isFinite || quantity <= 0) {
      return null;
    }

    return price / quantity;
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final rawQuantity = json['package_quantity'];

    return ProductModel(
      id: int.tryParse('${json['id']}') ?? 0,
      name: '${json['name'] ?? ''}',
      category: '${json['category'] ?? 'Geral'}',
      unit: '${json['unit'] ?? 'unidade'}',
      price: double.tryParse('${json['price']}') ?? 0.0,
      packageQuantity: rawQuantity == null
          ? null
          : double.tryParse('$rawQuantity'),
      supplierId: int.tryParse('${json['supplier_id']}') ?? 0,
      supplier: '${json['supplier'] ?? 'Fornecedor'}',
      location: '${json['location'] ?? ''}',
    );
  }
}
