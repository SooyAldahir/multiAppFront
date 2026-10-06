import 'package:latlong2/latlong.dart';

import '../core/formatters.dart';

class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.phone,
    this.birthDate,
    this.city,
    this.bio,
  });

  final int id;
  final String name;
  final String email;
  final String? avatarUrl;
  final String? phone;
  final DateTime? birthDate;
  final String? city;
  final String? bio;

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  int? get age {
    final b = birthDate;
    if (b == null) return null;
    final now = DateTime.now();
    var years = now.year - b.year;
    if (now.month < b.month || (now.month == b.month && now.day < b.day)) years--;
    return years;
  }

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'] as int,
        name: j['name'] as String,
        email: j['email'] as String,
        avatarUrl: j['avatarUrl'] as String?,
        phone: j['phone'] as String?,
        birthDate: j['birthDate'] == null ? null : DateTime.tryParse(j['birthDate'] as String),
        city: j['city'] as String?,
        bio: j['bio'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'avatarUrl': avatarUrl,
        'phone': phone,
        'birthDate': birthDate == null ? null : dateOnly(birthDate!),
        'city': city,
        'bio': bio,
      };

  static String dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Preferencias de notificaciones (se guardan en el servidor).
class NotificationPrefs {
  NotificationPrefs(Map<String, dynamic> json, {this.pushAvailable = false})
      : data = jsonDecodeCopy(json);

  final Map<String, dynamic> data;
  final bool pushAvailable;

  static Map<String, dynamic> jsonDecodeCopy(Map<String, dynamic> j) => {
        for (final e in j.entries)
          if (e.key != 'pushAvailable') e.key: e.value is Map ? Map<String, dynamic>.from(e.value as Map) : e.value,
      };

  factory NotificationPrefs.fromJson(Map<String, dynamic> j) =>
      NotificationPrefs(j, pushAvailable: j['pushAvailable'] == true);

  Map<String, dynamic> _section(String key) =>
      (data[key] as Map<String, dynamic>?) ?? (data[key] = <String, dynamic>{});

  bool enabled(String section) => _section(section)['enabled'] == true;
  void setEnabled(String section, bool v) => _section(section)['enabled'] = v;

  String time(String section, [String key = 'time', String fallback = '09:00']) =>
      (_section(section)[key] as String?) ?? fallback;
  void setTime(String section, String value, [String key = 'time']) => _section(section)[key] = value;

  int get minutesBefore => (_section('events')['minutesBefore'] as num?)?.toInt() ?? 15;
  set minutesBefore(int v) => _section('events')['minutesBefore'] = v;

  /// Días de ejercicio: 0 = domingo … 6 = sábado.
  List<int> get workoutDays =>
      ((_section('workout')['days'] as List?) ?? const [1, 3, 5]).map((e) => (e as num).toInt()).toList();
  set workoutDays(List<int> v) => _section('workout')['days'] = v;

  String get timezone => (data['timezone'] as String?) ?? 'America/Mexico_City';
  set timezone(String v) => data['timezone'] = v;

  Map<String, dynamic> toJson() => data;

  static NotificationPrefs defaults() => NotificationPrefs({
        'timezone': 'America/Mexico_City',
        'events': {'enabled': true, 'minutesBefore': 15},
        'todos': {'enabled': true, 'time': '09:00'},
        'workout': {'enabled': false, 'time': '18:00', 'days': [1, 3, 5]},
        'meals': {'enabled': false, 'breakfast': '08:30', 'lunch': '14:30', 'dinner': '20:30'},
        'dailySummary': {'enabled': true, 'time': '07:30'},
      });
}

/// Evento de la Agenda.
class AgendaEvent {
  const AgendaEvent({
    this.id,
    required this.title,
    required this.startAt,
    this.endAt,
    this.description,
    this.location,
    this.allDay = false,
    this.color,
  });

  final int? id;
  final String title;
  final String? description;
  final String? location;
  final DateTime startAt;
  final DateTime? endAt;
  final bool allDay;
  final String? color;

  factory AgendaEvent.fromJson(Map<String, dynamic> j) => AgendaEvent(
        id: j['id'] as int?,
        title: j['title'] as String,
        description: j['description'] as String?,
        location: j['location'] as String?,
        startAt: parseDate(j['startAt'])!,
        endAt: parseDate(j['endAt']),
        allDay: j['allDay'] == true,
        color: j['color'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'location': location,
        'startAt': toApiDate(startAt),
        'endAt': endAt == null ? null : toApiDate(endAt!),
        'allDay': allDay,
        'color': color,
      };
}

/// Nota personal.
class Note {
  const Note({
    this.id,
    required this.title,
    this.content,
    this.color,
    this.isPinned = false,
    this.updatedAt,
  });

