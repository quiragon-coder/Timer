import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/database_service.dart';

/// Expose un DatabaseService qui notifie les changements.
/// Toute UI qui fait `ref.watch(dbProvider)` sera rebuild après un start/pause/stop.
final dbProvider = ChangeNotifierProvider<DatabaseService>((ref) {
  return DatabaseService();
});
