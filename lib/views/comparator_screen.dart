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
                'Acesse o Catálogo e selecione pelo menos dois produtos '
                'para realizar uma comparação.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (sorted.length == 1) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, size: 56, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                'Selecione mais um produto',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Você selecionou apenas um produto. Volte ao Catálogo '
                'e adicione pelo menos mais um para comparar os preços.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  title: Text(sorted.first.name),
                  subtitle: Text(
                    '${sorted.first.supplier}\n'
                    '${sorted.first.unit} • ${sorted.first.location}',
                  ),
                  isThreeLine: true,
                  trailing: Text(
                    'R\$ ${sorted.first.price.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Comparador de preços',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          '${sorted.length} produtos selecionados. '
          'Menor preço primeiro, considerando a unidade informada.',
        ),
        const SizedBox(height: 16),
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
                    'Melhor preço entre os produtos selecionados',
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
                '${sorted[index].unit} • ${sorted[index].location}'
                '${index == 0 ? '\nMenor preço selecionado' : ''}',
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
