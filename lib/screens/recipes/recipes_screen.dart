import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/repositories.dart';
import '../../widgets/common.dart';
import '../modules.dart';
import 'log_recipe_sheet.dart';

/// Recetario conectado con IA: el usuario describe qué quiere cocinar y recibe la preparación.
class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  final _prompt = TextEditingController();
  int _servings = 2;
  bool _generating = false;
  bool _saving = false;
  bool _addingToList = false;
  Recipe? _result;
  String _lastPrompt = '';
  List<Recipe> _saved = [];

  static const _suggestions = ['Enchiladas verdes', 'Algo rápido con pollo y arroz', 'Postre sin horno', 'Cena vegetariana ligera'];

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    try {
      final saved = await context.read<RecipesRepository>().saved();
      if (mounted) setState(() => _saved = saved);
    } catch (_) {
      // La lista de guardadas es secundaria; si falla no bloquea la pantalla.
    }
  }

  Future<void> _generate([String? text]) async {
    final prompt = (text ?? _prompt.text).trim();
    if (prompt.length < 3) {
      showMessage(context, 'Cuéntame qué quieres cocinar', error: true);
      return;
    }
    _prompt.text = prompt;
    FocusScope.of(context).unfocus();
    setState(() {
      _generating = true;
      _result = null;
    });
    try {
      final recipe = await context.read<RecipesRepository>().generate(prompt, servings: _servings);
      if (!mounted) return;
      setState(() {
        _result = recipe;
        _lastPrompt = prompt;
      });
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _save() async {
    if (_result == null) return;
    setState(() => _saving = true);
    try {
      final saved = await context.read<RecipesRepository>().save(_result!, _lastPrompt);
      if (!mounted) return;
      setState(() {
        _saved = [saved, ..._saved];
        _result = saved;
      });
      showMessage(context, 'Receta guardada en tu recetario');
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Manda los ingredientes de la receta a la Lista de compras.
  Future<void> _addToShoppingList() async {
    final recipe = _result;
    if (recipe == null || recipe.ingredients.isEmpty) return;
    setState(() => _addingToList = true);
    try {
      final added = await context.read<ShoppingRepository>().addMany(recipe.ingredients);
      if (!mounted) return;
      context.read<DataRefresh>().changed();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('${added.length} ingredientes agregados a tu lista de compras'),
          backgroundColor: AppColors.ink,
          action: SnackBarAction(
            label: 'Ver lista',
            textColor: const Color(0xFFB7ACFA),
            onPressed: () {
              if (mounted) openModule(context, moduleById('shopping'));
            },
          ),
        ));
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _addingToList = false);
    }
  }

  Future<void> _deleteSaved(Recipe r) async {
    final ok = await confirm(context, title: 'Eliminar receta', message: '¿Eliminar "${r.title}" de tu recetario?');
    if (!ok || !mounted) return;
    try {
      await context.read<RecipesRepository>().delete(r.id!);
      if (mounted) setState(() => _saved = _saved.where((s) => s.id != r.id).toList());
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recetario')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          GlowCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('MULTIAPP IA',
                    style: TextStyle(color: Color(0xFFB7ACFA), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.9)),
                const SizedBox(height: 4),
                const Text('¿Qué quieres cocinar?',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                TextField(
                  controller: _prompt,
                  minLines: 1,
                  maxLines: 3,
                  maxLength: 500,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _generate(),
                  decoration: const InputDecoration(
                    hintText: 'Ej. pasta con lo que tengo: jitomate, ajo y queso',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.people_outline_rounded, color: Color(0xFFAAA7B1), size: 20),
                    const SizedBox(width: 8),
                    Text('$_servings porciones', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    _RoundIcon(icon: Icons.remove_rounded, onTap: _servings > 1 ? () => setState(() => _servings--) : null),
                    const SizedBox(width: 8),
                    _RoundIcon(icon: Icons.add_rounded, onTap: _servings < 20 ? () => setState(() => _servings++) : null),
                  ],
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _generating ? null : () => _generate(),
                  icon: _generating
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.auto_awesome),
                  label: Text(_generating ? 'Pensando la receta…' : 'Generar receta'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_result == null && !_generating)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in _suggestions)
                  ActionChip(
                    label: Text(s),
                    onPressed: () => _generate(s),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.border),
                  ),
              ],
            ),
          if (_result != null) ...[
            const SizedBox(height: 10),
            RecipeView(recipe: _result!),
            const SizedBox(height: 16),
            if (_result!.ingredients.isNotEmpty && _result!.title != 'Sin receta') ...[
              FilledButton.icon(
                onPressed: () => showLogRecipeSheet(context, _result!),
                style: FilledButton.styleFrom(backgroundColor: ModuleTint.amber.foreground),
                icon: const Icon(Icons.restaurant_rounded),
                label: const Text('Lo comí: registrar calorías'),
              ),
              const SizedBox(height: 10),
            ],
            if (_result!.ingredients.isNotEmpty) ...[
              FilledButton.icon(
                onPressed: _addingToList ? null : _addToShoppingList,
                icon: _addingToList
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.add_shopping_cart_rounded),
                label: const Text('Agregar ingredientes a mi lista de compras'),
              ),
              const SizedBox(height: 10),
            ],
            if (_result!.id == null && _result!.title != 'Sin receta')
              OutlinedButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Guardar en mi recetario'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
          ],
          if (_saved.isNotEmpty) ...[
            const SizedBox(height: 28),
            SectionHeader(title: 'Mis recetas', trailing: '${_saved.length}'),
            for (final r in _saved)
              SurfaceCard(
                margin: const EdgeInsets.only(bottom: 8),
                onTap: () => setState(() => _result = r),
                child: Row(
                  children: [
                    const ModuleIcon(icon: Icons.restaurant_menu_rounded, tint: ModuleTint.violet),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(
                            '${r.prepMinutes + r.cookMinutes} min · ${r.servings} porciones',
                            style: const TextStyle(color: AppColors.mutedLight, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _deleteSaved(r),
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.mutedLight),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: onTap == null ? 0.04 : 0.1),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(6), child: Icon(icon, color: Colors.white, size: 20)),
      ),
    );
  }
}

