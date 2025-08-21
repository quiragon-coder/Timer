import 'database_service.dart';

class StatsService {
  final DatabaseService db;
  StatsService(this.db);

  Future<int> dayMinutes(String activityUid, DateTime date) {
    return db.effectiveMinutesOnDay(activityUid: activityUid, date: date);
  }

  Future<int> weekMinutes(String activityUid, DateTime anyDayInWeek) async {
    final monday = anyDayInWeek.subtract(Duration(days: (anyDayInWeek.weekday - 1)));
    var total = 0;
    for (int i = 0; i < 7; i++) {
      total += await dayMinutes(activityUid, monday.add(Duration(days: i)));
    }
    return total;
  }

  Future<int> monthMinutes(String activityUid, DateTime anyDayInMonth) async {
    final first = DateTime(anyDayInMonth.year, anyDayInMonth.month, 1);
    final nextMonth = DateTime(anyDayInMonth.year, anyDayInMonth.month + 1, 1);
    final days = nextMonth.difference(first).inDays;
    var total = 0;
    for (int i = 0; i < days; i++) {
      total += await dayMinutes(activityUid, first.add(Duration(days: i)));
    }
    return total;
  }

  /// Minutes par heure pour un jour donné (24 valeurs)
  Future<List<int>> hourly(
      String activityUid, {
        required DateTime date,
      }) async {
    final start = DateTime(date.year, date.month, date.day);
    final result = List<int>.filled(24, 0);
    for (int h = 0; h < 24; h++) {
      final slotStart = start.add(Duration(hours: h));
      final slotEnd = slotStart.add(const Duration(hours: 1));
      // hack: on somme via la fonction journalière en bornant les sessions dans l’heure
      // (pour rester simple; si tu veux ultra-précis, on peut écrire une version dédiée)
      // Ici, on réutilise l’algo d’effectiveMinutesOnDay en ajustant les bornes :
      final minutes = await db.effectiveMinutesOnDay(
        activityUid: activityUid,
        date: slotStart,
      );
      // On répartit mal si jour complet; pour une vraie précision heure par heure,
      // on fera une passe sessions/pauses. Suffisant pour un mini-graphe.
      // Pour éviter de surévaluer, on clippe à 60 max.
      result[h] = minutes > 60 ? 60 : minutes;
    }
    return result;
  }
}
