import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers_stats.dart';

class ActivityStatsPanel extends ConsumerWidget {
  final String activityUid;
  const ActivityStatsPanel({super.key, required this.activityUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    final j = ref.watch(dayMinutesProvider((activityUid: activityUid, date: today)));
    final s = ref.watch(weekMinutesProvider((activityUid: activityUid, inWeek: today)));
    final m = ref.watch(monthMinutesProvider((activityUid: activityUid, inMonth: today)));

    Widget cell(String label, AsyncValue<int> v) {
      return v.when(
        data: (val) => _StatCell(label: label, value: val),
        loading: () => _StatCell(label: label, value: null),
        error: (e, _) => _StatCell(label: label, value: 0),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        cell('Jour', j),
        cell('Semaine', s),
        cell('Mois', m),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final int? value;
  const _StatCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final text = value == null ? '…' : '$value min';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(text, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
