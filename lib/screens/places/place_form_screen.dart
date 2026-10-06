import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/location.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/repositories.dart';
import '../../widgets/common.dart';
import '../../widgets/map_view.dart';
import 'place_categories.dart';

/// Crear o editar un lugar: se elige buscando la dirección, con la ubicación actual
/// o tocando el mapa.
class PlaceFormScreen extends StatefulWidget {
  const PlaceFormScreen({super.key, this.place, this.initialCategory, this.near});
  final Place? place;
  final String? initialCategory;

  /// Ubicación conocida del usuario (para centrar el mapa y priorizar resultados).
  final LatLng? near;

  @override
  State<PlaceFormScreen> createState() => _PlaceFormScreenState();
}

class _PlaceFormScreenState extends State<PlaceFormScreen> {
  final _map = MapController();
  late final TextEditingController _name = TextEditingController(text: widget.place?.name);
  late final TextEditingController _address = TextEditingController(text: widget.place?.address);
  late final TextEditingController _notes = TextEditingController(text: widget.place?.notes);
  final _search = TextEditingController();
  late String _category = widget.place?.category ?? widget.initialCategory ?? 'other';
  late LatLng? _point = widget.place?.point;

  List<GeoResult> _results = [];
  bool _searching = false;
  bool _locating = false;
  bool _saving = false;
  bool _mapReady = false;
  Timer? _reverseDebounce;

  bool get _isEditing => widget.place?.id != null;

  @override
  void initState() {
    super.initState();
    if (!_isEditing && _name.text.isEmpty && widget.initialCategory != null) {
      _name.text = placeCategory(widget.initialCategory!).label;
    }
  }

  @override
  void dispose() {
    _reverseDebounce?.cancel();
    _map.dispose();
    _name.dispose();
    _address.dispose();
    _notes.dispose();
    _search.dispose();
    super.dispose();
  }

  void _setPoint(LatLng point, {String? address, bool lookupAddress = false}) {
    setState(() {
      _point = point;
      if (address != null) _address.text = address;
    });
    if (_mapReady) _map.move(point, 17);
    if (lookupAddress) {
      // Espera a que el usuario deje de tocar el mapa antes de buscar la dirección.
      _reverseDebounce?.cancel();
      _reverseDebounce = Timer(const Duration(milliseconds: 700), () => _reverse(point));
    }
  }

  Future<void> _reverse(LatLng point) async {
    try {
      final r = await context.read<GeoRepository>().reverse(point);
      if (mounted && _point == point) setState(() => _address.text = r.address);
    } on ApiException {
      // La dirección es opcional; el punto ya quedó guardado.
    }
  }

  Future<void> _doSearch() async {
    final text = _search.text.trim();
    if (text.length < 3) {
      showMessage(context, 'Escribe al menos 3 letras', error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _searching = true);
    try {
      final results = await context.read<GeoRepository>().search(text, near: _point ?? widget.near);
      if (!mounted) return;
      setState(() => _results = results);
      if (results.isEmpty) showMessage(context, 'No encontramos esa dirección. Prueba agregando la ciudad.');
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      final me = await LocationService.current();
      if (!mounted) return;
      _setPoint(me, lookupAddress: true);
    } on LocationException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showMessage(context, 'Ponle un nombre al lugar', error: true);
      return;
    }
    if (_point == null) {
      showMessage(context, 'Elige la ubicación: busca la dirección, usa tu ubicación o toca el mapa', error: true);
      return;
    }
    final place = Place(
      name: name,
      category: _category,
      latitude: _point!.latitude,
      longitude: _point!.longitude,
      address: _address.text.trim().isEmpty ? null : _address.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );

    final repo = context.read<PlacesRepository>();
    final refresh = context.read<DataRefresh>();
    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await repo.update(widget.place!.id!, place);
      } else {
        await repo.create(place);
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
    final ok = await confirm(context, title: 'Eliminar lugar', message: '¿Eliminar "${widget.place!.name}"?');
    if (!ok || !mounted) return;
    final repo = context.read<PlacesRepository>();
    final refresh = context.read<DataRefresh>();
    try {
      await repo.delete(widget.place!.id!);
      refresh.changed();
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = placeCategory(_category);
    final center = _point ?? widget.near;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar lugar' : 'Nuevo lugar'),
        actions: [
          if (_isEditing) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Nombre (ej. Casa de mis papás)'),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in placeCategories)
                ChoiceChip(
                  avatar: Icon(c.icon, size: 18, color: _category == c.id ? Colors.white : c.tint.foreground),
                  label: Text(c.label),
                  selected: _category == c.id,
                  showCheckmark: false,
                  selectedColor: c.tint.foreground,
                  backgroundColor: c.tint.background,
                  side: BorderSide.none,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _category == c.id ? Colors.white : AppColors.inkSoft,
                  ),
                  onSelected: (_) => setState(() {
                    // Si el nombre era el de la categoría anterior, se actualiza también.
                    if (_name.text.trim().isEmpty || placeCategories.any((x) => x.label == _name.text.trim())) {
                      _name.text = c.label;
                    }
                    _category = c.id;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 22),
          const Text('Ubicación', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _doSearch(),
                  decoration: const InputDecoration(
                    hintText: 'Buscar dirección o lugar…',
                    prefixIcon: Icon(Icons.search_rounded, color: AppColors.mutedLight),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _searching ? null : _doSearch,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.fab,
                  minimumSize: const Size(50, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _searching
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              ),
            ],
          ),
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 8),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final r in _results)
                    ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(r.address, maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: () {
                        _setPoint(r.point, address: r.address);
                        setState(() => _results = []);
                      },
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _locating ? null : _useMyLocation,
              icon: _locating
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location_rounded),
              label: const Text('Usar mi ubicación actual'),
            ),
          ),
          const SizedBox(height: 4),
          AppMap(
            controller: _map,
            center: center,
            zoom: _point != null ? 17 : 14,
            height: 230,
            onReady: () => _mapReady = true,
            onTap: (p) => _setPoint(p, lookupAddress: true),
            markers: [
              if (widget.near != null && widget.near != _point) myLocationMarker(widget.near!),
              if (_point != null) iconMarker(_point!, cat.icon, cat.tint, selected: true),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Toca el mapa para ajustar el punto exacto.',
            style: TextStyle(color: AppColors.mutedLight, fontSize: 12),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _address,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Dirección (se llena sola)', prefixIcon: Icon(Icons.signpost_outlined)),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notes,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Notas (ej. portón azul, 2.º piso)'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Text(_isEditing ? 'Guardar cambios' : 'Guardar lugar'),
          ),
        ],
      ),
    );
  }
}
