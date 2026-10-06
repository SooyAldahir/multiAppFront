import 'dart:async';
import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/repositories.dart';
import '../../widgets/common.dart';
import 'workout_plan_screen.dart';

/// Modo entrenamiento: marca las series, descansa con temporizador y guarda al terminar.
class WorkoutSessionScreen extends StatefulWidget {
  const WorkoutSessionScreen({super.key, required this.plan});
  final WorkoutPlan plan;

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  final _stopwatch = Stopwatch()..start();
  late final List<int> _done = List.filled(widget.plan.exercises.length, 0);
  Timer? _ticker;
  int _restLeft = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      if (_restLeft > 0) {
        _restLeft--;
        if (_restLeft == 0) HapticFeedback.mediumImpact();
      }
    });
  }

  int get _totalSets => widget.plan.exercises.fold(0, (a, e) => a + e.sets);
  int get _doneSets => _done.fold(0, (a, b) => a + b);

  void _toggleSet(int exercise, int set) {
    final e = widget.plan.exercises[exercise];
    setState(() {
      if (set < _done[exercise]) {
        _done[exercise] = set; // desmarcar desde esa serie
        _restLeft = 0;
      } else {
        _done[exercise] = set + 1;
        // Descanso automático, salvo en la última serie de todo el entrenamiento.
        _restLeft = _doneSets >= _totalSets ? 0 : e.restSeconds;
      }
    });
  }

  String _clock(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _finish() async {
    if (_doneSets == 0) {
      showMessage(context, 'Marca al menos una serie antes de terminar', error: true);
      return;
    }
    if (_doneSets < _totalSets) {
      final ok = await confirm(
        context,
        title: 'Terminar entrenamiento',
        message: 'Llevas $_doneSets de $_totalSets series. ¿Guardarlo así?',
        action: 'Guardar',
      );
      if (!ok || !mounted) return;
    }

    final plan = widget.plan;
    final minutes = max(1, (_stopwatch.elapsed.inSeconds / 60).ceil());
    final double ratio = plan.durationMinutes > 0 ? (minutes / plan.durationMinutes).clamp(0.2, 2.0).toDouble() : 1.0;
    final session = WorkoutSession(
      title: plan.title,
      focus: plan.focus.isEmpty ? null : plan.focus,
      performedAt: DateTime.now(),
      durationMinutes: minutes,
      caloriesBurned: (plan.estimatedCalories * ratio * (_doneSets / _totalSets).clamp(0.3, 1.0).toDouble()).round(),
      exercises: [
        for (var i = 0; i < plan.exercises.length; i++)
          {
            'name': plan.exercises[i].name,
            'reps': plan.exercises[i].reps,
            'setsPlanned': plan.exercises[i].sets,
            'setsDone': _done[i],
          },
      ],
    );

    final repo = context.read<WorkoutsRepository>();
    final refresh = context.read<DataRefresh>();
    setState(() => _saving = true);
    try {
      final saved = await repo.save(session);
      refresh.changed();
      if (!mounted) return;
      showMessage(context, '¡Buen trabajo! ${saved.durationMinutes} min · ${saved.caloriesBurned} kcal. Quedó en tu agenda.');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmExit() async {
    final ok = await confirm(
      context,
      title: 'Salir del entrenamiento',
      message: 'No se guardará el progreso. ¿Salir?',
      action: 'Salir',
    );
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final progress = _totalSets == 0 ? 0.0 : _doneSets / _totalSets;

    return PopScope(
      canPop: _doneSets == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(plan.title),
          actions: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  _clock(_stopwatch.elapsed.inSeconds),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(value: progress, minHeight: 4, backgroundColor: AppColors.chip),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_restLeft > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                    decoration: BoxDecoration(color: AppColors.fab, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        const Icon(Icons.hourglass_bottom_rounded, color: Color(0xFFB7ACFA)),
                        const SizedBox(width: 10),
                        Text('Descanso  ${_clock(_restLeft)}',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setState(() => _restLeft += 15),
                          child: const Text('+15 s', style: TextStyle(color: Color(0xFFD5CDF8))),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _restLeft = 0),
                          child: const Text('Saltar', style: TextStyle(color: Color(0xFFD5CDF8))),
                        ),
                      ],
                    ),
                  ),
                FilledButton.icon(
                  onPressed: _saving ? null : _finish,
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.flag_rounded),
                  label: Text('Terminar ($_doneSets/$_totalSets series)'),
                ),
              ],
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            for (var i = 0; i < plan.exercises.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExerciseCard(
                      index: i + 1,
                      exercise: plan.exercises[i],
                      trailing: _done[i] >= plan.exercises[i].sets
                          ? const Icon(Icons.check_circle_rounded, color: AppColors.success)
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var s = 0; s < plan.exercises[i].sets; s++)
                          ChoiceChip(
                            label: Text('Serie ${s + 1} · ${plan.exercises[i].reps}'),
                            selected: s < _done[i],
                            showCheckmark: true,
                            selectedColor: ModuleTint.green.background,
                            checkmarkColor: ModuleTint.green.foreground,
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: s < _done[i] ? ModuleTint.green.foreground : AppColors.inkSoft,
                            ),
                            onSelected: (_) => _toggleSet(i, s),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
