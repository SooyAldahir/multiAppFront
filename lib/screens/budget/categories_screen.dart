import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/repositories.dart';
import '../../widgets/common.dart';
import '../expenses/expense_categories.dart';
import 'finance_widgets.dart';

/// Categorías de gasto (las mismas del presupuesto): agregar, renombrar, cambiar ícono y borrar.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    await context.read<CategoriesStore>().reload();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _edit([ExpenseCategory? current]) async {
    final result = await showModalBottomSheet<BudgetCategory>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) => _CategoryForm(current: current),
    );
    if (result == null || !mounted) return;
    final repo = context.read<BudgetRepository>();
    final refresh = context.read<DataRefresh>();
    try {
      if (current?.id != null) {
        await repo.updateCategory(current!.id!, result);
      } else {
        await repo.createCategory(result);
      }
      await _reload();
      refresh.changed();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  Future<void> _delete(ExpenseCategory c) async {
    final ok = await confirm(
      context,
      title: 'Eliminar "${c.name}"',
      message: 'Los gastos de esta categoría pasarán a "Otros" y se quitará su límite del presupuesto.',
    );
    if (!ok || !mounted) return;
    final repo = context.read<BudgetRepository>();
    final refresh = context.read<DataRefresh>();
    try {
      await repo.deleteCategory(c.id!);
      await _reload();
      refresh.changed();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = context.watch<CategoriesStore>().all;
    return Scaffold(
      appBar: AppBar(title: const Text('Categorías')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.fab,
        foregroundColor: Colors.white,
        onPressed: () => _edit(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              children: [
                const Text(
                  'Son las mismas en Gastos y en el Presupuesto. Si cambias un nombre, tus gastos se actualizan solos.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 14),
                for (final c in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SurfaceCard(
                      onTap: c.name == 'Otros' || c.id == null ? null : () => _edit(c),
                      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                      child: Row(
                        children: [
                          ModuleIcon(icon: c.icon, tint: c.tint),
                          const SizedBox(width: 12),
                          Expanded(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                          if (c.name != 'Otros' && c.id != null)
                            IconButton(
                              tooltip: 'Eliminar',
                              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.mutedLight),
                              onPressed: () => _delete(c),
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: Text('Fija', style: TextStyle(color: AppColors.mutedLight, fontSize: 12)),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _CategoryForm extends StatefulWidget {
  const _CategoryForm({this.current});
  final ExpenseCategory? current;

  @override
  State<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<_CategoryForm> {
  late final _name = TextEditingController(text: widget.current?.name);
  late String _icon = widget.current?.iconKey ?? 'other';
  late String _color = widget.current?.colorName ?? 'violet';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showMessage(context, 'Escribe un nombre', error: true);
      return;
    }
    Navigator.pop(context, BudgetCategory(name: name, icon: _icon, color: _color));
  }

  @override
  Widget build(BuildContext context) {
    final tint = ModuleTint.byName(_color, fallback: ModuleTint.ink);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  ModuleIcon(icon: financeIcon(_icon), tint: tint),
                  const SizedBox(width: 12),
                  Text(
                    widget.current == null ? 'Nueva categoría' : 'Editar categoría',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                autofocus: widget.current == null,
                maxLength: 50,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej. Mascotas, Ropa, Diezmo', counterText: ''),
              ),
              const SizedBox(height: 16),
              IconColorPicker(
                icon: _icon,
                color: _color,
                onIcon: (v) => setState(() => _icon = v),
                onColor: (v) => setState(() => _color = v),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                child: const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
