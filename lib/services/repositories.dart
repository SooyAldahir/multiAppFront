import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../core/api_client.dart';
import '../core/config.dart';
import '../core/formatters.dart';
import '../models/models.dart';

List<T> _list<T>(dynamic data, T Function(Map<String, dynamic>) fromJson) =>
    (data as List).map((e) => fromJson(e as Map<String, dynamic>)).toList();

/// Avisa a las pantallas que algo cambió (p. ej. al crear desde "Crear rápido")
/// para que vuelvan a cargar sus datos.
class DataRefresh extends ChangeNotifier {
  void changed() => notifyListeners();
}

class DashboardRepository {
  DashboardRepository(this._api);
  final ApiClient _api;

  Future<Dashboard> today() async {
    final from = startOfDay(DateTime.now());
    final to = from.add(const Duration(days: 1));
    final data = await _api.get('/dashboard', query: {'from': toApiDate(from), 'to': toApiDate(to)});
    return Dashboard.fromJson(data as Map<String, dynamic>);
  }

  Future<List<ActivityItem>> activity({String? module, int limit = 30}) async {
    final data = await _api.get('/activity', query: {'limit': limit, 'module': module});
    return _list(data, ActivityItem.fromJson);
  }
}

class EventsRepository {
  EventsRepository(this._api);
  final ApiClient _api;

  Future<List<AgendaEvent>> range(DateTime from, DateTime to) async {
    final data = await _api.get('/events', query: {'from': toApiDate(from), 'to': toApiDate(to)});
    return _list(data, AgendaEvent.fromJson);
  }

  Future<AgendaEvent> create(AgendaEvent e) async =>
      AgendaEvent.fromJson(await _api.post('/events', e.toJson()) as Map<String, dynamic>);

  Future<AgendaEvent> update(int id, AgendaEvent e) async =>
      AgendaEvent.fromJson(await _api.patch('/events/$id', e.toJson()) as Map<String, dynamic>);

  Future<void> delete(int id) => _api.delete('/events/$id');
}

class NotesRepository {
  NotesRepository(this._api);
  final ApiClient _api;

  Future<List<Note>> all({String? search}) async {
    final data = await _api.get('/notes', query: {'q': (search?.isEmpty ?? true) ? null : search});
    return _list(data, Note.fromJson);
  }

  Future<Note> create(Note n) async => Note.fromJson(await _api.post('/notes', n.toJson()) as Map<String, dynamic>);

  Future<Note> update(int id, Map<String, dynamic> changes) async =>
      Note.fromJson(await _api.patch('/notes/$id', changes) as Map<String, dynamic>);

  Future<void> delete(int id) => _api.delete('/notes/$id');
}

class TodosRepository {
  TodosRepository(this._api);
  final ApiClient _api;

  /// status: null (todas), 'pending' o 'completed'
  Future<List<Todo>> all({String? status}) async {
    final data = await _api.get('/todos', query: {'status': status});
    return _list(data, Todo.fromJson);
  }

  Future<Todo> create(Todo t) async => Todo.fromJson(await _api.post('/todos', t.toJson()) as Map<String, dynamic>);

  Future<Todo> update(int id, Map<String, dynamic> changes) async =>
      Todo.fromJson(await _api.patch('/todos/$id', changes) as Map<String, dynamic>);

  Future<Todo> toggle(Todo t) => update(t.id!, {'isCompleted': !t.isCompleted});

  Future<void> delete(int id) => _api.delete('/todos/$id');
}

class RecipesRepository {
  RecipesRepository(this._api);
  final ApiClient _api;

  Future<Recipe> generate(String prompt, {int? servings}) async {
    final data = await _api.post(
      '/recipes/generate',
      {'prompt': prompt, if (servings != null) 'servings': servings},
      AppConfig.aiTimeout,
    );
    return Recipe.fromJson(data as Map<String, dynamic>);
  }

  Future<Recipe> save(Recipe r, String prompt) async =>
      Recipe.fromJson(await _api.post('/recipes', {...r.raw, 'prompt': prompt}) as Map<String, dynamic>);

  Future<List<Recipe>> saved() async => _list(await _api.get('/recipes'), Recipe.fromJson);

  Future<void> delete(int id) => _api.delete('/recipes/$id');
}

class ExpensesRepository {
  ExpensesRepository(this._api);
  final ApiClient _api;

  Future<List<Expense>> range(DateTime from, DateTime to) async {
    final data = await _api.get('/expenses', query: {'from': toApiDate(from), 'to': toApiDate(to)});
    return _list(data, Expense.fromJson);
  }

