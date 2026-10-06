import 'package:flutter_test/flutter_test.dart';
import 'package:multiapp/models/models.dart';

void main() {
  test('User.initials toma las iniciales del nombre', () {
    expect(const User(id: 1, name: 'Aldahir Ballina', email: 'a@b.com').initials, 'AB');
    expect(const User(id: 1, name: 'ana', email: 'a@b.com').initials, 'A');
  });

  test('Todo se convierte desde y hacia JSON', () {
    final todo = Todo.fromJson({
      'id': 3,
      'title': 'Comprar pan',
      'dueDate': '2026-10-04T18:00:00.000Z',
      'priority': 'high',
      'isCompleted': false,
    });
    expect(todo.priority, Priority.high);
    expect(todo.toJson()['priority'], 'high');
    expect(todo.toJson()['dueDate'], '2026-10-04T18:00:00.000Z');
  });

  test('Dashboard calcula el tiempo libre descontando eventos', () {
    final now = DateTime(2026, 10, 4, 17);
    final dashboard = Dashboard(
      events: [
        AgendaEvent(title: 'Clase', startAt: DateTime(2026, 10, 4, 18), endAt: DateTime(2026, 10, 4, 19)),
      ],
      todos: const [],
      counts: const DashboardCounts(),
    );
    // De 17:00 a 21:00 hay 4 h, menos 1 h de evento = 3 h
    expect(dashboard.freeTimeToday(now), const Duration(hours: 3));
  });

  test('Expense y ShoppingItem se leen desde JSON', () {
    final e = Expense.fromJson({
      'id': 1,
      'description': 'Tacos',
      'amount': 120.5,
      'category': 'Comida',
      'spentAt': '2026-10-04T18:00:00.000Z',
    });
    expect(e.amount, 120.5);
    expect(e.toJson()['category'], 'Comida');

    final item = ShoppingItem.fromJson({'id': 2, 'name': 'Leche', 'quantity': null, 'isChecked': false});
    expect(item.copyWith(isChecked: true).isChecked, isTrue);
    expect(item.toJson()['quantity'], isNull);
  });

  test('Place y WhereToBuy se leen desde JSON', () {
    final place = Place.fromJson({
      'id': 1,
      'name': 'Iglesia',
      'category': 'church',
      'latitude': 25.1906,
      'longitude': -99.8268,
      'address': null,
    });
    expect(place.point.latitude, 25.1906);
    expect(place.toJson()['category'], 'church');

    final w = WhereToBuy.fromJson({
      'aiUsed': true,
      'groups': [
        {
          'type': 'pharmacy',
          'label': 'Farmacia',
          'items': [
            {'id': 2, 'name': 'Paracetamol', 'quantity': null}
          ],
          'stores': [
            {'id': 'node/8', 'name': 'Farmacia', 'type': 'pharmacy', 'label': 'Farmacia', 'lat': 25.19, 'lon': -99.82, 'distance': 350}
          ],
        }
      ],
      'storesError': null,
    });
    expect(w.groups.single.stores.single.distance, 350);
    expect(w.groups.single.items.single.name, 'Paracetamol');
  });

  test('WorkoutPlan, FoodEstimate y nutrición de recetas se leen desde JSON', () {
    final plan = WorkoutPlan.fromJson({
      'title': 'Piernas',
      'durationMinutes': 40,
      'estimatedCalories': 280,
      'exercises': [
        {'name': 'Sentadilla', 'sets': 4, 'reps': '12', 'restSeconds': 90, 'youtubeUrl': 'https://www.youtube.com/results?search_query=x'}
      ],
    });
    expect(plan.exercises.single.sets, 4);

    final e = FoodEstimate.fromJson({
      'description': 'Tacos',
      'items': [
        {'name': 'Taco', 'quantity': '2', 'calories': 300, 'protein': 14, 'carbs': 30, 'fat': 12}
      ],
      'total': {'calories': 300, 'protein': 14, 'carbs': 30, 'fat': 12},
      'confidence': 'media',
    });
    final log = FoodLog.fromNutrition(n: e.total * 1.5, description: 'Tacos', meal: 'lunch', source: 'text');
    expect(log.calories, 450);
    expect(log.toJson()['proteinG'], 21.0);

    final r = Recipe.fromJson({
      'title': 'Ensalada',
      'nutritionPerServing': {'calories': 320, 'protein': 12, 'carbs': 20, 'fat': 18},
    });
    expect(r.nutritionPerServing!.calories, 320);
    expect(Recipe.fromJson({'title': 'Vieja'}).nutritionPerServing, isNull);
  });

  test('BudgetView y SavingsFund se leen desde JSON', () {
    final view = BudgetView.fromJson({
      'settings': {'period': 'biweekly', 'startDay': 1, 'alertsEnabled': true, 'rolloverFundId': 3},
      'period': {'id': 9, 'startDate': '2026-10-01', 'endDate': '2026-10-15', 'period': 'biweekly', 'income': 8000, 'daysLeft': 11, 'isCurrent': true},
      'categories': [
        {'id': 1, 'name': 'Comida', 'icon': 'restaurant', 'color': 'coral', 'limit': 2000, 'spent': 1700.5, 'remaining': 299.5, 'percent': 85, 'status': 'warning'},
        {'id': 2, 'name': 'Otros', 'icon': 'other', 'color': 'ink', 'limit': null, 'spent': 0, 'status': 'none'},
      ],
      'totals': {'income': 8000, 'budgeted': 2000, 'spent': 1700.5, 'autoSaved': 800, 'saved': 800, 'unassigned': 5200, 'available': 5499.5, 'perDayLeft': 499.95},
    });
    expect(view.settings.period, BudgetPeriodType.biweekly);
    expect(view.period.startDate, DateTime(2026, 10, 1));
    expect(view.lines.first.status, 'warning');
    expect(view.lines.last.limit, isNull);
    expect(view.totals.available, 5499.5);

    final fund = SavingsFund.fromJson({
      'id': 3, 'name': 'Emergencias', 'icon': 'shield', 'color': 'coral', 'goal': 30000, 'goalDate': '2027-06-30',
      'autoType': 'percent', 'autoValue': 10, 'balance': 12000, 'progress': 40,
    });
    expect(fund.autoType, FundAutoType.percent);
    expect(fund.goalDate, DateTime(2027, 6, 30));
    expect(fund.toJson()['goalDate'], '2027-06-30');
    expect(fund.autoLabel, 'Auto 10 % del ingreso');
  });
}
