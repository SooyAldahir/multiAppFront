import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/repositories.dart';
import '../../widgets/common.dart';

/// Abre la hoja para crear o editar una tarea. Devuelve true si se guardó.
Future<bool?> showTodoForm(BuildContext context, {Todo? todo}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (_) => _TodoForm(todo: todo),
  );
}

class _TodoForm extends StatefulWidget {
  const _TodoForm({this.todo});
  final Todo? todo;

  @override
  State<_TodoForm> createState() => _TodoFormState();
}

class _TodoFormState extends State<_TodoForm> {
  late final TextEditingController _title = TextEditingController(text: widget.todo?.title);
  late final TextEditingController _description = TextEditingController(text: widget.todo?.description);
  late DateTime? _due = widget.todo?.dueDate;
  late Priority _priority = widget.todo?.priority ?? Priority.medium;
  bool _saving = false;

  bool get _isEditing => widget.todo?.id != null;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _due ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    // Se guarda al final del día para que "vence hoy" siga vigente todo el día.
    if (picked != null) setState(() => _due = DateTime(picked.year, picked.month, picked.day, 23, 59));
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      showMessage(context, 'Escribe qué tienes que hacer', error: true);
      return;
    }
    final repo = context.read<TodosRepository>();
    final refresh = context.read<DataRefresh>();
    setState(() => _saving = true);
    try {
      final data = Todo(
        title: _title.text.trim(),
        description: _description.text.trim(),
        dueDate: _due,
        priority: _priority,
        isCompleted: widget.todo?.isCompleted ?? false,
      );
      if (_isEditing) {
        await repo.update(widget.todo!.id!, data.toJson());
      } else {
        await repo.create(data);
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
    final repo = context.read<TodosRepository>();
    final refresh = context.read<DataRefresh>();
    try {
      await repo.delete(widget.todo!.id!);
      refresh.changed();
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  Widget _chip({required IconData icon, required String label, required VoidCallback onTap, VoidCallback? onClear}) {
    return InputChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
      onDeleted: onClear,
      backgroundColor: Colors.white,
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
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
                      _isEditing ? 'Editar tarea' : 'Nueva tarea',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                    ),
                  ),
                  if (_isEditing)
                    IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded, color: AppColors.priorityHigh)),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _title,
                autofocus: !_isEditing,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: '¿Qué tienes que hacer?'),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _description,
                minLines: 1,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Detalles (opcional)'),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(
                    icon: Icons.event_outlined,
                    label: _due == null ? 'Fecha límite' : Fmt.relativeDay(_due!),
                    onTap: _pickDate,
                    onClear: _due == null ? null : () => setState(() => _due = null),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('Prioridad', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              SegmentedButton<Priority>(
                segments: [for (final p in Priority.values) ButtonSegment(value: p, label: Text(p.label))],
                selected: {_priority},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _priority = s.first),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text(_isEditing ? 'Guardar cambios' : 'Agregar tarea'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
