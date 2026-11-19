import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../adapters/local_storage_service.dart';
import '../controllers/auth_controller.dart';
import '../models/product_model.dart';
import '../utils/app_feedback.dart';

class SupplierScreen extends StatefulWidget {
  const SupplierScreen({super.key});

  @override
  State<SupplierScreen> createState() => _SupplierScreenState();
}

class _SupplierScreenState extends State<SupplierScreen> {
  int _selectedTab = 0;
  Future<List<Map<String, dynamic>>>? _contactsFuture;
  Future<List<ProductModel>>? _offersFuture;
  Future<List<Map<String, dynamic>>>? _requestsFuture;
  Future<List<Map<String, dynamic>>>? _historyFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_offersFuture == null ||
        _requestsFuture == null ||
        _historyFuture == null) {
      final auth = context.read<AuthController>();
      final user = auth.user;
      final token = user?.token;

      if (token == null || token.isEmpty || user == null) {
        final error = Future<List<ProductModel>>.error(
          Exception('Sessão inválida. Faça login novamente.'),
        );

        _offersFuture ??= error;
        _requestsFuture ??= Future<List<Map<String, dynamic>>>.error(
          Exception('Sessão inválida. Faça login novamente.'),
        );
        _historyFuture ??= Future<List<Map<String, dynamic>>>.error(
          Exception('Sessão inválida. Faça login novamente.'),
        );
      } else {
        _offersFuture ??= _loadSupplierOffers(token: token, userId: user.id);

        _requestsFuture ??= _loadOpenQuoteRequests(
          token: token,
          userId: user.id,
        );

        _historyFuture ??= _loadSupplierHistory(token: token, userId: user.id);
        _contactsFuture ??= _loadSupplierContacts(token: token);
      }
    }
  }

  // ============================================================
  // CARREGAMENTO DOS CONTATOS DO FORNECEDOR
  // ============================================================

  Future<List<Map<String, dynamic>>> _loadSupplierContacts({
    required String token,
  }) async {
    return context.read<AuthController>().api.getSupplierContacts(token: token);
  }

  Future<void> _refreshContacts() async {
    final token = context.read<AuthController>().user?.token;

    if (token == null || token.isEmpty) return;

    final future = _loadSupplierContacts(token: token);

    setState(() {
      _contactsFuture = future;
    });

    try {
      await future;
    } catch (_) {
      // O erro será apresentado na seção de contatos.
    }
  }

  // ============================================================
  // CARREGAMENTO E CACHE DAS OFERTAS
  // ============================================================

  Future<List<ProductModel>> _loadSupplierOffers({
    required String token,
    required int userId,
  }) async {
    final localStorage = context.read<LocalStorageService>();
    final cacheKey = 'fornecedor_${userId}_offers';

    try {
      final offers = await context.read<AuthController>().api.getMyProducts(
        token,
      );

      final items = offers
          .map(
            (product) => <String, dynamic>{
              'id': product.id,
              'name': product.name,
              'category': product.category,
              'unit': product.unit,
              'price': product.price,
              'supplier': product.supplier,
              'location': product.location,
            },
          )
          .toList();

      await localStorage.saveCachedList(cacheKey: cacheKey, items: items);

      return offers;
    } catch (_) {
      final cachedOffers = await localStorage.getCachedList(cacheKey: cacheKey);

      if (cachedOffers.isNotEmpty) {
        return cachedOffers.map(ProductModel.fromJson).toList();
      }

      rethrow;
    }
  }

  Future<void> _refreshOffers() async {
    final auth = context.read<AuthController>();
    final user = auth.user;
    final token = user?.token;

    if (token == null || token.isEmpty || user == null) return;

    final future = _loadSupplierOffers(token: token, userId: user.id);

    setState(() {
      _offersFuture = future;
    });

    try {
      await future;
    } catch (_) {
      // O erro será apresentado na tela.
    }
  }

  // ============================================================
  // CARREGAMENTO E CACHE DAS SOLICITAÇÕES DE COTAÇÃO
  // ============================================================

  Future<List<Map<String, dynamic>>> _loadOpenQuoteRequests({
    required String token,
    required int userId,
  }) async {
    final localStorage = context.read<LocalStorageService>();
    final cacheKey = 'fornecedor_${userId}_open_requests';

    try {
      final requests = await context
          .read<AuthController>()
          .api
          .getOpenQuoteRequests(token: token);

      await localStorage.saveCachedList(cacheKey: cacheKey, items: requests);

      return requests;
    } catch (_) {
      final cachedRequests = await localStorage.getCachedList(
        cacheKey: cacheKey,
      );

      if (cachedRequests.isNotEmpty) {
        return cachedRequests;
      }

      rethrow;
    }
  }

  Future<void> _refreshRequests() async {
    final auth = context.read<AuthController>();
    final user = auth.user;
    final token = user?.token;

    if (token == null || token.isEmpty || user == null) return;

    final future = _loadOpenQuoteRequests(token: token, userId: user.id);

    setState(() {
      _requestsFuture = future;
    });

    try {
      await future;
    } catch (_) {
      // O erro será apresentado na tela.
    }
  }

  // ============================================================
  // CARREGAMENTO E CACHE DO HISTÓRICO
  // ============================================================

  Future<List<Map<String, dynamic>>> _loadSupplierHistory({
    required String token,
    required int userId,
  }) async {
    final localStorage = context.read<LocalStorageService>();
    final cacheKey = 'fornecedor_${userId}_history';

    try {
      final history = await context
          .read<AuthController>()
          .api
          .getSupplierHistory(token: token);

      await localStorage.saveCachedList(cacheKey: cacheKey, items: history);

      return history;
    } catch (_) {
      final cachedHistory = await localStorage.getCachedList(
        cacheKey: cacheKey,
      );

      if (cachedHistory.isNotEmpty) {
        return cachedHistory;
      }

      rethrow;
    }
  }

  Future<void> _refreshHistory() async {
    final auth = context.read<AuthController>();
    final user = auth.user;
    final token = user?.token;

    if (token == null || token.isEmpty || user == null) return;

    final future = _loadSupplierHistory(token: token, userId: user.id);

    setState(() {
      _historyFuture = future;
    });

    try {
      await future;
    } catch (_) {
      // O erro será apresentado na tela.
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _refreshOffers(),
      _refreshRequests(),
      _refreshHistory(),
      _refreshContacts(),
    ]);
  }

  String _formatPrice(double price) {
    return 'R\$ ${price.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'Não informada';

    final date = DateTime.tryParse(value.toString());
    if (date == null) return value.toString();

    final localDate = date.toLocal();

    return '${localDate.day.toString().padLeft(2, '0')}/'
        '${localDate.month.toString().padLeft(2, '0')}/'
        '${localDate.year}';
  }

  // ============================================================
  // CADASTRO E EDIÇÃO DE OFERTAS
  // ============================================================

  Future<void> _showOfferDialog({ProductModel? product}) async {
    final auth = context.read<AuthController>();
    final token = auth.user?.token;

    if (token == null || token.isEmpty) {
      AppFeedback.error(context, 'Sua sessão expirou. Entre novamente.');
      return;
    }

    final isEditing = product != null;
    final formKey = GlobalKey<FormState>();

    final nameController = TextEditingController(text: product?.name ?? '');
    final categoryController = TextEditingController(
      text: product?.category ?? '',
    );
    final priceController = TextEditingController(
      text: product?.price.toStringAsFixed(2).replaceAll('.', ',') ?? '',
    );
    final packageQuantityController = TextEditingController(
      text: product?.packageQuantity?.toString() ?? '',
    );
    final locationController = TextEditingController(
      text: product?.location ?? '',
    );

    String selectedUnit = product?.unit ?? 'kg';
    bool saving = false;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> saveOffer() async {
              if (saving) return;
              if (!formKey.currentState!.validate()) return;

              final price = double.tryParse(
                priceController.text.trim().replaceAll(',', '.'),
              );

              final packageQuantity = double.tryParse(
                packageQuantityController.text.trim().replaceAll(',', '.'),
              );

              if (price == null || packageQuantity == null) return;

              setDialogState(() {
                saving = true;
              });

              try {
                if (isEditing) {
                  await auth.api.updateProduct(
                    packageQuantity: packageQuantity,
                    token: token,
                    id: product.id,
                    name: nameController.text.trim(),
                    category: categoryController.text.trim(),
                    unit: selectedUnit,
                    price: price,
                    location: locationController.text.trim(),
                  );
                } else {
                  await auth.api.createProduct(
                    packageQuantity: packageQuantity,
                    token: token,
                    name: nameController.text.trim(),
                    category: categoryController.text.trim(),
                    unit: selectedUnit,
                    price: price,
                    location: locationController.text.trim(),
                  );
                }

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              } catch (error) {
                if (dialogContext.mounted) {
                  setDialogState(() {
                    saving = false;
                  });

                  AppFeedback.error(
                    dialogContext,
                    'Não foi possível salvar a oferta. ${AppFeedback.friendlyError(error)}',
                  );
                }
              }
            }

            return AlertDialog(
              title: Text(
                isEditing ? 'Editar oferta' : 'Cadastrar nova oferta',
              ),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Nome do produto',
                            prefixIcon: Icon(Icons.agriculture),
                            border: OutlineInputBorder(),
                          ),
                          maxLength: 180,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Informe o nome do produto.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: categoryController,
                          decoration: const InputDecoration(
                            labelText: 'Categoria',
                            hintText: 'Ex.: Fertilizantes, Grãos, Insumos',
                            prefixIcon: Icon(Icons.category_outlined),
                            border: OutlineInputBorder(),
                          ),
                          maxLength: 80,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Informe a categoria.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedUnit,
                          decoration: const InputDecoration(
                            labelText: 'Unidade de medida',
                            prefixIcon: Icon(Icons.straighten),
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
                          controller: priceController,
                          decoration: const InputDecoration(
                            labelText: 'Preço total da embalagem',
                            hintText: 'Ex.: 125,50',
                            helperText: 'O aplicativo calculará automaticamente o preço unitário.',
                            prefixText: 'R\$ ',
                            prefixIcon: Icon(Icons.attach_money),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (value) {
                            final text = (value ?? '').trim();
                            final price = double.tryParse(
                              text.replaceAll(',', '.'),
                            );

                            if (price == null || !price.isFinite) {
                              return 'Informe um preço válido.';
                            }

                            if (price < 0) {
                              return 'O preço não pode ser negativo.';
                            }

                            if (!RegExp(r'^\d+([,.]\d{1,2})?$')
                                .hasMatch(text)) {
                              return 'Use no máximo duas casas decimais.';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: packageQuantityController,
                          decoration: InputDecoration(
                            labelText:
                                'Quantidade da embalagem ($selectedUnit)',
                            hintText: selectedUnit == 'kg'
                                ? 'Ex.: 50'
                                : selectedUnit == 'L'
                                ? 'Ex.: 20'
                                : 'Ex.: 1',
                            helperText: 'Informe quanto existe dentro de cada embalagem.',
                            prefixIcon: const Icon(Icons.inventory_2_outlined),
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (value) {
                            final text = (value ?? '').trim();
                            final quantity = double.tryParse(
                              text.replaceAll(',', '.'),
                            );

                            if (quantity == null || !quantity.isFinite) {
                              return 'Informe uma quantidade válida.';
                            }

                            if (quantity <= 0) {
                              return 'A quantidade deve ser maior que zero.';
                            }

                            if (!RegExp(r'^\d+([,.]\d{1,3})?$')
                                .hasMatch(text)) {
                              return 'Use no máximo três casas decimais.';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: locationController,
                          decoration: const InputDecoration(
                            labelText: 'Localização',
                            hintText: 'Ex.: Cáceres - MT',
                            prefixIcon: Icon(Icons.location_on_outlined),
                            border: OutlineInputBorder(),
                          ),
                          maxLength: 180,
                          validator: (value) {
                            if ((value ?? '').trim().length > 180) {
                              return 'Máximo de 180 caracteres.';
                            }
                            return null;
                          },
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
                  onPressed: saving ? null : saveOffer,
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    saving
                        ? 'Salvando...'
                        : isEditing
                        ? 'Salvar alterações'
                        : 'Cadastrar oferta',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    categoryController.dispose();
    priceController.dispose();
    locationController.dispose();
    packageQuantityController.dispose();

    if (saved == true && mounted) {
      await _refreshOffers();

      if (!mounted) return;

      AppFeedback.success(
        context,
        isEditing
            ? 'Oferta atualizada com sucesso!'
            : 'Oferta cadastrada com sucesso!',
      );
    }
  }

  // ============================================================
  // CADASTRO E EDIÇÃO DE CONTATOS
  // ============================================================

  Future<void> _showContactDialog({Map<String, dynamic>? contact}) async {
    final auth = context.read<AuthController>();
    final token = auth.user?.token;

    if (token == null || token.isEmpty) {
      AppFeedback.error(context, 'Sua sessão expirou. Entre novamente.');
      return;
    }

    final isEditing = contact != null;
    final formKey = GlobalKey<FormState>();
    final labelController = TextEditingController(
      text: contact?['label']?.toString() ?? '',
    );
    final valueController = TextEditingController(
      text: contact?['contact_value']?.toString() ?? '',
    );

    const contactTypes = {
      'telefone': 'Telefone',
      'whatsapp': 'WhatsApp',
      'email': 'E-mail',
      'site': 'Site',
      'instagram': 'Instagram',
      'outro': 'Outro',
    };

    String selectedType = contact?['contact_type']?.toString() ?? 'telefone';
    bool saving = false;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> saveContact() async {
              if (saving || !formKey.currentState!.validate()) return;

              setDialogState(() => saving = true);

              try {
                if (isEditing) {
                  await auth.api.updateSupplierContact(
                    token: token,
                    contactId: int.parse(contact['id'].toString()),
                    contactType: selectedType,
                    contactValue: valueController.text.trim(),
                    label: labelController.text.trim(),
                  );
                } else {
                  await auth.api.createSupplierContact(
                    token: token,
                    contactType: selectedType,
                    contactValue: valueController.text.trim(),
                    label: labelController.text.trim(),
                  );
                }

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              } catch (error) {
                if (dialogContext.mounted) {
                  setDialogState(() => saving = false);

                  AppFeedback.error(
                    dialogContext,
                    'Não foi possível salvar o contato. ${AppFeedback.friendlyError(error)}',
                  );
                }
              }
            }

            return AlertDialog(
              title: Text(isEditing ? 'Editar contato' : 'Adicionar contato'),
              content: SizedBox(
                width: 450,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: selectedType,
                          decoration: const InputDecoration(
                            labelText: 'Tipo de contato',
                            prefixIcon: Icon(Icons.contact_phone_outlined),
                            border: OutlineInputBorder(),
                          ),
                          items: contactTypes.entries.map((entry) {
                            return DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            );
                          }).toList(),
                          onChanged: saving
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setDialogState(() => selectedType = value);
                                  }
                                },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: labelController,
                          decoration: const InputDecoration(
                            labelText: 'Rótulo (opcional)',
                            hintText: 'Ex.: Comercial, Atendimento',
                            prefixIcon: Icon(Icons.label_outline),
                            border: OutlineInputBorder(),
                          ),
                          maxLength: 60,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: valueController,
                          decoration: const InputDecoration(
                            labelText: 'Contato',
                            hintText: 'Informe telefone, e-mail ou endereço',
                            prefixIcon: Icon(Icons.link),
                            border: OutlineInputBorder(),
                          ),
                          maxLength: 254,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Informe o contato.';
                            }

                            if (selectedType == 'email' &&
                                !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                    .hasMatch(value.trim())) {
                              return 'Informe um e-mail válido.';
                            }

                            return null;
                          },
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
                  onPressed: saving ? null : saveContact,
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    saving
                        ? 'Salvando...'
                        : isEditing
                        ? 'Salvar alterações'
                        : 'Cadastrar contato',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    labelController.dispose();
    valueController.dispose();

    if (saved == true && mounted) {
      await _refreshContacts();

      if (!mounted) return;

      AppFeedback.success(
        context,
        isEditing
            ? 'Contato atualizado com sucesso!'
            : 'Contato cadastrado com sucesso!',
      );
    }
  }

  // ============================================================
  // EXCLUSÃO DE OFERTAS
  // ============================================================

  Future<void> _deleteOffer(ProductModel product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Excluir oferta'),
          content: Text(
            'Deseja realmente excluir "${product.name}"?\n\n'
            'A oferta deixará de aparecer como ativa.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final auth = context.read<AuthController>();
    final token = auth.user?.token;

    if (token == null || token.isEmpty) {
      AppFeedback.error(context, 'Sua sessão expirou. Entre novamente.');
      return;
    }

    try {
      await auth.api.deleteProduct(token: token, id: product.id);

      if (!mounted) return;

      await _refreshOffers();

      if (!mounted) return;

      AppFeedback.success(context, 'Oferta excluída com sucesso!');
    } catch (error) {
      if (!mounted) return;

      AppFeedback.error(
        context,
        'Não foi possível excluir a oferta. ${AppFeedback.friendlyError(error)}',
      );
    }
  }

  // ============================================================
  // ENVIO DE PROPOSTAS
  // ============================================================

  Future<void> _showProposalDialog(Map<String, dynamic> request) async {
    final auth = context.read<AuthController>();
    final token = auth.user?.token;

    if (token == null || token.isEmpty) {
      AppFeedback.error(context, 'Sua sessão expirou. Entre novamente.');
      return;
    }

    final requestId = int.tryParse('${request['id']}');

    if (requestId == null) {
      AppFeedback.error(context, 'Não foi possível identificar a solicitação.');
      return;
    }

    final formKey = GlobalKey<FormState>();
    final priceController = TextEditingController();
    final notesController = TextEditingController();

    bool sending = false;

    final sent = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> sendProposal() async {
              if (sending) return;
              if (!formKey.currentState!.validate()) return;

              final price = double.tryParse(
                priceController.text.trim().replaceAll(',', '.'),
              );

              if (price == null) return;

              setDialogState(() {
                sending = true;
              });

              try {
                await auth.api.createQuoteProposal(
                  token: token,
                  requestId: requestId,
                  price: price,
                  notes: notesController.text.trim(),
                );

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              } catch (error) {
                if (!dialogContext.mounted) return;

                setDialogState(() {
                  sending = false;
                });

                AppFeedback.error(
                  dialogContext,
                  'Não foi possível enviar a proposta. ${AppFeedback.friendlyError(error)}',
                );
              }
            }

            return AlertDialog(
              title: const Text('Enviar proposta'),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${request['product_name'] ?? 'Produto'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Quantidade: ${request['quantity'] ?? '-'} '
                          '${request['unit'] ?? ''}',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Localização: '
                          '${request['location'] ?? 'Não informada'}',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: priceController,
                          decoration: const InputDecoration(
                            labelText: 'Preço total da proposta',
                            hintText: 'Ex.: 1500,00',
                            prefixText: 'R\$ ',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (value) {
                            final text = (value ?? '').trim();
                            final price = double.tryParse(
                              text.replaceAll(',', '.'),
                            );

                            if (price == null || !price.isFinite) {
                              return 'Informe um preço válido.';
                            }

                            if (price < 0) {
                              return 'O preço não pode ser negativo.';
                            }

                            if (!RegExp(r'^\d+([,.]\d{1,2})?$')
                                .hasMatch(text)) {
                              return 'Use no máximo duas casas decimais.';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: notesController,
                          decoration: const InputDecoration(
                            labelText: 'Observações',
                            hintText:
                                'Informe condições de entrega, pagamento etc.',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                          maxLines: 4,
                          maxLength: 1000,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: sending
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: sending ? null : sendProposal,
                  icon: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(sending ? 'Enviando...' : 'Enviar proposta'),
                ),
              ],
            );
          },
        );
      },
    );

    priceController.dispose();
    notesController.dispose();

    if (sent == true && mounted) {
      await _refreshRequests();

      if (!mounted) return;

      AppFeedback.success(context, 'Proposta enviada com sucesso!');
    }
  }

  // ============================================================
  // EXIBIÇÃO DO HISTÓRICO
  // ============================================================

  Widget _buildHistory() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _historyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 36),
                const SizedBox(height: 8),
                const Text(
                  'Não foi possível carregar seu histórico de ofertas.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _refreshHistory,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          );
        }

        final history = snapshot.data ?? [];

        if (history.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(Icons.history, size: 42, color: Colors.grey),
                SizedBox(height: 8),
                Text(
                  'Você ainda não possui propostas no histórico.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Column(
          children: history.map((item) {
            final priceValue = item['price'];
            final price = priceValue is num
                ? priceValue.toDouble()
                : double.tryParse('$priceValue');

            final status = (item['proposal_status'] ?? 'pendente')
                .toString()
                .toLowerCase();

            final statusLabel = switch (status) {
              'aceita' => 'Aceita',
              'recusada' => 'Recusada',
              'pendente' => 'Pendente',
              _ => status.isEmpty ? 'Não informado' : status,
            };

            final statusColor = switch (status) {
              'aceita' => Colors.green,
              'recusada' => Colors.red,
              _ => Colors.orange,
            };

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        Chip(
                          label: Text(statusLabel),
                          backgroundColor: statusColor.withValues(alpha: 0.12),
                          side: BorderSide(color: statusColor),
                          labelStyle: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Categoria: ${item['category'] ?? 'Não informada'}'),
                    Text(
                      'Quantidade: ${item['quantity'] ?? '-'} '
                      '${item['unit'] ?? ''}',
                    ),
                    Text('Produtor: ${item['producer'] ?? 'Não informado'}'),
                    Text('Localização: ${item['location'] ?? 'Não informada'}'),
                    Text(
                      'Prazo da solicitação: '
                      '${_formatDate(item['deadline'])}',
                    ),
                    Text(
                      'Proposta enviada: '
                      '${_formatDate(item['proposal_created_at'])}',
                    ),
                    if (price != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Valor proposto: ${_formatPrice(price)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    if ((item['notes'] ?? '').toString().trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('Observações: ${item['notes']}'),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ============================================================
  // EXIBIÇÃO E EXCLUSÃO DOS CONTATOS
  // ============================================================

  Future<void> _deleteContact(Map<String, dynamic> contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir contato'),
        content: Text(
          'Deseja realmente excluir "${contact['contact_value']}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final auth = context.read<AuthController>();
    final token = auth.user?.token;

    if (token == null || token.isEmpty) {
      AppFeedback.error(context, 'Sua sessão expirou. Entre novamente.');
      return;
    }

    try {
      await auth.api.deleteSupplierContact(
        token: token,
        contactId: int.parse(contact['id'].toString()),
      );

      await _refreshContacts();

      if (!mounted) return;

      AppFeedback.success(context, 'Contato excluído com sucesso.');
    } catch (error) {
      if (!mounted) return;

      AppFeedback.error(
        context,
        'Não foi possível excluir o contato. ${AppFeedback.friendlyError(error)}',
      );
    }
  }

  Widget _buildContacts() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _contactsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 36),
                const SizedBox(height: 8),
                const Text(
                  'Não foi possível carregar seus contatos.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _refreshContacts,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          );
        }

        final contacts = snapshot.data ?? [];

        if (contacts.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  Icons.contact_phone_outlined,
                  size: 42,
                  color: Colors.grey,
                ),
                SizedBox(height: 8),
                Text(
                  'Você ainda não cadastrou contatos.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        const contactLabels = {
          'telefone': 'Telefone',
          'whatsapp': 'WhatsApp',
          'email': 'E-mail',
          'site': 'Site',
          'instagram': 'Instagram',
          'outro': 'Outro',
        };

        const contactIcons = {
          'telefone': Icons.phone,
          'whatsapp': Icons.chat,
          'email': Icons.email_outlined,
          'site': Icons.language,
          'instagram': Icons.camera_alt_outlined,
          'outro': Icons.contact_page_outlined,
        };

        return Column(
          children: contacts.map((contact) {
            final type = (contact['contact_type'] ?? 'outro').toString();
            final label = (contact['label'] ?? '').toString().trim();
            final value = (contact['contact_value'] ?? '').toString();

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: ListTile(
                leading: Icon(
                  contactIcons[type] ?? Icons.contact_page_outlined,
                  color: Colors.green,
                ),
                title: Text(
                  label.isNotEmpty ? label : (contactLabels[type] ?? 'Contato'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(value),
                isThreeLine: false,
                trailing: PopupMenuButton<String>(
                  tooltip: 'Opções do contato',
                  onSelected: (action) {
                    if (action == 'edit') {
                      _showContactDialog(contact: contact);
                    } else if (action == 'delete') {
                      _deleteContact(contact);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Editar'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text('Excluir'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ============================================================
  // EXIBIÇÃO DAS OFERTAS
  // ============================================================

  Widget _buildOffers() {
    return FutureBuilder<List<ProductModel>>(
      future: _offersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 36),
                const SizedBox(height: 8),
                const Text(
                  'Não foi possível carregar suas ofertas.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _refreshOffers,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          );
        }

        final products = snapshot.data ?? <ProductModel>[];

        if (products.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(Icons.inventory_2_outlined, size: 42, color: Colors.grey),
                SizedBox(height: 8),
                Text('Você ainda não possui ofertas cadastradas.'),
              ],
            ),
          );
        }

        return Column(
          children: products.map((product) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  leading: const CircleAvatar(child: Icon(Icons.agriculture)),
                  title: Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 2),
                      Text(
                        '${product.category} • ${product.unit}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (product.location.trim().isNotEmpty)
                        Text(
                          product.location,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      const SizedBox(height: 4),
                      Text(
                        _formatPrice(product.price),
                        softWrap: false,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Editar oferta',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () {
                          _showOfferDialog(product: product);
                        },
                      ),
                      IconButton(
                        tooltip: 'Excluir oferta',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () {
                          _deleteOffer(product);
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
              ],
            );
          }).toList(),
        );
      },
    );
  }

  // ============================================================
  // EXIBIÇÃO DAS SOLICITAÇÕES DE COTAÇÃO
  // ============================================================

  Widget _buildRequests() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _requestsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 36),
                const SizedBox(height: 8),
                const Text(
                  'Não foi possível carregar as solicitações.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _refreshRequests,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          );
        }

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(Icons.inbox_outlined, size: 42, color: Colors.grey),
                SizedBox(height: 8),
                Text('Não há solicitações de cotação abertas no momento.'),
              ],
            ),
          );
        }

        return Column(
          children: requests.map((request) {
            final quantity = request['quantity'] ?? '-';
            final unit = request['unit'] ?? '';
            final deadline = _formatDate(request['deadline']);

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Categoria: ${request['category'] ?? 'Não informada'}',
                    ),
                    Text('Quantidade: $quantity $unit'),
                    Text(
                      'Localização: '
                      '${request['location'] ?? 'Não informada'}',
                    ),
                    Text('Prazo para cotação: $deadline'),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: () {
                          _showProposalDialog(request);
                        },
                        icon: const Icon(Icons.send),
                        label: const Text('Enviar proposta'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ============================================================
  // INTERFACE PRINCIPAL
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;

    final sections = [
      (
        title: 'Minhas ofertas',
        subtitle: 'Produtos cadastrados por você.',
        icon: Icons.inventory_2_outlined,
        refresh: _refreshOffers,
        content: _buildOffers(),
        action: FilledButton.icon(
          onPressed: () => _showOfferDialog(),
          icon: const Icon(Icons.add),
          label: const Text('Cadastrar nova oferta'),
        ),
      ),
      (
        title: 'Solicitações de cotação',
        subtitle: 'Consulte pedidos e envie suas propostas.',
        icon: Icons.request_quote_outlined,
        refresh: _refreshRequests,
        content: _buildRequests(),
        action: const SizedBox.shrink(),
      ),
      (
        title: 'Meus contatos',
        subtitle: 'Gerencie os canais de atendimento aos produtores.',
        icon: Icons.contact_phone_outlined,
        refresh: _refreshContacts,
        content: _buildContacts(),
        action: FilledButton.icon(
          onPressed: () => _showContactDialog(),
          icon: const Icon(Icons.add),
          label: const Text('Adicionar contato'),
        ),
      ),
      (
        title: 'Histórico de ofertas',
        subtitle: 'Consulte suas propostas e respectivos status.',
        icon: Icons.history,
        refresh: _refreshHistory,
        content: _buildHistory(),
        action: const SizedBox.shrink(),
      ),
    ];

    final section = sections[_selectedTab];

    return Scaffold(
      appBar: AppBar(
        title: const Text('AgroMarkt - Fornecedor'),
        actions: [
          IconButton(
            tooltip: 'Atualizar tudo',
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAll,
          ),
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: auth.logout,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Icon(Icons.storefront, size: 42, color: Colors.green),
                const SizedBox(height: 8),
                const Text(
                  'Área do Fornecedor',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bem-vindo${user?.name.isNotEmpty == true ? ', ${user!.name}' : ''}!',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ListTile(
                                leading: Icon(
                                  section.icon,
                                  color: Colors.green,
                                ),
                                title: Text(section.title),
                                subtitle: Text(section.subtitle),
                                trailing: IconButton(
                                  tooltip: 'Atualizar seção',
                                  icon: const Icon(Icons.refresh),
                                  onPressed: section.refresh,
                                ),
                              ),
                              if (_selectedTab == 0 || _selectedTab == 2) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  child: section.action,
                                ),
                              ],
                              const Divider(height: 1),
                              section.content,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) {
          setState(() {
            _selectedTab = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Ofertas',
          ),
          NavigationDestination(
            icon: Icon(Icons.request_quote_outlined),
            selectedIcon: Icon(Icons.request_quote),
            label: 'Cotações',
          ),
          NavigationDestination(
            icon: Icon(Icons.contact_phone_outlined),
            selectedIcon: Icon(Icons.contact_phone),
            label: 'Contatos',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            selectedIcon: Icon(Icons.history),
            label: 'Histórico',
          ),
        ],
      ),
    );
  }
}
