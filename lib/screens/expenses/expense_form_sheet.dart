import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/repositories.dart';
import '../../widgets/common.dart';
import '../../services/notification_service.dart';
import '../budget/categories_screen.dart';
import 'expense_categories.dart';

/// Abre la hoja para registrar o editar un gasto. Devuelve true si se guardó.
Future<bool?> showExpenseForm(BuildContext context, {Expense? expense, DateTime? initialDate}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (_) => _ExpenseForm(expense: expense, initialDate: initialDate),
  );
}

class _ExpenseForm extends StatefulWidget {
  const _ExpenseForm({this.expense, this.initialDate});
  final Expense? expense;
  final DateTime? initialDate;

  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.expense == null ? '' : widget.expense!.amount.toStringAsFixed(2),
  );
  late final TextEditingController _description = TextEditingController(text: widget.expense?.description);
  late String _category = widget.expense?.category ?? expenseCategories.first.name;
  late DateTime _date = widget.expense?.spentAt ?? _defaultDate();
  bool _saving = false;

  bool get _isEditing => widget.expense?.id != null;

  /// Si se abre desde un mes pasado, propone el último día de ese mes.
  DateTime _defaultDate() {
    final now = DateTime.now();
    final initial = widget.initialDate;
    if (initial == null || (initial.year == now.year && initial.month == now.month)) return now;
    return DateTime(initial.year, initial.month + 1, 0, 12);
  }

  @override
  void initState() {
    super.initState();
    context.read<CategoriesStore>().ensureLoaded();
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  double? get _parsedAmount => double.tryParse(_amount.text.replaceAll(',', '.').replaceAll(r'$', '').trim());

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = DateTime(picked.year, picked.month, picked.day, 12));
  }

  Future<void> _save() async {
    final amount = _parsedAmount;
    if (amount == null || amount <= 0) {
      showMessage(context, 'Escribe un monto mayor a cero', error: true);
      return;
    }
    final description = _description.text.trim().isEmpty ? _category : _description.text.trim();
    final expense = Expense(
      description: description,
      amount: double.parse(amount.toStringAsFixed(2)),
      category: _category,
      spentAt: _date,
    );

    final repo = context.read<ExpensesRepository>();
    final refresh = context.read<DataRefresh>();
    setState(() => _saving = true);
    try {
      BudgetAlert? alert;
      if (_isEditing) {
        await repo.update(widget.expense!.id!, expense);
      } else {
        alert = (await repo.createWithAlert(expense)).$2;
      }
      refresh.changed();
      if (alert != null) _notifyBudget(alert);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Aviso cuando una categoría llega al 80 % o se pasa del presupuesto.
  void _notifyBudget(BudgetAlert a) {
    final title = a.level >= 100 ? 'Te pasaste en ${a.category}' : 'Vas en el ${a.level} % de ${a.category}';
    final body = a.level >= 100
        ? 'Llevas ${Fmt.money(a.spent)} de ${Fmt.money(a.limit)} presupuestados este periodo.'
        : 'Llevas ${Fmt.money(a.spent)} de ${Fmt.money(a.limit)}. Te quedan ${Fmt.money(a.limit - a.spent)}.';
    NotificationService.instance.showNow(title, body, payload: 'budget');
  }

  Future<void> _delete() async {
    final repo = context.read<ExpensesRepository>();
    final refresh = context.read<DataRefresh>();
    try {
      await repo.delete(widget.expense!.id!);
      refresh.changed();
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: const Color(0xFFD2D0D7), borderRadius: BorderRadius.circular(99)),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEditing ? 'Editar gasto' : 'Nuevo gasto',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                    ),
                  ),
                  if (_isEditing)
                    IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded, color: AppColors.priorityHigh)),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amount,
                autofocus: !_isEditing,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1),
                decoration: const InputDecoration(
                  hintText: '0.00',
                  prefixText: r'$ ',
                  prefixStyle: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.muted),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _description,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: '¿En qué fue? (opcional)'),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(child: Text('Categoría', style: TextStyle(fontWeight: FontWeight.w700))),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CategoriesScreen())),
                    child: const Text('Editar'),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in context.watch<CategoriesStore>().all)
                    ChoiceChip(
                      avatar: Icon(c.icon, size: 18, color: _category == c.name ? Colors.white : c.tint.foreground),
                      label: Text(c.name),
                      selected: _category == c.name,
                      showCheckmark: false,
                      selectedColor: c.tint.foreground,
                      backgroundColor: c.tint.background,
                      side: BorderSide.none,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _category == c.name ? Colors.white : AppColors.inkSoft,
                      ),
                      onSelected: (_) => setState(() => _category = c.name),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              InputChip(
                avatar: const Icon(Icons.event_outlined, size: 18),
                label: Text(Fmt.relativeDay(_date)),
                onPressed: _pickDate,
                backgroundColor: Colors.white,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text(_isEditing ? 'Guardar cambios' : 'Registrar gasto'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
