import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/repositories.dart';

/// Íconos disponibles para categorías y apartados (la clave es lo que se guarda en la BD).
const Map<String, IconData> financeIcons = {
  'restaurant': Icons.restaurant_rounded,
  'basket': Icons.shopping_basket_outlined,
  'car': Icons.directions_car_outlined,
  'home': Icons.home_outlined,
  'bolt': Icons.bolt_rounded,
  'health': Icons.favorite_outline_rounded,
  'medication': Icons.medication_outlined,
  'movie': Icons.movie_outlined,
  'school': Icons.school_outlined,
  'other': Icons.more_horiz_rounded,
  'savings': Icons.savings_outlined,
  'shield': Icons.shield_outlined,
  'bank': Icons.account_balance_outlined,
  'card': Icons.credit_card_rounded,
  'pets': Icons.pets_rounded,
  'gift': Icons.card_giftcard_rounded,
  'clothes': Icons.checkroom_rounded,
  'phone': Icons.smartphone_rounded,
  'baby': Icons.child_friendly_outlined,
  'gym': Icons.fitness_center_rounded,
  'travel': Icons.flight_takeoff_rounded,
  'coffee': Icons.local_cafe_outlined,
  'beauty': Icons.spa_outlined,
  'church': Icons.church_outlined,
  'tools': Icons.build_outlined,
  'game': Icons.sports_esports_outlined,
  'gas': Icons.local_gas_station_outlined,
  'wifi': Icons.wifi_rounded,
  'party': Icons.celebration_outlined,
  'beach': Icons.beach_access_outlined,
};

IconData financeIcon(String? key) => financeIcons[key] ?? Icons.more_horiz_rounded;

/// Categoría lista para pintar (nombre + ícono + colores).
class ExpenseCategory {
  const ExpenseCategory(this.name, this.icon, this.tint, {this.id, this.iconKey = 'other', this.colorName = 'ink'});
  final int? id;
  final String name;
  final IconData icon;
  final ModuleTint tint;
  final String iconKey;
  final String colorName;

  factory ExpenseCategory.from(BudgetCategory c) => ExpenseCategory(
        c.name,
        financeIcon(c.icon),
        ModuleTint.byName(c.color, fallback: ModuleTint.ink),
        id: c.id,
        iconKey: c.icon,
        colorName: c.color,
      );
}

/// Categorías predeterminadas (se usan mientras se cargan las del usuario o si no hay conexión).
const _defaults = [
  ExpenseCategory('Comida', Icons.restaurant_rounded, ModuleTint.coral, iconKey: 'restaurant', colorName: 'coral'),
  ExpenseCategory('Súper', Icons.shopping_basket_outlined, ModuleTint.green, iconKey: 'basket', colorName: 'green'),
  ExpenseCategory('Transporte', Icons.directions_car_outlined, ModuleTint.blue, iconKey: 'car', colorName: 'blue'),
  ExpenseCategory('Casa', Icons.home_outlined, ModuleTint.amber, iconKey: 'home', colorName: 'amber'),
  ExpenseCategory('Servicios', Icons.bolt_rounded, ModuleTint.teal, iconKey: 'bolt', colorName: 'teal'),
  ExpenseCategory('Salud', Icons.favorite_outline_rounded, ModuleTint.pink, iconKey: 'health', colorName: 'pink'),
  ExpenseCategory('Medicamentos', Icons.medication_outlined, ModuleTint.pink, iconKey: 'medication', colorName: 'pink'),
  ExpenseCategory('Entretenimiento', Icons.movie_outlined, ModuleTint.violet, iconKey: 'movie', colorName: 'violet'),
  ExpenseCategory('Educación', Icons.school_outlined, ModuleTint.blue, iconKey: 'school', colorName: 'blue'),
  ExpenseCategory('Otros', Icons.more_horiz_rounded, ModuleTint.ink, iconKey: 'other', colorName: 'ink'),
];

/// Categorías actuales del usuario (las comparten Gastos y Presupuesto).
List<ExpenseCategory> expenseCategories = List.of(_defaults);

ExpenseCategory categoryByName(String name) => expenseCategories.firstWhere(
      (c) => c.name == name,
      orElse: () => _defaults.firstWhere((c) => c.name == name, orElse: () => _defaults.last),
    );

/// Carga y guarda en memoria las categorías del usuario; avisa a las pantallas cuando cambian.
class CategoriesStore extends ChangeNotifier {
  CategoriesStore(this._repo);
  final BudgetRepository _repo;
  bool _loaded = false;

  List<ExpenseCategory> get all => expenseCategories;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await reload();
  }

  Future<void> reload() async {
    try {
      final list = await _repo.categories();
      if (list.isNotEmpty) {
        expenseCategories = [for (final c in list) ExpenseCategory.from(c)];
        _loaded = true;
        notifyListeners();
      }
    } catch (_) {
      // Sin conexión se siguen usando las predeterminadas.
    }
  }

  void reset() {
    expenseCategories = List.of(_defaults);
    _loaded = false;
  }
}

/// Suma los gastos por categoría, de mayor a menor.
List<CategoryTotal> totalsByCategory(List<Expense> expenses) {
  final totals = <String, double>{};
  final counts = <String, int>{};
  for (final e in expenses) {
    totals[e.category] = (totals[e.category] ?? 0) + e.amount;
    counts[e.category] = (counts[e.category] ?? 0) + 1;
  }
  final list = [for (final k in totals.keys) CategoryTotal(k, totals[k]!, counts[k]!)];
  list.sort((a, b) => b.total.compareTo(a.total));
  return list;
}
