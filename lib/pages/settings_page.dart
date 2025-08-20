import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers_settings.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          // Thème
          ListTile(
            title: const Text('Thème'),
            subtitle: const Text('Choisir entre système, clair ou sombre'),
            trailing: DropdownButton<AppThemeMode>(
              value: s.themeMode,
              onChanged: (m) {
                if (m != null) {
                  ref.read(settingsProvider.notifier).setThemeMode(m);
                }
              },
              items: const [
                DropdownMenuItem(
                  value: AppThemeMode.system,
                  child: Text('Système'),
                ),
                DropdownMenuItem(
                  value: AppThemeMode.light,
                  child: Text('Clair'),
                ),
                DropdownMenuItem(
                  value: AppThemeMode.dark,
                  child: Text('Sombre'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Compacter la liste
          SwitchListTile(
            title: const Text('Compacter la liste d’activités'),
            subtitle: const Text('Réduit la hauteur des tuiles'),
            value: s.compactListTiles,
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).setCompactListTiles(v),
          ),
          const Divider(height: 1),

          // Secondes dans le badge
          SwitchListTile(
            title: const Text('Afficher les secondes dans le badge'),
            subtitle: const Text('Ex: 07:12 au lieu de 7 min'),
            value: s.showSecondsInBadges,
            onChanged: (v) => ref
                .read(settingsProvider.notifier)
                .setShowSecondsInBadges(v),
          ),
          const Divider(height: 1),

          // Mini-heatmap accueil
          SwitchListTile(
            title: const Text('Mini-heatmap sur la page d’accueil'),
            subtitle: const Text(
                'Affiche la mini-heatmap “7 derniers jours” quand il n’y a qu’une seule activité'),
            value: s.showMiniHeatmapHome,
            onChanged: (v) => ref
                .read(settingsProvider.notifier)
                .setShowMiniHeatmapHome(v),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
