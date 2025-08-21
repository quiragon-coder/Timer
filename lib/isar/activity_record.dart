// GENERATED-SAFE: You will still need to run build_runner to generate the *.g.dart files.
import 'package:isar/isar.dart';

part 'activity_record.g.dart';

@collection
class ActivityRecord {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String uid;

  late String name;
  late String emoji;
  late int colorValue;

  int? dailyGoalMinutes;
  int? weeklyGoalMinutes;
  int? monthlyGoalMinutes;
  int? yearlyGoalMinutes;

  DateTime createdAt = DateTime.now();
}
