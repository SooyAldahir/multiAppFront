import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/directions.dart';
import '../../core/formatters.dart';
import '../../core/location.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/repositories.dart';
import '../../widgets/common.dart';
import '../../widgets/map_view.dart';
import 'place_categories.dart';
import 'place_form_screen.dart';

/// Lugares guardados: casa, trabajo, iglesia… con mapa y acceso directo a la ruta.
class PlacesScreen extends StatefulWidget {
  const PlacesScreen({super.key});

  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
  final _map = MapController();
  List<Place> _places = [];
  LatLng? _me;
  int? _selectedId;
  bool _loading = true;
  bool _mapReady = false;
  String? _error;
  late final DataRefresh _refresh;

  @override
  void initState() {
    super.initState();
    _refresh = context.read<DataRefresh>()..addListener(_load);
    _load();
    _locate();
  }

  @override
  void dispose() {
    _refresh.removeListener(_load);
    _map.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final places = await context.read<PlacesRepository>().all();
      if (!mounted) return;
      setState(() {
        _places = places;
        _error = null;
        _loading = false;
      });
      _fitAll();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Error inesperado: $e';
        _loading = false;
      });
    }
  }

  /// La ubicación es opcional: solo sirve para mostrar distancias y el punto azul.
  Future<void> _locate() async {
    try {
      final me = await LocationService.current();
      if (!mounted) return;
      setState(() => _me = me);
      _fitAll();
    } on LocationException {
      // Sin ubicación la pantalla funciona igual.
    }
  }

  List<LatLng> get _points => [for (final p in _places) p.point, if (_me != null) _me!];

  /// Ajusta el mapa para que se vean todos los lugares (y tu ubicación).
  void _fitAll() {
    if (!_mapReady) return;
    final points = _points;
    if (points.length > 1) {
      _map.fitCamera(CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.all(48), maxZoom: 16));
    } else if (points.length == 1) {
      _map.move(points.first, 15);
    }
  }

  void _focus(Place p) {
    setState(() => _selectedId = p.id);
    if (_mapReady) _map.move(p.point, 16);
  }

  Future<void> _openForm({Place? place, String? category}) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlaceFormScreen(place: place, initialCategory: category, near: _me)),
    );
  }

  String? _distanceTo(Place p) {
    if (_me == null) return null;
    return Fmt.distance(const Distance().as(LengthUnit.Meter, _me!, p.point));
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[
      for (final p in _places)
        iconMarker(
          p.point,
          placeCategory(p.category).icon,
          placeCategory(p.category).tint,
          selected: p.id == _selectedId,
          onTap: () => _focus(p),
        ),
      if (_me != null) myLocationMarker(_me!),
    ];
    final points = _points;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lugares'),
        actions: [
          if (_places.isNotEmpty)
            IconButton(tooltip: 'Ver todos', onPressed: _fitAll, icon: const Icon(Icons.zoom_out_map_rounded)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.fab,
        foregroundColor: Colors.white,
        onPressed: () => _openForm(),
        child: const Icon(Icons.add_location_alt_outlined),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: AppMap(
                    controller: _map,
                    markers: markers,
                    fitPoints: points,
                    center: points.length == 1 ? points.first : null,
                    height: 260,
                    onReady: () {
                      _mapReady = true;
                      _fitAll();
                    },
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                      children: [
                        if (_error != null)
                          ErrorState(message: _error!, onRetry: _load)
                        else if (_places.isEmpty)
                          _EmptyPlaces(onAdd: (category) => _openForm(category: category))
                        else ...[
                          SectionHeader(title: 'Tus lugares', trailing: '${_places.length}'),
                          for (final p in _places)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _PlaceTile(
                                place: p,
                                distance: _distanceTo(p),
                                selected: p.id == _selectedId,
                                onTap: () => _focus(p),
                                onEdit: () => _openForm(place: p),
                                onGo: () => showDirections(context, lat: p.latitude, lon: p.longitude, label: p.name),
                              ),
                            ),
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

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({
    required this.place,
    required this.onTap,
    required this.onEdit,
    required this.onGo,
    this.distance,
    this.selected = false,
  });

  final Place place;
  final String? distance;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    final cat = placeCategory(place.category);
    final subtitle = [if (distance != null) distance!, if ((place.address ?? '').isNotEmpty) place.address!].join(' · ');
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      child: Row(
        children: [
          ModuleIcon(icon: cat.icon, tint: cat.tint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: selected ? cat.tint.foreground : AppColors.ink),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.mutedLight, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          IconButton(tooltip: 'Editar', onPressed: onEdit, icon: const Icon(Icons.edit_outlined, color: AppColors.mutedLight)),
          FilledButton.tonalIcon(
            onPressed: onGo,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.navigation_rounded, size: 18),
            label: const Text('Ir'),
          ),
        ],
      ),
    );
  }
}

class _EmptyPlaces extends StatelessWidget {
  const _EmptyPlaces({required this.onAdd});
  final ValueChanged<String> onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const EmptyState(
          icon: Icons.place_outlined,
          title: 'Guarda tus lugares',
          message: 'Agrega tu casa, trabajo o iglesia para llegar con un toque.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final id in ['home', 'work', 'church'])
              ActionChip(
                avatar: Icon(placeCategory(id).icon, size: 18, color: placeCategory(id).tint.foreground),
                label: Text('Agregar ${placeCategory(id).label.toLowerCase()}'),
                backgroundColor: placeCategory(id).tint.background,
                side: BorderSide.none,
                onPressed: () => onAdd(id),
              ),
          ],
        ),
      ],
    );
  }
}
