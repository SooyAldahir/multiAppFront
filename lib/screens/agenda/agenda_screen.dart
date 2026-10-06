import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/repositories.dart';
import '../../widgets/common.dart';
import '../../widgets/items.dart';
import 'event_form_screen.dart';

/// Agenda personal: semana navegable + eventos del día seleccionado.
class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  late DateTime _selected = startOfDay(DateTime.now());
  List<AgendaEvent> _weekEvents = [];
  bool _loading = true;
  String? _error;
  late final DataRefresh _refresh;

  /// Lunes de la semana del día seleccionado.
  DateTime get _weekStart => _mondayOf(_selected);

  static DateTime _mondayOf(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

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
    final from = _weekStart;
    final to = DateTime(from.year, from.month, from.day + 7);
    try {
      final events = await context.read<EventsRepository>().range(from, to);
      if (!mounted) return;
      setState(() {
        _weekEvents = events;
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

  void _select(DateTime day) {
    final changedWeek = _mondayOf(day) != _weekStart;
    setState(() => _selected = startOfDay(day));
    if (changedWeek) {
      setState(() => _loading = true);
      _load();
    }
  }

  List<AgendaEvent> _eventsOn(DateTime day) {
    final next = DateTime(day.year, day.month, day.day + 1);
    return _weekEvents.where((e) {
      final end = e.endAt ?? e.startAt;
      return e.startAt.isBefore(next) && !end.isBefore(day);
    }).toList();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) _select(picked);
  }

  @override
  Widget build(BuildContext context) {
    final dayEvents = _eventsOn(_selected);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda'),
        actions: [
          TextButton(onPressed: () => _select(DateTime.now()), child: const Text('Hoy')),
          IconButton(onPressed: _pickDate, icon: const Icon(Icons.calendar_month_outlined)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.fab,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => EventFormScreen(initialDate: _selected)),
        ),
        child: const Icon(Icons.add_rounded),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    Fmt.capitalize(Fmt.longDay(_selected)),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: () => _select(_selected.subtract(const Duration(days: 7))),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                IconButton(
                  onPressed: () => _select(_selected.add(const Duration(days: 7))),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _WeekStrip(
              weekStart: _weekStart,
              selected: _selected,
              hasEvents: (d) => _eventsOn(d).isNotEmpty,
              onSelect: _select,
            ),
            const SizedBox(height: 24),
            SectionHeader(
              title: Fmt.relativeDay(_selected),
              trailing: dayEvents.length == 1 ? '1 evento' : '${dayEvents.length} eventos',
            ),
            if (_loading)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              ErrorState(message: _error!, onRetry: _load)
            else if (dayEvents.isEmpty)
              const EmptyState(
                icon: Icons.event_available_outlined,
                title: 'Nada agendado',
                message: 'Toca + para agregar un evento a este día.',
              )
            else
              for (final e in dayEvents)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: EventTile(
                    event: e,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => EventFormScreen(event: e)),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.weekStart, required this.selected, required this.hasEvents, required this.onSelect});
  final DateTime weekStart;
  final DateTime selected;
  final bool Function(DateTime) hasEvents;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    const labels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    final today = startOfDay(DateTime.now());
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Builder(builder: (context) {
            final day = DateTime(weekStart.year, weekStart.month, weekStart.day + i);
            final isSelected = day == selected;
            final isToday = day == today;
            return Expanded(
              child: GestureDetector(
                onTap: () => onSelect(day),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.fab : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isSelected ? AppColors.fab : AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? const Color(0xFFB7ACFA) : AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.white : (isToday ? AppColors.primary : AppColors.ink),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: hasEvents(day)
                              ? (isSelected ? Colors.white : const Color(0xFFDF6A4E))
                              : Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}
