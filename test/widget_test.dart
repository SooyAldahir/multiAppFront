import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:multiapp/core/api_client.dart';
import 'package:multiapp/core/theme.dart';
import 'package:multiapp/screens/auth/login_screen.dart';
import 'package:multiapp/services/auth_controller.dart';

void main() {
  testWidgets('La pantalla de inicio de sesión valida los campos', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthController(ApiClient()),
        child: MaterialApp(theme: AppTheme.light(), home: const LoginScreen()),
      ),
    );

    expect(find.text('Iniciar sesión'), findsOneWidget);

    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump();

    expect(find.text('Escribe un correo válido'), findsOneWidget);
    expect(find.text('Escribe tu contraseña'), findsOneWidget);
  });
}
