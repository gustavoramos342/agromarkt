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

  Future<bool> login(String email, String password) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      user = await api.login(email, password);
      return true;
    } catch (e) {
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