/// Muestra una receta: resumen, ingredientes, pasos y consejos.
class RecipeView extends StatelessWidget {
  const RecipeView({super.key, required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    Widget pill(IconData icon, String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(99)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: AppColors.primary),
              const SizedBox(width: 5),
              Text(text, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        );

    return SurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(recipe.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          if (recipe.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(recipe.description, style: const TextStyle(color: AppColors.muted, fontSize: 14, height: 1.4)),
          ],
          if (recipe.ingredients.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                pill(Icons.timer_outlined, '${recipe.prepMinutes + recipe.cookMinutes} min'),
                pill(Icons.people_outline_rounded, '${recipe.servings} porciones'),
                if (recipe.difficulty.isNotEmpty) pill(Icons.signal_cellular_alt_rounded, recipe.difficulty),
                if (recipe.nutritionPerServing != null)
                  pill(Icons.local_fire_department_outlined, '${recipe.nutritionPerServing!.calories.round()} kcal/porción'),
              ],
            ),
            if (recipe.nutritionPerServing != null) ...[
              const SizedBox(height: 8),
              Text(
                'Por porción: proteína ${recipe.nutritionPerServing!.protein.round()} g · '
                'carbs ${recipe.nutritionPerServing!.carbs.round()} g · grasa ${recipe.nutritionPerServing!.fat.round()} g',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            const Text('Ingredientes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (final i in recipe.ingredients)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 7),
                      child: Icon(Icons.circle, size: 6, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(i.name, style: const TextStyle(fontSize: 14))),
                    if (i.quantity.isNotEmpty)
                      Text(i.quantity, style: const TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
          ],
          if (recipe.steps.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Preparación', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (var s = 0; s < recipe.steps.length; s++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.fab, borderRadius: BorderRadius.circular(9)),
                      child: Text('${s + 1}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(recipe.steps[s], style: const TextStyle(fontSize: 14, height: 1.45))),
                  ],
                ),
              ),
          ],
          if (recipe.tips.isNotEmpty) ...[
            const SizedBox(height: 16),
            InsightCard(
              icon: Icons.lightbulb_outline_rounded,
              title: 'Consejos',
              subtitle: recipe.tips.map((t) => '• $t').join('\n'),
            ),
          ],
        ],
      ),
    );
  }
}
