import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/repositories.dart';
import '../../widgets/common.dart';
import 'health_labels.dart';

/// Perfil de salud: se usa para la meta de calorías y para adaptar las rutinas.
/// Devuelve `true` al guardar.
class HealthProfileScreen extends StatefulWidget {
  const HealthProfileScreen({super.key, this.initial});
  final HealthProfile? initial;

  @override
  State<HealthProfileScreen> createState() => _HealthProfileScreenState();
}

class _HealthProfileScreenState extends State<HealthProfileScreen> {
  late final _p = widget.initial;
  late String _sex = _p?.sex ?? 'male';
  late final _birthYear = TextEditingController(text: _p?.birthYear.toString());
  late final _height = TextEditingController(text: _p?.heightCm.toStringAsFixed(0));
  late final _weight = TextEditingController(text: _p?.weightKg.toStringAsFixed(1));
  late final _limitations = TextEditingController(text: _p?.limitations);
  late String _activity = _p?.activityLevel ?? 'light';
  late String _goal = _p?.goal ?? 'maintain';
  late String _level = _p?.fitnessLevel ?? 'beginner';
  late String _equipment = _p?.equipment ?? 'none';
  late int _days = _p?.daysPerWeek ?? 3;
  late int _minutes = _p?.minutesPerSession ?? 45;
  bool _saving = false;
  HealthTargets? _targets;

  @override
  void dispose() {
    _birthYear.dispose();
    _height.dispose();
    _weight.dispose();
    _limitations.dispose();
    super.dispose();
  }

  double? _num(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.').trim());

  Future<void> _save() async {
    final year = int.tryParse(_birthYear.text.trim());
    final height = _num(_height);
    final weight = _num(_weight);
    final now = DateTime.now().year;
    if (year == null || year < 1900 || year > now - 10) {
      showMessage(context, 'Escribe un año de nacimiento válido', error: true);
      return;
    }
    if (height == null || height < 100 || height > 250) {
      showMessage(context, 'Escribe tu estatura en centímetros (ej. 170)', error: true);
      return;
    }
    if (weight == null || weight < 25 || weight > 350) {
      showMessage(context, 'Escribe tu peso en kilos (ej. 70.5)', error: true);
      return;
    }

    final profile = HealthProfile(
      sex: _sex,
      birthYear: year,
      heightCm: height,
      weightKg: weight,
      activityLevel: _activity,
      goal: _goal,
      fitnessLevel: _level,
      daysPerWeek: _days,
      minutesPerSession: _minutes,
      equipment: _equipment,
      limitations: _limitations.text.trim().isEmpty ? null : _limitations.text.trim(),
    );

    setState(() => _saving = true);
    try {
      final data = await context.read<HealthRepository>().save(profile);
      if (!mounted) return;
      context.read<DataRefresh>().changed();
      setState(() => _targets = data.targets);
      await _showTargets(data.targets);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showTargets(HealthTargets? t) async {
    if (t == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tus metas diarias'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${t.calories.round()} kcal', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Proteína ${t.protein.round()} g · Carbohidratos ${t.carbs.round()} g · Grasa ${t.fat.round()} g'),
            const SizedBox(height: 12),
            Text(
              'Gasto diario estimado: ${t.tdee.round()} kcal\nÍndice de masa corporal: ${t.bmi.toStringAsFixed(1)}',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text(
              'Son estimaciones generales. Si tienes alguna condición de salud, consulta a un profesional.',
              style: TextStyle(color: AppColors.mutedLight, fontSize: 12),
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido'))],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      );

  Widget _choices(Map<String, String> options, String value, ValueChanged<String> onChanged) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in options.entries)
          ChoiceChip(
            label: Text(e.value),
            selected: value == e.key,
            showCheckmark: false,
            selectedColor: AppColors.primary,
            labelStyle: TextStyle(fontWeight: FontWeight.w600, color: value == e.key ? Colors.white : AppColors.inkSoft),
            onSelected: (_) => onChanged(e.key),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final numberInput = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil de salud')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          const Text(
            'Con estos datos calculamos tu meta de calorías y adaptamos tus rutinas.',
            style: TextStyle(color: AppColors.muted),
          ),
          _label('Sexo'),
          _choices(const {'male': 'Hombre', 'female': 'Mujer'}, _sex, (v) => setState(() => _sex = v)),
          _label('Datos'),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _birthYear,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Año de nacimiento'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _height,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: numberInput,
                  decoration: const InputDecoration(labelText: 'Estatura (cm)'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _weight,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: numberInput,
                  decoration: const InputDecoration(labelText: 'Peso (kg)'),
                ),
              ),
            ],
          ),
          _label('Objetivo'),
          _choices(goalLabels, _goal, (v) => setState(() => _goal = v)),
          _label('Actividad diaria'),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final e in activityLabels.entries)
                  ListTile(
                    dense: true,
                    title: Text(e.value),
                    trailing: Icon(
                      _activity == e.key ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                      color: _activity == e.key ? AppColors.primary : AppColors.mutedLight,
                    ),
                    onTap: () => setState(() => _activity = e.key),
                  ),
              ],
            ),
          ),
          _label('Nivel de entrenamiento'),
          _choices(levelLabels, _level, (v) => setState(() => _level = v)),
          _label('¿Dónde entrenas?'),
          _choices(equipmentLabels, _equipment, (v) => setState(() => _equipment = v)),
          _label('Días por semana: $_days'),
          Slider(value: _days.toDouble(), min: 1, max: 7, divisions: 6, label: '$_days', onChanged: (v) => setState(() => _days = v.round())),
          _label('Minutos por sesión: $_minutes'),
          Slider(
            value: _minutes.toDouble(),
            min: 15,
            max: 120,
            divisions: 21,
            label: '$_minutes',
            onChanged: (v) => setState(() => _minutes = v.round()),
          ),
          _label('Lesiones o limitaciones (opcional)'),
          TextField(
            controller: _limitations,
            minLines: 1,
            maxLines: 3,
            maxLength: 300,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Ej. dolor de rodilla derecha, hernia lumbar…'),
          ),
          if (_targets != null) ...[
            const SizedBox(height: 8),
            InsightCard(title: 'Meta: ${_targets!.calories.round()} kcal', subtitle: 'Guardado'),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Guardar perfil'),
          ),
        ],
      ),
    );
  }
}
