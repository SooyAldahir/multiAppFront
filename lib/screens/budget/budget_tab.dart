import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/repositories.dart';
import '../../widgets/common.dart';
import '../expenses/expense_categories.dart';
import 'finance_widgets.dart';
import 'plan_budget_screen.dart';

String periodLabel(BudgetPeriod p) {
  final sameMonth = p.startDate.month == p.endDate.month && p.startDate.year == p.endDate.year;
  final start = DateFormat(sameMonth ? 'd' : 'd MMM', 'es').format(p.startDate).replaceAll('.', '');
  final end = DateFormat('d MMM y', 'es').format(p.endDate).replaceAll('.', '');
  return '$start – $end';
}

/// Pestaña Presupuesto: cuánto entra, cuánto va por categoría, cuánto queda.
class BudgetTab extends StatefulWidget {
  const BudgetTab({super.key, this.onViewLoaded});

  /// Avisa a la pantalla de Finanzas qué periodo se está viendo (para ajustes y el botón +).
  final ValueChanged<BudgetView>? onViewLoaded;

  @override
  State<BudgetTab> createState() => BudgetTabState();
}

class BudgetTabState extends State<BudgetTab> {
  BudgetView? _view;
  List<BudgetPeriod> _periods = [];
  int? _periodId; // null = periodo actual
  bool _loading = true;
  String? _error;
  late final DataRefresh _refresh;

  @override
  void initState() {
    super.initState();
    _refresh = context.read<DataRefresh>()..addListener(load);
    context.read<CategoriesStore>().ensureLoaded();
    load();
  }

  @override
  void dispose() {
    _refresh.removeListener(load);
    super.dispose();
  }

