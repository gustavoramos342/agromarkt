import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/product_model.dart';
import '../models/user_model.dart';

class ApiService {
  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  // Usuários fictícios para testes e apresentações.
  static const _demoUsers = [
    {
      'id': 1,
      'name': 'Produtor Demo',
      'email': 'produtor@agro.com',
      'password': '123456',
      'role': 'produtor',
    },
    {
      'id': 2,
      'name': 'Fornecedor Demo',
      'email': 'fornecedor@agro.com',
      'password': '123456',
      'role': 'fornecedor',
    },
    {
      'id': 3,
      'name': 'Administrador Demo',
      'email': 'admin@agro.com',
      'password': '123456',
      'role': 'admin',
    },
  ];

  // Produtos fictícios para demonstração do catálogo.
  static const _demoProducts = [
    {
      'id': 1,
      'name': 'Milho',
      'category': 'Grãos',
      'unit': 'saco de 60 kg',
      'price': 75.00,
      'supplier': 'Fornecedor Campo Verde',
      'location': 'Mato Grosso',
    },
    {
      'id': 2,
      'name': 'Milho',
      'category': 'Grãos',
      'unit': 'saco de 60 kg',
      'price': 71.50,
      'supplier': 'Agro Rural Demo',
      'location': 'Goiás',
    },
    {
      'id': 3,
      'name': 'Soja',
      'category': 'Grãos',
      'unit': 'saco de 60 kg',
      'price': 128.00,
      'supplier': 'Fornecedor Cerrado',
      'location': 'Mato Grosso',
    },
    {
      'id': 4,
      'name': 'Fertilizante NPK',
      'category': 'Insumos',
      'unit': 'saco de 50 kg',
      'price': 189.90,
      'supplier': 'Insumos Brasil Demo',
      'location': 'Mato Grosso do Sul',
    },
    {
      'id': 5,
      'name': 'Ureia',
      'category': 'Insumos',
      'unit': 'saco de 50 kg',
      'price': 165.00,
      'supplier': 'Agro Rural Demo',
      'location': 'Goiás',
    },
  ];

  // ============================================================
  // AUTENTICAÇÃO
  // ============================================================

