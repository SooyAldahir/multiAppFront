import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/repositories.dart';
import '../../widgets/common.dart';
import '../expenses/expense_categories.dart';
import 'finance_widgets.dart';

/// Crear o editar un apartado. Devuelve true si se guardó (o "deleted" si se eliminó).
class FundFormScreen extends StatefulWidget {
  const FundFormScreen({super.key, this.fund});
  final SavingsFund? fund;

  @override
  State<FundFormScreen> createState() => _FundFormScreenState();
}

class _FundFormScreenState extends State<FundFormScreen> {
  late final _f = widget.fund;
  late final _name = TextEditingController(text: _f?.name);
  final _initial = TextEditingController();
  late final _goal = TextEditingController(text: moneyText(_f?.goal));
  late final _autoValue = TextEditingController(text: moneyText(_f?.autoValue));
  late String _icon = _f?.icon ?? 'savings';
  late String _color = _f?.color ?? 'green';
  late DateTime? _goalDate = _f?.goalDate;
  late FundAutoType _auto = _f?.autoType ?? FundAutoType.none;
  late bool _archived = _f?.isArchived ?? false;
  bool _saving = false;

  bool get _isEditing => _f?.id != null;

  @override
  void dispose() {
    _name.dispose();
    _initial.dispose();
    _goal.dispose();
    _autoValue.dispose();
    super.dispose();
  }

  Future<void> _pickGoalDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _goalDate ?? DateTime(now.year, 12, 31),
      firstDate: now,
      lastDate: DateTime(now.year + 30),
      helpText: '¿Para cuándo?',
    );
    if (picked != null) setState(() => _goalDate = picked);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showMessage(context, 'Escribe un nombre', error: true);
      return;
    }
    final goal = _goal.text.trim().isEmpty ? null : parseMoney(_goal.text);
    if (_goal.text.trim().isNotEmpty && (goal == null || goal <= 0)) {
      showMessage(context, 'Revisa la meta', error: true);
      return;
    }
    final autoValue = _auto == FundAutoType.none ? null : parseMoney(_autoValue.text);
    if (_auto != FundAutoType.none && (autoValue == null || autoValue <= 0)) {
      showMessage(context, 'Escribe cuánto apartar automáticamente', error: true);
      return;
    }
    if (_auto == FundAutoType.percent && autoValue! > 100) {
      showMessage(context, 'El porcentaje no puede ser mayor a 100', error: true);
      return;
    }
    final fund = SavingsFund(
      name: name,
      icon: _icon,
      color: _color,
      goal: goal,
      goalDate: goal == null ? null : _goalDate,
      autoType: _auto,
      autoValue: autoValue,
      isArchived: _archived,
    );
    final repo = context.read<FundsRepository>();
    final refresh = context.read<DataRefresh>();
    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await repo.update(_f!.id!, fund);
      } else {
        await repo.create(fund, initialBalance: parseMoney(_initial.text) ?? 0);
      }
      refresh.changed();
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final fund = _f!;
    final ok = await confirm(
      context,
      title: 'Eliminar "${fund.name}"',
      message: 'Se borrará el apartado y todo su historial. Si solo ya no lo usas, mejor archívalo.',
    );
    if (!ok || !mounted) return;
    final repo = context.read<FundsRepository>();
    final refresh = context.read<DataRefresh>();
    try {
      await repo.delete(fund.id!);
      refresh.changed();
      if (mounted) Navigator.pop(context, 'deleted');
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tint = ModuleTint.byName(_color, fallback: ModuleTint.green);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar apartado' : 'Nuevo apartado'),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Eliminar',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.priorityHigh),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Row(
            children: [
              ModuleIcon(icon: financeIcon(_icon), tint: tint, large: true),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: _name,
                  autofocus: !_isEditing,
                  maxLength: 60,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej. Vacaciones, Coche, Diezmo', counterText: ''),
                ),
              ),
            ],
          ),
          if (!_isEditing) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _initial,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: moneyInputFormatters,
              decoration: const InputDecoration(
                labelText: '¿Cuánto llevas ya? (opcional)',
                prefixText: r'$ ',
                helperText: 'Lo que ya tienes guardado para esto, en el banco o en efectivo',
              ),
            ),
          ],
          const SizedBox(height: 22),
          const SectionHeader(title: 'Meta (opcional)'),
          TextField(
            controller: _goal,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: moneyInputFormatters,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: '¿Cuánto quieres juntar?', prefixText: r'$ '),
          ),
          if (_goal.text.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            InputChip(
              avatar: const Icon(Icons.flag_outlined, size: 18),
              label: Text(_goalDate == null ? 'Sin fecha límite' : 'Para el ${DateFormat("d 'de' MMMM 'de' y", 'es').format(_goalDate!)}'),
              onPressed: _pickGoalDate,
              onDeleted: _goalDate == null ? null : () => setState(() => _goalDate = null),
              backgroundColor: Colors.white,
              side: const BorderSide(color: AppColors.border),
            ),
          ],
          const SizedBox(height: 22),
          const SectionHeader(title: 'Aportación automática'),
          const Text(
            'Cuando registres tu ingreso del periodo, se apartará esto solo.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 10),
          SegmentedButton<FundAutoType>(
            segments: const [
              ButtonSegment(value: FundAutoType.none, label: Text('No')),
              ButtonSegment(value: FundAutoType.fixed, label: Text('Cantidad')),
              ButtonSegment(value: FundAutoType.percent, label: Text('% ingreso')),
            ],
            selected: {_auto},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _auto = s.first),
          ),
          if (_auto != FundAutoType.none) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _autoValue,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: moneyInputFormatters,
              decoration: InputDecoration(
                labelText: _auto == FundAutoType.percent ? 'Porcentaje del ingreso' : 'Cantidad por periodo',
                prefixText: _auto == FundAutoType.fixed ? r'$ ' : null,
                suffixText: _auto == FundAutoType.percent ? '%' : null,
              ),
            ),
          ],
          const SizedBox(height: 22),
          IconColorPicker(
            icon: _icon,
            color: _color,
            onIcon: (v) => setState(() => _icon = v),
            onColor: (v) => setState(() => _color = v),
          ),
          if (_isEditing) ...[
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _archived,
              onChanged: (v) => setState(() => _archived = v),
              title: const Text('Archivar'),
              subtitle: const Text('Ocultarlo sin perder su historial', style: TextStyle(fontSize: 12)),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: _saving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : Text(_isEditing ? 'Guardar cambios' : 'Crear apartado'),
          ),
        ],
      ),
    );
  }
}
