import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'agenda/agenda_screen.dart';
import 'budget/finance_screen.dart';
import 'notes/notes_screen.dart';
import 'nutrition/nutrition_screen.dart';
import 'places/places_screen.dart';
import 'recipes/recipes_screen.dart';
import 'shopping/shopping_screen.dart';
import 'todos/todos_screen.dart';
import 'workouts/workouts_screen.dart';

/// Catálogo de "mini apps" que viven dentro de multiApp.
/// Para agregar un módulo nuevo basta con añadirlo a esta lista.
class AppModule {
  const AppModule({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.tint,
    required this.builder,
    this.available = true,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final ModuleTint tint;
  final WidgetBuilder builder;
  final bool available;
}

final List<AppModule> appModules = [
  AppModule(
    id: 'agenda',
    name: 'Agenda',
    description: 'Eventos y citas',
    icon: Icons.calendar_month_outlined,
    tint: ModuleTint.coral,
    builder: (_) => const AgendaScreen(),
  ),
  AppModule(
    id: 'todos',
    name: 'Pendientes',
    description: 'Cosas por hacer',
    icon: Icons.task_alt_rounded,
    tint: ModuleTint.blue,
    builder: (_) => const TodosScreen(),
  ),
  AppModule(
    id: 'notes',
    name: 'Notas',
    description: 'Ideas y apuntes',
    icon: Icons.sticky_note_2_outlined,
    tint: ModuleTint.amber,
    builder: (_) => const NotesScreen(),
  ),
  AppModule(
    id: 'recipes',
    name: 'Recetario',
    description: 'Recetas con IA',
    icon: Icons.restaurant_menu_rounded,
    tint: ModuleTint.violet,
    builder: (_) => const RecipesScreen(),
  ),
  AppModule(
    id: 'expenses',
    name: 'Finanzas',
    description: 'Presupuesto, gastos y ahorro',
    icon: Icons.account_balance_wallet_outlined,
    tint: ModuleTint.teal,
    builder: (_) => const FinanceScreen(),
  ),
  AppModule(
    id: 'shopping',
    name: 'Compras',
    description: 'Lista de compras',
    icon: Icons.shopping_cart_outlined,
    tint: ModuleTint.green,
    builder: (_) => const ShoppingScreen(),
  ),
  AppModule(
    id: 'places',
    name: 'Lugares',
    description: 'Casa, trabajo, iglesia y cómo llegar',
    icon: Icons.place_outlined,
    tint: ModuleTint.pink,
    builder: (_) => const PlacesScreen(),
  ),
  AppModule(
    id: 'workouts',
    name: 'Ejercicio',
    description: 'Rutinas con IA y tutoriales',
    icon: Icons.fitness_center_rounded,
    tint: ModuleTint.coral,
    builder: (_) => const WorkoutsScreen(),
  ),
  AppModule(
    id: 'nutrition',
    name: 'Calorías',
    description: 'Conteo de calorías y macros',
    icon: Icons.local_fire_department_outlined,
    tint: ModuleTint.amber,
    builder: (_) => const NutritionScreen(),
  ),
];

AppModule moduleById(String id) => appModules.firstWhere((m) => m.id == id);

Future<void> openModule(BuildContext context, AppModule module) {
  return Navigator.of(context).push(MaterialPageRoute(builder: module.builder));
}
