import 'package:flutter/foundation.dart';

import '../adapters/api_service.dart';
import '../models/user_model.dart';

class AuthController extends ChangeNotifier {
  final ApiService api;

  AuthController(this.api);

  UserModel? user;
  bool loading = false;
  String? error;

  bool get isAuthenticated => user != null;

  bool get isProducer => user?.role == UserRole.produtor;

  bool get isSupplier => user?.role == UserRole.fornecedor;

  bool get isAdmin => user?.role == UserRole.admin;

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

      if (authenticatedUser.role != expectedRole) {
        user = null;
        error = 'O perfil selecionado não corresponde a esta conta.';
        return false;
      }

      if (authenticatedUser.role == UserRole.admin) {
        user = null;
        error = 'Acesso administrativo não disponível nesta tela.';
        return false;
      }

      user = authenticatedUser;
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

  void logout() {
    user = null;
    error = null;
    notifyListeners();
  }
}