  final int? id;
  final String title;
  final String? content;
  final String? color;
  final bool isPinned;
  final DateTime? updatedAt;

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: j['id'] as int?,
        title: j['title'] as String,
        content: j['content'] as String?,
        color: j['color'] as String?,
        isPinned: j['isPinned'] == true,
        updatedAt: parseDate(j['updatedAt']),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'content': content,
        'color': color,
        'isPinned': isPinned,
      };
}

enum Priority {
  low('low', 'Baja'),
  medium('medium', 'Media'),
  high('high', 'Alta');

  const Priority(this.value, this.label);
  final String value;
  final String label;

  static Priority from(String? v) =>
      Priority.values.firstWhere((p) => p.value == v, orElse: () => Priority.medium);
}

/// Cosa por hacer (ToDo).
class Todo {
  const Todo({
    this.id,
    required this.title,
    this.description,
    this.dueDate,
    this.priority = Priority.medium,
    this.isCompleted = false,
  });

  final int? id;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final Priority priority;
  final bool isCompleted;

  bool get isOverdue {
    if (isCompleted || dueDate == null) return false;
    return dueDate!.isBefore(startOfDay(DateTime.now()));
  }

  factory Todo.fromJson(Map<String, dynamic> j) => Todo(
        id: j['id'] as int?,
        title: j['title'] as String,
        description: j['description'] as String?,
        dueDate: parseDate(j['dueDate']),
        priority: Priority.from(j['priority'] as String?),
        isCompleted: j['isCompleted'] == true,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'dueDate': dueDate == null ? null : toApiDate(dueDate!),
        'priority': priority.value,
        'isCompleted': isCompleted,
      };
}

class DashboardCounts {
  const DashboardCounts({
    this.pendingTodos = 0,
    this.overdueTodos = 0,
    this.notes = 0,
    this.shoppingPending = 0,
  });

  final int pendingTodos;
  final int overdueTodos;
  final int notes;
  final int shoppingPending;

  factory DashboardCounts.fromJson(Map<String, dynamic>? j) => DashboardCounts(
        pendingTodos: (j?['pendingTodos'] as num?)?.toInt() ?? 0,
        overdueTodos: (j?['overdueTodos'] as num?)?.toInt() ?? 0,
        notes: (j?['notes'] as num?)?.toInt() ?? 0,
        shoppingPending: (j?['shoppingPending'] as num?)?.toInt() ?? 0,
      );
}

/// Resumen del día para la pantalla de Inicio.
class Dashboard {
  const Dashboard({required this.events, required this.todos, required this.counts});

  final List<AgendaEvent> events;
  final List<Todo> todos;
  final DashboardCounts counts;

  factory Dashboard.fromJson(Map<String, dynamic> j) => Dashboard(
        events: (j['events'] as List).map((e) => AgendaEvent.fromJson(e as Map<String, dynamic>)).toList(),
        todos: (j['todos'] as List).map((e) => Todo.fromJson(e as Map<String, dynamic>)).toList(),
        counts: DashboardCounts.fromJson(j['counts'] as Map<String, dynamic>?),
      );

  /// Tiempo libre entre ahora y las 21:00 descontando los eventos de hoy.
  Duration freeTimeToday(DateTime now) {
    final endOfDay = DateTime(now.year, now.month, now.day, 21);
    if (!now.isBefore(endOfDay)) return Duration.zero;
    var free = endOfDay.difference(now);
    for (final e in events.where((e) => !e.allDay)) {
      final start = e.startAt.isBefore(now) ? now : e.startAt;
      final end = (e.endAt ?? e.startAt.add(const Duration(hours: 1)));
      final clippedEnd = end.isAfter(endOfDay) ? endOfDay : end;
      if (clippedEnd.isAfter(start)) free -= clippedEnd.difference(start);
    }
    return free.isNegative ? Duration.zero : free;
  }
}

/// Elemento del feed de Actividad.
class ActivityItem {
  const ActivityItem({
    required this.module,
    required this.id,
    required this.title,
    required this.action,
    required this.updatedAt,
  });

  final String module; // event | note | todo | expense | shopping
  final int id;
  final String title;
  final String action; // created | updated | completed
  final DateTime updatedAt;

  factory ActivityItem.fromJson(Map<String, dynamic> j) => ActivityItem(
        module: j['module'] as String,
        id: j['id'] as int,
        title: (j['title'] ?? '') as String,
        action: j['action'] as String,
        updatedAt: parseDate(j['updatedAt']) ?? DateTime.now(),
      );
}

class Ingredient {
  const Ingredient(this.name, this.quantity);
  final String name;
  final String quantity;
}

/// Receta generada por la IA.
class Recipe {
  const Recipe({
    this.id,
    required this.title,
    required this.description,
    required this.servings,
    required this.prepMinutes,
    required this.cookMinutes,
    required this.difficulty,
    required this.ingredients,
    required this.steps,
    required this.tips,
    this.nutritionPerServing,
    this.raw = const {},
  });

