import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../agenda/event_form_screen.dart';
import '../expenses/expense_form_sheet.dart';
import '../modules.dart';
import '../notes/note_editor_screen.dart';
import '../nutrition/add_food_screen.dart';
import '../todos/todo_form_sheet.dart';

/// Hoja inferior "Crear rápido" del botón central.
Future<void> showQuickCreate(BuildContext context) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.background,
    barrierColor: const Color(0x6618161E),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (context) => const _QuickCreateSheet(),
  );
  if (choice == null || !context.mounted) return;

  switch (choice) {
    case 'todo':
      await showTodoForm(context);
    case 'event':
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EventFormScreen()));
    case 'note':
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NoteEditorScreen()));
    case 'expense':
      await showExpenseForm(context);
    case 'shopping':
      await openModule(context, moduleById('shopping'));
    case 'recipe':
      await openModule(context, moduleById('recipes'));
    case 'food':
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddFoodScreen(day: startOfDay(DateTime.now()))));
    case 'workout':
      await openModule(context, moduleById('workouts'));
  }
}

class _QuickCreateSheet extends StatelessWidget {
  const _QuickCreateSheet();

  @override
  Widget build(BuildContext context) {
    const items = [
      ('todo', 'Tarea', Icons.task_alt_rounded, ModuleTint.blue),
      ('event', 'Evento', Icons.calendar_month_outlined, ModuleTint.coral),
      ('note', 'Nota', Icons.sticky_note_2_outlined, ModuleTint.amber),
      ('expense', 'Gasto', Icons.account_balance_wallet_outlined, ModuleTint.teal),
      ('shopping', 'Compra', Icons.shopping_cart_outlined, ModuleTint.green),
      ('recipe', 'Receta', Icons.restaurant_menu_rounded, ModuleTint.violet),
      ('food', 'Comida', Icons.local_fire_department_outlined, ModuleTint.amber),
      ('workout', 'Entrenar', Icons.fitness_center_rounded, ModuleTint.coral),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(color: const Color(0xFFD2D0D7), borderRadius: BorderRadius.circular(99)),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('NUEVO', style: TextStyle(color: Color(0xFF8C8A94), fontSize: 11, fontWeight: FontWeight.w700)),
                      SizedBox(height: 2),
                      Text('Crear rápido', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
                    ],
                  ),
                ),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Listo')),
              ],
            ),
            const SizedBox(height: 22),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              childAspectRatio: 0.95,
              children: [
                for (final (id, label, icon, tint) in items)
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.pop(context, id),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ModuleIcon(icon: icon, tint: tint),
                        const SizedBox(height: 8),
                        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