  Future<Expense> create(Expense e) async => (await createWithAlert(e)).$1;

  /// Crea el gasto y devuelve también la alerta de presupuesto (si la categoría cruzó el 80 % o el 100 %).
  Future<(Expense, BudgetAlert?)> createWithAlert(Expense e) async {
    final data = await _api.post('/expenses', e.toJson()) as Map<String, dynamic>;
    final alert = data['budgetAlert'] is Map<String, dynamic> ? BudgetAlert.fromJson(data['budgetAlert'] as Map<String, dynamic>) : null;
    return (Expense.fromJson(data), alert);
  }

  Future<Expense> update(int id, Expense e) async =>
      Expense.fromJson(await _api.patch('/expenses/$id', e.toJson()) as Map<String, dynamic>);

  Future<void> delete(int id) => _api.delete('/expenses/$id');
}

class ShoppingRepository {
  ShoppingRepository(this._api);
  final ApiClient _api;

  Future<List<ShoppingItem>> all() async => _list(await _api.get('/shopping'), ShoppingItem.fromJson);

  Future<ShoppingItem> create(String name, {String? quantity}) async => ShoppingItem.fromJson(
        await _api.post('/shopping', {'name': name, 'quantity': quantity}) as Map<String, dynamic>,
      );

  /// Agrega varios artículos de una vez (p. ej. los ingredientes de una receta).
  Future<List<ShoppingItem>> addMany(List<Ingredient> items) async {
    final data = await _api.post('/shopping/bulk', {
      'items': [
        for (final i in items.take(50)) {'name': i.name, 'quantity': i.quantity.isEmpty ? null : i.quantity},
      ],
    });
    return _list(data, ShoppingItem.fromJson);
  }

  Future<ShoppingItem> update(int id, Map<String, dynamic> changes) async =>
      ShoppingItem.fromJson(await _api.patch('/shopping/$id', changes) as Map<String, dynamic>);

  Future<ShoppingItem> toggle(ShoppingItem item) => update(item.id!, {'isChecked': !item.isChecked});

  Future<void> delete(int id) => _api.delete('/shopping/$id');

  /// Borra los artículos ya comprados. Devuelve cuántos se borraron.
  Future<int> clearChecked() async {
    final data = await _api.delete('/shopping/checked') as Map<String, dynamic>?;
    return (data?['deleted'] as num?)?.toInt() ?? 0;
  }
}

class PlacesRepository {
  PlacesRepository(this._api);
  final ApiClient _api;

  Future<List<Place>> all() async => _list(await _api.get('/places'), Place.fromJson);

  Future<Place> create(Place p) async => Place.fromJson(await _api.post('/places', p.toJson()) as Map<String, dynamic>);

  Future<Place> update(int id, Place p) async =>
      Place.fromJson(await _api.patch('/places/$id', p.toJson()) as Map<String, dynamic>);

  Future<void> delete(int id) => _api.delete('/places/$id');
}

class GeoRepository {
  GeoRepository(this._api);
  final ApiClient _api;

  /// Busca direcciones; si se pasa [near], prioriza resultados cercanos.
  Future<List<GeoResult>> search(String text, {LatLng? near}) async {
    final data = await _api.get('/geo/search', query: {
      'q': text,
      'lat': near?.latitude,
      'lon': near?.longitude,
    });
    return _list(data, GeoResult.fromJson);
  }

  Future<GeoResult> reverse(LatLng point) async {
    final data = await _api.get('/geo/reverse', query: {'lat': point.latitude, 'lon': point.longitude});
    return GeoResult.fromJson(data as Map<String, dynamic>);
  }

  /// Agrupa la lista de compras por tipo de tienda y trae las tiendas cercanas a [from].
  Future<WhereToBuy> whereToBuy(LatLng? from) async {
    final data = await _api.post(
      '/shopping/where-to-buy',
      {if (from != null) 'lat': from.latitude, if (from != null) 'lon': from.longitude},
      AppConfig.aiTimeout,
    );
    return WhereToBuy.fromJson(data as Map<String, dynamic>);
  }
}

class HealthRepository {
  HealthRepository(this._api);
  final ApiClient _api;

  Future<HealthData> get() async => HealthData.fromJson(await _api.get('/health/profile') as Map<String, dynamic>);

  Future<HealthData> save(HealthProfile p) async =>
      HealthData.fromJson(await _api.put('/health/profile', p.toJson()) as Map<String, dynamic>);
}

class WorkoutsRepository {
  WorkoutsRepository(this._api);
  final ApiClient _api;

