import 'services/database_service_isar.dart';

final dbProvider = ChangeNotifierProvider<DatabaseServiceIsar>((ref) {
  // On l’initialise dans main.dart et on override ce provider avec l’instance.
  throw UnimplementedError('Initialisé via override dans main.dart');
});
