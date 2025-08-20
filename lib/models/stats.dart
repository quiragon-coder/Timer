// Modèles partagés pour les stats et les widgets (graphiques, panneaux, etc.)

class HourlyBucket {
  final int hour;     // 0..23
  final int minutes;  // minutes sur cette heure
  const HourlyBucket({required this.hour, required this.minutes});
}

class DailyStat {
  final DateTime day; // minuit du jour
  final int minutes;  // minutes totales sur ce jour
  const DailyStat({required this.day, required this.minutes});
}
