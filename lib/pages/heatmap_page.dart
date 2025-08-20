import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../providers_heatmap.dart";
import "../widgets/heatmap.dart";

class ActivityHeatmapPage extends ConsumerWidget {
  final String activityId;
  final String name;
  final Color color;

  const ActivityHeatmapPage({
    super.key,
    required this.activityId,
    required this.name,
    required this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncMap = ref.watch(heatmapYearProvider(activityId));
    return Scaffold(
      appBar: AppBar(title: Text("Heatmap - " + name)),
      body: asyncMap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Error: " + e.toString())),
        data: (map) {
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Last 12 months", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Heatmap(
                        data: map,
                        baseColor: color,
                        maxMinutes: 60,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Each square is one day. Color intensity scales with minutes tracked.",
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
