class ProductModel {
  final int id;
  final String name;
  final String category;
  final String unit;
  final double price;
  final String supplier;
  final String location;

  const ProductModel({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.price,
    required this.supplier,
    required this.location,
  });

  double get unitPrice => price;

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: int.tryParse('${json['id']}') ?? 0,
      name: '${json['name'] ?? ''}',
      category: '${json['category'] ?? 'Geral'}',
      unit: '${json['unit'] ?? 'unidade'}',
      price: double.tryParse('${json['price']}') ?? 0.0,
      supplier: '${json['supplier'] ?? 'Fornecedor'}',
      location: '${json['location'] ?? ''}',
    );
  }
}
