import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Tipos de lugar que se pueden guardar.
class PlaceCategory {
  const PlaceCategory(this.id, this.label, this.icon, this.tint);
  final String id;
  final String label;
  final IconData icon;
  final ModuleTint tint;
}

const placeCategories = [
  PlaceCategory('home', 'Casa', Icons.home_rounded, ModuleTint.coral),
  PlaceCategory('work', 'Trabajo', Icons.work_outline_rounded, ModuleTint.blue),
  PlaceCategory('church', 'Iglesia', Icons.church_outlined, ModuleTint.violet),
  PlaceCategory('school', 'Escuela', Icons.school_outlined, ModuleTint.amber),
  PlaceCategory('gym', 'Gimnasio', Icons.fitness_center_rounded, ModuleTint.green),
  PlaceCategory('family', 'Familia', Icons.family_restroom_rounded, ModuleTint.pink),
  PlaceCategory('store', 'Tienda', Icons.storefront_outlined, ModuleTint.teal),
  PlaceCategory('other', 'Otro', Icons.place_outlined, ModuleTint.ink),
];

PlaceCategory placeCategory(String id) =>
    placeCategories.firstWhere((c) => c.id == id, orElse: () => placeCategories.last);
