import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:agromarkt/adapters/api_service.dart';
import 'package:agromarkt/controllers/auth_controller.dart';
import 'package:agromarkt/views/login_screen.dart';

void main() {
  testWidgets('AgroMarkt exibe a tela de login', (tester) async {
    final api = ApiService();
    final auth = AuthController(api);
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: auth,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    expect(find.text('AgroMarkt'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);

  });
}
