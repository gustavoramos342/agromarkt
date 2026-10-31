import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../controllers/catalog_controller.dart';
import 'comparator_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _search = TextEditingController();
  int _tab = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CatalogController>().loadProducts();
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openComparator() {
    setState(() => _tab = 1);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final catalog = context.watch<CatalogController>();

    final user = auth.user!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AgroMarkt'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(user.name, overflow: TextOverflow.ellipsis),
            ),
          ),
          IconButton(
            tooltip: 'Sair',
            onPressed: auth.logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_tab == 0)
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _search,
                onChanged: catalog.search,
                decoration: InputDecoration(
                  labelText: 'Buscar produtos, categorias ou fornecedores',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    onPressed: () {
                      _search.clear();
                      catalog.search('');
                    },
                    icon: const Icon(Icons.clear),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          Expanded(
            child: _tab == 1
                ? ComparatorScreen(products: catalog.selectedProducts)
                : _buildCatalog(context, catalog),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) {
          setState(() => _tab = index);
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Catálogo',
          ),
          NavigationDestination(
            icon: const Icon(Icons.compare_arrows),
            label: catalog.selectedCount > 0
                ? 'Comparador (${catalog.selectedCount})'
                : 'Comparador',
          ),
        ],
      ),
    );
  }

  Widget _buildCatalog(BuildContext context, CatalogController catalog) {
    if (catalog.loading && catalog.products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (catalog.error != null && catalog.products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(catalog.error!),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: catalog.loadProducts,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (catalog.products.isEmpty) {
      return const Center(child: Text('Nenhum produto encontrado.'));
    }

    return Column(
      children: [
        if (catalog.selectedCount > 0)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  '${catalog.selectedCount} produto(s) selecionado(s)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Wrap(
                  spacing: 4,
                  children: [
                    TextButton(
                      onPressed: catalog.clearSelection,
                      child: const Text('Limpar'),
                    ),
                    FilledButton.icon(
                      onPressed: _openComparator,
                      icon: const Icon(Icons.compare_arrows),
                      label: const Text('Comparar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: catalog.loadProducts,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              itemCount: catalog.sortedProducts.length,
              itemBuilder: (context, index) {
                final product = catalog.sortedProducts[index];

                final isCheapest = product.id == catalog.cheapestProduct?.id;

                final selected = catalog.isSelected(product);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  color: selected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minVerticalPadding: 8,
                    leading: CircleAvatar(
                      backgroundColor: isCheapest
                          ? Colors.green.shade100
                          : null,
                      child: Icon(
                        selected ? Icons.check : Icons.inventory_2_outlined,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : isCheapest
                            ? Colors.green.shade800
                            : null,
                      ),
                    ),
                    title: Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${product.category}\n'
                      '${product.supplier} • ${product.location}\n'
                      '${product.unit}'
                      '${isCheapest ? '\nMenor preço encontrado' : ''}',
                    ),
                    isThreeLine: true,
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'R\$ ${product.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isCheapest ? Colors.green.shade800 : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 28,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              minimumSize: const Size(0, 28),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () {
                              catalog.toggleProductSelection(product);
                            },
                            child: Text(selected ? 'Remover' : 'Comparar'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
