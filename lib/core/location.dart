import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Error de ubicación con un mensaje listo para mostrar.
class LocationException implements Exception {
  LocationException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Obtiene la ubicación actual pidiendo permiso cuando haga falta.
class LocationService {
  LocationService._();

  static Future<LatLng> current() async {
    try {
      return await _current();
    } on LocationException {
      rethrow;
    } catch (e) {
      // Errores de la plataforma (p. ej. permisos faltantes en el AndroidManifest / Info.plist).
      throw LocationException('No se pudo acceder a la ubicación del teléfono.');
    }
  }

  static Future<LatLng> _current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationException('Activa la ubicación (GPS) de tu teléfono.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw LocationException('Sin permiso de ubicación no podemos mostrar lo que está cerca de ti.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationException('El permiso de ubicación está bloqueado. Actívalo en Ajustes > multiApp.');
    }

    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return LatLng(p.latitude, p.longitude);
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return LatLng(last.latitude, last.longitude);
      throw LocationException('No pudimos obtener tu ubicación. Intenta de nuevo al aire libre.');
    }
  }
}
