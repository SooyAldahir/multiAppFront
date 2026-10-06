import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/notification_service.dart';
import '../../services/push_service.dart';
import '../../services/repositories.dart';
import '../../widgets/common.dart';

/// Qué recordatorios quiere recibir el usuario y a qué hora.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  NotificationPrefs? _prefs;
  String? _error;
  bool _saving = false;
  bool _dirty = false;

  static const _dayLabels = ['D', 'L', 'M', 'M', 'J', 'V', 'S'];
  static const _minutesOptions = [0, 5, 10, 15, 30, 60, 120];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final p = await context.read<ProfileRepository>().notificationPrefs();
      if (mounted) setState(() => _prefs = p);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _edit(void Function(NotificationPrefs p) change) {
    setState(() {
      change(_prefs!);
      _dirty = true;
    });
  }

  Future<void> _save() async {
    final repo = context.read<ProfileRepository>();
    setState(() => _saving = true);
    try {
      _prefs!.timezone = NotificationService.instance.timezone;
      final saved = await repo.saveNotificationPrefs(_prefs!);
      if (!mounted) return;
      setState(() {
        _prefs = saved;
        _dirty = false;
      });
      await NotificationService.instance.requestPermission();
      if (!mounted) return;
      await NotificationService.instance.sync(repo, context.read<EventsRepository>(), context.read<TodosRepository>());
      if (mounted) showMessage(context, 'Recordatorios actualizados');
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickTime(String section, String key, String fallback) async {
    final current = _prefs!.time(section, key, fallback).split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.tryParse(current.first) ?? 9, minute: int.tryParse(current.last) ?? 0),
    );
    if (picked == null) return;
    final value = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    _edit((p) => p.setTime(section, value, key));
  }

  Future<void> _testLocal() async {
    final ok = await NotificationService.instance.requestPermission();
    await NotificationService.instance.showNow('multiApp', 'Así se verán tus recordatorios 🔔');
    if (!ok && mounted) {
      showMessage(context, 'Si no la ves, activa las notificaciones de multiApp en los ajustes del teléfono.');
    }
  }

  Future<void> _testPush() async {
    final repo = context.read<ProfileRepository>();
    if (!PushService.instance.registered) await PushService.instance.start(repo);
    if (!PushService.instance.registered) {
      if (mounted) {
        showMessage(context, PushService.instance.unavailableReason ?? 'Este teléfono no está registrado para push', error: true);
      }
      return;
    }
    try {
      await repo.testPush();
      if (mounted) showMessage(context, 'Push enviado. Debe llegar en unos segundos.');
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  Widget _timeChip(String section, String key, String fallback, {String? label}) {
    final value = _prefs!.time(section, key, fallback);
    return ActionChip(
      avatar: const Icon(Icons.schedule_rounded, size: 18),
      label: Text(label == null ? value : '$label · $value'),
      onPressed: () => _pickTime(section, key, fallback),
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    required String subtitle,
    required String key,
    List<Widget> children = const [],
  }) {
    final on = _prefs!.enabled(key);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SurfaceCard(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              secondary: Icon(icon),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
              value: on,
              onChanged: (v) => _edit((p) => p.setEnabled(key, v)),
            ),
            if (on && children.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Wrap(spacing: 8, runSpacing: 8, children: children),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _prefs;
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: p == null
          ? (_error != null ? ErrorState(message: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator()))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              children: [
                _section(
                  icon: Icons.event_outlined,
                  title: 'Eventos de la agenda',
                  subtitle: 'Aviso antes de que empiecen',
                  key: 'events',
                  children: [
                    for (final m in _minutesOptions)
                      ChoiceChip(
                        label: Text(m == 0 ? 'A la hora' : m < 60 ? '$m min antes' : '${m ~/ 60} h antes'),
                        selected: p.minutesBefore == m,
                        showCheckmark: false,
                        onSelected: (_) => _edit((p) => p.minutesBefore = m),
                      ),
                  ],
                ),
                _section(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'Pendientes',
                  subtitle: 'El día de su fecha límite',
                  key: 'todos',
                  children: [_timeChip('todos', 'time', '09:00')],
                ),
                _section(
                  icon: Icons.fitness_center_rounded,
                  title: 'Ejercicio',
                  subtitle: 'Recordatorio para entrenar',
                  key: 'workout',
                  children: [
                    _timeChip('workout', 'time', '18:00'),
                    const SizedBox(width: double.infinity),
                    for (var d = 1; d <= 7; d++)
                      _DayToggle(
                        label: _dayLabels[d % 7],
                        selected: p.workoutDays.contains(d % 7),
                        onTap: () => _edit((p) {
                          final days = p.workoutDays.toSet();
                          days.contains(d % 7) ? days.remove(d % 7) : days.add(d % 7);
                          p.workoutDays = days.toList()..sort();
                        }),
                      ),
                  ],
                ),
                _section(
                  icon: Icons.restaurant_outlined,
                  title: 'Comidas',
                  subtitle: 'Para registrar tus calorías',
                  key: 'meals',
                  children: [
                    _timeChip('meals', 'breakfast', '08:30', label: 'Desayuno'),
                    _timeChip('meals', 'lunch', '14:30', label: 'Comida'),
                    _timeChip('meals', 'dinner', '20:30', label: 'Cena'),
                  ],
                ),
                _section(
                  icon: Icons.wb_sunny_outlined,
                  title: 'Resumen del día',
                  subtitle: p.pushAvailable
                      ? 'Cada mañana: cuántos eventos y pendientes tienes'
                      : 'Cada mañana (sin push: aviso general para revisar tu día)',
                  key: 'dailySummary',
                  children: [_timeChip('dailySummary', 'time', '07:30')],
                ),
                const SizedBox(height: 12),
                const SectionHeader(title: 'Probar'),
                SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.notifications_active_outlined),
                        title: const Text('Notificación local de prueba'),
                        onTap: _testLocal,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.cloud_outlined),
                        title: const Text('Push de prueba (Firebase)'),
                        subtitle: Text(
                          !p.pushAvailable
                              ? 'El servidor aún no tiene Firebase configurado'
                              : PushService.instance.registered
                                  ? 'Este teléfono está registrado'
                                  : (PushService.instance.unavailableReason ?? 'Este teléfono aún no está registrado'),
                          style: const TextStyle(fontSize: 12),
                        ),
                        enabled: p.pushAvailable,
                        onTap: _testPush,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Zona horaria: ${NotificationService.instance.timezone}. '
                  'Los recordatorios los programa tu teléfono y pueden llegar con unos minutos de diferencia.',
                  style: const TextStyle(color: AppColors.mutedLight, fontSize: 12),
                ),
              ],
            ),
      bottomNavigationBar: p == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: FilledButton(
                onPressed: _saving || !_dirty ? null : _save,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : Text(_dirty ? 'Guardar cambios' : 'Sin cambios'),
              ),
            ),
    );
  }
}

class _DayToggle extends StatelessWidget {
  const _DayToggle({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(color: selected ? Colors.white : AppColors.ink, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
