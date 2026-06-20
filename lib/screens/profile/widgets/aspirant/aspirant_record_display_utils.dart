import 'package:flutter/material.dart';

IconData aspirantRecordIconFromString(String iconStr) {
  switch (iconStr) {
    case 'directions_run':
      return Icons.directions_run;
    case 'fitness_center':
      return Icons.fitness_center;
    case 'pool':
      return Icons.pool;
    case 'timer':
      return Icons.timer;
    default:
      return Icons.fitness_center;
  }
}

Color aspirantRecordColorFromString(String colorStr) {
  switch (colorStr) {
    case 'green':
      return Colors.green;
    case 'orange':
      return Colors.orange;
    case 'red':
      return Colors.red;
    case 'purple':
      return Colors.purple;
    default:
      return Colors.blue;
  }
}
