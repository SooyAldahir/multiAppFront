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
import 'fund_detail_screen.dart';
import 'fund_form_screen.dart';

/// Apartados sugeridos para empezar rápido.
const suggestedFunds = [
  SavingsFund(name: 'Ahorro', icon: 'savings', color: 'green'),
  SavingsFund(name: 'Emergencias', icon: 'shield', color: 'coral'),
  SavingsFund(name: 'Medicamentos', icon: 'medication', color: 'pink'),
];

/// Pestaña Apartados: cuánto llevas en cada fondo (aunque el dinero esté en el banco o en efectivo).
class FundsTab extends StatefulWidget {
  const FundsTab({super.key});

  @override
  State<FundsTab> createState() => FundsTabState();
}

class FundsTabState extends State<FundsTab> {
  List<SavingsFund> _funds = [];
  double _total = 0;
  bool _loading = true;
  String? _error;
  late final DataRefresh _refresh;

  @override
  void initState() {
    super.initState();
    _refresh = context.read<DataRefresh>()..addListener(load);
    load();
  }

  @override
  void dispose() {
    _refresh.removeListener(load);
    super.dispose();
  }

  Future<void> load() async {
    try {
      final (funds, total) = await context.read<FundsRepository>().all();
      if (!mounted) return;
      setState(() {
        _funds = funds;
        _total = total;
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

  Future<void> openNew() async {
    final created = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const FundFormScreen()));
    if (created == true) load();
  }

  Future<void> _createSuggested() async {
    final repo = context.read<FundsRepository>();
    setState(() => _loading = true);
    try {
      for (final f in suggestedFunds) {
        await repo.create(f);
      }
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
    _refresh.changed();
  }

  Future<void> _quickMove(SavingsFund f, bool deposit) async {
    String note = '';
    final amount = await askAmount(
      context,
      title: deposit ? 'Depositar en ${f.name}' : 'Retirar de ${f.name}',
      message: deposit ? null : 'Tienes ${Fmt.money(f.balance)} en este apartado.',
      action: deposit ? 'Depositar' : 'Retirar',
      noteLabel: 'Nota (opcional)',
      onNote: (v) => note = v,
    );
    if (amount == null || !mounted) return;
    try {
      await context.read<FundsRepository>().move(f.id!, deposit: deposit, amount: amount, note: note.isEmpty ? null : note);
      _refresh.changed();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _funds.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_error != null && _funds.isEmpty) return ErrorState(message: _error!, onRetry: load);

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          GlowCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LLEVAS APARTADO',
                  style: TextStyle(color: Color(0xFFB7ACFA), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.9),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    Fmt.money(_total),
                    style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _funds.isEmpty
                      ? 'Registra aquí lo que guardas, esté donde esté'
                      : '${_funds.length == 1 ? '1 apartado' : '${_funds.length} apartados'} · el dinero puede estar en el banco o en efectivo',
                  style: const TextStyle(color: Color(0xFFAAA7B1), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          if (_funds.isEmpty)
            EmptyState(
              icon: Icons.savings_outlined,
              title: 'Crea tus apartados',
              message: 'Separa tu dinero por objetivos: ahorro, emergencias, medicamentos, vacaciones…',
              action: Column(
                children: [
                  FilledButton.icon(
                    onPressed: _createSuggested,
                    icon: const Icon(Icons.auto_awesome_motion_outlined),
                    label: const Text('Crear Ahorro, Emergencias y Medicamentos'),
                  ),
                  TextButton(onPressed: openNew, child: const Text('Crear uno a mi manera')),
                ],
              ),
            )
          else
            for (final f in _funds)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FundCard(
                  fund: f,
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => FundDetailScreen(fundId: f.id!)));
                    load();
                  },
                  onDeposit: () => _quickMove(f, true),
                  onWithdraw: f.balance > 0 ? () => _quickMove(f, false) : null,
                ),
              ),
        ],
      ),
    );
  }
}

class FundCard extends StatelessWidget {
  const FundCard({super.key, required this.fund, this.onTap, this.onDeposit, this.onWithdraw});
  final SavingsFund fund;
  final VoidCallback? onTap;
  final VoidCallback? onDeposit;
  final VoidCallback? onWithdraw;

  @override
  Widget build(BuildContext context) {
    final f = fund;
    final tint = ModuleTint.byName(f.color, fallback: ModuleTint.green);
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ModuleIcon(icon: financeIcon(f.icon), tint: tint),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    if (f.autoLabel != null)
                      Text(f.autoLabel!, style: const TextStyle(color: AppColors.mutedLight, fontSize: 12)),
                  ],
                ),
              ),
              Text(Fmt.money(f.balance), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ],
          ),
          if (f.goal != null) ...[
            const SizedBox(height: 12),
            BudgetBar(value: (f.progress ?? 0) / 100, color: tint.foreground),
            const SizedBox(height: 6),
            Text(goalText(f), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onWithdraw,
                icon: const Icon(Icons.remove_rounded, size: 18),
                label: const Text('Retirar'),
              ),
              TextButton.icon(
                onPressed: onDeposit,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Depositar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String goalText(SavingsFund f) {
  if (f.goal == null) return '';
  if (f.balance >= f.goal!) return '¡Meta de ${Fmt.money(f.goal!)} cumplida! 🎉';
  final parts = <String>['${(f.progress ?? 0).toStringAsFixed(0)} % de ${Fmt.money(f.goal!)}'];
  if (f.goalDate != null) parts.add('para el ${DateFormat("d MMM y", 'es').format(f.goalDate!).replaceAll('.', '')}');
  if (f.neededPerMonth != null) parts.add('aparta ${Fmt.money(f.neededPerMonth!)}/mes');
  return parts.join(' · ');
}
