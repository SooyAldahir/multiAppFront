import 'package:flutter/material.dart';

/// Textos en español para los valores del perfil de salud y las comidas.
const goalLabels = {'lose': 'Bajar de peso', 'maintain': 'Mantenerme', 'gain': 'Ganar músculo'};

const activityLabels = {
  'sedentary': 'Sedentario (casi no me muevo)',
  'light': 'Ligero (camino un poco, 1-2 días de ejercicio)',
  'moderate': 'Moderado (3-5 días de ejercicio)',
  'active': 'Activo (6-7 días de ejercicio)',
  'very_active': 'Muy activo (trabajo físico o 2 entrenamientos al día)',
};

const levelLabels = {'beginner': 'Principiante', 'intermediate': 'Intermedio', 'advanced': 'Avanzado'};

const equipmentLabels = {'none': 'En casa, sin equipo', 'dumbbells': 'En casa, con mancuernas', 'gym': 'Gimnasio'};

const mealLabels = {'breakfast': 'Desayuno', 'lunch': 'Comida', 'dinner': 'Cena', 'snack': 'Colación'};

const mealIcons = {
  'breakfast': Icons.free_breakfast_outlined,
  'lunch': Icons.lunch_dining_outlined,
  'dinner': Icons.dinner_dining_outlined,
  'snack': Icons.cookie_outlined,
};

/// Comida sugerida según la hora.
String mealForTime(DateTime t) {
  if (t.hour < 11) return 'breakfast';
  if (t.hour < 17) return 'lunch';
  if (t.hour < 22) return 'dinner';
  return 'snack';
}

/// Grupos musculares que el usuario puede elegir (null = la IA decide).
const focusOptions = <(String?, String)>[
  (null, 'La IA decide'),
  ('cuerpo completo', 'Cuerpo completo'),
  ('pecho', 'Pecho'),
  ('espalda', 'Espalda'),
  ('piernas', 'Piernas'),
  ('glúteos', 'Glúteos'),
  ('hombros', 'Hombros'),
  ('brazos', 'Brazos'),
  ('core', 'Abdomen / core'),
  ('cardio', 'Cardio'),
  ('movilidad', 'Movilidad'),
];
