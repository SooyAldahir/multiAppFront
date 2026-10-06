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

/// Ícono y color de cada tipo de tienda.
(IconData, ModuleTint) storeStyle(String type) => switch (type) {
      'supermarket' => (Icons.shopping_basket_outlined, ModuleTint.green),
      'convenience' => (Icons.local_convenience_store_outlined, ModuleTint.teal),
      'pharmacy' => (Icons.local_pharmacy_outlined, ModuleTint.pink),
      'hardware' => (Icons.hardware_outlined, ModuleTint.amber),
      'bakery' => (Icons.bakery_dining_outlined, ModuleTint.coral),
      'butcher' => (Icons.set_meal_outlined, ModuleTint.coral),
      'greengrocer' => (Icons.eco_outlined, ModuleTint.green),
      'stationery' => (Icons.edit_note_rounded, ModuleTint.blue),
      'pet' => (Icons.pets_outlined, ModuleTint.violet),
      'electronics' => (Icons.devices_other_outlined, ModuleTint.blue),
      'clothes' => (Icons.checkroom_outlined, ModuleTint.violet),
      'department_store' => (Icons.local_mall_outlined, ModuleTint.ink),
      _ => (Icons.storefront_outlined, ModuleTint.ink),
    };

/// "¿Dónde compro?": agrupa la lista por tipo de tienda y muestra las tiendas más cercanas.
class WhereToBuyScreen extends StatefulWidget {
  const WhereToBuyScreen({super.key});

  @override
  State<WhereToBuyScreen> createState() => _WhereToBuyScreenState();
}

class _WhereToBuyScreenState extends State<WhereToBuyScreen> {
  final _map = MapController();
  bool _mapReady = false;

  LatLng? _origin;
  String? _originLabel; // "Tu ubicación" o el nombre del lugar guardado
  String? _locationWarning;

  WhereToBuy? _data;
  String? _selectedStoreId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  /// Usa la ubicación actual; si no se puede, usa el lugar guardado "Casa".
  Future<void> _resolveOrigin() async {
    try {
      _origin = await LocationService.current();
      _originLabel = 'Tu ubicación';
      _locationWarning = null;
      return;
    } on LocationException catch (e) {
      _locationWarning = e.message;
    }
    if (!mounted) return;
    try {
      final places = await context.read<PlacesRepository>().all();
      final home = places.where((p) => p.category == 'home').firstOrNull ?? places.firstOrNull;
      if (home != null) {
        _origin = home.point;
        _originLabel = home.name;
        _locationWarning = '${_locationWarning!} Mostrando tiendas cerca de "${home.name}".';
      }
    } on ApiException {
      // Sin lugares guardados: solo se mostrará la clasificación.
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _resolveOrigin();
      if (!mounted) return;
      final data = await context.read<GeoRepository>().whereToBuy(_origin);
      if (!mounted) return;
      setState(() {
        _data = data;
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

  List<Store> get _allStores => [for (final g in _data?.groups ?? const <StoreGroup>[]) ...g.stores];

  void _fitAll() {
    if (!_mapReady) return;
    final points = [for (final s in _allStores) s.point, if (_origin != null) _origin!];
    if (points.length > 1) {
      _map.fitCamera(CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.all(40), maxZoom: 16));
    } else if (points.length == 1) {
      _map.move(points.first, 15);
    }
  }

  void _select(Store s) {
    setState(() => _selectedStoreId = s.id);
    if (_mapReady) _map.move(s.point, 17);
  }

  @override
  Widget build(BuildContext context) {
    final stores = _allStores;
    final markers = <Marker>[
      for (final s in stores)
        iconMarker(
          s.point,
          storeStyle(s.type).$1,
          storeStyle(s.type).$2,
          selected: s.id == _selectedStoreId,
          onTap: () => _select(s),
        ),
      if (_origin != null) myLocationMarker(_origin!),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('¿Dónde compro?'),
        actions: [IconButton(tooltip: 'Actualizar', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: _loading
          ? const _Loading()
          : _error != null
              ? Center(child: ErrorState(message: _error!, onRetry: _load))
              : (_data?.groups.isEmpty ?? true)
                  ? const Center(
                      child: EmptyState(
                        icon: Icons.shopping_cart_outlined,
                        title: 'No hay nada pendiente',
                        message: 'Agrega artículos a tu lista de compras y aquí te diremos dónde conseguirlos.',
                      ),
                    )
                  : Column(
                      children: [
                        if (_origin != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                            child: AppMap(
                              controller: _map,
                              markers: markers,
                              fitPoints: [for (final s in stores) s.point, _origin!],
                              center: stores.isEmpty ? _origin : null,
                              height: 230,
                              onReady: () {
                                _mapReady = true;
                                _fitAll();
                              },
                            ),
                          ),
                        Expanded(child: _list()),
                      ],
                    ),
    );
  }

  Widget _list() {
    final data = _data!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        if (_locationWarning != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InsightCard(icon: Icons.location_off_outlined, title: 'Ubicación', subtitle: _locationWarning!),
          ),
        if (data.storesError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InsightCard(icon: Icons.cloud_off_rounded, title: 'Tiendas no disponibles', subtitle: data.storesError!),
          ),
        if (_origin != null && _originLabel != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Cerca de: $_originLabel', style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        for (final g in data.groups) ...[
          _GroupHeader(group: g),
          if (_origin != null && g.stores.isEmpty && data.storesError == null)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('No encontramos tiendas de este tipo cerca.', style: TextStyle(color: AppColors.mutedLight)),
            ),
          for (final s in g.stores.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _StoreTile(
                store: s,
                selected: s.id == _selectedStoreId,
                onTap: () => _select(s),
                onGo: () => showDirections(context, lat: s.lat, lon: s.lon, label: s.name),
              ),
            ),
          const SizedBox(height: 14),
        ],
        Text(
          data.aiUsed
              ? 'Clasificado con IA · Tiendas de OpenStreetMap'
              : 'Clasificado con reglas básicas (IA no disponible) · Tiendas de OpenStreetMap',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.mutedLight, fontSize: 11),
        ),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Revisando tu lista y buscando tiendas cerca…', style: TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group});
  final StoreGroup group;

  @override
  Widget build(BuildContext context) {
    final (icon, tint) = storeStyle(group.type);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ModuleIcon(icon: icon, tint: tint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final item in group.items)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(color: tint.background, borderRadius: BorderRadius.circular(99)),
                        child: Text(
                          (item.quantity ?? '').isEmpty ? item.name : '${item.name} · ${item.quantity}',
                          style: TextStyle(color: tint.foreground, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreTile extends StatelessWidget {
  const _StoreTile({required this.store, required this.onTap, required this.onGo, this.selected = false});
  final Store store;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    final details = [Fmt.distance(store.distance), if ((store.address ?? '').isNotEmpty) store.address!].join(' · ');
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.primary : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(details, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.mutedLight, fontSize: 12)),
                if (store.openingHours != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Horario: ${store.openingHours}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.mutedLight, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
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