  final int? id;
  final String title;
  final String description;
  final int servings;
  final int prepMinutes;
  final int cookMinutes;
  final String difficulty;
  final List<Ingredient> ingredients;
  final List<String> steps;
  final List<String> tips;

  /// Calorías y macros estimados por porción (null en recetas antiguas).
  final Nutrition? nutritionPerServing;

  /// JSON original, para poder guardarla tal cual.
  final Map<String, dynamic> raw;

  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
        id: j['id'] as int?,
        title: (j['title'] ?? 'Receta') as String,
        description: (j['description'] ?? '') as String,
        servings: (j['servings'] as num?)?.toInt() ?? 0,
        prepMinutes: (j['prepMinutes'] as num?)?.toInt() ?? 0,
        cookMinutes: (j['cookMinutes'] as num?)?.toInt() ?? 0,
        difficulty: (j['difficulty'] ?? '') as String,
        ingredients: ((j['ingredients'] as List?) ?? const [])
            .map((i) => Ingredient((i['name'] ?? '').toString(), (i['quantity'] ?? '').toString()))
            .toList(),
        steps: ((j['steps'] as List?) ?? const []).map((s) => s.toString()).toList(),
        tips: ((j['tips'] as List?) ?? const []).map((s) => s.toString()).toList(),
        nutritionPerServing: Nutrition.maybe(j['nutritionPerServing']),
        raw: j,
      );
}

/// Gasto personal.
class Expense {
  const Expense({
    this.id,
    required this.description,
    required this.amount,
    required this.category,
    required this.spentAt,
  });

  final int? id;
  final String description;
  final double amount;
  final String category;
  final DateTime spentAt;

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'] as int?,
        description: j['description'] as String,
        amount: (j['amount'] as num).toDouble(),
        category: (j['category'] ?? 'Otros') as String,
        spentAt: parseDate(j['spentAt']) ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'description': description,
        'amount': amount,
        'category': category,
        'spentAt': toApiDate(spentAt),
      };
}

class CategoryTotal {
  const CategoryTotal(this.category, this.total, this.count);
  final String category;
  final double total;
  final int count;
}

/// Artículo de la lista de compras.
class ShoppingItem {
  const ShoppingItem({this.id, required this.name, this.quantity, this.isChecked = false});

  final int? id;
  final String name;
  final String? quantity;
  final bool isChecked;

  factory ShoppingItem.fromJson(Map<String, dynamic> j) => ShoppingItem(
        id: j['id'] as int?,
        name: j['name'] as String,
        quantity: j['quantity'] as String?,
        isChecked: j['isChecked'] == true,
      );

  ShoppingItem copyWith({bool? isChecked}) =>
      ShoppingItem(id: id, name: name, quantity: quantity, isChecked: isChecked ?? this.isChecked);

  Map<String, dynamic> toJson() => {'name': name, 'quantity': quantity, 'isChecked': isChecked};
}

/// Lugar guardado (casa, trabajo, iglesia…).
class Place {
  const Place({
    this.id,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    this.address,
    this.notes,
  });

  final int? id;
  final String name;
  final String category; // home | work | church | school | gym | family | store | other
  final double latitude;
  final double longitude;
  final String? address;
  final String? notes;

  LatLng get point => LatLng(latitude, longitude);

  factory Place.fromJson(Map<String, dynamic> j) => Place(
        id: j['id'] as int?,
        name: j['name'] as String,
        category: (j['category'] ?? 'other') as String,
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        address: j['address'] as String?,
        notes: j['notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
        'latitude': double.parse(latitude.toStringAsFixed(6)),
        'longitude': double.parse(longitude.toStringAsFixed(6)),
        'address': address,
        'notes': notes,
      };
}

/// Resultado de búsqueda de direcciones.
class GeoResult {
  const GeoResult({required this.name, required this.address, required this.lat, required this.lon});

  final String name;
  final String address;
  final double lat;
  final double lon;

  LatLng get point => LatLng(lat, lon);

  factory GeoResult.fromJson(Map<String, dynamic> j) => GeoResult(
        name: (j['name'] ?? '') as String,
        address: (j['address'] ?? '') as String,
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
      );
}

/// Tienda cercana encontrada en OpenStreetMap.
class Store {
  const Store({
    required this.id,
    required this.name,
    required this.type,
    required this.label,
    required this.lat,
    required this.lon,
    required this.distance,
    this.address,
    this.openingHours,
  });

  final String id;
  final String name;
  final String type;
  final String label;
  final double lat;
  final double lon;
  final int distance; // metros
  final String? address;
  final String? openingHours;

  LatLng get point => LatLng(lat, lon);

  factory Store.fromJson(Map<String, dynamic> j) => Store(
        id: j['id'].toString(),
        name: (j['name'] ?? '') as String,
        type: (j['type'] ?? '') as String,
        label: (j['label'] ?? '') as String,
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        distance: (j['distance'] as num?)?.toInt() ?? 0,
        address: j['address'] as String?,
        openingHours: j['openingHours'] as String?,
      );
}

/// Grupo de artículos que se compran en el mismo tipo de tienda.
class StoreGroup {
  const StoreGroup({required this.type, required this.label, required this.items, required this.stores});

