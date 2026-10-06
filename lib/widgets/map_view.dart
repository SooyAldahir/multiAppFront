import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/config.dart';
import '../core/theme.dart';

/// Mapa de OpenStreetMap con el estilo de la app (esquinas redondeadas y atribución).
class AppMap extends StatelessWidget {
  const AppMap({
    super.key,
    required this.controller,
    this.markers = const [],
    this.center,
    this.zoom = 15,
    this.fitPoints = const [],
    this.onTap,
    this.onReady,
    this.height = 240,
  });

  final MapController controller;
  final List<Marker> markers;
  final LatLng? center;
  final double zoom;

  /// Si hay 2 o más puntos, el mapa se ajusta para mostrarlos todos al abrir.
  final List<LatLng> fitPoints;
  final void Function(LatLng point)? onTap;
  final VoidCallback? onReady;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fit = fitPoints.length > 1
        ? CameraFit.coordinates(coordinates: fitPoints, padding: const EdgeInsets.all(48), maxZoom: 16)
        : null;
    final initialCenter = center ?? (fitPoints.isNotEmpty ? fitPoints.first : AppConfig.defaultMapCenter);
    final hasLocation = center != null || fitPoints.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          mapController: controller,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: hasLocation ? zoom : 4.5,
            initialCameraFit: fit,
            onTap: onTap == null ? null : (_, point) => onTap!(point),
            onMapReady: onReady,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: AppConfig.packageName,
            ),
            MarkerLayer(markers: markers),
            SimpleAttributionWidget(source: const Text('© OpenStreetMap')),
          ],
        ),
      ),
    );
  }
}

/// Marcador redondo con ícono, en los colores de un módulo.
Marker iconMarker(LatLng point, IconData icon, ModuleTint tint, {VoidCallback? onTap, bool selected = false}) {
  final size = selected ? 46.0 : 38.0;
  return Marker(
    point: point,
    width: size,
    height: size,
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: selected ? tint.foreground : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: tint.foreground, width: 2.5),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: Icon(icon, size: selected ? 22 : 19, color: selected ? Colors.white : tint.foreground),
      ),
    ),
  );
}

/// Punto azul de "estás aquí".
Marker myLocationMarker(LatLng point) {
  return Marker(
    point: point,
    width: 24,
    height: 24,
    child: Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2F80ED),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x552F80ED), blurRadius: 10, spreadRadius: 4)],
      ),
    ),
  );
}
