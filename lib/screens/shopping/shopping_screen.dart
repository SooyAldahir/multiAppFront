import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/repositories.dart';
import '../../widgets/common.dart';
import 'where_to_buy_screen.dart';

/// Lista de compras: agrega rápido, marca lo que ya está en el carrito y limpia al terminar.
class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  final _name = TextEditingController();
  final _quantity = TextEditingController();
  final _nameFocus = FocusNode();
  List<ShoppingItem> _items = [];
  bool _loading = true;
  bool _adding = false;
  String? _error;
  late final DataRefresh _refresh;

  List<ShoppingItem> get _pending => _items.where((i) => !i.isChecked).toList();
  List<ShoppingItem> get _checked => _items.where((i) => i.isChecked).toList();

  @override
  void initState() {
    super.initState();
    _refresh = context.read<DataRefresh>()..addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _refresh.removeListener(_load);
    _name.dispose();
    _quantity.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await context.read<ShoppingRepository>().all();
      if (!mounted) return;
      setState(() {
        _items = items;
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

  Future<void> _add() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final quantity = _quantity.text.trim();
    setState(() => _adding = true);
    try {
      final item = await context.read<ShoppingRepository>().create(name, quantity: quantity.isEmpty ? null : quantity);
      if (!mounted) return;
      setState(() => _items = [item, ..._items]);
      _name.clear();
      _quantity.clear();
      _nameFocus.requestFocus(); // listo para el siguiente artículo
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _toggle(ShoppingItem item) async {
    // Actualización optimista
    setState(() => _items = [for (final i in _items) i.id == item.id ? i.copyWith(isChecked: !i.isChecked) : i]);
    try {
      await context.read<ShoppingRepository>().toggle(item);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
      _load();
    }
  }

  Future<void> _delete(ShoppingItem item) async {
    setState(() => _items = _items.where((i) => i.id != item.id).toList());
    try {
      await context.read<ShoppingRepository>().delete(item.id!);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
      _load();
    }
  }

  Future<void> _clearChecked() async {
    final count = _checked.length;
    final ok = await confirm(
      context,
      title: 'Limpiar comprados',
      message: '¿Quitar de la lista los $count artículos que ya compraste?',
      action: 'Limpiar',
    );
    if (!ok || !mounted) return;
    final repo = context.read<ShoppingRepository>();
    setState(() => _items = _pending);
    try {
      await repo.clearChecked();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
      _load();
    }
  }

  Future<void> _edit(ShoppingItem item) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _EditItemDialog(item: item),
    );
    if (result == null || !mounted) return;
    final (newName, newQuantity) = result;
    try {
      final updated = await context
          .read<ShoppingRepository>()
          .update(item.id!, {'name': newName, 'quantity': newQuantity.isEmpty ? null : newQuantity});
      if (mounted) setState(() => _items = [for (final i in _items) i.id == item.id ? updated : i]);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  Widget _row(ShoppingItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey('shop-${item.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(color: AppColors.priorityHighBg, borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.delete_outline_rounded, color: AppColors.priorityHigh),
        ),
        onDismissed: (_) => _delete(item),
        child: SurfaceCard(
          onTap: () => _edit(item),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _toggle(item),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: item.isChecked ? const Color(0xFF4D994F) : Colors.transparent,
                      border: Border.all(color: item.isChecked ? const Color(0xFF4D994F) : const Color(0xFFB7B5C0), width: 1.6),
                    ),
                    child: item.isChecked ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: item.isChecked ? AppColors.mutedLight : AppColors.ink,
                    decoration: item.isChecked ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              if ((item.quantity ?? '').isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: ModuleTint.green.background, borderRadius: BorderRadius.circular(99)),
                  child: Text(
                    item.quantity!,
                    style: TextStyle(color: ModuleTint.green.foreground, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _pending;
    final checked = _checked;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de compras'),
        actions: [
          if (pending.isNotEmpty)
            IconButton(
              tooltip: '¿Dónde compro?',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WhereToBuyScreen())),
              icon: const Icon(Icons.map_outlined),
            ),
          if (checked.isNotEmpty)
            TextButton.icon(
              onPressed: _clearChecked,
              icon: const Icon(Icons.cleaning_services_outlined, size: 18),
              label: const Text('Limpiar'),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _name,
                    focusNode: _nameFocus,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _add(),
                    decoration: const InputDecoration(
                      hintText: 'Agregar artículo…',
                      prefixIcon: Icon(Icons.add_shopping_cart_rounded, color: AppColors.mutedLight),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 86,
                  child: TextField(
                    controller: _quantity,
                    onSubmitted: (_) => _add(),
                    decoration: const InputDecoration(hintText: 'Cant.'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _adding ? null : _add,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.fab,
                    minimumSize: const Size(50, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                children: [
                  if (_loading)
                    const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
                  else if (_error != null)
                    ErrorState(message: _error!, onRetry: _load)
                  else if (_items.isEmpty)
                    const EmptyState(
                      icon: Icons.shopping_cart_outlined,
                      title: 'Tu lista está vacía',
                      message: 'Escribe arriba lo que necesitas comprar, o manda los ingredientes de una receta desde el Recetario.',
                    )
                  else ...[
                    if (pending.isNotEmpty) ...[
                      InsightCard(
                        icon: Icons.storefront_outlined,
                        title: '¿Dónde compro todo esto?',
                        subtitle: 'Te digo qué tiendas cercanas tienen lo de tu lista.',
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WhereToBuyScreen())),
                      ),
                      const SizedBox(height: 18),
                    ],
                    SectionHeader(title: 'Por comprar', trailing: '${pending.length}'),
                    if (pending.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text('¡Ya tienes todo!', style: TextStyle(color: AppColors.muted)),
                      ),
                    for (final i in pending) _row(i),
                    if (checked.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      SectionHeader(title: 'En el carrito', trailing: '${checked.length}'),
                      for (final i in checked) _row(i),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Diálogo para editar nombre y cantidad. Devuelve (nombre, cantidad) o null si se cancela.
class _EditItemDialog extends StatefulWidget {
  const _EditItemDialog({required this.item});
  final ShoppingItem item;

  @override
  State<_EditItemDialog> createState() => _EditItemDialogState();
}

class _EditItemDialogState extends State<_EditItemDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.item.name);
  late final TextEditingController _quantity = TextEditingController(text: widget.item.quantity);

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, (name, _quantity.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar artículo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Artículo'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _quantity,
            onSubmitted: (_) => _save(),
            decoration: const InputDecoration(hintText: 'Cantidad (opcional)'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        TextButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}
