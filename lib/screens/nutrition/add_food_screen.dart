import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/repositories.dart';
import '../../widgets/common.dart';
import '../health/health_labels.dart';
import 'nutrition_widgets.dart';

enum _Mode { text, photo, manual }

/// Registrar una comida: describiéndola, con una foto o a mano.
class AddFoodScreen extends StatefulWidget {
  const AddFoodScreen({super.key, required this.day});

  /// Día al que se agrega (hoy = hora actual).
  final DateTime day;

  @override
  State<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends State<AddFoodScreen> {
  _Mode _mode = _Mode.text;
  late String _meal = mealForTime(DateTime.now());

  final _text = TextEditingController();
  final _note = TextEditingController();
  final _manualName = TextEditingController();
  final _manualCalories = TextEditingController();
  final _manualProtein = TextEditingController();
  final _manualCarbs = TextEditingController();
  final _manualFat = TextEditingController();

  Uint8List? _photo;
  FoodEstimate? _estimate;
  double _servings = 1;
  bool _working = false;

  @override
  void dispose() {
    for (final c in [_text, _note, _manualName, _manualCalories, _manualProtein, _manualCarbs, _manualFat]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Si el día es hoy se usa la hora actual; si no, una hora típica de esa comida.
  DateTime get _eatenAt {
    final now = DateTime.now();
    final d = widget.day;
    if (d.year == now.year && d.month == now.month && d.day == now.day) return now;
    const hours = {'breakfast': 8, 'lunch': 14, 'dinner': 20, 'snack': 17};
    return DateTime(d.year, d.month, d.day, hours[_meal] ?? 12);
  }

  Future<void> _run(Future<void> Function() action) async {
    FocusScope.of(context).unfocus();
    setState(() => _working = true);
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _estimateText() async {
    final text = _text.text.trim();
    if (text.length < 2) {
      showMessage(context, 'Describe lo que comiste', error: true);
      return;
    }
    await _run(() async {
      final e = await context.read<NutritionRepository>().estimateText(text);
      if (mounted) setState(() => _estimate = e);
    });
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 70);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photo = bytes;
        _estimate = null;
      });
    } on PlatformException {
      if (mounted) showMessage(context, 'No se pudo abrir la cámara o la galería. Revisa los permisos.', error: true);
    }
  }

  Future<void> _estimatePhoto() async {
    if (_photo == null) return;
    await _run(() async {
      final e = await context.read<NutritionRepository>().estimatePhoto(_photo!, note: _note.text.trim());
      if (!mounted) return;
      setState(() => _estimate = e);
      if (e.items.isEmpty) showMessage(context, e.notes.isEmpty ? 'No reconocimos comida en la foto' : e.notes);
    });
  }

  Future<void> _saveEstimate() async {
    final e = _estimate;
    if (e == null || e.items.isEmpty) return;
    final isPhoto = _mode == _Mode.photo;
    final desc = e.description.isNotEmpty ? e.description : (isPhoto ? 'Platillo (foto)' : _text.text.trim());
    final log = FoodLog.fromNutrition(
      n: e.total * _servings,
      description: _servings == 1 ? desc : '$desc (×${_servings.toStringAsFixed(1)})',
      meal: _meal,
      source: isPhoto ? 'photo' : 'text',
      eatenAt: _eatenAt,
      servings: _servings,
      imageUrl: isPhoto ? e.imageUrl : null,
    );
    await _save(log);
  }

