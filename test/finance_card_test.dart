import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiapp/models/models.dart';
import 'package:multiapp/screens/home/finance_summary_card.dart';

BudgetView _view({double? income, String status = 'warning'}) => BudgetView.fromJson({
      'settings': {'period': 'monthly'},
      'period': {'id': 1, 'startDate': '2026-10-01', 'endDate': '2026-10-31', 'period': 'monthly', 'income': income, 'daysLeft': 26, 'isCurrent': true},
      'categories': [
        {'id': 1, 'name': 'Comida', 'icon': 'restaurant', 'color': 'coral', 'limit': 2000, 'spent': 1700, 'percent': 85, 'status': status},
      ],
      'totals': {
        'income': income,
        'budgeted': 2000,
        'spent': 1700,
        'saved': 1000,
        'available': income == null ? null : income - 1700 - 1000,
        'perDayLeft': income == null ? null : (income - 2700) / 26,
      },
    });

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  testWidgets('Resumen de finanzas: lo que queda, categoría en riesgo y meta de ahorro', (tester) async {
    await tester.pumpWidget(_wrap(FinanceSummaryCard(
      view: _view(income: 12000),
      funds: [
        SavingsFund.fromJson({'id': 1, 'name': 'Emergencias', 'icon': 'shield', 'color': 'coral', 'goal': 20000, 'balance': 5000, 'progress': 25}),
      ],
      fundsTotal: 5000,
    )));
    expect(find.text('TE QUEDA'), findsOneWidget);
    expect(find.text('Quedan 26 días'), findsOneWidget);
    expect(find.text('Comida 85 %'), findsOneWidget);
    expect(find.text('Llevas apartado'), findsOneWidget);
    expect(find.textContaining('Emergencias:'), findsOneWidget);
  });

  testWidgets('Resumen de finanzas: invita a empezar si no hay presupuesto ni apartados', (tester) async {
    await tester.pumpWidget(_wrap(FinanceSummaryCard(view: BudgetView.fromJson({
      'settings': {},
      'period': {'id': 1, 'startDate': '2026-10-01', 'endDate': '2026-10-31', 'period': 'monthly'},
      'categories': [],
      'totals': {'spent': 0, 'budgeted': 0},
    }))));
    expect(find.text('Arma tu presupuesto'), findsOneWidget);
  });
}
