import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/repositories.dart';
import '../../widgets/common.dart';
import '../expenses/expense_categories.dart';
import 'finance_widgets.dart';
import 'fund_form_screen.dart';
import 'funds_tab.dart';

/// Detalle de un apartado: saldo, meta e historial de depósitos y retiros.
class FundDetailScreen extends StatefulWidget {
  const FundDetailScreen({super.key, required this.fundId});
  final int fundId;

  @override
  State<FundDetailScreen> createState() => _FundDetailScreenState();
}

class _FundDetailScreenState extends State<FundDetailScreen> {
  SavingsFund? _fund;
  List<FundMovement> _movements = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final (fund, movements) = await context.read<FundsRepository>().get(widget.fundId);
      if (!mounted) return;
      setState(() {
        _fund = fund;
        _movements = movements;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'Error inesperado: $e');
    }
  }

  Future<void> _move(bool deposit) async {
    final f = _fund!;
    String note = '';
    final amount = await askAmount(
      context,
      title: deposit ? 'Depositar en ${f.name}' : 'Retirar de ${f.name}',
      message: deposit ? null : 'Tienes ${Fmt.money(f.balance)} en este apartado.',
      action: deposit ? 'Depositar' : 'Retirar',
      noteLabel: deposit ? 'Nota (opcional)' : '¿Para qué? (opcional)',
      onNote: (v) => note = v,
    );
    if (amount == null || !mounted) return;
    final refresh = context.read<DataRefresh>();
    try {
      await context.read<FundsRepository>().move(f.id!, deposit: deposit, amount: amount, note: note.isEmpty ? null : note);
      refresh.changed();
      await _load();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  Future<void> _deleteMovement(FundMovement m) async {
    final refresh = context.read<DataRefresh>();
    try {
      await context.read<FundsRepository>().deleteMovement(m.id);
      refresh.changed();
      await _load();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
      _load();
    }
  }

  Future<void> _edit() async {
    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(builder: (_) => FundFormScreen(fund: _fund)),
    );
    if (!mounted) return;
    if (result == 'deleted') {
      Navigator.pop(context);
    } else if (result == true) {
      _load();
    }
  }

  String _sourceLabel(FundMovement m) => switch (m.source) {
        'auto' => 'Automático',
        'rollover' => 'Sobrante del periodo',
        _ => m.isDeposit ? 'Depósito' : 'Retiro',
      };

  @override
  Widget build(BuildContext context) {
    final f = _fund;
    return Scaffold(
      appBar: AppBar(
        title: Text(f?.name ?? 'Apartado'),
        actions: [if (f != null) IconButton(tooltip: 'Editar', onPressed: _edit, icon: const Icon(Icons.edit_outlined))],
      ),
      body: f == null
          ? (_error != null ? ErrorState(message: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                children: [
                  _Header(fund: f),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: f.balance > 0 ? () => _move(false) : null,
                          icon: const Icon(Icons.remove_rounded),
                          label: const Text('Retirar'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _move(true),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Depositar'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Movimientos'),
                  if (_movements.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Aún no hay movimientos.', style: TextStyle(color: AppColors.muted)),
                    )
                  else
                    for (final m in _movements)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Dismissible(
                          key: ValueKey('mov-${m.id}'),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) => confirm(
                            context,
                            title: 'Borrar movimiento',
                            message: 'El saldo de "${f.name}" se recalculará.',
                            action: 'Borrar',
                          ),
                          onDismissed: (_) => _deleteMovement(m),
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(color: AppColors.priorityHighBg, borderRadius: BorderRadius.circular(18)),
                            child: const Icon(Icons.delete_outline_rounded, color: AppColors.priorityHigh),
                          ),
                          child: SurfaceCard(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(
                                  m.isDeposit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                  color: m.isDeposit ? AppColors.success : AppColors.priorityHigh,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(m.note?.isNotEmpty == true ? m.note! : _sourceLabel(m),
                                          maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                                      Text(
                                        '${_sourceLabel(m)} · ${Fmt.capitalize(Fmt.relativeDay(m.movedAt))}',
                                        style: const TextStyle(color: AppColors.mutedLight, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${m.isDeposit ? '+' : '−'}${Fmt.money(m.amount.abs())}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: m.isDeposit ? AppColors.success : AppColors.priorityHigh,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.fund});
  final SavingsFund fund;

  @override
  Widget build(BuildContext context) {
    final f = fund;
    final tint = ModuleTint.byName(f.color, fallback: ModuleTint.green);
    return GlowCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(financeIcon(f.icon), color: const Color(0xFFB7ACFA), size: 18),
              const SizedBox(width: 6),
              Text(
                f.name.toUpperCase(),
                style: const TextStyle(color: Color(0xFFB7ACFA), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.9),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Fmt.money(f.balance),
              style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1),
            ),
          ),
          if (f.goal != null) ...[
            const SizedBox(height: 12),
            BudgetBar(value: (f.progress ?? 0) / 100, color: tint.foreground, height: 8),
            const SizedBox(height: 6),
            Text(goalText(f), style: const TextStyle(color: Color(0xFFCFCBDA), fontSize: 12)),
          ],
          if (f.autoLabel != null) ...[
            const SizedBox(height: 8),
            Text(f.autoLabel!, style: const TextStyle(color: Color(0xFFAAA7B1), fontSize: 12)),
          ],
        ],
      ),
    );
  }
}
