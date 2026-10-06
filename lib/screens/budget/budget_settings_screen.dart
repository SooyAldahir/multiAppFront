import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/repositories.dart';
import '../../widgets/common.dart';
import 'categories_screen.dart';

/// Periodo del presupuesto, día de inicio, avisos y apartado para lo que sobra.
class BudgetSettingsScreen extends StatefulWidget {
  const BudgetSettingsScreen({super.key, required this.initial});
  final BudgetSettings initial;

  @override
  State<BudgetSettingsScreen> createState() => _BudgetSettingsScreenState();
}

class _BudgetSettingsScreenState extends State<BudgetSettingsScreen> {
  late BudgetPeriodType _period = widget.initial.period;
  late int _startDay = widget.initial.startDay;
  late bool _alerts = widget.initial.alertsEnabled;
  late int? _rolloverFund = widget.initial.rolloverFundId;
  List<SavingsFund> _funds = [];
  bool _saving = false;

  static const _weekdays = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

  @override
  void initState() {
    super.initState();
    _loadFunds();
  }

  Future<void> _loadFunds() async {
    try {
      final (funds, _) = await context.read<FundsRepository>().all();
      if (mounted) setState(() => _funds = funds);
    } catch (_) {}
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final saved = await context.read<BudgetRepository>().saveSettings(BudgetSettings(
            period: _period,
            startDay: _period == BudgetPeriodType.biweekly ? 1 : _startDay,
            alertsEnabled: _alerts,
            rolloverFundId: _rolloverFund,
          ));
      if (!mounted) return;
      context.read<DataRefresh>().changed();
      Navigator.pop(context, saved);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes del presupuesto')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const SectionHeader(title: 'Periodo'),
          SegmentedButton<BudgetPeriodType>(
            segments: const [
              ButtonSegment(value: BudgetPeriodType.monthly, label: Text('Mensual')),
              ButtonSegment(value: BudgetPeriodType.biweekly, label: Text('Quincenal')),
              ButtonSegment(value: BudgetPeriodType.weekly, label: Text('Semanal')),
            ],
            selected: {_period},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() {
              _period = s.first;
              if (_period == BudgetPeriodType.weekly && _startDay > 7) _startDay = 1;
            }),
          ),
          const SizedBox(height: 14),
          if (_period == BudgetPeriodType.monthly)
            SurfaceCard(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
              child: Row(
                children: [
                  const Expanded(child: Text('Empieza el día', style: TextStyle(fontWeight: FontWeight.w600))),
                  DropdownButton<int>(
                    value: _startDay.clamp(1, 28),
                    underline: const SizedBox.shrink(),
                    items: [for (var d = 1; d <= 28; d++) DropdownMenuItem(value: d, child: Text('$d'))],
                    onChanged: (v) => setState(() => _startDay = v ?? 1),
                  ),
                ],
              ),
            )
          else if (_period == BudgetPeriodType.weekly)
            SurfaceCard(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
              child: Row(
                children: [
                  const Expanded(child: Text('Empieza el', style: TextStyle(fontWeight: FontWeight.w600))),
                  DropdownButton<int>(
                    value: _startDay.clamp(1, 7),
                    underline: const SizedBox.shrink(),
                    items: [for (var d = 1; d <= 7; d++) DropdownMenuItem(value: d, child: Text(_weekdays[d - 1]))],
                    onChanged: (v) => setState(() => _startDay = v ?? 1),
                  ),
                ],
              ),
            )
          else
            const Text('Del 1 al 15 y del 16 al último día de cada mes.', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 6),
          const Text(
            'Si cambias el periodo, el actual se ajusta de inmediato; tus límites se conservan.',
            style: TextStyle(color: AppColors.mutedLight, fontSize: 12),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Avisos'),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: SwitchListTile(
              value: _alerts,
              onChanged: (v) => setState(() => _alerts = v),
              title: const Text('Avisarme al 80 % y al 100 %'),
              subtitle: const Text('Cuando una categoría esté por agotarse o se pase', style: TextStyle(fontSize: 12)),
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Lo que sobre al cerrar'),
          SurfaceCard(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
            child: Row(
              children: [
                const Expanded(child: Text('Mandarlo a', style: TextStyle(fontWeight: FontWeight.w600))),
                DropdownButton<int?>(
                  value: _funds.any((f) => f.id == _rolloverFund) ? _rolloverFund : null,
                  underline: const SizedBox.shrink(),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Preguntar')),
                    for (final f in _funds) DropdownMenuItem<int?>(value: f.id, child: Text(f.name)),
                  ],
                  onChanged: (v) => setState(() => _rolloverFund = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('Categorías'),
              subtitle: const Text('Agregar, renombrar o quitar', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CategoriesScreen())),
            ),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: _saving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
