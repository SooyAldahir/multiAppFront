import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../expenses/expense_categories.dart';

double? parseMoney(String text) => double.tryParse(text.replaceAll(',', '').replaceAll(r'$', '').replaceAll(' ', '').trim());

String moneyText(double? v) => v == null || v == 0 ? '' : (v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(2));

final moneyInputFormatters = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];

/// Pide una cantidad en un diálogo. Devuelve null si se cancela; 0 si se deja vacío y [allowZero].
Future<double?> askAmount(
  BuildContext context, {
  required String title,
  String? message,
  double? initial,
  String action = 'Guardar',
  bool allowZero = false,
  String? noteLabel,
  ValueChanged<String>? onNote,
}) {
  final controller = TextEditingController(text: moneyText(initial));
  final note = TextEditingController();
  return showDialog<double>(
    context: context,
    builder: (context) {
      void submit() {
        final v = controller.text.trim().isEmpty ? 0.0 : parseMoney(controller.text);
        if (v == null || v < 0 || (!allowZero && v == 0)) return;
        onNote?.call(note.text.trim());
        Navigator.pop(context, double.parse(v.toStringAsFixed(2)));
      }

      return AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message != null) ...[
              Text(message, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: moneyInputFormatters,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              decoration: const InputDecoration(prefixText: r'$ ', hintText: '0'),
              onSubmitted: (_) => submit(),
            ),
            if (noteLabel != null) ...[
              const SizedBox(height: 10),
              TextField(
                controller: note,
                maxLength: 200,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(hintText: noteLabel, counterText: ''),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: submit, child: Text(action)),
        ],
      );
    },
  );
}

/// Barra de avance con color según el estado (verde, ámbar al 80 %, rojo al pasarse).
class BudgetBar extends StatelessWidget {
  const BudgetBar({super.key, required this.value, this.color, this.height = 7});
  final double value; // 0..1+ (más de 1 = se pasó)
  final Color? color;
  final double height;

  static Color colorFor(double value) {
    if (value > 1) return AppColors.danger;
    if (value >= 0.8) return const Color(0xFFE0A030);
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1).toDouble(),
        minHeight: height,
        backgroundColor: AppColors.chip,
        valueColor: AlwaysStoppedAnimation(color ?? colorFor(value)),
      ),
    );
  }
}

/// Selector de ícono y color (categorías y apartados).
class IconColorPicker extends StatelessWidget {
  const IconColorPicker({
    super.key,
    required this.icon,
    required this.color,
    required this.onIcon,
    required this.onColor,
  });
  final String icon;
  final String color;
  final ValueChanged<String> onIcon;
  final ValueChanged<String> onColor;

  @override
  Widget build(BuildContext context) {
    final tint = ModuleTint.byName(color, fallback: ModuleTint.ink);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Color', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < ModuleTint.names.length; i++)
              GestureDetector(
                onTap: () => onColor(ModuleTint.names[i]),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: ModuleTint.all[i].foreground,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color == ModuleTint.names[i] ? AppColors.ink : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Ícono', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in financeIcons.entries)
              GestureDetector(
                onTap: () => onIcon(e.key),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: icon == e.key ? tint.foreground : tint.background,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(e.value, size: 22, color: icon == e.key ? Colors.white : tint.foreground),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Fila "etiqueta ........ $monto" para resúmenes.
class MoneyRow extends StatelessWidget {
  const MoneyRow({super.key, required this.label, required this.value, this.color, this.bold = false, this.light = false});
  final String label;
  final double value;
  final Color? color;
  final bool bold;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final base = light ? const Color(0xFFCFCBDA) : AppColors.muted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: base, fontSize: 13))),
          Text(
            Fmt.money(value),
            style: TextStyle(
              color: color ?? (light ? Colors.white : AppColors.ink),
              fontSize: 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
