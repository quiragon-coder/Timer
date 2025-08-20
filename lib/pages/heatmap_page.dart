// lib/pages/heatmap_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ActivityHeatmapPage extends ConsumerStatefulWidget {
  final String activityId;
  final String title;

  const ActivityHeatmapPage({
    super.key,
    required this.activityId,
    required this.title,
  });

  @override
  ConsumerState<ActivityHeatmapPage> createState() => _ActivityHeatmapPageState();
}

class _ActivityHeatmapPageState extends ConsumerState<ActivityHeatmapPage> {
  int _year = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.title} — Heatmap $_year'),
      ),
      body: Center(
        child: Text(
          "Heatmap annuelle en cours d'implémentation.\n"
              "Activité: ${widget.activityId}\n"
              "Année: $_year",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FilledButton.tonal(
              onPressed: () => setState(() => _year--),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [Icon(Icons.chevron_left), SizedBox(width: 6), Text('Année -')],
              ),
            ),
            FilledButton.tonal(
              onPressed: () => setState(() => _year++),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text('Année +'), SizedBox(width: 6), Icon(Icons.chevron_right)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
