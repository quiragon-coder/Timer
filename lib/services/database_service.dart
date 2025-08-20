/// Sessions terminées pour une activité, triées du plus récent au plus ancien.
List<Session> sessionsByActivity(String activityId) {
  final list = _sessions
      .where((s) => s.activityId == activityId && s.endAt != null)
      .toList(); // copie => on peut trier
  list.sort((a, b) => b.startAt.compareTo(a.startAt));
  return list;
}

/// Début de la session en cours pour l’activité (si en cours).
DateTime currentSessionStart(String activityId) {
  final s = _sessions.firstWhere(
        (s) => s.activityId == activityId && s.endAt == null,
    orElse: () => Session(
      id: 'n/a',
      activityId: activityId,
      startAt: DateTime.now(),
      endAt: null,
    ),
  );
  return s.startAt;
}
