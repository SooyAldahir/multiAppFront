import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/expenses/expense_categories.dart';
import 'screens/shell/main_shell.dart';
import 'services/auth_controller.dart';
import 'services/notification_service.dart';
import 'services/push_service.dart';
import 'services/repositories.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final api = ApiClient();
  final profileRepo = ProfileRepository(api);
  final budgetRepo = BudgetRepository(api);
  final categories = CategoriesStore(budgetRepo);
  final auth = AuthController(api);
  // Al cerrar sesión: dar de baja el push y borrar los recordatorios de esta cuenta.
  auth.beforeSignOut = () async {
    await PushService.instance.stop(profileRepo);
    await NotificationService.instance.cancelScheduled();
    NotificationService.instance.stop();
    categories.reset();
  };
  unawaited(NotificationService.instance.init());
  auth.restore();

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: api),
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider(create: (_) => DataRefresh()),
        Provider(create: (_) => DashboardRepository(api)),
        Provider(create: (_) => EventsRepository(api)),
        Provider(create: (_) => NotesRepository(api)),
        Provider(create: (_) => TodosRepository(api)),
        Provider(create: (_) => RecipesRepository(api)),
        Provider(create: (_) => ExpensesRepository(api)),
        Provider(create: (_) => ShoppingRepository(api)),
        Provider(create: (_) => PlacesRepository(api)),
        Provider(create: (_) => GeoRepository(api)),
        Provider(create: (_) => HealthRepository(api)),
        Provider(create: (_) => WorkoutsRepository(api)),
        Provider(create: (_) => NutritionRepository(api)),
        Provider.value(value: profileRepo),
        Provider.value(value: budgetRepo),
        Provider(create: (_) => FundsRepository(api)),
        ChangeNotifierProvider.value(value: categories),
      ],
      child: const MultiApp(),
    ),
  );
}

class MultiApp extends StatelessWidget {
  const MultiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.select<AuthController, AuthStatus>((a) => a.status);

    return MaterialApp(
      // Al iniciar o cerrar sesión se reconstruye el navegador completo,
      // así no quedan pantallas abiertas de la sesión anterior.
      key: ValueKey(status == AuthStatus.signedIn),
      title: 'multiApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: const Locale('es', 'MX'),
      supportedLocales: const [Locale('es', 'MX'), Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: switch (status) {
        AuthStatus.loading => const _Splash(),
        AuthStatus.signedOut => const LoginScreen(),
        AuthStatus.signedIn => const MainShell(),
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
