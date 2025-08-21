import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers_stats.dart';

class WeeklyBarsCard extends ConsumerWidget {
  final String activityUid;
  const WeeklyBarsCard({super.key, required this.activityUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    return ref.watch(weekMinutesProvider((activityUid: activityUid, inWeek: now))).when(
      data: (v) => _Card(title: 'Semaine', value: v),
      loading: () => const _Card(title: 'Semaine', value: null),
      error: (e, _) => _Card(title: 'Semaine', value: 0),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final int? value;
  const _Card({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final text = value == null ? '…' : '$value min';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Text(text, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
