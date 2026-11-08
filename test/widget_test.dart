import 'package:flutter_test/flutter_test.dart';
import 'package:agromarkt/adapters/api_service.dart';
import 'package:agromarkt/adapters/local_storage_service.dart';
import 'package:agromarkt/main.dart';

void main() {
  testWidgets('AgroMarkt exibe a tela de login', (tester) async {
    final api = ApiService();
    final localStorage = LocalStorageService();

    await tester.pumpWidget(AgroMarktApp(api: api, localStorage: localStorage));

    expect(find.text('AgroMarkt'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
