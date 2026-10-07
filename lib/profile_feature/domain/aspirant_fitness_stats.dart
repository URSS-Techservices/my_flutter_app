/// Totals shown in the Fitness Stats section.
///
/// Stored in the `fitnessStats` map on the user document. Key names match
/// what the old pages already saved, so existing data keeps working.
class AspirantFitnessStats {
  final int workouts;
  final int calories;
  final int hours;
  final int dayStreak;

  const AspirantFitnessStats({
    required this.workouts,
    required this.calories,
    required this.hours,
    required this.dayStreak,
  });

  static const empty =
      AspirantFitnessStats(workouts: 0, calories: 0, hours: 0, dayStreak: 0);

  factory AspirantFitnessStats.fromMap(Object? raw) {
    if (raw is! Map) return empty;
    int read(String key) => raw[key] is num ? (raw[key] as num).toInt() : 0;
    return AspirantFitnessStats(
      workouts: read('workouts'),
      calories: read('caloriesBurned'),
      hours: read('hours'),
      dayStreak: read('currentStreak'),
    );
  }

  /// Dotted paths so other keys inside `fitnessStats` are left untouched.
  Map<String, Object> toUpdate() => {
        'fitnessStats.workouts': workouts,
        'fitnessStats.caloriesBurned': calories,
        'fitnessStats.hours': hours,
        'fitnessStats.currentStreak': dayStreak,
      };
}
