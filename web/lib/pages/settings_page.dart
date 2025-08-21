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
            trailing: DropdownButton<AppThemeMode>(
              value: s.themeMode,
              onChanged: (m) {
                if (m != null) {
                  ref.read(settingsProvider.notifier).setThemeMode(m);
                }
              },
              items: const [
                DropdownMenuItem(value: AppThemeMode.system, child: Text('Système')),
                DropdownMenuItem(value: AppThemeMode.light, child: Text('Clair')),
                DropdownMenuItem(value: AppThemeMode.dark, child: Text('Sombre')),
              ],
            ),
          ),
          const Divider(height: 1),

          // Langue
          ListTile(
            title: const Text('Langue'),
            trailing: DropdownButton<AppLocaleMode>(
              value: s.localeMode,
              onChanged: (m) {
                if (m != null) {
                  ref.read(settingsProvider.notifier).setLocaleMode(m);
                }
              },
              items: const [
                DropdownMenuItem(value: AppLocaleMode.system, child: Text('Système')),
                DropdownMenuItem(value: AppLocaleMode.fr, child: Text('Français')),
                DropdownMenuItem(value: AppLocaleMode.en, child: Text('English')),
              ],
            ),
          ),
          const Divider(height: 1),

          // Tri
          ListTile(
            title: const Text('Tri des activités'),
            trailing: DropdownButton<ActivitiesSort>(
              value: s.activitiesSort,
              onChanged: (v) {
                if (v != null) {
                  ref.read(settingsProvider.notifier).setActivitiesSort(v);
                }
              },
              items: const [
                DropdownMenuItem(value: ActivitiesSort.name, child: Text('Nom')),
                DropdownMenuItem(value: ActivitiesSort.runningFirst, child: Text('En cours d’abord')),
              ],
            ),
          ),
          const Divider(height: 1),

          // Compacter la liste
          SwitchListTile(
            title: const Text('Compacter la liste d’activités'),
            value: s.compactListTiles,
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).setCompactListTiles(v),
          ),
          const Divider(height: 1),

          // Badge secondes
          SwitchListTile(
            title: const Text('Afficher les secondes dans le badge'),
            value: s.showSecondsInBadges,
            onChanged: (v) => ref
                .read(settingsProvider.notifier)
                .setShowSecondsInBadges(v),
          ),
          const Divider(height: 1),

          // Haptique
          SwitchListTile(
            title: const Text('Vibration (haptique) sur Start/Pause/Stop'),
            value: s.hapticsOnControls,
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).setHapticsOnControls(v),
          ),
          const Divider(height: 1),

          // Confirmation stop
          SwitchListTile(
            title: const Text('Confirmer avant d’arrêter'),
            value: s.confirmStop,
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).setConfirmStop(v),
          ),
          const Divider(height: 1),

          // Mini-heatmap accueil
          SwitchListTile(
            title: const Text('Mini-heatmap sur la page d’accueil'),
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
