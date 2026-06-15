import 'package:flutter/material.dart';

/// GPS button for location fields — keeps the text field editable for manual entry.
Widget gpsLocationSuffix({
  required bool isFetching,
  required VoidCallback onPressed,
  Color iconColor = Colors.white70,
}) {
  if (isFetching) {
    return const Padding(
      padding: EdgeInsets.all(12),
      child: SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
  return IconButton(
    tooltip: 'Use current location',
    onPressed: onPressed,
    icon: Icon(Icons.my_location_rounded, color: iconColor),
  );
}
