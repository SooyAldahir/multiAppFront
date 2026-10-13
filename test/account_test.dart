import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:multiapp/core/api_client.dart';
import 'package:multiapp/core/location.dart';
import 'package:multiapp/models/models.dart';

void main() {
  test('User lee si tiene contraseña y sus cuentas vinculadas', () {
    final social = User.fromJson({'id': 1, 'name': 'Ana', 'email': 'a@b.com', 'hasPassword': false, 'providers': ['apple']});
    expect(social.hasPassword, isFalse);
    expect(social.providers, ['apple']);
    final old = User.fromJson({'id': 2, 'name': 'Luis', 'email': 'l@b.com'});
    expect(old.hasPassword, isTrue);
    expect(old.providers, isEmpty);
    expect(User.fromJson(social.toJson()).providers, ['apple']);
  });

  test('Las rutas de IA piden permiso; las demás no', () {
    for (final p in [
      '/recipes/generate',
      '/workouts/generate',
      '/nutrition/estimate',
      '/nutrition/estimate-photo',
      '/shopping/where-to-buy',
      '/budget/periods/12/insights',
    ]) {
      expect(ApiClient.aiPaths.hasMatch(p), isTrue, reason: p);
    }
    for (final p in ['/recipes', '/auth/login', '/budget/periods/12', '/nutrition/logs']) {
      expect(ApiClient.aiPaths.hasMatch(p), isFalse, reason: p);
    }
  });

  test('Detecta la ubicación de fábrica de los emuladores', () {
    expect(LocationService.simulatorHint(const LatLng(37.4219983, -122.084)), isNotNull);
    expect(LocationService.simulatorHint(const LatLng(37.3323, -122.0312)), isNotNull);
    expect(LocationService.simulatorHint(const LatLng(19.4326, -99.1332)), isNull); // CDMX
  });
}