  final String type;
  final String label;
  final List<ShoppingItem> items;
  final List<Store> stores;

  factory StoreGroup.fromJson(Map<String, dynamic> j) => StoreGroup(
        type: j['type'] as String,
        label: j['label'] as String,
        items: ((j['items'] as List?) ?? const [])
            .map((i) => ShoppingItem.fromJson(i as Map<String, dynamic>))
            .toList(),
        stores: ((j['stores'] as List?) ?? const []).map((s) => Store.fromJson(s as Map<String, dynamic>)).toList(),
      );
}

class WhereToBuy {
  const WhereToBuy({required this.aiUsed, required this.groups, this.storesError});

  final bool aiUsed;
  final List<StoreGroup> groups;
  final String? storesError;

  factory WhereToBuy.fromJson(Map<String, dynamic> j) => WhereToBuy(
        aiUsed: j['aiUsed'] == true,
        groups: ((j['groups'] as List?) ?? const []).map((g) => StoreGroup.fromJson(g as Map<String, dynamic>)).toList(),
        storesError: j['storesError'] as String?,
      );
}

/* ====================== Salud: perfil, rutinas y calorías ====================== */

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
List<String> _strings(dynamic v) => ((v as List?) ?? const []).map((e) => e.toString()).toList();

/// Calorías (kcal) y macros (g).
class Nutrition {
  const Nutrition({this.calories = 0, this.protein = 0, this.carbs = 0, this.fat = 0});

  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  factory Nutrition.fromJson(Map<String, dynamic> j) =>
      Nutrition(calories: _d(j['calories']), protein: _d(j['protein']), carbs: _d(j['carbs']), fat: _d(j['fat']));

  static Nutrition? maybe(dynamic j) => j is Map<String, dynamic> ? Nutrition.fromJson(j) : null;

  Nutrition operator *(num factor) =>
      Nutrition(calories: calories * factor, protein: protein * factor, carbs: carbs * factor, fat: fat * factor);
}

class HealthProfile {
  const HealthProfile({
    required this.sex,
    required this.birthYear,
    required this.heightCm,
    required this.weightKg,
    this.activityLevel = 'light',
    this.goal = 'maintain',
    this.fitnessLevel = 'beginner',
    this.daysPerWeek = 3,
    this.minutesPerSession = 45,
    this.equipment = 'none',
    this.limitations,
  });

  final String sex; // male | female
  final int birthYear;
  final double heightCm;
  final double weightKg;
  final String activityLevel; // sedentary | light | moderate | active | very_active
  final String goal; // lose | maintain | gain
  final String fitnessLevel; // beginner | intermediate | advanced
  final int daysPerWeek;
  final int minutesPerSession;
  final String equipment; // none | dumbbells | gym
  final String? limitations;

  factory HealthProfile.fromJson(Map<String, dynamic> j) => HealthProfile(
        sex: (j['sex'] ?? 'male') as String,
        birthYear: (j['birthYear'] as num).toInt(),
        heightCm: _d(j['heightCm']),
        weightKg: _d(j['weightKg']),
        activityLevel: (j['activityLevel'] ?? 'light') as String,
        goal: (j['goal'] ?? 'maintain') as String,
        fitnessLevel: (j['fitnessLevel'] ?? 'beginner') as String,
        daysPerWeek: (j['daysPerWeek'] as num?)?.toInt() ?? 3,
        minutesPerSession: (j['minutesPerSession'] as num?)?.toInt() ?? 45,
        equipment: (j['equipment'] ?? 'none') as String,
        limitations: j['limitations'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'sex': sex,
        'birthYear': birthYear,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'activityLevel': activityLevel,
        'goal': goal,
        'fitnessLevel': fitnessLevel,
        'daysPerWeek': daysPerWeek,
        'minutesPerSession': minutesPerSession,
        'equipment': equipment,
        'limitations': limitations,
      };
}

class HealthTargets {
  const HealthTargets({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.bmr,
    required this.tdee,
    required this.bmi,
  });

  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double bmr;
  final double tdee;
  final double bmi;

  factory HealthTargets.fromJson(Map<String, dynamic> j) => HealthTargets(
        calories: _d(j['calories']),
        protein: _d(j['protein']),
        carbs: _d(j['carbs']),
        fat: _d(j['fat']),
        bmr: _d(j['bmr']),
        tdee: _d(j['tdee']),
        bmi: _d(j['bmi']),
      );

  static HealthTargets? maybe(dynamic j) => j is Map<String, dynamic> ? HealthTargets.fromJson(j) : null;
}

class HealthData {
  const HealthData({this.profile, this.targets});
  final HealthProfile? profile;
  final HealthTargets? targets;

