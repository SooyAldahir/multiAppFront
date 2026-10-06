import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/repositories.dart';
import '../../widgets/common.dart';
import '../../widgets/items.dart';
import 'todo_form_sheet.dart';

/// Cosas por hacer agrupadas por fecha de vencimiento.
class TodosScreen extends StatefulWidget {
  const TodosScreen({super.key});

  @override
  State<TodosScreen> createState() => _TodosScreenState();
}

class _TodosScreenState extends State<TodosScreen> {
  bool _showCompleted = false;
  List<Todo> _todos = [];
  bool _loading = true;
  String? _error;
  late final DataRefresh _refresh;

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
    try {
      final todos = await context.read<TodosRepository>().all(status: _showCompleted ? 'completed' : 'pending');
      if (!mounted) return;
      setState(() {
        _todos = todos;
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

  Future<void> _toggle(Todo todo) async {
    // Actualización optimista: se quita de la lista al instante.
    setState(() => _todos = _todos.where((t) => t.id != todo.id).toList());
    final repo = context.read<TodosRepository>();
    final refresh = context.read<DataRefresh>();
    try {
      await repo.toggle(todo);
      refresh.changed();
      if (mounted && !todo.isCompleted) showMessage(context, '¡Listo! "${todo.title}" completada');
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
      _load();
    }
  }

  Future<void> _delete(Todo todo) async {
    final repo = context.read<TodosRepository>();
    final refresh = context.read<DataRefresh>();
    setState(() => _todos = _todos.where((t) => t.id != todo.id).toList());
    try {
      await repo.delete(todo.id!);
      refresh.changed();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
      _load();
    }
  }

  Map<String, List<Todo>> _groups() {
    if (_showCompleted) return {'Completadas': _todos};
    final today = startOfDay(DateTime.now());
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final groups = <String, List<Todo>>{'Vencidas': [], 'Hoy': [], 'Próximas': [], 'Sin fecha': []};
    for (final t in _todos) {
      final d = t.dueDate;
      if (d == null) {
        groups['Sin fecha']!.add(t);
      } else if (d.isBefore(today)) {
        groups['Vencidas']!.add(t);
      } else if (d.isBefore(tomorrow)) {
        groups['Hoy']!.add(t);
      } else {
        groups['Próximas']!.add(t);
      }
    }
    groups.removeWhere((_, v) => v.isEmpty);
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pendientes')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.fab,
        foregroundColor: Colors.white,
        onPressed: () => showTodoForm(context),
        child: const Icon(Icons.add_rounded),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Pendientes'), icon: Icon(Icons.radio_button_unchecked)),
                ButtonSegment(value: true, label: Text('Completadas'), icon: Icon(Icons.check_circle_outline)),
              ],
              selected: {_showCompleted},
              showSelectedIcon: false,
              onSelectionChanged: (s) {
                setState(() {
                  _showCompleted = s.first;
                  _loading = true;
                });
                _load();
              },
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              ErrorState(message: _error!, onRetry: _load)
            else if (_todos.isEmpty)
              EmptyState(
                icon: _showCompleted ? Icons.inbox_outlined : Icons.celebration_outlined,
                title: _showCompleted ? 'Nada completado aún' : '¡Todo al día!',
                message: _showCompleted
                    ? 'Las tareas que completes aparecerán aquí.'
                    : 'No tienes pendientes. Toca + para agregar uno.',
              )
            else
              for (final entry in _groups().entries) ...[
                SectionHeader(title: entry.key, trailing: '${entry.value.length}'),
                for (final t in entry.value)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Dismissible(
                      key: ValueKey(t.id),
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
                      onDismissed: (_) => _delete(t),
                      child: TodoTile(
                        todo: t,
                        onToggle: () => _toggle(t),
                        onTap: () => showTodoForm(context, todo: t),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}
