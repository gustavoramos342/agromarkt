
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

  /// Autentica o usuário.
  ///
  /// Por padrão, usa a API real.
  /// Para usar usuários fictícios, ative USE_MOCK_AUTH.
  Future<UserModel> login(String email, String password) async {
    if (AppConfig.useMockAuth) {
      final normalizedEmail = email.trim().toLowerCase();

      final matches = _demoUsers.where(
        (user) =>
            user['email'] == normalizedEmail &&
            user['password'] == password,
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
          body: jsonEncode({
            'email': email.trim(),
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    return UserModel.fromJson(data);
  }

  /// Busca produtos.
  ///
  /// Por padrão, usa os produtos demonstrativos até a API de catálogo
  /// estar implementada.
  /// Para usar a API real, desative USE_MOCK_PRODUCTS.
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
          .map(
            (item) => ProductModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    }

    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/products',
    ).replace(
      queryParameters: query.trim().isEmpty
          ? null
          : {'q': query.trim()},
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
          (item) => ProductModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
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