  factory HealthData.fromJson(Map<String, dynamic> j) => HealthData(
        profile: j['profile'] is Map<String, dynamic> ? HealthProfile.fromJson(j['profile'] as Map<String, dynamic>) : null,
        targets: HealthTargets.maybe(j['targets']),
      );
}

/// Ejercicio dentro de una rutina generada.
class PlanExercise {
  const PlanExercise({
    required this.name,
    required this.muscles,
    required this.sets,
    required this.reps,
    required this.restSeconds,
    required this.instructions,
    required this.commonMistakes,
    required this.youtubeUrl,
    this.easierVariant,
  });

  final String name;
  final List<String> muscles;
  final int sets;
  final String reps;
  final int restSeconds;
  final List<String> instructions;
  final List<String> commonMistakes;
  final String youtubeUrl;
  final String? easierVariant;

  factory PlanExercise.fromJson(Map<String, dynamic> j) => PlanExercise(
        name: (j['name'] ?? 'Ejercicio') as String,
        muscles: _strings(j['muscles']),
        sets: (j['sets'] as num?)?.toInt() ?? 3,
        reps: (j['reps'] ?? '10') as String,
        restSeconds: (j['restSeconds'] as num?)?.toInt() ?? 60,
        instructions: _strings(j['instructions']),
        commonMistakes: _strings(j['commonMistakes']),
        youtubeUrl: (j['youtubeUrl'] ?? '') as String,
        easierVariant: j['easierVariant'] as String?,
      );
}

class WorkoutPlan {
  const WorkoutPlan({
    required this.title,
    required this.focus,
    required this.reason,
    required this.durationMinutes,
    required this.estimatedCalories,
    required this.warmup,
    required this.exercises,
    required this.cooldown,
    required this.tips,
  });

  final String title;
  final String focus;
  final String reason;
  final int durationMinutes;
  final int estimatedCalories;
  final List<String> warmup;
  final List<PlanExercise> exercises;
  final List<String> cooldown;
  final List<String> tips;

  factory WorkoutPlan.fromJson(Map<String, dynamic> j) => WorkoutPlan(
        title: (j['title'] ?? 'Rutina') as String,
        focus: (j['focus'] ?? '') as String,
        reason: (j['reason'] ?? '') as String,
        durationMinutes: (j['durationMinutes'] as num?)?.toInt() ?? 45,
        estimatedCalories: (j['estimatedCalories'] as num?)?.toInt() ?? 0,
        warmup: _strings(j['warmup']),
        exercises: ((j['exercises'] as List?) ?? const [])
            .map((e) => PlanExercise.fromJson(e as Map<String, dynamic>))
            .toList(),
        cooldown: _strings(j['cooldown']),
        tips: _strings(j['tips']),
      );
}

/// Entrenamiento terminado (historial).
class WorkoutSession {
  const WorkoutSession({
    this.id,
    required this.title,
    required this.performedAt,
    required this.durationMinutes,
    required this.caloriesBurned,
    this.focus,
    this.exercises = const [],
  });

  final int? id;
  final String title;
  final String? focus;
  final DateTime performedAt;
  final int durationMinutes;
  final int caloriesBurned;

  /// [{ name, setsPlanned, setsDone, reps }]
  final List<Map<String, dynamic>> exercises;

  factory WorkoutSession.fromJson(Map<String, dynamic> j) => WorkoutSession(
        id: j['id'] as int?,
        title: (j['title'] ?? '') as String,
        focus: j['focus'] as String?,
        performedAt: parseDate(j['performedAt']) ?? DateTime.now(),
        durationMinutes: (j['durationMinutes'] as num?)?.toInt() ?? 0,
        caloriesBurned: (j['caloriesBurned'] as num?)?.toInt() ?? 0,
        exercises: ((j['exercises'] as List?) ?? const []).whereType<Map<String, dynamic>>().toList(),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'focus': focus,
        'performedAt': toApiDate(performedAt),
        'durationMinutes': durationMinutes,
        'caloriesBurned': caloriesBurned,
        'exercises': exercises,
      };
}

class FoodItemEstimate {
  const FoodItemEstimate({required this.name, required this.quantity, required this.nutrition});
  final String name;
  final String quantity;
  final Nutrition nutrition;

  factory FoodItemEstimate.fromJson(Map<String, dynamic> j) => FoodItemEstimate(
        name: (j['name'] ?? '') as String,
        quantity: (j['quantity'] ?? '') as String,
        nutrition: Nutrition.fromJson(j),
      );
}

/// Estimación de calorías hecha por la IA (por texto o foto).
class FoodEstimate {
  const FoodEstimate({
    required this.description,
    required this.items,
    required this.total,
    required this.confidence,
    required this.notes,
    this.imageUrl,
    this.imageWarning,
  });