  Future<void> load() async {
    final repo = context.read<BudgetRepository>();
    try {
      final view = _periodId == null ? await repo.current() : await repo.period(_periodId!);
      final periods = await repo.periods();
      if (!mounted) return;
      setState(() {
        _view = view;
        _periods = periods;
        _error = null;
        _loading = false;
      });
      widget.onViewLoaded?.call(view);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Error inesperado: $e';
        _loading = false;
      });
    }
  }

  void _go(int delta) {
    final idx = _periods.indexWhere((p) => p.id == _view?.period.id);
    final target = idx - delta; // la lista viene del más reciente al más antiguo
    if (idx < 0 || target < 0 || target >= _periods.length) return;
    setState(() {
      _periodId = target == 0 ? null : _periods[target].id;
      _loading = true;
    });
    load();
  }

  Future<void> _setIncome() async {
    final view = _view!;
    final previous = _periods.where((p) => p.income != null && p.id != view.period.id).firstOrNull;
    final income = await askAmount(
      context,
      title: '¿Cuánto recibes este periodo?',
      message: 'Sueldo, ventas, apoyos… Con esto se calcula cuánto te queda.',
      initial: view.totals.income ?? previous?.income,
    );
    if (income == null || !mounted) return;
    await _update(income: income);
  }

  Future<void> _editLimit(BudgetLine line) async {
    final value = await askAmount(
      context,
      title: 'Límite para ${line.category.name}',
      message: 'Llevas ${Fmt.money(line.spent)} este periodo. Déjalo vacío para quitar el límite.',
      initial: line.limit,
      allowZero: true,
    );
    if (value == null || !mounted) return;
    final limits = <int, double>{
      for (final l in _view!.lines)
        if (l.category.id != null && l.limit != null) l.category.id!: l.limit!,
    };
    limits[line.category.id!] = value;
    await _update(limits: limits);
  }

  Future<void> _update({double? income, Map<int, double>? limits}) async {
    try {
      final view = await context.read<BudgetRepository>().updatePeriod(_view!.period.id, income: income, limits: limits);
      if (!mounted) return;
      setState(() => _view = view);
      _refresh.changed();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  Future<void> openPlan() async {
    if (_view == null) return;
    final saved = await Navigator.of(context).push<BudgetView>(
      MaterialPageRoute(builder: (_) => PlanBudgetScreen(view: _view!)),
    );
    if (saved != null && mounted) setState(() => _view = saved);
  }

  Future<void> _insights() async {
    final repo = context.read<BudgetRepository>();
    final id = _view!.period.id;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) => _InsightsSheet(future: repo.insights(id)),
    );
  }

  Future<void> _close() async {
    final view = _view!;
    final repo = context.read<BudgetRepository>();
    final fundsRepo = context.read<FundsRepository>();
    List<SavingsFund> funds = [];
    try {
      funds = (await fundsRepo.all()).$1;
    } catch (_) {}
    if (!mounted) return;
    final leftover = view.totals.available ?? 0;
    final result = await showDialog<(bool, int?)>(
      context: context,
      builder: (_) => _CloseDialog(
        leftover: leftover,
        funds: funds,
        preselected: view.settings.rolloverFundId,
        early: !view.period.hasEnded,
      ),
    );
    if (result == null || !result.$1 || !mounted) return;
    try {
      final moved = await repo.close(view.period.id, fundId: result.$2);
      if (!mounted) return;
      showMessage(context, moved > 0 ? 'Periodo cerrado. Apartaste ${Fmt.money(moved)}' : 'Periodo cerrado');
      _refresh.changed();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<CategoriesStore>();
    if (_loading && _view == null) return const Center(child: CircularProgressIndicator());
    if (_error != null && _view == null) return ErrorState(message: _error!, onRetry: load);
    final view = _view!;
    final t = view.totals;
    final p = view.period;
    final idx = _periods.indexWhere((x) => x.id == p.id);
    final withLimit = view.lines.where((l) => l.limit != null).toList()
      ..sort((a, b) => (b.percent ?? 0).compareTo(a.percent ?? 0));
    final noLimit = view.lines.where((l) => l.limit == null && l.spent > 0).toList()
      ..sort((a, b) => b.spent.compareTo(a.spent));

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: idx >= 0 && idx < _periods.length - 1 ? () => _go(-1) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(periodLabel(p), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    Text(
                      p.isClosed
                          ? 'Cerrado'
                          : p.isCurrent
                              ? (p.daysLeft == 1 ? 'Último día' : 'Quedan ${p.daysLeft} días')
                              : view.settings.label,
                      style: const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(onPressed: idx > 0 ? () => _go(1) : null, icon: const Icon(Icons.chevron_right_rounded)),
            ],
          ),
          const SizedBox(height: 8),
          _SummaryCard(totals: t, period: p, onSetIncome: p.isClosed ? null : _setIncome),
          const SizedBox(height: 12),
          if (!p.isClosed && t.unassigned != null && t.unassigned!.abs() >= 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SurfaceCard(
                onTap: openPlan,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      t.unassigned! > 0 ? Icons.pie_chart_outline_rounded : Icons.warning_amber_rounded,
                      color: t.unassigned! > 0 ? AppColors.primary : AppColors.priorityHigh,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t.unassigned! > 0
                            ? 'Tienes ${Fmt.money(t.unassigned!)} sin asignar'
                            : 'Asignaste ${Fmt.money(-t.unassigned!)} más de lo que recibes',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Text('Planear', style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          Row(
            children: [
              if (!p.isClosed)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: openPlan,
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text('Planear'),
                  ),
                ),
              if (!p.isClosed) const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _insights,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Consejos IA'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (withLimit.isEmpty && noLimit.isEmpty)
            EmptyState(
              icon: Icons.pie_chart_outline_rounded,
              title: 'Arma tu presupuesto',
              message: 'Ponle un límite a cada categoría (comida, transporte, entretenimiento…) y ve cuánto te queda.',
              action: TextButton.icon(onPressed: openPlan, icon: const Icon(Icons.tune_rounded), label: const Text('Planear')),
            )
          else ...[
            if (withLimit.isNotEmpty) ...[
              const SectionHeader(title: 'Por categoría'),
              for (final l in withLimit)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _LineTile(line: l, onTap: p.isClosed ? null : () => _editLimit(l)),
                ),
            ],
            if (noLimit.isNotEmpty) ...[
              const SizedBox(height: 14),
              const SectionHeader(title: 'Sin límite'),
              for (final l in noLimit)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _LineTile(line: l, onTap: p.isClosed ? null : () => _editLimit(l)),
                ),
            ],
          ],
          if (!p.isClosed) ...[
            const SizedBox(height: 18),
            Center(
              child: TextButton.icon(
                onPressed: _close,
                icon: const Icon(Icons.lock_outline_rounded, size: 18),
                label: Text(p.hasEnded ? 'Cerrar periodo y apartar lo que sobró' : 'Cerrar periodo'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.totals, required this.period, this.onSetIncome});
  final BudgetTotals totals;
  final BudgetPeriod period;
  final VoidCallback? onSetIncome;

  @override
  Widget build(BuildContext context) {
    final t = totals;
    final hasIncome = t.income != null;
    final available = t.available ?? 0;
    return GlowCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasIncome ? 'TE QUEDA' : 'GASTADO EN EL PERIODO',
            style: const TextStyle(color: Color(0xFFB7ACFA), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.9),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Fmt.money(hasIncome ? available : t.spent),
              style: TextStyle(
                color: hasIncome && available < 0 ? const Color(0xFFFF8E86) : Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
          ),
          if (hasIncome && t.perDayLeft != null && period.isCurrent && !period.isClosed)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Puedes gastar ${Fmt.money(t.perDayLeft!)} al día',
                style: const TextStyle(color: Color(0xFFAAA7B1), fontSize: 12),
              ),
            ),
          const SizedBox(height: 14),
          if (hasIncome) ...[
            MoneyRow(label: 'Ingreso', value: t.income!, light: true),
            MoneyRow(label: 'Gastado', value: t.spent, light: true),
            if (t.saved != 0) MoneyRow(label: 'Apartado', value: t.saved, light: true),
            if (t.budgeted > 0) MoneyRow(label: 'Presupuestado', value: t.budgeted, light: true),
            if (onSetIncome != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onSetIncome,
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFCFC6FF)),
                  child: const Text('Cambiar ingreso'),
                ),
              ),
          ] else if (onSetIncome != null)
            FilledButton.icon(
              onPressed: onSetIncome,
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.ink),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Registrar mi ingreso'),
            ),
        ],
      ),
    );
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({required this.line, this.onTap});
  final BudgetLine line;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cat = categoryByName(line.category.name);
    final limit = line.limit;
    final ratio = limit == null || limit == 0 ? 0.0 : line.spent / limit;
    final remaining = line.remaining ?? 0;
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
                Row(
                  children: [
                    Expanded(
                      child: Text(line.category.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                    Text(
                      limit == null ? Fmt.money(line.spent) : '${Fmt.money(line.spent)} / ${Fmt.money(limit)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                if (limit != null) ...[
                  const SizedBox(height: 7),
                  BudgetBar(value: ratio),
                  const SizedBox(height: 5),
                  Text(
                    remaining >= 0 ? 'Quedan ${Fmt.money(remaining)}' : 'Te pasaste por ${Fmt.money(-remaining)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: remaining >= 0 ? AppColors.mutedLight : AppColors.priorityHigh,
                      fontWeight: remaining >= 0 ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                ] else
                  const Text('Toca para ponerle límite', style: TextStyle(fontSize: 12, color: AppColors.mutedLight)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CloseDialog extends StatefulWidget {
  const _CloseDialog({required this.leftover, required this.funds, this.preselected, required this.early});
  final double leftover;
  final List<SavingsFund> funds;
  final int? preselected;
  final bool early;

  @override
  State<_CloseDialog> createState() => _CloseDialogState();
}

class _CloseDialogState extends State<_CloseDialog> {
  late int? _fund = widget.funds.any((f) => f.id == widget.preselected) ? widget.preselected : widget.funds.firstOrNull?.id;

  @override
  Widget build(BuildContext context) {
    final canMove = widget.leftover > 0 && widget.funds.isNotEmpty;
    return AlertDialog(
      title: const Text('Cerrar periodo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.early)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text('Este periodo todavía no termina. Al cerrarlo ya no podrás cambiar su presupuesto.'),
            ),
          Text(
            widget.leftover > 0 ? 'Te sobraron ${Fmt.money(widget.leftover)}.' : 'No hay sobrante para apartar.',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (canMove) ...[
            const SizedBox(height: 10),
            const Text('¿A qué apartado lo mandamos?'),
            RadioGroup<int?>(
              groupValue: _fund,
              onChanged: (v) => setState(() => _fund = v),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final f in widget.funds)
                    RadioListTile<int?>(contentPadding: EdgeInsets.zero, dense: true, value: f.id, title: Text(f.name)),
                  const RadioListTile<int?>(contentPadding: EdgeInsets.zero, dense: true, value: null, title: Text('No apartar')),
                ],
              ),
            ),
          ] else if (widget.leftover > 0)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Crea un apartado (pestaña Apartados) para guardar lo que sobra.', style: TextStyle(color: AppColors.muted)),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, (true, canMove ? _fund : null)), child: const Text('Cerrar')),
      ],
    );
  }
}

class _InsightsSheet extends StatelessWidget {
  const _InsightsSheet({required this.future});
  final Future<BudgetInsights> future;

  Widget _section(String title, IconData icon, Color color, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          for (final i in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 8),
                  Expanded(child: Text(i, style: const TextStyle(height: 1.35))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: FutureBuilder<BudgetInsights>(
          future: future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 220,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [CircularProgressIndicator(), SizedBox(height: 12), Text('Analizando tu periodo…')],
                  ),
                ),
              );
            }
            if (snap.hasError) {
              final msg = snap.error is ApiException ? (snap.error as ApiException).message : 'No se pudo generar el análisis';
              return Padding(padding: const EdgeInsets.all(24), child: Text(msg));
            }
            final r = snap.data!;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text('Tu periodo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(r.summary, style: const TextStyle(fontSize: 15, height: 1.4)),
                  _section('Lo que vas haciendo bien', Icons.check_circle_outline_rounded, AppColors.success, r.wins),
                  _section('Ojo con', Icons.warning_amber_rounded, const Color(0xFFE0A030), r.warnings),
                  _section('Consejos', Icons.lightbulb_outline_rounded, AppColors.primary, r.tips),
                  if (r.suggestedSavings > 0) ...[
                    const SizedBox(height: 16),
                    SurfaceCard(
                      child: Row(
                        children: [
                          const Icon(Icons.savings_outlined, color: AppColors.success),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('Podrías apartar ${Fmt.money(r.suggestedSavings)} el siguiente periodo.',
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  const Text(
                    'Son sugerencias generales hechas por IA, no asesoría financiera profesional.',
                    style: TextStyle(color: AppColors.mutedLight, fontSize: 12),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
