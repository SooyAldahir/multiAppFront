import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/repositories.dart';
import '../../widgets/common.dart';
import 'expense_categories.dart';
import 'expense_form_sheet.dart';

/// Control de gastos personales por mes.
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key, this.embedded = false});

  /// true cuando se muestra como pestaña dentro de Finanzas (sin barra ni botón propios).
  final bool embedded;

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<Expense> _expenses = [];
  bool _loading = true;
  String? _error;
  late final DataRefresh _refresh;

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  @override
  void initState() {
    super.initState();
    _refresh = context.read<DataRefresh>()..addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _refresh.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final from = _month;
    final to = DateTime(_month.year, _month.month + 1);
    try {
      final expenses = await context.read<ExpensesRepository>().range(from, to);
      if (!mounted) return;
      setState(() {
        _expenses = expenses;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Error inesperado: $e';
        _loading = false;
      });
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _loading = true;
    });
    _load();
  }

  Future<void> _delete(Expense e) async {
    final repo = context.read<ExpensesRepository>();
    final refresh = context.read<DataRefresh>();
    setState(() => _expenses = _expenses.where((x) => x.id != e.id).toList());
    try {
      await repo.delete(e.id!);
      refresh.changed();
    } on ApiException catch (err) {
      if (mounted) showMessage(context, err.message, error: true);
      _load();
    }
  }

  /// Agrupa los gastos por día (más reciente primero).
  List<MapEntry<DateTime, List<Expense>>> _byDay() {
    final groups = <DateTime, List<Expense>>{};
    for (final e in _expenses) {
      groups.putIfAbsent(startOfDay(e.spentAt), () => []).add(e);
    }
    final entries = groups.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final total = _expenses.fold<double>(0, (sum, e) => sum + e.amount);
    final categories = totalsByCategory(_expenses);
    context.watch<CategoriesStore>(); // repinta si cambian nombres o íconos

    final body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
          children: [
            Row(
              children: [
                IconButton(onPressed: () => _changeMonth(-1), icon: const Icon(Icons.chevron_left_rounded)),
                Expanded(
                  child: Text(
                    Fmt.capitalize(Fmt.monthYear(_month)),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: _isCurrentMonth ? null : () => _changeMonth(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _TotalCard(month: _month, total: total, count: _expenses.length, isCurrentMonth: _isCurrentMonth),
            const SizedBox(height: 24),
            if (_loading)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              ErrorState(message: _error!, onRetry: _load)
            else if (_expenses.isEmpty)
              EmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Sin gastos este mes',
                message: 'Registra tus gastos con el botón + y aquí verás en qué se va tu dinero.',
                action: TextButton.icon(
                  onPressed: () => showExpenseForm(context, initialDate: _month),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Registrar gasto'),
                ),
              )
            else ...[
              const SectionHeader(title: 'Por categoría'),
              SurfaceCard(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                child: Column(
                  children: [for (final c in categories) _CategoryRow(total: c, monthTotal: total)],
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Movimientos'),
              for (final day in _byDay()) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          Fmt.capitalize(Fmt.relativeDay(day.key)),
                          style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        Fmt.money(day.value.fold<double>(0, (s, e) => s + e.amount)),
                        style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                for (final e in day.value)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Dismissible(
                      key: ValueKey('expense-${e.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: AppColors.priorityHighBg,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(Icons.delete_outline_rounded, color: AppColors.priorityHigh),
                      ),
                      onDismissed: (_) => _delete(e),
                      child: ExpenseTile(expense: e, onTap: () => showExpenseForm(context, expense: e)),
                    ),
                  ),
              ],
            ],
          ],
        ),
    );

    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Gastos')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.fab,
        foregroundColor: Colors.white,
        onPressed: () => showExpenseForm(context, initialDate: _month),
        child: const Icon(Icons.add_rounded),
      ),
      body: body,
    );
  }
}

/// Tarjeta oscura con el total del mes.
class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.month, required this.total, required this.count, required this.isCurrentMonth});
  final DateTime month;
  final double total;
  final int count;
  final bool isCurrentMonth;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final daysElapsed = isCurrentMonth ? DateTime.now().day : daysInMonth;
    final dailyAverage = daysElapsed == 0 ? 0 : total / daysElapsed;

    return GlowCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isCurrentMonth ? 'GASTADO ESTE MES' : 'GASTADO EN ${Fmt.monthYear(month).toUpperCase()}',
            style: const TextStyle(color: Color(0xFFB7ACFA), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.9),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Fmt.money(total),
              style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${count == 1 ? '1 gasto' : '$count gastos'} · ${Fmt.money(dailyAverage)} por día en promedio',
            style: const TextStyle(color: Color(0xFFAAA7B1), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.total, required this.monthTotal});
  final CategoryTotal total;
  final double monthTotal;

  @override
  Widget build(BuildContext context) {
    final cat = categoryByName(total.category);
    final share = monthTotal == 0 ? 0.0 : total.total / monthTotal;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: cat.tint.background, borderRadius: BorderRadius.circular(11)),
            child: Icon(cat.icon, size: 19, color: cat.tint.foreground),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(total.category, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    ),
                    Text(Fmt.money(total.total), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: share,
                    minHeight: 6,
                    backgroundColor: AppColors.chip,
                    valueColor: AlwaysStoppedAnimation(cat.tint.foreground),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 38,
            child: Text(
              '${(share * 100).round()}%',
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de un gasto.
class ExpenseTile extends StatelessWidget {
  const ExpenseTile({super.key, required this.expense, this.onTap});
  final Expense expense;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cat = categoryByName(expense.category);
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ModuleIcon(icon: cat.icon, tint: cat.tint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(expense.category, style: const TextStyle(color: AppColors.mutedLight, fontSize: 12)),
              ],
            ),
          ),
          Text(
            '-${Fmt.money(expense.amount)}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}