  final String description;
  final List<FoodItemEstimate> items;
  final Nutrition total;
  final String confidence; // alta | media | baja
  final String notes;
  final String? imageUrl;
  final String? imageWarning;

  factory FoodEstimate.fromJson(Map<String, dynamic> j) => FoodEstimate(
        description: (j['description'] ?? '') as String,
        items: ((j['items'] as List?) ?? const [])
            .map((i) => FoodItemEstimate.fromJson(i as Map<String, dynamic>))
            .toList(),
        total: Nutrition.fromJson((j['total'] as Map<String, dynamic>?) ?? const {}),
        confidence: (j['confidence'] ?? 'media') as String,
        notes: (j['notes'] ?? '') as String,
        imageUrl: j['imageUrl'] as String?,
        imageWarning: j['imageWarning'] as String?,
      );
}

/// Comida registrada.
class FoodLog {
  const FoodLog({
    this.id,
    required this.eatenAt,
    required this.meal,
    required this.description,
    required this.calories,
    this.servings = 1,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.imageUrl,
    this.recipeId,
    this.source = 'manual',
  });

  final int? id;
  final DateTime eatenAt;
  final String meal; // breakfast | lunch | dinner | snack
  final String description;
  final double servings;
  final int calories;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final String? imageUrl;
  final int? recipeId;
  final String source; // text | photo | recipe | manual

  factory FoodLog.fromJson(Map<String, dynamic> j) => FoodLog(
        id: j['id'] as int?,
        eatenAt: parseDate(j['eatenAt']) ?? DateTime.now(),
        meal: (j['meal'] ?? 'snack') as String,
        description: (j['description'] ?? '') as String,
        servings: _d(j['servings']) == 0 ? 1 : _d(j['servings']),
        calories: (j['calories'] as num?)?.toInt() ?? 0,
        proteinG: (j['proteinG'] as num?)?.toDouble(),
        carbsG: (j['carbsG'] as num?)?.toDouble(),
        fatG: (j['fatG'] as num?)?.toDouble(),
        imageUrl: j['imageUrl'] as String?,
        recipeId: j['recipeId'] as int?,
        source: (j['source'] ?? 'manual') as String,
      );

  /// Crea el registro a partir de valores nutricionales (redondeando como la BD).
  factory FoodLog.fromNutrition({
    required Nutrition n,
    required String description,
    required String meal,
    required String source,
    DateTime? eatenAt,
    double servings = 1,
    String? imageUrl,
    int? recipeId,
  }) =>
      FoodLog(
        eatenAt: eatenAt ?? DateTime.now(),
        meal: meal,
        description: description.length > 300 ? description.substring(0, 300) : description,
        servings: servings,
        calories: n.calories.round(),
        proteinG: double.parse(n.protein.toStringAsFixed(1)),
        carbsG: double.parse(n.carbs.toStringAsFixed(1)),
        fatG: double.parse(n.fat.toStringAsFixed(1)),
        imageUrl: imageUrl,
        recipeId: recipeId,
        source: source,
      );

  Map<String, dynamic> toJson() => {
        'eatenAt': toApiDate(eatenAt),
        'meal': meal,
        'description': description,
        'servings': servings,
        'calories': calories,
        'proteinG': proteinG,
        'carbsG': carbsG,
        'fatG': fatG,
        'imageUrl': imageUrl,
        'recipeId': recipeId,
        'source': source,
      };
}

class NutritionSummary {
  const NutritionSummary({required this.consumed, required this.burned, required this.sessions, this.targets});

  final Nutrition consumed;
  final int burned;
  final int sessions;
  final HealthTargets? targets;