  Future<void> _saveManual() async {
    final name = _manualName.text.trim();
    final kcal = double.tryParse(_manualCalories.text.replaceAll(',', '.'));
    if (name.isEmpty || kcal == null || kcal < 0) {
      showMessage(context, 'Escribe qué comiste y sus calorías', error: true);
      return;
    }
    double? n(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.'));
    await _save(FoodLog(
      eatenAt: _eatenAt,
      meal: _meal,
      description: name,
      calories: kcal.round(),
      proteinG: n(_manualProtein),
      carbsG: n(_manualCarbs),
      fatG: n(_manualFat),
      source: 'manual',
    ));
  }

  Future<void> _save(FoodLog log) async {
    final repo = context.read<NutritionRepository>();
    final refresh = context.read<DataRefresh>();
    await _run(() async {
      await repo.create(log);
      refresh.changed();
      if (!mounted) return;
      showMessage(context, '${log.calories} kcal agregadas a ${mealLabels[log.meal]!.toLowerCase()}');
      Navigator.pop(context, true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar comida')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          SegmentedButton<_Mode>(
            segments: const [
              ButtonSegment(value: _Mode.text, label: Text('Describir'), icon: Icon(Icons.edit_note_rounded)),
              ButtonSegment(value: _Mode.photo, label: Text('Foto'), icon: Icon(Icons.photo_camera_outlined)),
              ButtonSegment(value: _Mode.manual, label: Text('Manual'), icon: Icon(Icons.calculate_outlined)),
            ],
            selected: {_mode},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() {
              _mode = s.first;
              _estimate = null;
              _servings = 1;
            }),
          ),
          const SizedBox(height: 18),
          MealPicker(value: _meal, onChanged: (m) => setState(() => _meal = m), labels: mealLabels, icons: mealIcons),
          if (!(widget.day.year == DateTime.now().year &&
              widget.day.month == DateTime.now().month &&
              widget.day.day == DateTime.now().day)) ...[
            const SizedBox(height: 8),
            Text('Se agregará al ${Fmt.longDay(widget.day)}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
          const SizedBox(height: 18),
          ...switch (_mode) {
            _Mode.text => _textMode(),
            _Mode.photo => _photoMode(),
            _Mode.manual => _manualMode(),
          },
          if (_estimate != null && _estimate!.items.isNotEmpty && _mode != _Mode.manual) ...[
            const SizedBox(height: 18),
            EstimateReview(estimate: _estimate!, servings: _servings, onServings: (v) => setState(() => _servings = v)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _working ? null : _saveEstimate,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Guardar'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _primaryButton(String label, IconData icon, VoidCallback onPressed) {
    return FilledButton.icon(
      onPressed: _working ? null : onPressed,
      icon: _working
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Icon(icon),
      label: Text(_working ? 'Calculando…' : label),
    );
  }

  List<Widget> _textMode() => [
        TextField(
          controller: _text,
          minLines: 2,
          maxLines: 4,
          maxLength: 600,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Ej. 2 tacos de pastor con piña y un refresco de 600 ml'),
        ),
        const SizedBox(height: 8),
        _primaryButton('Calcular calorías', Icons.auto_awesome, _estimateText),
      ];

  List<Widget> _photoMode() => [
        if (_photo != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.memory(_photo!, height: 220, width: double.infinity, fit: BoxFit.cover),
          )
        else
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: ModuleTint.amber.background,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.restaurant_rounded, size: 40, color: ModuleTint.amber.foreground),
                  const SizedBox(height: 8),
                  const Text('Tómale foto a tu plato', style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _working ? null : () => _pickPhoto(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Cámara'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _working ? null : () => _pickPhoto(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Galería'),
              ),
            ),
          ],
        ),
        if (_photo != null) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            maxLength: 300,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Detalles opcionales (ej. "frito en aceite", "porción grande")'),
          ),
          const SizedBox(height: 4),
          _primaryButton('Analizar foto', Icons.auto_awesome, _estimatePhoto),
        ],
      ];

  List<Widget> _manualMode() {
    final numbers = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    const decimal = TextInputType.numberWithOptions(decimal: true);
    return [
      TextField(
        controller: _manualName,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: '¿Qué comiste?'),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _manualCalories,
        keyboardType: decimal,
        inputFormatters: numbers,
        decoration: const InputDecoration(labelText: 'Calorías (kcal)'),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _manualProtein,
              keyboardType: decimal,
              inputFormatters: numbers,
              decoration: const InputDecoration(labelText: 'Proteína g'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _manualCarbs,
              keyboardType: decimal,
              inputFormatters: numbers,
              decoration: const InputDecoration(labelText: 'Carbs g'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _manualFat,
              keyboardType: decimal,
              inputFormatters: numbers,
              decoration: const InputDecoration(labelText: 'Grasa g'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: _working ? null : _saveManual,
        icon: const Icon(Icons.check_rounded),
        label: const Text('Guardar'),
      ),
    ];
  }
}
