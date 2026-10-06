import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/formatters.dart';
import '../models/models.dart' hide Priority;
import 'push_service.dart';
import 'repositories.dart';

/// Recordatorios locales: los programa el propio teléfono, funcionan sin internet y sin Firebase.
///
/// Cada vez que cambian los datos (o las preferencias) se borran los recordatorios pendientes
/// y se vuelven a programar. iOS permite máximo 64 pendientes, por eso hay topes por tipo.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  Future<void>? _initFuture;

  /// Zona horaria del teléfono (ej. America/Mexico_City).
  String timezone = 'America/Mexico_City';

  /// Últimas preferencias conocidas (para la pantalla de ajustes).
  NotificationPrefs? prefs;

  static const _maxEvents = 25;
  static const _maxTodos = 15;

  static const AndroidNotificationChannel _generalChannel = AndroidNotificationChannel(
    'multiapp_general',
    'General',
    description: 'Avisos de multiApp y resumen del día',
    importance: Importance.high,
  );

  static const AndroidNotificationChannel _remindersChannel = AndroidNotificationChannel(
    'multiapp_reminders',
    'Recordatorios',
    description: 'Eventos, pendientes, ejercicio y comidas',
    importance: Importance.high,
  );

  Future<void> init() => _initFuture ??= _init();

  Future<void> _init() async {
    try {
      tzdata.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        timezone = info.identifier;
        tz.setLocalLocation(tz.getLocation(timezone));
      } catch (_) {
        timezone = 'America/Mexico_City';
        tz.setLocalLocation(tz.getLocation(timezone));
      }

      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(settings: settings);

      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(_generalChannel);
      await android?.createNotificationChannel(_remindersChannel);
      _ready = true;
    } catch (e) {
      debugPrint('Notificaciones locales no disponibles: $e');
    }
  }

  /// Pide permiso para mostrar notificaciones (Android 13+ e iOS). Devuelve true si se concedió.
  Future<bool> requestPermission() async {
    await init();
    if (!_ready) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) return await android.requestNotificationsPermission() ?? false;
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) return await ios.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    } catch (e) {
      debugPrint('No se pudo pedir permiso de notificaciones: $e');
    }
    return false;
  }

  NotificationDetails _details(AndroidNotificationChannel channel) => NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.high,
          priority: Priority.high,
          color: const Color(0xFF6B59DD),
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true, presentBanner: true),
      );

  /// Muestra una notificación inmediata (push recibido con la app abierta, o prueba).
  Future<void> showNow(String title, String body, {String? payload}) async {
    await init();
    if (!_ready) return;
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
      notificationDetails: _details(_generalChannel),
      payload: payload,
    );
  }

  Future<void> _schedule(
    int id,
    String title,
    String body,
    tz.TZDateTime when, {
    DateTimeComponents? repeat,
    String? payload,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: when,
        notificationDetails: _details(_remindersChannel),
        // Inexacto: no requiere el permiso especial de "alarmas exactas" (puede variar unos minutos).
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: repeat,
        payload: payload,
      );
    } catch (e) {
      debugPrint('No se pudo programar el recordatorio $id: $e');
    }
  }

  static (int, int) _hm(String value) {
    final parts = value.split(':');
    final h = int.tryParse(parts.first) ?? 9;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return (h.clamp(0, 23), m.clamp(0, 59));
  }

  /// Próxima vez (hoy o mañana) que el reloj marque [time].
  static tz.TZDateTime _nextTime(String time) {
    final now = tz.TZDateTime.now(tz.local);
    final (h, m) = _hm(time);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, h, m);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    return at;
  }

  /// Próximo [weekday] (1 = lunes … 7 = domingo) a la hora indicada.
  static tz.TZDateTime _nextWeekday(int weekday, String time) {
    var at = _nextTime(time);
    while (at.weekday != weekday) {
      at = at.add(const Duration(days: 1));
    }
    return at;
  }

  /// Borra los recordatorios pendientes (no quita los que ya se mostraron).
  Future<void> cancelScheduled() async {
    await init();
    if (!_ready) return;
    final pending = await _plugin.pendingNotificationRequests();
    for (final p in pending) {
      await _plugin.cancel(id: p.id);
    }
  }

  Future<void> cancelAll() async {
    await init();
    if (_ready) await _plugin.cancelAll();
  }

  /// Vuelve a programar todos los recordatorios según las preferencias.
  Future<void> reschedule(NotificationPrefs prefs, {List<AgendaEvent> events = const [], List<Todo> todos = const []}) async {
    await init();
    if (!_ready) return;
    this.prefs = prefs;
    await cancelScheduled();
    final now = DateTime.now();

    // Eventos de la Agenda (próximos 7 días).
    if (prefs.enabled('events')) {
      final before = Duration(minutes: prefs.minutesBefore);
      final upcoming = events.where((e) => e.startAt.isAfter(now)).toList()
        ..sort((a, b) => a.startAt.compareTo(b.startAt));
      var i = 0;
      for (final e in upcoming.take(_maxEvents)) {
        final DateTime at;
        final String body;
        if (e.allDay) {
          at = DateTime(e.startAt.year, e.startAt.month, e.startAt.day, 8);
          body = 'Hoy, todo el día';
        } else {
          at = e.startAt.subtract(before);
          body = prefs.minutesBefore == 0
              ? 'Empieza ahora · ${Fmt.time(e.startAt)}'
              : 'En ${_minutesLabel(prefs.minutesBefore)} · ${Fmt.time(e.startAt)}'
                  '${(e.location ?? '').isNotEmpty ? ' · ${e.location}' : ''}';
        }
        if (!at.isAfter(now)) continue;
        await _schedule(1000 + i++, e.title, body, tz.TZDateTime.from(at, tz.local), payload: 'event:${e.id}');
      }
    }

    // Pendientes con fecha límite: aviso ese día a la hora elegida.
    if (prefs.enabled('todos')) {
      final (h, m) = _hm(prefs.time('todos'));
      final due = todos.where((t) => !t.isCompleted && t.dueDate != null).toList()
        ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
      var i = 0;
      for (final t in due) {
        if (i >= _maxTodos) break;
        final d = t.dueDate!;
        final at = DateTime(d.year, d.month, d.day, h, m);
        if (!at.isAfter(now)) continue;
        await _schedule(2000 + i++, 'Pendiente para hoy', t.title, tz.TZDateTime.from(at, tz.local), payload: 'todo:${t.id}');
      }
    }

    // Ejercicio: semanal en los días elegidos (0 = domingo … 6 = sábado).
    if (prefs.enabled('workout')) {
      final time = prefs.time('workout', 'time', '18:00');
      for (final day in prefs.workoutDays.toSet()) {
        final weekday = day == 0 ? DateTime.sunday : day;
        await _schedule(
          3000 + day,
          'Hora de entrenar 💪',
          'Abre Ejercicio y genera tu rutina de hoy.',
          _nextWeekday(weekday, time),
          repeat: DateTimeComponents.dayOfWeekAndTime,
          payload: 'workout',
        );
      }
    }

    // Comidas: diario.
    if (prefs.enabled('meals')) {
      const meals = {'breakfast': 'el desayuno', 'lunch': 'la comida', 'dinner': 'la cena'};
      var i = 0;
      for (final entry in meals.entries) {
        final time = prefs.time('meals', entry.key, '');
        if (time.isEmpty) {
          i++;
          continue;
        }
        await _schedule(
          4000 + i++,
          'Registra ${entry.value}',
          'Anota lo que comiste para llevar tus calorías al día.',
          _nextTime(time),
          repeat: DateTimeComponents.time,
          payload: 'meal',
        );
      }
    }

    // Sin push (Firebase) el resumen del día se hace local, con un texto genérico.
    if (prefs.enabled('dailySummary') && !(prefs.pushAvailable && PushService.instance.registered)) {
      await _schedule(
        5000,
        'Buenos días ☀️',
        'Revisa tu agenda y tus pendientes de hoy en multiApp.',
        _nextTime(prefs.time('dailySummary', 'time', '07:30')),
        repeat: DateTimeComponents.time,
        payload: 'daily_summary',
      );
    }
  }

  static String _minutesLabel(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }

  /* ---------------- Sincronización con el servidor ---------------- */

  Timer? _debounce;

  /// Programa una sincronización en unos segundos (para no repetir si hay varios cambios seguidos).
  void scheduleSync(ProfileRepository profile, EventsRepository events, TodosRepository todos) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () => sync(profile, events, todos));
  }

  /// Descarga preferencias, eventos y pendientes y reprograma los recordatorios.
  Future<void> sync(ProfileRepository profile, EventsRepository events, TodosRepository todos) async {
    try {
      await init();
      var p = await profile.notificationPrefs();
      // El resumen del servidor se manda a la hora local del usuario: guardamos su zona horaria.
      if (p.timezone != timezone) {
        p.timezone = timezone;
        p = await profile.saveNotificationPrefs(p);
      }
      final now = DateTime.now();
      final results = await Future.wait([
        events.range(startOfDay(now), startOfDay(now).add(const Duration(days: 8))),
        todos.all(status: 'pending'),
      ]);
      await reschedule(
        p,
        events: results[0] as List<AgendaEvent>,
        todos: results[1] as List<Todo>,
      );
    } catch (e) {
      debugPrint('No se pudieron sincronizar los recordatorios: $e');
    }
  }

  void stop() {
    _debounce?.cancel();
    _debounce = null;
    prefs = null;
  }
}
