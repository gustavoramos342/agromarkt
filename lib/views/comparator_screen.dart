import 'package:flutter/material.dart';

import '../models/product_model.dart';

class ComparatorScreen extends StatelessWidget {
  final List<ProductModel> products;

  const ComparatorScreen({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    final sorted = List<ProductModel>.from(products)
      ..sort((a, b) => a.unitPrice.compareTo(b.unitPrice));

    if (sorted.isEmpty) {
      return const Center(child: Text('Nenhum produto para comparar.'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Comparador de preços',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text('Menor preço primeiro, considerando a unidade informada.'),
        const SizedBox(height: 16),
        for (var index = 0; index < sorted.length; index++)
          Card(
            color: index == 0 ? Colors.green.shade50 : null,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: index == 0
                    ? Colors.green
                    : Colors.grey.shade300,
                child: Text('${index + 1}'),
              ),
              title: Text(sorted[index].name),
              subtitle: Text(
                '${sorted[index].supplier}\n'
                '${sorted[index].unit} • ${sorted[index].location}',
              ),
              isThreeLine: true,
              trailing: Text(
                'R\$ ${sorted[index].price.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: index == 0 ? Colors.green.shade800 : null,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
