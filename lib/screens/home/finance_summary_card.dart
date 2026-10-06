import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import '../budget/finance_screen.dart';
import '../budget/finance_widgets.dart';
import '../expenses/expense_categories.dart';

/// Resumen de Finanzas para Inicio: cuánto queda del periodo, categorías en riesgo y ahorro.
class FinanceSummaryCard extends StatelessWidget {
  const FinanceSummaryCard({super.key, this.view, this.funds = const [], this.fundsTotal = 0});
  final BudgetView? view;
  final List<SavingsFund> funds;
  final double fundsTotal;

  void _open(BuildContext context, int tab) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => FinanceScreen(initialTab: tab)));

  @override
  Widget build(BuildContext context) {
    final v = view;
    final hasBudget = v != null && (v.totals.income != null || v.totals.budgeted > 0);

    // Aún no hay nada configurado: invitación a empezar.
    if (!hasBudget && funds.isEmpty) {
      return InsightCard(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Arma tu presupuesto',
        subtitle: v != null && v.totals.spent > 0
            ? 'Llevas ${Fmt.money(v.totals.spent)} gastados este periodo. Ponles límite y crea tus apartados.'
            : 'Registra tu ingreso, ponle límite a cada categoría y lleva la cuenta de tus ahorros.',
        onTap: () => _open(context, 0),
      );
    }

    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          if (v != null) _BudgetPart(view: v, hasBudget: hasBudget, onTap: () => _open(context, 0)),
          if (v != null && funds.isNotEmpty) const Divider(height: 1),
          if (funds.isNotEmpty) _SavingsPart(funds: funds, total: fundsTotal, onTap: () => _open(context, 2)),
        ],
      ),
    );
  }
}

class _BudgetPart extends StatelessWidget {
  const _BudgetPart({required this.view, required this.hasBudget, required this.onTap});
  final BudgetView view;
  final bool hasBudget;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = view.totals;
    final p = view.period;
    final income = t.income;
    final available = t.available;
    // Lo que se puede gastar = ingreso − apartado; la barra muestra cuánto de eso ya se gastó.
    final spendable = income == null ? null : income - t.saved;
    final ratio = spendable == null || spendable <= 0 ? null : t.spent / spendable;
    final risky = view.lines.where((l) => l.status == 'over' || l.status == 'warning').toList()
      ..sort((a, b) => (b.percent ?? 0).compareTo(a.percent ?? 0));

    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        available != null ? 'TE QUEDA' : 'GASTADO EN EL PERIODO',
                        style: const TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Fmt.money(available ?? t.spent),
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                          color: available != null && available < 0 ? AppColors.priorityHigh : AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      p.daysLeft == 1 ? 'Último día' : 'Quedan ${p.daysLeft} días',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    if (t.perDayLeft != null && p.daysLeft > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${Fmt.money(t.perDayLeft!)} / día',
                        style: const TextStyle(color: AppColors.primaryText, fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            if (ratio != null) ...[
              const SizedBox(height: 12),
              BudgetBar(value: ratio),
              const SizedBox(height: 6),
              Text(
                'Gastaste ${Fmt.money(t.spent)} de ${Fmt.money(spendable!)} disponibles para gastar',
                style: const TextStyle(color: AppColors.mutedLight, fontSize: 12),
              ),
            ] else if (!hasBudget || income == null) ...[
              const SizedBox(height: 8),
              const Text(
                'Registra tu ingreso del periodo para saber cuánto te queda.',
                style: TextStyle(color: AppColors.mutedLight, fontSize: 12),
              ),
            ],
            if (risky.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final l in risky.take(3)) _RiskChip(line: l)],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RiskChip extends StatelessWidget {
  const _RiskChip({required this.line});
  final BudgetLine line;

  @override
  Widget build(BuildContext context) {
    final over = line.status == 'over';
    final cat = categoryByName(line.category.name);
    final color = over ? AppColors.priorityHigh : const Color(0xFFB37A12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: over ? AppColors.priorityHighBg : const Color(0xFFFFF4D9),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(cat.icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            over ? '${line.category.name}: te pasaste' : '${line.category.name} ${(line.percent ?? 0).round()} %',
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _SavingsPart extends StatelessWidget {
  const _SavingsPart({required this.funds, required this.total, required this.onTap});
  final List<SavingsFund> funds;
  final double total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // La meta más cercana a cumplirse (sin contar las ya cumplidas).
    final withGoal = funds.where((f) => f.goal != null && f.balance < f.goal!).toList()
      ..sort((a, b) => (b.progress ?? 0).compareTo(a.progress ?? 0));
    final goal = withGoal.firstOrNull;
    final tint = goal == null ? ModuleTint.green : ModuleTint.byName(goal.color, fallback: ModuleTint.green);

    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.savings_outlined, size: 20, color: AppColors.success),
                const SizedBox(width: 8),
                const Expanded(child: Text('Llevas apartado', style: TextStyle(fontWeight: FontWeight.w600))),
                Text(Fmt.money(total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ],
            ),
            if (goal != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(financeIcon(goal.icon), size: 16, color: tint.foreground),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${goal.name}: ${Fmt.money(goal.balance)} de ${Fmt.money(goal.goal!)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${(goal.progress ?? 0).round()} %',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: tint.foreground),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              BudgetBar(value: (goal.progress ?? 0) / 100, color: tint.foreground, height: 6),
            ] else if (funds.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  funds.take(3).map((f) => '${f.name} ${Fmt.money(f.balance)}').join(' · '),
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