  factory NutritionSummary.fromJson(Map<String, dynamic> j) {
    final burned = (j['burned'] as Map<String, dynamic>?) ?? const {};
    return NutritionSummary(
      consumed: Nutrition.fromJson((j['consumed'] as Map<String, dynamic>?) ?? const {}),
      burned: (burned['calories'] as num?)?.toInt() ?? 0,
      sessions: (burned['sessions'] as num?)?.toInt() ?? 0,
      targets: HealthTargets.maybe(j['targets']),
    );
  }
}

/* ======================= Presupuesto y apartados ======================= */

double _money(dynamic v) => v == null ? 0 : (v as num).toDouble();
double? _moneyOrNull(dynamic v) => v == null ? null : (v as num).toDouble();

/// Fecha local en formato YYYY-MM-DD (así la espera el servidor para el presupuesto).
String localDateString(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? parseLocalDate(dynamic v) {
  if (v == null) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(v.toString());
  if (m == null) return null;
  return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
}

/// Categoría compartida por Gastos y Presupuesto.
class BudgetCategory {
  const BudgetCategory({this.id, required this.name, this.icon = 'other', this.color = 'ink'});
  final int? id;
  final String name;
  final String icon;
  final String color;

  factory BudgetCategory.fromJson(Map<String, dynamic> j) => BudgetCategory(
        id: j['id'] as int?,
        name: j['name'] as String,
        icon: (j['icon'] ?? 'other') as String,
        color: (j['color'] ?? 'ink') as String,
      );

  Map<String, dynamic> toJson() => {'name': name, 'icon': icon, 'color': color};
}

enum BudgetPeriodType { monthly, biweekly, weekly }

class BudgetSettings {
  const BudgetSettings({
    this.period = BudgetPeriodType.monthly,
    this.startDay = 1,
    this.alertsEnabled = true,
    this.rolloverFundId,
  });
  final BudgetPeriodType period;
  final int startDay;
  final bool alertsEnabled;
  final int? rolloverFundId;

  factory BudgetSettings.fromJson(Map<String, dynamic> j) => BudgetSettings(
        period: BudgetPeriodType.values.firstWhere((p) => p.name == j['period'], orElse: () => BudgetPeriodType.monthly),
        startDay: (j['startDay'] as num?)?.toInt() ?? 1,
        alertsEnabled: j['alertsEnabled'] != false,
        rolloverFundId: j['rolloverFundId'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'period': period.name,
        'startDay': startDay,
        'alertsEnabled': alertsEnabled,
        'rolloverFundId': rolloverFundId,
      };

  String get label => switch (period) {
        BudgetPeriodType.monthly => startDay == 1 ? 'Mensual' : 'Mensual (desde el día $startDay)',
        BudgetPeriodType.biweekly => 'Quincenal (1-15 y 16-fin de mes)',
        BudgetPeriodType.weekly => 'Semanal',
      };
}

class BudgetPeriod {
  const BudgetPeriod({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.period,
    this.income,
    this.closedAt,
    this.daysTotal = 0,
    this.daysLeft = 0,
    this.isCurrent = false,
    this.budgeted,
  });
  final int id;
  final DateTime startDate;
  final DateTime endDate;
  final String period;
  final double? income;
  final DateTime? closedAt;
  final int daysTotal;
  final int daysLeft;
  final bool isCurrent;
  final double? budgeted;

  bool get isClosed => closedAt != null;
  bool get hasEnded => DateTime.now().isAfter(endDate.add(const Duration(days: 1)));

  factory BudgetPeriod.fromJson(Map<String, dynamic> j) => BudgetPeriod(
        id: j['id'] as int,
        startDate: parseLocalDate(j['startDate'])!,
        endDate: parseLocalDate(j['endDate'])!,
        period: (j['period'] ?? 'monthly') as String,
        income: _moneyOrNull(j['income']),
        closedAt: parseDate(j['closedAt']),
        daysTotal: (j['daysTotal'] as num?)?.toInt() ?? 0,
        daysLeft: (j['daysLeft'] as num?)?.toInt() ?? 0,
        isCurrent: j['isCurrent'] == true,
        budgeted: _moneyOrNull(j['budgeted']),
      );
}

/// Una categoría dentro del periodo: límite y lo gastado.
class BudgetLine {
  const BudgetLine({
    required this.category,
    this.limit,
    this.spent = 0,
    this.count = 0,
    this.remaining,
    this.percent,
    this.status = 'none',
  });
  final BudgetCategory category;
  final double? limit;
  final double spent;
  final int count;
  final double? remaining;
  final double? percent;
  final String status; // none | ok | warning | over

  factory BudgetLine.fromJson(Map<String, dynamic> j) => BudgetLine(
        category: BudgetCategory.fromJson(j),
        limit: _moneyOrNull(j['limit']),
        spent: _money(j['spent']),
        count: (j['count'] as num?)?.toInt() ?? 0,
        remaining: _moneyOrNull(j['remaining']),
        percent: _moneyOrNull(j['percent']),
        status: (j['status'] ?? 'none') as String,
      );
}

class BudgetTotals {
  const BudgetTotals({
    this.income,
    this.budgeted = 0,
    this.spent = 0,
    this.autoSaved = 0,
    this.manualSaved = 0,
    this.rolledOver = 0,
    this.saved = 0,
    this.unassigned,
    this.available,
    this.perDayLeft,
  });
  final double? income;
  final double budgeted;
  final double spent;
  final double autoSaved;
  final double manualSaved;
  final double rolledOver;
  final double saved;
  final double? unassigned;
  final double? available;
  final double? perDayLeft;

  factory BudgetTotals.fromJson(Map<String, dynamic> j) => BudgetTotals(
        income: _moneyOrNull(j['income']),
        budgeted: _money(j['budgeted']),
        spent: _money(j['spent']),
        autoSaved: _money(j['autoSaved']),
        manualSaved: _money(j['manualSaved']),
        rolledOver: _money(j['rolledOver']),
        saved: _money(j['saved']),
        unassigned: _moneyOrNull(j['unassigned']),
        available: _moneyOrNull(j['available']),
        perDayLeft: _moneyOrNull(j['perDayLeft']),
      );
}

/// Todo lo que muestra la pestaña Presupuesto.
class BudgetView {
  const BudgetView({required this.settings, required this.period, required this.lines, required this.totals});
  final BudgetSettings settings;
  final BudgetPeriod period;
  final List<BudgetLine> lines;
  final BudgetTotals totals;

  factory BudgetView.fromJson(Map<String, dynamic> j) => BudgetView(
        settings: BudgetSettings.fromJson((j['settings'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{}),
        period: BudgetPeriod.fromJson(j['period'] as Map<String, dynamic>),
        lines: [for (final c in (j['categories'] as List? ?? const [])) BudgetLine.fromJson(c as Map<String, dynamic>)],
        totals: BudgetTotals.fromJson(j['totals'] as Map<String, dynamic>),
      );
}

class BudgetAlert {
  const BudgetAlert({required this.category, required this.level, required this.spent, required this.limit});
  final String category;
  final int level; // 80 | 100
  final double spent;
  final double limit;

  factory BudgetAlert.fromJson(Map<String, dynamic> j) => BudgetAlert(
        category: j['category'] as String,
        level: (j['level'] as num).toInt(),
        spent: _money(j['spent']),
        limit: _money(j['limit']),
      );
}

class BudgetInsights {
  const BudgetInsights({this.summary = '', this.wins = const [], this.warnings = const [], this.tips = const [], this.suggestedSavings = 0});
  final String summary;
  final List<String> wins;
  final List<String> warnings;
  final List<String> tips;
  final double suggestedSavings;

  factory BudgetInsights.fromJson(Map<String, dynamic> j) {
    List<String> list(dynamic v) => [for (final x in (v as List? ?? const [])) x.toString()];
    return BudgetInsights(
      summary: (j['summary'] ?? '') as String,
      wins: list(j['wins']),
      warnings: list(j['warnings']),
      tips: list(j['tips']),
      suggestedSavings: _money(j['suggestedSavings']),
    );
  }
}

enum FundAutoType { none, fixed, percent }

/// Apartado: Ahorro, Emergencias, Medicamentos…
class SavingsFund {
  const SavingsFund({
    this.id,
    required this.name,
    this.icon = 'savings',
    this.color = 'green',
    this.goal,
    this.goalDate,
    this.autoType = FundAutoType.none,
    this.autoValue,
    this.isArchived = false,
    this.balance = 0,
    this.progress,
    this.neededPerMonth,
    this.lastMovementAt,
  });
  final int? id;
  final String name;
  final String icon;
  final String color;
  final double? goal;
  final DateTime? goalDate;
  final FundAutoType autoType;
  final double? autoValue;
  final bool isArchived;
  final double balance;
  final double? progress;
  final double? neededPerMonth;
  final DateTime? lastMovementAt;

  String? get autoLabel => switch (autoType) {
        FundAutoType.none => null,
        FundAutoType.fixed => autoValue == null ? null : 'Auto ${Fmt.money(autoValue!)} por periodo',
        FundAutoType.percent => autoValue == null ? null : 'Auto ${autoValue!.toStringAsFixed(autoValue! % 1 == 0 ? 0 : 1)} % del ingreso',
      };

  factory SavingsFund.fromJson(Map<String, dynamic> j) => SavingsFund(
        id: j['id'] as int?,
        name: j['name'] as String,
        icon: (j['icon'] ?? 'savings') as String,
        color: (j['color'] ?? 'green') as String,
        goal: _moneyOrNull(j['goal']),
        goalDate: parseLocalDate(j['goalDate']),
        autoType: FundAutoType.values.firstWhere((t) => t.name == j['autoType'], orElse: () => FundAutoType.none),
        autoValue: _moneyOrNull(j['autoValue']),
        isArchived: j['isArchived'] == true,
        balance: _money(j['balance']),
        progress: _moneyOrNull(j['progress']),
        neededPerMonth: _moneyOrNull(j['neededPerMonth']),
        lastMovementAt: parseDate(j['lastMovementAt']),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'icon': icon,
        'color': color,
        'goal': goal,
        'goalDate': goalDate == null ? null : localDateString(goalDate!),
        'autoType': autoType.name,
        'autoValue': autoType == FundAutoType.none ? null : autoValue,
        'isArchived': isArchived,
      };
}

class FundMovement {
  const FundMovement({required this.id, required this.amount, this.note, this.source = 'manual', required this.movedAt});
  final int id;
  final double amount; // + depósito, − retiro
  final String? note;
  final String source; // manual | auto | rollover
  final DateTime movedAt;

  bool get isDeposit => amount > 0;

  factory FundMovement.fromJson(Map<String, dynamic> j) => FundMovement(
        id: j['id'] as int,
        amount: _money(j['amount']),
        note: j['note'] as String?,
        source: (j['source'] ?? 'manual') as String,
        movedAt: parseDate(j['movedAt']) ?? DateTime.now(),
      );
}