  /// La IA decide el enfoque si [focus] es null.
  Future<WorkoutPlan> generate({String? focus, int? minutes, String? notes}) async {
    final data = await _api.post(
      '/workouts/generate',
      {
        if (focus != null) 'focus': focus,
        if (minutes != null) 'minutes': minutes,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
      AppConfig.aiTimeout,
    );
    return WorkoutPlan.fromJson(data as Map<String, dynamic>);
  }

  Future<List<WorkoutSession>> history({DateTime? from}) async {
    final data = await _api.get('/workouts', query: {'from': from == null ? null : toApiDate(from)});
    return _list(data, WorkoutSession.fromJson);
  }

  Future<WorkoutSession> save(WorkoutSession s) async =>
      WorkoutSession.fromJson(await _api.post('/workouts', s.toJson()) as Map<String, dynamic>);

  Future<void> delete(int id) => _api.delete('/workouts/$id');
}

class NutritionRepository {
  NutritionRepository(this._api);
  final ApiClient _api;

  Future<FoodEstimate> estimateText(String text) async => FoodEstimate.fromJson(
        await _api.post('/nutrition/estimate', {'text': text}, AppConfig.aiTimeout) as Map<String, dynamic>,
      );

  /// [jpegBytes] ya comprimido (image_picker con maxWidth/imageQuality).
  Future<FoodEstimate> estimatePhoto(Uint8List jpegBytes, {String? note}) async => FoodEstimate.fromJson(
        await _api.post(
          '/nutrition/estimate-photo',
          {'image': 'data:image/jpeg;base64,${base64Encode(jpegBytes)}', if (note != null && note.isNotEmpty) 'note': note},
          AppConfig.aiTimeout,
        ) as Map<String, dynamic>,
      );

  Future<List<FoodLog>> logs(DateTime from, DateTime to) async {
    final data = await _api.get('/food-logs', query: {'from': toApiDate(from), 'to': toApiDate(to)});
    return _list(data, FoodLog.fromJson);
  }

  Future<FoodLog> create(FoodLog log) async =>
      FoodLog.fromJson(await _api.post('/food-logs', log.toJson()) as Map<String, dynamic>);

  Future<void> delete(int id) => _api.delete('/food-logs/$id');

  Future<NutritionSummary> summary(DateTime from, DateTime to) async {
    final data = await _api.get('/nutrition/summary', query: {'from': toApiDate(from), 'to': toApiDate(to)});
    return NutritionSummary.fromJson(data as Map<String, dynamic>);
  }
}

/// Perfil completo, seguridad, preferencias de notificaciones y registro de dispositivos.
class ProfileRepository {
  ProfileRepository(this._api);
  final ApiClient _api;

  Future<User> me() async => User.fromJson(await _api.get('/users/me') as Map<String, dynamic>);

  /// changes: name, phone, birthDate (YYYY-MM-DD), city, bio. Usa null para borrar un campo.
  Future<User> update(Map<String, dynamic> changes) async =>
      User.fromJson(await _api.patch('/users/me', changes) as Map<String, dynamic>);

  Future<User> uploadAvatar(Uint8List bytes) async {
    final data = await _api.post(
      '/users/me/avatar',
      {'image': 'data:image/jpeg;base64,${base64Encode(bytes)}'},
      const Duration(seconds: 60),
    );
    return User.fromJson(data as Map<String, dynamic>);
  }

  Future<User> deleteAvatar() async => User.fromJson(await _api.delete('/users/me/avatar') as Map<String, dynamic>);

  Future<void> changePassword(String current, String next) =>
      _api.put('/users/me/password', {'currentPassword': current, 'newPassword': next});

  /// Devuelve { token, user } (el token cambia porque incluye el correo).
  Future<Map<String, dynamic>> changeEmail(String email, String password) async =>
      await _api.put('/users/me/email', {'email': email, 'password': password}) as Map<String, dynamic>;

  Future<void> deleteAccount(String password) => _api.delete('/users/me', {'password': password});

  Future<NotificationPrefs> notificationPrefs() async =>
      NotificationPrefs.fromJson(await _api.get('/users/me/notifications') as Map<String, dynamic>);

  Future<NotificationPrefs> saveNotificationPrefs(NotificationPrefs prefs) async =>
      NotificationPrefs.fromJson(await _api.put('/users/me/notifications', prefs.toJson()) as Map<String, dynamic>);

  Future<void> registerDevice(String token, String platform) =>
      _api.post('/devices', {'token': token, 'platform': platform});

