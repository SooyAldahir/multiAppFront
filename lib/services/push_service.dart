import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'notification_service.dart';
import 'repositories.dart';

/// Notificaciones push con Firebase Cloud Messaging (resumen diario y avisos del servidor).
///
/// Si el proyecto aún no tiene `google-services.json` (Android) o `GoogleService-Info.plist` (iOS),
/// Firebase no arranca y la app sigue funcionando solo con recordatorios locales.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  /// true cuando este teléfono quedó registrado para recibir push.
  bool registered = false;

  /// Motivo por el que no hay push (para mostrarlo en Ajustes).
  String? unavailableReason;

  String? _token;
  StreamSubscription<String>? _refreshSub;
  StreamSubscription<RemoteMessage>? _messageSub;

  String get _platform => Platform.isIOS ? 'ios' : 'android';

  Future<bool> _initFirebase() async {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      return true;
    } catch (e) {
      unavailableReason = 'Firebase no está configurado en la app (falta google-services.json / GoogleService-Info.plist).';
      debugPrint('Push desactivado: $e');
      return false;
    }
  }

  /// Pide permiso, obtiene el token del teléfono y lo registra en el servidor.
  Future<void> start(ProfileRepository repo) async {
    if (!await _initFirebase()) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        unavailableReason = 'Las notificaciones están bloqueadas en los ajustes del teléfono.';
        return;
      }
      // Con la app abierta, iOS también muestra el aviso.
      await messaging.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

      if (Platform.isIOS) {
        // En iOS el token de FCM depende del de Apple (APNs); en el simulador puede no existir.
        final apns = await messaging.getAPNSToken();
        if (apns == null) {
          unavailableReason = 'iOS aún no entrega el token de Apple (APNs). Prueba en un iPhone real.';
          return;
        }
      }

      final token = await messaging.getToken();
      if (token == null) return;
      _token = token;
      await repo.registerDevice(token, _platform);
      registered = true;
      unavailableReason = null;

      _refreshSub ??= messaging.onTokenRefresh.listen((t) async {
        _token = t;
        try {
          await repo.registerDevice(t, _platform);
        } catch (_) {}
      });

      // En Android el push no se muestra solo si la app está abierta: lo mostramos nosotros.
      _messageSub ??= FirebaseMessaging.onMessage.listen((message) {
        final n = message.notification;
        if (n == null || Platform.isIOS) return;
        NotificationService.instance.showNow(n.title ?? 'multiApp', n.body ?? '', payload: message.data['type']?.toString());
      });
    } catch (e) {
      unavailableReason = 'No se pudo registrar el teléfono para push: $e';
      debugPrint(unavailableReason);
    }
  }

  /// Da de baja este teléfono (al cerrar sesión) para que no le lleguen avisos de otra cuenta.
  Future<void> stop(ProfileRepository repo) async {
    await _refreshSub?.cancel();
    await _messageSub?.cancel();
    _refreshSub = null;
    _messageSub = null;
    final token = _token;
    _token = null;
    registered = false;
    if (token != null) {
      try {
        await repo.unregisterDevice(token);
      } catch (_) {}
    }
    if (Firebase.apps.isNotEmpty) {
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {}
    }
  }
}
