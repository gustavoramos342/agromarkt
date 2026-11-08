import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'adapters/api_service.dart';
import 'adapters/local_storage_service.dart';
import 'controllers/auth_controller.dart';
import 'controllers/catalog_controller.dart';
import 'views/catalog_screen.dart';
import 'views/login_screen.dart';
import 'views/supplier_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final api = ApiService();
  final localStorage = LocalStorageService();

  runApp(AgroMarktApp(api: api, localStorage: localStorage));
}

class AgroMarktApp extends StatelessWidget {
  final ApiService api;
  final LocalStorageService localStorage;

  const AgroMarktApp({
    super.key,
    required this.api,
    required this.localStorage,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: api),
        Provider<LocalStorageService>.value(value: localStorage),
        ChangeNotifierProvider(create: (_) => AuthController(api)),
        ChangeNotifierProvider(
          create: (_) => CatalogController(api, localStorage),
        ),
      ],
      child: MaterialApp(
        title: 'AgroMarkt',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
          scaffoldBackgroundColor: const Color(0xFFF7F9F6),
          appBarTheme: const AppBarTheme(centerTitle: false),
          cardTheme: const CardThemeData(
            elevation: 1,
            margin: EdgeInsets.symmetric(vertical: 6),
          ),
        ),
        home: Consumer<AuthController>(
          builder: (context, auth, _) {
            // Usuário não autenticado: tela de login.
            if (!auth.isAuthenticated) {
              return const LoginScreen();
            }

            // Produtor: catálogo e comparador.
            if (auth.isProducer) {
              return const CatalogScreen();
            }

            // Fornecedor: área específica do fornecedor.
            if (auth.isSupplier) {
              return const SupplierScreen();
            }

            // Administrador ou perfil não reconhecido:
            // não concede acesso automático ao catálogo.
            return Scaffold(
              appBar: AppBar(title: const Text('Acesso restrito')),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Este perfil não possui uma tela disponível.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: auth.logout,
                        icon: const Icon(Icons.logout),
                        label: const Text('Sair'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