  Future<void> unregisterDevice(String token) => _api.delete('/devices/${Uri.encodeComponent(token)}');

  Future<void> testPush() => _api.post('/notifications/test');
}

/// Presupuesto por periodos y categorías.
class BudgetRepository {
  BudgetRepository(this._api);
  final ApiClient _api;

  Future<BudgetSettings> settings() async =>
      BudgetSettings.fromJson(await _api.get('/budget/settings') as Map<String, dynamic>);

  Future<BudgetSettings> saveSettings(BudgetSettings s) async => BudgetSettings.fromJson(
        await _api.put('/budget/settings', {...s.toJson(), 'date': localDateString(DateTime.now())}) as Map<String, dynamic>,
      );

  Future<List<BudgetCategory>> categories() async => _list(await _api.get('/budget/categories'), BudgetCategory.fromJson);

  Future<BudgetCategory> createCategory(BudgetCategory c) async =>
      BudgetCategory.fromJson(await _api.post('/budget/categories', c.toJson()) as Map<String, dynamic>);

  Future<BudgetCategory> updateCategory(int id, BudgetCategory c) async =>
      BudgetCategory.fromJson(await _api.patch('/budget/categories/$id', c.toJson()) as Map<String, dynamic>);

  Future<void> deleteCategory(int id) => _api.delete('/budget/categories/$id');

  Future<BudgetView> current() async => BudgetView.fromJson(
        await _api.get('/budget/current', query: {'date': localDateString(DateTime.now())}) as Map<String, dynamic>,
      );

  Future<BudgetView> period(int id) async => BudgetView.fromJson(await _api.get('/budget/periods/$id') as Map<String, dynamic>);

  Future<List<BudgetPeriod>> periods() async => _list(await _api.get('/budget/periods'), BudgetPeriod.fromJson);

  /// limits: { categoryId: monto }. Montos en 0 quitan el límite.
  Future<BudgetView> updatePeriod(int id, {double? income, bool clearIncome = false, Map<int, double>? limits}) async {
    final body = <String, dynamic>{
      if (income != null || clearIncome) 'income': income,
      if (limits != null) 'limits': [for (final e in limits.entries) {'categoryId': e.key, 'amount': e.value}],
    };
    return BudgetView.fromJson(await _api.put('/budget/periods/$id', body) as Map<String, dynamic>);
  }

  Future<double> close(int id, {int? fundId}) async {
    final data = await _api.post('/budget/periods/$id/close', {'fundId': fundId}) as Map<String, dynamic>;
    return ((data['moved'] ?? 0) as num).toDouble();
  }

  Future<BudgetInsights> insights(int id) async => BudgetInsights.fromJson(
        await _api.post('/budget/periods/$id/insights', const {}, AppConfig.aiTimeout) as Map<String, dynamic>,
      );
}

/// Apartados de ahorro y sus movimientos.
class FundsRepository {
  FundsRepository(this._api);
  final ApiClient _api;

  Future<(List<SavingsFund>, double)> all({bool archived = false}) async {
    final data = await _api.get('/funds', query: {if (archived) 'archived': 'true'}) as Map<String, dynamic>;
    return (_list(data['funds'], SavingsFund.fromJson), ((data['total'] ?? 0) as num).toDouble());
  }

  Future<(SavingsFund, List<FundMovement>)> get(int id) async {
    final data = await _api.get('/funds/$id') as Map<String, dynamic>;
    return (SavingsFund.fromJson(data), _list(data['movements'], FundMovement.fromJson));
  }

  Future<SavingsFund> create(SavingsFund f, {double initialBalance = 0}) async => SavingsFund.fromJson(
        await _api.post('/funds', {...f.toJson(), if (initialBalance > 0) 'initialBalance': initialBalance})
            as Map<String, dynamic>,
      );

  Future<SavingsFund> update(int id, SavingsFund f) async =>
      SavingsFund.fromJson(await _api.patch('/funds/$id', f.toJson()) as Map<String, dynamic>);

  Future<void> delete(int id) => _api.delete('/funds/$id');

  Future<SavingsFund> move(int fundId, {required bool deposit, required double amount, String? note}) async {
    final data = await _api.post('/funds/$fundId/movements', {
      'type': deposit ? 'deposit' : 'withdraw',
      'amount': amount,
      'note': note,
    }) as Map<String, dynamic>;
    return SavingsFund.fromJson(data['fund'] as Map<String, dynamic>);
  }

  Future<void> deleteMovement(int movementId) => _api.delete('/funds/movements/$movementId');
}
