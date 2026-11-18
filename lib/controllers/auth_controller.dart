import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';
import '../adapters/api_service.dart';
import '../models/user_model.dart';

class AuthController extends ChangeNotifier {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _tokenKey = 'agromarkt_jwt';
  final ApiService api;

  AuthController(this.api);

  UserModel? user;
  bool loading = false;
  String? error;

  bool get isAuthenticated => user != null;

  bool get isProducer => user?.role == UserRole.produtor;

  bool get isSupplier => user?.role == UserRole.fornecedor;

  bool get isAdmin => user?.role == UserRole.admin;
  Future<void> restoreSession() async {
    if (AppConfig.useMockAuth) return;

    loading = true;
    notifyListeners();

    try {
      final token = await _storage.read(key: _tokenKey);

      if (token == null || token.isEmpty) return;

      final restoredUser = await api.getCurrentUser(token);

      if (restoredUser.role == UserRole.admin &&
          !AppConfig.developerAdminEnabled) {
        await _storage.delete(key: _tokenKey);
        return;
      }

      user = restoredUser;
    } catch (_) {
      await _storage.delete(key: _tokenKey);
      user = null;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> login(
    String email,
    String password, {
    required UserRole expectedRole,
  }) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final authenticatedUser = await api.login(email, password);

      if (authenticatedUser.role != expectedRole &&
          !(authenticatedUser.role == UserRole.admin &&
              AppConfig.developerAdminEnabled)) {
        user = null;
        error = 'O perfil selecionado não corresponde a esta conta.';
        return false;
      }

      if (authenticatedUser.role == UserRole.admin &&
          !AppConfig.developerAdminEnabled) {
        user = null;
        error = 'Acesso administrativo não disponível nesta tela.';
        return false;
      }

      user = authenticatedUser;

      if (!AppConfig.useMockAuth) {
        final token = authenticatedUser.token;

        if (token != null && token.isNotEmpty) {
          await _storage.write(key: _tokenKey, value: token);
        }
      }

      return true;
    } catch (e) {
      user = null;
      error = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      if (role == UserRole.admin) {
        throw Exception('Não é permitido criar uma conta administrativa.');
      }

      final registeredUser = await api.register(
        name: name,
        email: email,
        password: password,
        role: role,
      );

      user = registeredUser;
      return true;
    } catch (e) {
      user = null;
      error = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    user = null;
    error = null;
    notifyListeners();
  }
}
