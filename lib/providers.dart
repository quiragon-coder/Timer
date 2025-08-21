import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/database_service.dart';

/// Service DB unique, initialisé automatiquement.
final dbProvider = Provider<DatabaseService>((ref) {
  final db = DatabaseService.instance;
  db.init(); // non bloquant pour l’UI
  return db;
});
