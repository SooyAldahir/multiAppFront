import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/repositories.dart';
import '../../widgets/common.dart';
import '../expenses/expense_categories.dart';
import 'categories_screen.dart';
import 'finance_widgets.dart';

/// Repartir el ingreso del periodo entre las categorías. Devuelve el BudgetView guardado.
class PlanBudgetScreen extends StatefulWidget {
  const PlanBudgetScreen({super.key, required this.view});
  final BudgetView view;

  @override
  State<PlanBudgetScreen> createState() => _PlanBudgetScreenState();
}

class _PlanBudgetScreenState extends State<PlanBudgetScreen> {
  late final _income = TextEditingController(text: moneyText(widget.view.totals.income));
  final Map<int, TextEditingController> _limits = {};
  List<SavingsFund> _autoFunds = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final l in widget.view.lines) {
      if (l.category.id != null) _limits[l.category.id!] = TextEditingController(text: moneyText(l.limit));
    }
    _loadFunds();
  }

  Future<void> _loadFunds() async {
    try {
      final (funds, _) = await context.read<FundsRepository>().all();
      if (mounted) setState(() => _autoFunds = funds.where((f) => f.autoType != FundAutoType.none).toList());
    } catch (_) {}
  }

  @override
  void dispose() {
    _income.dispose();
    for (final c in _limits.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _incomeValue => parseMoney(_income.text) ?? 0;
  double get _budgeted => _limits.values.fold(0, (s, c) => s + (parseMoney(c.text) ?? 0));

  double get _autoSavings => _autoFunds.fold(0, (s, f) {
        final v = f.autoValue ?? 0;
        return s + (f.autoType == FundAutoType.percent ? _incomeValue * v / 100 : v);
      });

  Future<void> _save() async {
    final income = parseMoney(_income.text);
    if (_income.text.trim().isNotEmpty && income == null) {
      showMessage(context, 'Revisa la cantidad del ingreso', error: true);
      return;
    }
    final limits = <int, double>{};
    for (final e in _limits.entries) {
      final v = e.value.text.trim().isEmpty ? 0.0 : parseMoney(e.value.text);
      if (v == null) {
        showMessage(context, 'Revisa las cantidades', error: true);
        return;
      }
      limits[e.key] = v;
    }
    setState(() => _saving = true);
    try {
      final view = await context.read<BudgetRepository>().updatePeriod(
            widget.view.period.id,
            income: _income.text.trim().isEmpty ? null : income,
            clearIncome: _income.text.trim().isEmpty,
            limits: limits,
          );
      if (!mounted) return;
      context.read<DataRefresh>().changed();
      Navigator.pop(context, view);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unassigned = _incomeValue - _budgeted - _autoSavings;
    final over = unassigned < -0.005;
    final lines = widget.view.lines;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planear presupuesto'),
        actions: [
          IconButton(
            tooltip: 'Categorías',
            icon: const Icon(Icons.category_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CategoriesScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          const Text('¿Cuánto recibes este periodo?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          TextField(
            controller: _income,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: moneyInputFormatters,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            decoration: const InputDecoration(prefixText: r'$ ', hintText: '0', helperText: 'Sueldo, ventas, apoyos… todo lo que entra'),
          ),
          if (_autoFunds.isNotEmpty) ...[
            const SizedBox(height: 14),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Se apartará automáticamente', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  for (final f in _autoFunds)
                    MoneyRow(
                      label: '${f.name} (${f.autoType == FundAutoType.percent ? '${f.autoValue!.toStringAsFixed(0)} %' : 'fijo'})',
                      value: f.autoType == FundAutoType.percent ? _incomeValue * (f.autoValue ?? 0) / 100 : (f.autoValue ?? 0),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          const Text('Límite por categoría', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('Déjalo vacío si no quieres ponerle límite.', style: TextStyle(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 10),
          for (final l in lines)
            if (l.category.id != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _LimitRow(
                  line: l,
                  controller: _limits[l.category.id!]!,
                  onChanged: () => setState(() {}),
                ),
              ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: over ? AppColors.priorityHighBg : AppColors.primarySoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      over ? 'Asignaste más de lo que recibes' : 'Sin asignar',
                      style: TextStyle(fontWeight: FontWeight.w700, color: over ? AppColors.priorityHigh : AppColors.primaryText),
                    ),
                  ),
                  Text(
                    Fmt.money(unassigned),
                    style: TextStyle(fontWeight: FontWeight.w800, color: over ? AppColors.priorityHigh : AppColors.primaryText),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: _saving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : const Text('Guardar presupuesto'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LimitRow extends StatelessWidget {
  const _LimitRow({required this.line, required this.controller, required this.onChanged});
  final BudgetLine line;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final cat = categoryByName(line.category.name);
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          ModuleIcon(icon: cat.icon, tint: cat.tint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.category.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (line.spent > 0)
                  Text('Llevas ${Fmt.money(line.spent)}', style: const TextStyle(color: AppColors.mutedLight, fontSize: 12)),
              ],
            ),
          ),
          SizedBox(
            width: 120,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: moneyInputFormatters,
              onChanged: (_) => onChanged(),
              decoration: const InputDecoration(prefixText: r'$ ', hintText: 'Sin límite', isDense: true),
            ),
          ),
        ],
      ),
    );
  }
}
