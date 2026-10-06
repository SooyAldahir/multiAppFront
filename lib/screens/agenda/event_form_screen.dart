import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/repositories.dart';
import '../../widgets/common.dart';

/// Crear o editar un evento de la agenda.
class EventFormScreen extends StatefulWidget {
  const EventFormScreen({super.key, this.event, this.initialDate});
  final AgendaEvent? event;
  final DateTime? initialDate;

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _location;
  late final TextEditingController _description;
  late DateTime _date;
  late TimeOfDay _start;
  late TimeOfDay _end;
  late bool _allDay;
  late String _color;
  bool _saving = false;

  bool get _isEditing => widget.event?.id != null;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _title = TextEditingController(text: e?.title);
    _location = TextEditingController(text: e?.location);
    _description = TextEditingController(text: e?.description);
    _allDay = e?.allDay ?? false;
    _color = e?.color ?? 'coral';

    if (e != null) {
      _date = startOfDay(e.startAt);
      _start = TimeOfDay.fromDateTime(e.startAt);
      _end = TimeOfDay.fromDateTime(e.endAt ?? e.startAt.add(const Duration(hours: 1)));
    } else {
      final now = DateTime.now();
      _date = startOfDay(widget.initialDate ?? now);
      // Siguiente hora en punto
      final nextHour = (now.hour + 1).clamp(0, 22);
      _start = TimeOfDay(hour: nextHour, minute: 0);
      _end = TimeOfDay(hour: nextHour + 1, minute: 0);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  DateTime _combine(TimeOfDay t) => DateTime(_date.year, _date.month, _date.day, t.hour, t.minute);

  int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime({required bool start}) async {
    final picked = await showTimePicker(context: context, initialTime: start ? _start : _end);
    if (picked == null) return;
    setState(() {
      if (start) {
        final duration = _minutes(_end) - _minutes(_start);
        _start = picked;
        final endMinutes = (_minutes(picked) + (duration > 0 ? duration : 60)).clamp(0, 23 * 60 + 59);
        _end = TimeOfDay(hour: endMinutes ~/ 60, minute: endMinutes % 60);
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_allDay && _minutes(_end) <= _minutes(_start)) {
      showMessage(context, 'La hora de fin debe ser después del inicio', error: true);
      return;
    }

    final event = AgendaEvent(
      title: _title.text.trim(),
      location: _location.text.trim(),
      description: _description.text.trim(),
      startAt: _allDay ? _date : _combine(_start),
      endAt: _allDay ? DateTime(_date.year, _date.month, _date.day, 23, 59) : _combine(_end),
      allDay: _allDay,
      color: _color,
    );

    setState(() => _saving = true);
    final repo = context.read<EventsRepository>();
    final refresh = context.read<DataRefresh>();
    try {
      if (_isEditing) {
        await repo.update(widget.event!.id!, event);
      } else {
        await repo.create(event);
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
    final ok = await confirm(context, title: 'Eliminar evento', message: '¿Eliminar "${widget.event!.title}"?');
    if (!ok || !mounted) return;
    final repo = context.read<EventsRepository>();
    final refresh = context.read<DataRefresh>();
    try {
      await repo.delete(widget.event!.id!);
      refresh.changed();
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar evento' : 'Nuevo evento'),
        actions: [
          if (_isEditing) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded)),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _title,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Título del evento'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Escribe un título' : null,
            ),
            const SizedBox(height: 16),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.event_outlined),
                    title: Text(Fmt.capitalize(Fmt.longDay(_date))),
                    onTap: _pickDate,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.wb_sunny_outlined),
                    title: const Text('Todo el día'),
                    value: _allDay,
                    onChanged: (v) => setState(() => _allDay = v),
                  ),
                  if (!_allDay) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.schedule_rounded),
                      title: const Text('Inicio'),
                      trailing: Text(_start.format(context), style: const TextStyle(fontWeight: FontWeight.w700)),
                      onTap: () => _pickTime(start: true),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.schedule_outlined),
                      title: const Text('Fin'),
                      trailing: Text(_end.format(context), style: const TextStyle(fontWeight: FontWeight.w700)),
                      onTap: () => _pickTime(start: false),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(hintText: 'Lugar o enlace (opcional)', prefixIcon: Icon(Icons.place_outlined)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 4,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Descripción (opcional)'),
            ),
            const SizedBox(height: 20),
            const Text('Color', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ColorPicker(selected: _color, onChanged: (c) => setState(() => _color = c)),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Text(_isEditing ? 'Guardar cambios' : 'Crear evento'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Selector de color con los tintes del mockup.
class ColorPicker extends StatelessWidget {
  const ColorPicker({super.key, required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var i = 0; i < ModuleTint.names.length; i++)
          GestureDetector(
            onTap: () => onChanged(ModuleTint.names[i]),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: ModuleTint.all[i].background,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected == ModuleTint.names[i] ? ModuleTint.all[i].foreground : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: Center(
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(color: ModuleTint.all[i].foreground, shape: BoxShape.circle),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
