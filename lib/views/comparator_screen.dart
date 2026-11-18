import 'package:flutter/material.dart';

import '../models/product_model.dart';

class ComparatorScreen extends StatelessWidget {
  final List<ProductModel> products;

  const ComparatorScreen({super.key, required this.products});

  String _formatQuantity(double value) {
    return value.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  String _unitLabel(String unit) {
    switch (unit) {
      case 'kg':
        return 'kg';
      case 'L':
        return 'L';
      default:
        return 'unidade(s)';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.compare_arrows,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Nenhum produto selecionado',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Acesse o Catálogo e selecione produtos para '
                'realizar uma comparação.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final comparableByUnit = <String, List<ProductModel>>{};
    final productsWithoutQuantity = <ProductModel>[];

    for (final product in products) {
      if (product.unitPrice == null) {
        productsWithoutQuantity.add(product);
      } else {
        comparableByUnit.putIfAbsent(product.unit, () => []).add(product);
      }
    }

    for (final group in comparableByUnit.values) {
      group.sort((a, b) => a.unitPrice!.compareTo(b.unitPrice!));
    }

    final unitOrder = ['kg', 'L', 'unidade'];
    final sortedUnits = comparableByUnit.keys.toList()
      ..sort((a, b) => unitOrder.indexOf(a).compareTo(unitOrder.indexOf(b)));

    final totalComparable = comparableByUnit.values.fold<int>(
      0,
      (total, group) => total + group.length,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Comparador de preços',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          '${products.length} produtos selecionados. '
          '$totalComparable com preço unitário calculado.',
        ),
        const SizedBox(height: 16),

        if (totalComparable == 0)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Nenhum dos produtos selecionados possui quantidade '
                'de embalagem informada. Não é possível comparar '
                'os preços unitários ainda.',
              ),
            ),
          ),

        for (final unit in sortedUnits) ...[
          Text(
            'Comparação por ${_unitLabel(unit)}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Card(
            color: Colors.green.shade50,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.emoji_events, color: Colors.green),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Melhor preço neste grupo',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < comparableByUnit[unit]!.length; index++)
            _buildProductCard(context, comparableByUnit[unit]![index], index),
          const SizedBox(height: 16),
        ],

        if (productsWithoutQuantity.isNotEmpty) ...[
          Text(
            'Produtos sem quantidade informada',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Estes produtos continuam disponíveis, mas não podem '
            'participar da comparação por preço unitário.',
          ),
          const SizedBox(height: 8),
          for (final product in productsWithoutQuantity)
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.inventory_2_outlined),
                ),
                title: Text(product.name),
                subtitle: Text(
                  '${product.supplier}\n'
                  'Unidade: ${_unitLabel(product.unit)} • '
                  '${product.location}\n'
                  'Quantidade da embalagem não informada',
                ),
                isThreeLine: true,
                trailing: Text(
                  'R\$ ${product.price.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    ProductModel product,
    int index,
  ) {
    final isCheapest = index == 0;
    final quantity = _formatQuantity(product.packageQuantity!);

    return Card(
      color: isCheapest ? Colors.green.shade50 : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isCheapest ? Colors.green : Colors.grey.shade300,
          child: Text('${index + 1}'),
        ),
        title: Text(product.name),
        subtitle: Text(
          '${product.supplier}\n'
          'Embalagem: $quantity ${_unitLabel(product.unit)}\n'
          'Preço da embalagem: R\$ ${product.price.toStringAsFixed(2)}\n'
          'Preço por ${_unitLabel(product.unit)}: '
          'R\$ ${product.unitPrice!.toStringAsFixed(2)}'
          '${isCheapest ? '\nMenor preço deste grupo' : ''}',
        ),
        isThreeLine: true,
        trailing: isCheapest
            ? const Icon(Icons.emoji_events, color: Colors.green)
            : null,
      ),
    );
  }
}
