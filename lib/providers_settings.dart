import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modes de thème supportés
enum AppThemeMode { system, light, dark }

extension AppThemeModePrefs on AppThemeMode {
  int get indexForPrefs {
    switch (this) {
      case AppThemeMode.system:
        return 0;
      case AppThemeMode.light:
        return 1;
      case AppThemeMode.dark:
        return 2;
    }
  }

  static AppThemeMode fromIndex(int i) {
    switch (i) {
      case 1:
        return AppThemeMode.light;
      case 2:
        return AppThemeMode.dark;
      case 0:
      default:
        return AppThemeMode.system;
    }
  }
}

/// État des réglages applicatifs
class AppSettings {
  final bool showMiniHeatmapHome;
  final bool compactListTiles;
  final bool showSecondsInBadges;
  final AppThemeMode themeMode;

  const AppSettings({
    required this.showMiniHeatmapHome,
    required this.compactListTiles,
    required this.showSecondsInBadges,
    required this.themeMode,
  });

  AppSettings copyWith({
    bool? showMiniHeatmapHome,
    bool? compactListTiles,
    bool? showSecondsInBadges,
    AppThemeMode? themeMode,
  }) {
    return AppSettings(
      showMiniHeatmapHome: showMiniHeatmapHome ?? this.showMiniHeatmapHome,
      compactListTiles: compactListTiles ?? this.compactListTiles,
      showSecondsInBadges: showSecondsInBadges ?? this.showSecondsInBadges,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  static const defaults = AppSettings(
    showMiniHeatmapHome: true,
    compactListTiles: false,
    showSecondsInBadges: true,
    themeMode: AppThemeMode.system,
  );
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(AppSettings.defaults) {
    _load();
  }

  // Clés de persistance
  static const _kMiniHeatmap = 'showMiniHeatmapHome';
  static const _kCompact = 'compactListTiles';
  static const _kShowSeconds = 'showSecondsInBadges';
  static const _kThemeMode = 'themeMode';

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    state = state.copyWith(
      showMiniHeatmapHome: p.getBool(_kMiniHeatmap) ?? state.showMiniHeatmapHome,
      compactListTiles: p.getBool(_kCompact) ?? state.compactListTiles,
      showSecondsInBadges: p.getBool(_kShowSeconds) ?? state.showSecondsInBadges,
      themeMode: AppThemeModePrefs.fromIndex(p.getInt(_kThemeMode) ?? state.themeMode.indexForPrefs),
    );
  }

  Future<void> setShowMiniHeatmapHome(bool v) async {
    state = state.copyWith(showMiniHeatmapHome: v);
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kMiniHeatmap, v);
  }

  Future<void> setCompactListTiles(bool v) async {
    state = state.copyWith(compactListTiles: v);
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kCompact, v);
  }

  Future<void> setShowSecondsInBadges(bool v) async {
    state = state.copyWith(showSecondsInBadges: v);
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kShowSeconds, v);
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kThemeMode, mode.indexForPrefs);
  }
}

/// Provider public des réglages
final settingsProvider =
StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});
