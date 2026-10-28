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
            child: Center(child: Text(user.name)),
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
                ? ComparatorScreen(products: catalog.sortedProducts)
                : _buildCatalog(context, catalog),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) {
          setState(() => _tab = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Catálogo',
          ),
          NavigationDestination(
            icon: Icon(Icons.compare_arrows),
            label: 'Comparador',
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

    return RefreshIndicator(
      onRefresh: catalog.loadProducts,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        itemCount: catalog.sortedProducts.length,
        itemBuilder: (context, index) {
          final product = catalog.sortedProducts[index];
          final isCheapest = product.id == catalog.cheapestProduct?.id;

          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isCheapest ? Colors.green.shade100 : null,
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: isCheapest ? Colors.green.shade800 : null,
                ),
              ),
              title: Text(product.name),
              subtitle: Text(
                '${product.category}\n'
                '${product.supplier} • ${product.location}\n'
                '${product.unit}'
                '${isCheapest ? '\nMenor preço encontrado' : ''}',
              ),
              isThreeLine: true,
              trailing: Text(
                'R\$ ${product.price.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isCheapest ? Colors.green.shade800 : null,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
