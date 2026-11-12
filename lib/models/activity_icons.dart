import 'package:flutter/material.dart';

/// Icons an activity can show on its grid tile, stored by key in
/// `activities.icon`. Keys are stable; never rename one that has shipped.
/// Kept `const` so Flutter's icon tree shaking still works.
const Map<String, IconData> activityIcons = {
  'work': Icons.work_outline,
  'computer': Icons.computer,
  'code': Icons.code,
  'study': Icons.school_outlined,
  'reading': Icons.menu_book_outlined,
  'writing': Icons.edit_outlined,
  'meeting': Icons.groups_outlined,
  'phone': Icons.phone_outlined,
  'fitness': Icons.fitness_center,
  'running': Icons.directions_run,
  'walking': Icons.directions_walk,
  'cycling': Icons.directions_bike,
  'sports': Icons.sports_soccer,
  'meditation': Icons.self_improvement,
  'sleep': Icons.bedtime_outlined,
  'food': Icons.restaurant,
  'cooking': Icons.soup_kitchen_outlined,
  'coffee': Icons.local_cafe_outlined,
  'cleaning': Icons.cleaning_services_outlined,
  'shopping': Icons.shopping_cart_outlined,
  'commute': Icons.directions_car_outlined,
  'travel': Icons.flight_outlined,
  'gaming': Icons.sports_esports_outlined,
  'tv': Icons.tv,
  'music': Icons.music_note_outlined,
  'art': Icons.palette_outlined,
  'social': Icons.people_outline,
  'family': Icons.family_restroom,
  'pets': Icons.pets,
  'garden': Icons.yard_outlined,
  'health': Icons.favorite_border,
  'relax': Icons.weekend_outlined,
};

/// The icon for [key], or null if none is set (or the key is unknown, e.g.
/// from a newer app version).
IconData? activityIcon(String? key) => key == null ? null : activityIcons[key];
