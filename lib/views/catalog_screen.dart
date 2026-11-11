import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../adapters/local_storage_service.dart';
import '../controllers/auth_controller.dart';
import '../controllers/catalog_controller.dart';
import '../models/product_model.dart';
import 'comparator_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _search = TextEditingController();

  int _tab = 0;

  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  DateTime? _lastSync;
  bool _checkingConnection = true;

  List<Map<String, dynamic>> _requests = [];
  bool _loadingRequests = false;
  String? _requestError;


  final Map<int, List<Map<String, dynamic>>> _supplierContacts = {};
  final Set<int> _loadingSupplierContacts = {};
  final Map<int, String> _supplierContactErrors = {};

  List<Map<String, dynamic>> _history = [];
  bool _loadingHistory = false;
  String? _historyError;

  @override
  void initState() {
    super.initState();

    _startConnectivityMonitoring();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      context.read<CatalogController>().loadProducts();
      _loadRequests();
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _startConnectivityMonitoring() async {
    final connectivity = Connectivity();

    Future<void> updateStatus(List<ConnectivityResult> results) async {
      final online = results.any((result) => result != ConnectivityResult.none);

      if (!mounted) return;

      setState(() {
        _isOnline = online;
        _checkingConnection = false;
      });

      if (online) {
        await _refreshLastSync();
      }
    }

    try {
      final initial = await connectivity.checkConnectivity();
      await updateStatus(initial);

      _connectivitySubscription = connectivity.onConnectivityChanged.listen((
        results,
      ) {
        updateStatus(results);
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isOnline = false;
        _checkingConnection = false;
      });
    }
  }

  Future<void> _refreshLastSync() async {
    final user = context.read<AuthController>().user;

    if (user == null) return;

    final storage = context.read<LocalStorageService>();

    final dates = await Future.wait<DateTime?>([
      storage.getCacheSavedAt(cacheKey: 'produtor_${user.id}_requests'),
      storage.getCacheSavedAt(cacheKey: 'produtor_${user.id}_history'),
    ]);

    if (!mounted) return;

    DateTime? latest;

    for (final date in dates) {
      if (date != null && (latest == null || date.isAfter(latest))) {
        latest = date;
      }
    }

    setState(() {
      _lastSync = latest;
    });
  }

  String _formatSyncDate(DateTime? date) {
    if (date == null) return 'Ainda não sincronizado';

    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$day/$month/$year às $hour:$minute';
  }

  Widget _buildConnectionBanner() {
    final backgroundColor = _isOnline
        ? Colors.green.shade50
        : Colors.orange.shade50;

    final icon = _isOnline ? Icons.cloud_done : Icons.cloud_off;

    final status = _isOnline
        ? 'Conectividade disponível'
        : 'Sem conexão de rede';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: backgroundColor,
      child: Row(
        children: [
          Icon(
            icon,
            color: _isOnline ? Colors.green.shade700 : Colors.orange.shade800,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Última sincronização: ${_formatSyncDate(_lastSync)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSupplierContacts(int supplierId) async {
    if (supplierId < 1 ||
        _loadingSupplierContacts.contains(supplierId) ||
        _supplierContacts.containsKey(supplierId)) {
      return;
    }

    final token = _token;

    if (token == null) {
      setState(() {
        _supplierContactErrors[supplierId] =
            'Sessão expirada. Faça login novamente.';
      });
      return;
    }

    setState(() {
      _loadingSupplierContacts.add(supplierId);
      _supplierContactErrors.remove(supplierId);
    });

    try {
      final contacts = await context
          .read<AuthController>()
          .api
          .getPublicSupplierContacts(token: token, supplierId: supplierId);

      if (!mounted) return;

      setState(() {
        _supplierContacts[supplierId] = contacts;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _supplierContactErrors[supplierId] = error.toString().replaceFirst(
          'Exception: ',
          '',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingSupplierContacts.remove(supplierId);
        });
      }
    }
  }

  void _showSupplierContacts(int supplierId, String supplierName) {
    final error = _supplierContactErrors[supplierId];
    final contacts = _supplierContacts[supplierId] ?? [];

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Contatos de $supplierName'),
          content: SizedBox(
            width: 400,
            child: error != null
                ? Text(error)
                : contacts.isEmpty
                ? const Text('Este fornecedor ainda não cadastrou contatos.')
                : ListView(
                    shrinkWrap: true,
                    children: contacts.map((contact) {
                      final type = '${contact['contact_type'] ?? 'outro'}';
                      final label = '${contact['label'] ?? ''}';
                      final value = '${contact['contact_value'] ?? ''}';

                      return ListTile(
                        leading: const Icon(Icons.contact_phone_outlined),
                        title: Text(label.isEmpty ? type : label),
                        subtitle: Text(value),
                      );
                    }).toList(),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  String? get _token {
    final token = context.read<AuthController>().user?.token;

    if (token == null || token.isEmpty) return null;

    return token;
  }

  int _id(dynamic value) {
    return int.tryParse('$value') ?? 0;
  }

  String _formatPrice(dynamic value) {
    final price = double.tryParse('$value') ?? 0;

    return 'R\$ ${price.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'Não informado';

    final date = DateTime.tryParse('$value');

    if (date == null) return 'Não informado';

    final local = date.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }

  void _openComparator() {
    final catalog = context.read<CatalogController>();

    if (catalog.selectedProducts.isEmpty) return;

    setState(() {
      _tab = 1;
    });
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _loadRequests() async {
    final auth = context.read<AuthController>();
    final user = auth.user;
    final token = user?.token;

    if (token == null || token.isEmpty || user == null) {
      if (!mounted) return;

      setState(() {
        _requestError = 'Sessão inválida. Faça login novamente.';
        _loadingRequests = false;
      });
      return;
    }

    final api = auth.api;
    final localStorage = context.read<LocalStorageService>();
    final cacheKey = 'produtor_${user.id}_requests';

    setState(() {
      _loadingRequests = true;
      _requestError = null;
    });

    try {
      final requests = await api.getMyQuoteRequests(token: token);
      debugPrint(
        'PRODUTOR REQUESTS: salvando $cacheKey (${requests.length} registros)',
      );

      await localStorage.saveCachedList(cacheKey: cacheKey, items: requests);

      if (!mounted) return;

      setState(() {
        _requests = requests;
        _loadingRequests = false;
      });
    } catch (error) {
      try {
        final cachedRequests = await localStorage.getCachedList(
          cacheKey: cacheKey,
        );

        if (!mounted) return;

        if (cachedRequests.isNotEmpty) {
          setState(() {
            _requests = cachedRequests;
            _requestError = null;
            _loadingRequests = false;
          });
        } else {
          setState(() {
            _requestError = error.toString().replaceFirst('Exception: ', '');
            _loadingRequests = false;
          });
        }
      } catch (cacheError) {
        if (!mounted) return;

        setState(() {
          _requestError = cacheError.toString().replaceFirst('Exception: ', '');
          _loadingRequests = false;
        });
      }
    }
  }

  Future<void> _loadHistory() async {
    final auth = context.read<AuthController>();
    final user = auth.user;
    final token = user?.token;

    if (token == null || token.isEmpty || user == null) {
      if (!mounted) return;

      setState(() {
        _historyError = 'Sessão inválida. Faça login novamente.';
        _loadingHistory = false;
      });
      return;
    }

    final api = auth.api;
    final localStorage = context.read<LocalStorageService>();
    final cacheKey = 'produtor_${user.id}_history';

    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });

    try {
      final history = await api.getProducerHistory(token: token);
      debugPrint(
        'PRODUTOR HISTORY: salvando $cacheKey (${history.length} registros)',
      );

      await localStorage.saveCachedList(cacheKey: cacheKey, items: history);

      if (!mounted) return;

      setState(() {
        _history = history;
        _loadingHistory = false;
      });
    } catch (error) {
      try {
        final cachedHistory = await localStorage.getCachedList(
          cacheKey: cacheKey,
        );

        if (!mounted) return;

        if (cachedHistory.isNotEmpty) {
          setState(() {
            _history = cachedHistory;
            _historyError = null;
            _loadingHistory = false;
          });
        } else {
          setState(() {
            _historyError = error.toString().replaceFirst('Exception: ', '');
            _loadingHistory = false;
          });
        }
      } catch (cacheError) {
        if (!mounted) return;

        setState(() {
          _historyError = cacheError.toString().replaceFirst('Exception: ', '');
          _loadingHistory = false;
        });
      }
    }
  }

  Future<void> _showQuoteDialog(ProductModel product) async {
    final token = _token;

    if (token == null) {
      _showMessage('Sessão inválida. Faça login novamente.', error: true);
      return;
    }

    final api = context.read<AuthController>().api;

    final formKey = GlobalKey<FormState>();
    final quantityController = TextEditingController();
    final locationController = TextEditingController(text: product.location);

    final allowedUnits = ['kg', 'L', 'unidade'];

    String selectedUnit = allowedUnits.contains(product.unit)
        ? product.unit
        : 'kg';

    DateTime deadline = DateTime.now().add(const Duration(days: 7));

    bool saving = false;

    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> submit() async {
              if (saving) return;

              if (!formKey.currentState!.validate()) return;

              final quantity = double.tryParse(
                quantityController.text.trim().replaceAll(',', '.'),
              );

              if (quantity == null) return;

              setDialogState(() {
                saving = true;
              });

              try {
                await api.createQuoteRequest(
                  token: token,
                  productId: product.id,
                  productName: product.name,
                  category: product.category,
                  quantity: quantity,
                  unit: selectedUnit,
                  location: locationController.text.trim(),
                  deadline: deadline,
                );

                if (!dialogContext.mounted) return;

                Navigator.of(dialogContext).pop(true);
              } catch (error) {
                if (!dialogContext.mounted) return;

                setDialogState(() {
                  saving = false;
                });

                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text('Não foi possível criar a cotação: $error'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }

            return AlertDialog(
              title: const Text('Solicitar cotação'),
              content: SizedBox(
                width: 430,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.inventory_2_outlined,
                            color: Colors.green,
                          ),
                          title: Text(product.name),
                          subtitle: Text(product.category),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: quantityController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Quantidade desejada',
                            hintText: 'Ex.: 500',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final text = (value ?? '').trim();

                            final number = double.tryParse(
                              text.replaceAll(',', '.'),
                            );

                            if (number == null ||
                                !number.isFinite ||
                                number <= 0) {
                              return 'Informe uma quantidade válida.';
                            }

                            if (!RegExp(r'^\d+([,.]\d{1,2})?$')
                                .hasMatch(text)) {
                              return 'Use no máximo duas casas decimais.';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedUnit,
                          decoration: const InputDecoration(
                            labelText: 'Unidade de medida',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'kg',
                              child: Text('Quilograma (kg)'),
                            ),
                            DropdownMenuItem(
                              value: 'L',
                              child: Text('Litro (L)'),
                            ),
                            DropdownMenuItem(
                              value: 'unidade',
                              child: Text('Unidade'),
                            ),
                          ],
                          onChanged: saving
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setDialogState(() {
                                      selectedUnit = value;
                                    });
                                  }
                                },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: locationController,
                          maxLength: 180,
                          decoration: const InputDecoration(
                            labelText: 'Local de entrega',
                            hintText: 'Ex.: Cáceres - MT',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Informe o local de entrega.';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.calendar_month),
                          title: const Text('Prazo da cotação'),
                          subtitle: Text(
                            _formatDate(deadline.toIso8601String()),
                          ),
                          trailing: IconButton(
                            tooltip: 'Escolher prazo',
                            icon: const Icon(Icons.edit_calendar),
                            onPressed: saving
                                ? null
                                : () async {
                                    final selected = await showDatePicker(
                                      context: dialogContext,
                                      initialDate: deadline,
                                      firstDate: DateTime.now().add(
                                        const Duration(days: 1),
                                      ),
                                      lastDate: DateTime.now().add(
                                        const Duration(days: 365),
                                      ),
                                    );

                                    if (selected != null &&
                                        dialogContext.mounted) {
                                      setDialogState(() {
                                        deadline = DateTime(
                                          selected.year,
                                          selected.month,
                                          selected.day,
                                          23,
                                          59,
                                        );
                                      });
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: saving ? null : submit,
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(saving ? 'Enviando...' : 'Enviar solicitação'),
                ),
              ],
            );
          },
        );
      },
    );

    quantityController.dispose();
    locationController.dispose();

    if (created == true && mounted) {
      await _loadRequests();

      if (!mounted) return;

      setState(() {
        _tab = 2;
      });

      _showMessage('Solicitação de cotação criada com sucesso!');
    }
  }

  Future<List<Map<String, dynamic>>> _loadProposals({
    required String token,
    required int userId,
    required int requestId,
  }) async {
    final localStorage = context.read<LocalStorageService>();
    final cacheKey = 'produtor_${userId}_proposals_$requestId';

    try {
      final proposals = await context
          .read<AuthController>()
          .api
          .getQuoteProposals(token: token, requestId: requestId);

      await localStorage.saveCachedList(cacheKey: cacheKey, items: proposals);

      return proposals;
    } catch (_) {
      final cachedProposals = await localStorage.getCachedList(
        cacheKey: cacheKey,
      );

      if (cachedProposals.isNotEmpty) {
        return cachedProposals;
      }

      rethrow;
    }
  }

  Future<void> _showProposals(Map<String, dynamic> request) async {
    final token = _token;
    final requestId = _id(request['id']);

    if (token == null || requestId < 1) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Propostas - ${request['product_name'] ?? 'Cotação'}'),
          content: SizedBox(
            width: 520,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _loadProposals(
                token: token,
                userId: context.read<AuthController>().user!.id,
                requestId: requestId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return Text(
                    'Não foi possível carregar as propostas: '
                    '${snapshot.error}',
                  );
                }

                final proposals = snapshot.data ?? <Map<String, dynamic>>[];

                if (proposals.isEmpty) {
                  return const Text(
                    'Ainda não existem propostas para esta solicitação.',
                  );
                }

                return SizedBox(
                  height: 350,
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: proposals.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) {
                      final proposal = proposals[index];

                      final status = '${proposal['status'] ?? 'enviada'}';
                      final proposalId = _id(proposal['id']);
                      final canRespond = status == 'enviada';

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${proposal['supplier'] ?? 'Fornecedor'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _formatPrice(proposal['price']),
                                style: const TextStyle(
                                  fontSize: 20,
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if ('${proposal['notes'] ?? ''}'.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text('${proposal['notes']}'),
                                ),
                              const SizedBox(height: 6),
                              Text('Situação: $status'),
                              if (canRespond)
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    FilledButton(
                                      onPressed: () async {
                                        final success = await _respondProposal(
                                          requestId: requestId,
                                          proposalId: proposalId,
                                          status: 'aceita',
                                        );

                                        if (success && dialogContext.mounted) {
                                          Navigator.of(dialogContext).pop();
                                        }
                                      },
                                      child: const Text('Aceitar'),
                                    ),
                                    OutlinedButton(
                                      onPressed: () async {
                                        final success = await _respondProposal(
                                          requestId: requestId,
                                          proposalId: proposalId,
                                          status: 'recusada',
                                        );

                                        if (success && dialogContext.mounted) {
                                          Navigator.of(dialogContext).pop();
                                        }
                                      },
                                      child: const Text('Recusar'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );

    if (mounted) {
      await _loadRequests();
    }
  }

  Future<bool> _respondProposal({
    required int requestId,
    required int proposalId,
    required String status,
  }) async {
    final token = _token;

    if (token == null) {
      _showMessage('Sessão inválida. Faça login novamente.', error: true);
      return false;
    }

    final api = context.read<AuthController>().api;

    try {
      await api.updateQuoteProposalStatus(
        token: token,
        requestId: requestId,
        proposalId: proposalId,
        status: status,
      );

      _showMessage(
        status == 'aceita'
            ? 'Proposta aceita com sucesso!'
            : 'Proposta recusada.',
      );

      return true;
    } catch (error) {
      _showMessage(
        'Não foi possível atualizar a proposta: $error',
        error: true,
      );

      return false;
    }
  }

  Widget _statusChip(String status) {
    final Color color;
    final String label;

    switch (status) {
      case 'em_negociacao':
        color = Colors.orange;
        label = 'Em negociação';
        break;
      case 'concluida':
        color = Colors.green;
        label = 'Concluída';
        break;
      case 'cancelada':
        color = Colors.red;
        label = 'Cancelada';
        break;
      default:
        color = Colors.blue;
        label = 'Aberta';
    }

    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildHistory() {
    if (_loadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_historyError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 12),
              Text(_historyError!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _loadHistory,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (_history.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadHistory,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 100),
            Icon(Icons.history, size: 56, color: Colors.grey),
            SizedBox(height: 12),
            Center(child: Text('Nenhum registro no histórico comercial.')),
            Center(child: Text('Suas solicitações aparecerão aqui.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _history.length,
        itemBuilder: (context, index) {
          final item = _history[index];
          final status = '${item['status'] ?? 'aberta'}';
          final acceptedPrice = item['accepted_price'];
          final acceptedSupplier = item['accepted_supplier'];

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${item['product_name'] ?? 'Produto'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      _statusChip(status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('${item['category'] ?? 'Categoria não informada'}'),
                  Text('Quantidade: ${item['quantity']} ${item['unit']}'),
                  Text('Entrega: ${item['location'] ?? 'Não informada'}'),
                  Text('Prazo: ${_formatDate(item['deadline'])}'),
                  Text('Solicitada em: ${_formatDate(item['created_at'])}'),
                  Text('Propostas recebidas: ${item['proposals_count'] ?? 0}'),
                  const Divider(),
                  if (acceptedPrice != null) ...[
                    const Text(
                      'Proposta aceita',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _formatPrice(acceptedPrice),
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text('Fornecedor: ${acceptedSupplier ?? 'Não informado'}'),
                  ] else
                    const Text('Nenhuma proposta aceita até o momento.'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRequests() {
    if (_loadingRequests) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_requestError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 12),
              Text(_requestError!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _loadRequests,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (_requests.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadRequests,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 100),
            Icon(Icons.request_quote_outlined, size: 56, color: Colors.grey),
            SizedBox(height: 12),
            Center(
              child: Text('Você ainda não possui solicitações de cotação.'),
            ),
            Center(
              child: Text('Solicite uma cotação diretamente pelo catálogo.'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _requests.length,
        itemBuilder: (context, index) {
          final request = _requests[index];
          final status = '${request['status'] ?? 'aberta'}';

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.request_quote_outlined,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${request['product_name'] ?? 'Produto'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      _statusChip(status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('${request['category'] ?? 'Categoria não informada'}'),
                  Text(
                    'Quantidade: ${request['quantity']} '
                    '${request['unit']}',
                  ),
                  Text('Entrega: ${request['location']}'),
                  Text('Prazo: ${_formatDate(request['deadline'])}'),
                  Text('Criada em: ${_formatDate(request['created_at'])}'),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => _showProposals(request),
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Ver propostas'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
                    trailing: SizedBox(
                      width: 155,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatPrice(product.price),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isCheapest ? Colors.green.shade800 : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 2,
                            children: [
                              IconButton(
                                tooltip: selected
                                    ? 'Remover do comparador'
                                    : 'Adicionar ao comparador',
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(5),
                                onPressed: () {
                                  catalog.toggleProductSelection(product);
                                },
                                icon: Icon(
                                  selected
                                      ? Icons.check_circle
                                      : Icons.compare_arrows,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Solicitar cotação',
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(5),
                                onPressed: () {
                                  _showQuoteDialog(product);
                                },
                                icon: const Icon(Icons.request_quote_outlined),
                              ),
                              IconButton(
  tooltip: 'Contatos do fornecedor',
  visualDensity: VisualDensity.compact,
  constraints: const BoxConstraints(),
  padding: const EdgeInsets.all(5),
  onPressed: () async {
    final supplierId = product.supplierId;

    await _loadSupplierContacts(supplierId);

    if (!mounted) return;

    _showSupplierContacts(supplierId, product.supplier);
  },
  icon: const Icon(Icons.contact_phone_outlined),
),
                            ],
                          ),
                        ],
                      ),
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final catalog = context.watch<CatalogController>();

    final user = auth.user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Sessão não encontrada. Faça login.')),
      );
    }

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
          if (_checkingConnection)
            const LinearProgressIndicator()
          else
            _buildConnectionBanner(),

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
            child: switch (_tab) {
              1 => ComparatorScreen(products: catalog.selectedProducts),
              2 => _buildRequests(),
              3 => _buildHistory(),
              _ => _buildCatalog(context, catalog),
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) {
          setState(() {
            _tab = index;
          });

          if (index == 2) {
            _loadRequests();
          }

          if (index == 3) {
            _loadHistory();
          }
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
          const NavigationDestination(
            icon: Icon(Icons.request_quote_outlined),
            selectedIcon: Icon(Icons.request_quote),
            label: 'Minhas cotações',
          ),
          const NavigationDestination(
            icon: Icon(Icons.history),
            selectedIcon: Icon(Icons.history),
            label: 'Histórico',
          ),
        ],
      ),
    );
  }
}