  /// Autentica o usuário.
  Future<UserModel> login(String email, String password) async {
    if (AppConfig.useMockAuth) {
      final normalizedEmail = email.trim().toLowerCase();

      final matches = _demoUsers.where(
        (user) =>
            user['email'] == normalizedEmail && user['password'] == password,
      );

      if (matches.isEmpty) {
        throw Exception('E-mail ou senha inválidos.');
      }

      final data = Map<String, dynamic>.from(matches.first)
        ..remove('password')
        ..['token'] = 'demo-token';

      return UserModel.fromJson(data);
    }

    final response = await _client
        .post(
          Uri.parse('${AppConfig.apiBaseUrl}/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email.trim(), 'password': password}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    return UserModel.fromJson(data);
  }

  /// Recupera o usuário autenticado e valida o JWT salvo.
  Future<UserModel> getCurrentUser(String token) async {
    _validateToken(token);

    if (AppConfig.useMockAuth) {
      throw Exception('Restauração de sessão indisponível no modo demo.');
    }

    final response = await _client
        .get(
          Uri.parse('${AppConfig.apiBaseUrl}/auth/me'),
          headers: _authHeaders(token),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    return UserModel.fromJson({
      ...data['user'] as Map<String, dynamic>,
      'token': token,
    });
  }

  /// Cadastra um novo produtor ou fornecedor na API.
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    if (AppConfig.useMockAuth) {
      throw Exception('O cadastro exige autenticação pela API real.');
    }

    if (role == UserRole.admin) {
      throw Exception('Não é permitido criar uma conta administrativa.');
    }

    if (name.trim().length < 2) {
      throw Exception('Informe um nome válido.');
    }

    if (!email.trim().contains('@')) {
      throw Exception('Informe um e-mail válido.');
    }

    if (password.length < 12 || password.length > 72) {
      throw Exception('A senha deve ter entre 12 e 72 caracteres.');
    }

    final response = await _client
        .post(
          Uri.parse('${AppConfig.apiBaseUrl}/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': name.trim(),
            'email': email.trim().toLowerCase(),
            'password': password,
            'role': role.name,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 201) {
      throw Exception(_errorMessage(response));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    return UserModel.fromJson(data);
  }

  // ============================================================
  // CATÁLOGO DE PRODUTOS
  // ============================================================

  /// Busca produtos do catálogo.
  Future<List<ProductModel>> getProducts({String query = ''}) async {
    if (AppConfig.useMockProducts) {
      final normalizedQuery = query.trim().toLowerCase();

      return _demoProducts
          .where((product) {
            final searchable =
                '${product['name']} ${product['category']} '
                        '${product['supplier']} ${product['location']}'
                    .toLowerCase();

            return searchable.contains(normalizedQuery);
          })
          .map((item) => ProductModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/products').replace(
      queryParameters: query.trim().isEmpty ? null : {'q': query.trim()},
    );

    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response));
    }

    final decoded = jsonDecode(response.body);

    final List<dynamic> items = decoded is List
        ? decoded
        : (decoded['products'] as List<dynamic>);

    return items
        .map(
          (item) =>
              ProductModel.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  // ============================================================
  // OFERTAS DO FORNECEDOR
  // ============================================================

  /// Busca somente as ofertas do fornecedor autenticado.
  Future<List<ProductModel>> getMyProducts(String token) async {
    _validateToken(token);

    final response = await _client
        .get(
          Uri.parse('${AppConfig.apiBaseUrl}/products/mine'),
          headers: _authHeaders(token),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final items = decoded['products'] as List<dynamic>;

    return items
        .map(
          (item) =>
              ProductModel.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  /// Cadastra uma nova oferta para o fornecedor autenticado.
  Future<ProductModel> createProduct({
    required String token,
    required String name,
    required String category,
    required String unit,
    required double price,
    required double packageQuantity,
    required String location,
  }) async {
    _validateProductInput(
      token: token,
      name: name,
      category: category,
      unit: unit,
      price: price,
      packageQuantity: packageQuantity,
      location: location,
    );

    final response = await _client
        .post(
          Uri.parse('${AppConfig.apiBaseUrl}/products'),
          headers: _authHeaders(token),
          body: jsonEncode({
            'name': name.trim(),
            'category': category.trim(),
            'unit': unit,
            'price': price,
            'package_quantity': packageQuantity,
            'location': location.trim(),
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 201) {
      throw Exception(_errorMessage(response));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final product = decoded['product'] as Map<String, dynamic>;

    return ProductModel.fromJson(product);
  }

  /// Atualiza uma oferta existente do fornecedor autenticado.
  Future<ProductModel> updateProduct({
    required String token,
    required int id,
    required String name,
    required String category,
    required String unit,
    required double price,
    required double packageQuantity,
    required String location,
  }) async {
    _validateToken(token);

    if (id < 1) {
      throw Exception('ID do produto inválido.');
    }

    _validateProductInput(
      token: token,
      name: name,
      category: category,
      unit: unit,
      price: price,
      packageQuantity: packageQuantity,
      location: location,
    );

    final response = await _client
        .put(
          Uri.parse('${AppConfig.apiBaseUrl}/products/$id'),
          headers: _authHeaders(token),
          body: jsonEncode({
            'name': name.trim(),
            'category': category.trim(),
            'unit': unit,
            'price': price,
            'package_quantity': packageQuantity,
            'location': location.trim(),
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final product = decoded['product'] as Map<String, dynamic>;

    return ProductModel.fromJson(product);
  }

  /// Desativa uma oferta do fornecedor autenticado.
  Future<void> deleteProduct({required String token, required int id}) async {
    _validateToken(token);

    if (id < 1) {
      throw Exception('ID do produto inválido.');
    }

    final response = await _client
        .delete(
          Uri.parse('${AppConfig.apiBaseUrl}/products/$id'),
          headers: _authHeaders(token),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response));
    }
  }

  // ============================================================
  // SOLICITAÇÕES DE COTAÇÃO - PRODUTOR
  // ============================================================

  /// Cria uma solicitação de cotação.
  ///
  /// productId é opcional.
  /// deadline deve ser uma data futura.
  Future<Map<String, dynamic>> createQuoteRequest({
    required String token,
    int? productId,
    required String productName,
    required String category,
    required double quantity,
    required String unit,
    required String location,
    required DateTime deadline,
  }) async {
    _validateToken(token);

    _validateQuoteRequestInput(
      productName: productName,
      category: category,
      quantity: quantity,
      unit: unit,
      location: location,
      deadline: deadline,
    );

    if (productId != null && productId < 1) {
      throw Exception('ID do produto inválido.');
    }

    final response = await _client
        .post(
          Uri.parse('${AppConfig.apiBaseUrl}/quotes'),
          headers: _authHeaders(token),
          body: jsonEncode({
            'productId': productId,
            'productName': productName.trim(),
            'category': category.trim(),
            'quantity': quantity,
            'unit': unit,
            'location': location.trim(),
            'deadline': deadline.toUtc().toIso8601String(),
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 201) {
      throw Exception(_errorMessage(response));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    return Map<String, dynamic>.from(decoded['request'] as Map);
  }

  /// Lista as solicitações de cotação do produtor autenticado.
  Future<List<Map<String, dynamic>>> getMyQuoteRequests({
    required String token,
  }) async {
    _validateToken(token);

    final response = await _client
        .get(
          Uri.parse('${AppConfig.apiBaseUrl}/quotes/mine'),
          headers: _authHeaders(token),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final items = decoded['requests'] as List<dynamic>;

    return items.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  /// Lista os contatos de um fornecedor para o produtor autenticado.
  Future<List<Map<String, dynamic>>> getPublicSupplierContacts({
    required String token,
    required int supplierId,
  }) async {
    _validateToken(token);

    final response = await _client
        .get(
          Uri.parse('${AppConfig.apiBaseUrl}/suppliers/$supplierId/contatos'),
          headers: _authHeaders(token),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final items = decoded['contacts'] as List<dynamic>;

    return items.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  /// Lista as propostas recebidas para uma solicitação do produtor.
  Future<List<Map<String, dynamic>>> getQuoteProposals({
    required String token,
    required int requestId,
  }) async {
    _validateToken(token);

    if (requestId < 1) {
      throw Exception('ID da solicitação inválido.');
    }

    final response = await _client
        .get(
          Uri.parse('${AppConfig.apiBaseUrl}/quotes/$requestId/proposals'),
          headers: _authHeaders(token),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final items = decoded['proposals'] as List<dynamic>;

    return items.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  /// Aceita ou recusa uma proposta recebida.
  Future<void> updateQuoteProposalStatus({
    required String token,
    required int requestId,
    required int proposalId,
    required String status,
  }) async {
    _validateToken(token);

    if (requestId < 1 || proposalId < 1) {
      throw Exception('ID da solicitação ou proposta inválido.');
    }

    if (!['aceita', 'recusada'].contains(status)) {
      throw Exception('Situação da proposta inválida.');
    }

    final response = await _client
        .patch(
          Uri.parse(
            '${AppConfig.apiBaseUrl}/quotes/$requestId/proposals/$proposalId',
          ),
          headers: _authHeaders(token),
          body: jsonEncode({'status': status}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response));
    }
  }

  // ============================================================
  // PROPOSTAS DE COTAÇÃO - FORNECEDOR
  // ============================================================

  /// Lista solicitações abertas disponíveis para o fornecedor.
  Future<List<Map<String, dynamic>>> getOpenQuoteRequests({
    required String token,
  }) async {
    _validateToken(token);

    final response = await _client
        .get(
          Uri.parse('${AppConfig.apiBaseUrl}/quotes/open'),
          headers: _authHeaders(token),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final items = decoded['requests'] as List<dynamic>;

    return items.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  /// Envia uma proposta para uma solicitação de cotação.
  Future<Map<String, dynamic>> createQuoteProposal({
    required String token,
    required int requestId,
    required double price,
    String notes = '',
  }) async {
    _validateToken(token);

    if (requestId < 1) {
      throw Exception('ID da solicitação inválido.');
    }

    if (!price.isFinite || price < 0) {
      throw Exception('Informe um preço válido.');
    }

    if (price.toStringAsFixed(2) != price.toStringAsFixed(2)) {
      throw Exception('Preço inválido.');
    }

    if (notes.length > 1000) {
      throw Exception('As observações devem ter até 1000 caracteres.');
    }

    final response = await _client
        .post(
          Uri.parse('${AppConfig.apiBaseUrl}/quotes/$requestId/proposals'),
          headers: _authHeaders(token),
          body: jsonEncode({'price': price, 'notes': notes.trim()}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 201) {
      throw Exception(_errorMessage(response));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    return Map<String, dynamic>.from(decoded['proposal'] as Map);
  }
  // ============================================================
  // HISTÓRICO COMERCIAL
  // ============================================================

  /// Busca o histórico de solicitações do produtor.
  Future<List<Map<String, dynamic>>> getProducerHistory({
    required String token,
  }) async {
    _validateToken(token);

    final response = await _client
        .get(
          Uri.parse('${AppConfig.apiBaseUrl}/quotes/history/producer'),
          headers: _authHeaders(token),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final items = decoded['history'] as List<dynamic>;

    return items.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  /// Busca o histórico de propostas do fornecedor.
  Future<List<Map<String, dynamic>>> getSupplierHistory({
    required String token,
  }) async {
    _validateToken(token);

    final response = await _client
        .get(
          Uri.parse('${AppConfig.apiBaseUrl}/quotes/history/supplier'),
          headers: _authHeaders(token),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final items = decoded['history'] as List<dynamic>;

    return items.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  // ============================================================
  // CONTATOS DO FORNECEDOR
  // ============================================================

  /// Lista os contatos do fornecedor autenticado.
  Future<List<Map<String, dynamic>>> getSupplierContacts({
    required String token,
  }) async {
    _validateToken(token);

    final response = await _client
        .get(
          Uri.parse('${AppConfig.apiBaseUrl}/profile/fornecedor/contatos'),
          headers: _authHeaders(token),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final items = decoded['contacts'] as List<dynamic>;

    return items.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  /// Cadastra um contato do fornecedor.
  Future<Map<String, dynamic>> createSupplierContact({
    required String token,
    required String contactType,
    required String contactValue,
    String label = '',
  }) async {
    _validateToken(token);

    final response = await _client
        .post(
          Uri.parse('${AppConfig.apiBaseUrl}/profile/fornecedor/contatos'),
          headers: _authHeaders(token),
          body: jsonEncode({
            'contact_type': contactType,
            'contact_value': contactValue.trim(),
            'label': label.trim(),
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 201) {
      throw Exception(_errorMessage(response));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    return Map<String, dynamic>.from(decoded['contact'] as Map);
  }

  /// Atualiza um contato do fornecedor.
  Future<Map<String, dynamic>> updateSupplierContact({
    required String token,
    required int contactId,
    required String contactType,
    required String contactValue,
    String label = '',
  }) async {
    _validateToken(token);

    if (contactId < 1) {
      throw Exception('ID do contato inválido.');
    }

    final response = await _client
        .put(
          Uri.parse(
            '${AppConfig.apiBaseUrl}/profile/fornecedor/contatos/$contactId',
          ),
          headers: _authHeaders(token),
          body: jsonEncode({
            'contact_type': contactType,
            'contact_value': contactValue.trim(),
            'label': label.trim(),
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    return Map<String, dynamic>.from(decoded['contact'] as Map);
  }

  /// Exclui um contato do fornecedor.
  Future<void> deleteSupplierContact({
    required String token,
    required int contactId,
  }) async {
    _validateToken(token);

    if (contactId < 1) {
      throw Exception('ID do contato inválido.');
    }

    final response = await _client
        .delete(
          Uri.parse(
            '${AppConfig.apiBaseUrl}/profile/fornecedor/contatos/$contactId',
          ),
          headers: _authHeaders(token),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response));
    }
  }

  // ============================================================
  // ADMINISTRAÇÃO
  // ============================================================

  /// Lista os usuários cadastrados (acesso exclusivo para Admin).
  Future<List<Map<String, dynamic>>> getAdminUsers({
    required String token,
  }) async {
    _validateToken(token);

    final response = await _client
        .get(
          Uri.parse('${AppConfig.apiBaseUrl}/admin/users'),
          headers: _authHeaders(token),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final items = decoded['users'] as List<dynamic>;

    return items.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  /// Ativa ou desativa um usuário (acesso exclusivo para Admin).
  Future<Map<String, dynamic>> updateAdminUserStatus({
    required String token,
    required int id,
    required bool isActive,
  }) async {
    _validateToken(token);

    if (id < 1) {
      throw Exception('ID do usuário inválido.');
    }

    final response = await _client
        .patch(
          Uri.parse('${AppConfig.apiBaseUrl}/admin/users/$id/status'),
          headers: _authHeaders(token),
          body: jsonEncode({'is_active': isActive}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    return Map<String, dynamic>.from(decoded['user'] as Map);
  }

  /// Altera o perfil de um usuário entre produtor e fornecedor.
  Future<Map<String, dynamic>> updateAdminUserRole({
    required String token,
    required int id,
    required String role,
  }) async {
    _validateToken(token);

    if (id < 1) {
      throw Exception('ID do usuário inválido.');
    }

    if (!['produtor', 'fornecedor'].contains(role)) {
      throw Exception('Perfil inválido.');
    }

    final response = await _client
        .patch(
          Uri.parse('${AppConfig.apiBaseUrl}/admin/users/$id/role'),
          headers: _authHeaders(token),
          body: jsonEncode({'role': role}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    return Map<String, dynamic>.from(decoded['user'] as Map);
  }

  // ============================================================
  // VALIDAÇÕES E UTILITÁRIOS
  // ============================================================

  Map<String, String> _authHeaders(String token) => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  void _validateToken(String token) {
    if (token.trim().isEmpty) {
      throw Exception('Token de autenticação não informado.');
    }
  }

  /// Valida os dados de uma oferta de produto.
  void _validateProductInput({
    required String token,
    required String name,
    required String category,
    required String unit,
    required double price,
    required double packageQuantity,
    required String location,
  }) {
    _validateToken(token);

    if (name.trim().isEmpty ||
        name.trim().length > 180 ||
        category.trim().isEmpty ||
        category.trim().length > 80 ||
        location.trim().length > 180 ||
        price < 0 ||
        !price.isFinite ||
        !packageQuantity.isFinite ||
        packageQuantity <= 0) {
      throw Exception('Confira os dados informados para o produto.');
    }

    if (!['kg', 'L', 'unidade'].contains(unit)) {
      throw Exception('Unidade de medida inválida.');
    }

    // Preço: máximo de duas casas decimais.
    final priceScaled = price * 100;

    if ((priceScaled - priceScaled.round()).abs() > 0.000001) {
      throw Exception('O preço deve ter até duas casas decimais.');
    }

    // Quantidade da embalagem: máximo de três casas decimais.
    final quantityScaled = packageQuantity * 1000;

    if ((quantityScaled - quantityScaled.round()).abs() > 0.000001) {
      throw Exception(
        'A quantidade da embalagem deve ter até três casas decimais.',
      );
    }
  }

  /// Valida os dados de uma solicitação de cotação.
  void _validateQuoteRequestInput({
    required String productName,
    required String category,
    required double quantity,
    required String unit,
    required String location,
    required DateTime deadline,
  }) {
    if (productName.trim().isEmpty ||
        productName.trim().length > 180 ||
        category.trim().isEmpty ||
        category.trim().length > 80 ||
        !quantity.isFinite ||
        quantity <= 0 ||
        location.trim().isEmpty ||
        location.trim().length > 180) {
      throw Exception('Confira os dados da solicitação de cotação.');
    }

    if (!['kg', 'L', 'unidade'].contains(unit)) {
      throw Exception('Unidade de medida inválida.');
    }

    final formattedQuantity = quantity.toString();

    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(formattedQuantity)) {
      throw Exception('A quantidade deve ter até duas casas decimais.');
    }

    if (!deadline.isAfter(DateTime.now())) {
      throw Exception('O prazo da cotação deve ser uma data futura.');
    }
  }

  /// Extrai mensagens de erro retornadas pela API.
  String _errorMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body);

      if (body is Map) {
        final message = body['message'] ?? body['error'];

        if (message != null) {
          return message.toString();
        }
      }
    } catch (_) {
      // A resposta não contém JSON válido.
    }

    return 'Erro na API (HTTP ${response.statusCode}).';
  }

  /// Fecha o cliente HTTP quando não for mais necessário.
  void dispose() {
    _client.close();
  }
}
