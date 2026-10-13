import 'dart:async';

import 'package:flutter/foundation.dart';
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

  /// Una ubicación "guardada" más vieja que esto ya no se usa: podría ser de otra ciudad.
  static const Duration maxLastKnownAge = Duration(minutes: 10);

  /// Ubicaciones de fábrica de los emuladores (California). Si llega una de estas, el teléfono
  /// es un emulador con la ubicación simulada, no la real del usuario.
  static const List<LatLng> _simulatorDefaults = [
    LatLng(37.4219983, -122.084), // Emulador de Android (Googleplex, Mountain View)
    LatLng(37.33233141, -122.0312186), // Simulador de iOS (Apple, Cupertino)
    LatLng(37.785834, -122.406417), // Simulador de iOS (San Francisco)
  ];

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

  /// En modo desarrollo avisa si la ubicación es la que traen los emuladores por defecto.
  static String? simulatorHint(LatLng p) {
    if (kReleaseMode) return null;
    const d = Distance();
    final fake = _simulatorDefaults.any((s) => d.as(LengthUnit.Meter, s, p) < 1500);
    if (!fake) return null;
    final android = defaultTargetPlatform == TargetPlatform.android;
    return android
        ? 'El emulador usa una ubicación simulada en California. Cámbiala en el emulador: '
            '⋯ (Extended controls) → Location → busca tu dirección → Set location. '
            'En un teléfono real se usa tu ubicación verdadera.'
        : 'El simulador usa una ubicación simulada en California. Cámbiala en el menú del simulador: '
            'Features → Location → Custom Location… En un teléfono real se usa tu ubicación verdadera.';
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
      throw LocationException('El permiso de ubicación está bloqueado. Actívalo en Ajustes > MultiApp.');
    }

    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return LatLng(p.latitude, p.longitude);
    } catch (_) {
      // Solo se usa la última ubicación conocida si es reciente; una vieja puede ser de otro lugar.
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && DateTime.now().difference(last.timestamp) < maxLastKnownAge) {
        return LatLng(last.latitude, last.longitude);
      }
      throw LocationException('No pudimos obtener tu ubicación. Intenta de nuevo al aire libre.');
    }
  }
}
