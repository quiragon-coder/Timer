import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thème
enum AppThemeMode { system, light, dark }
extension AppThemeModePrefs on AppThemeMode {
  int get indexForPrefs => switch (this) {
    AppThemeMode.system => 0,
    AppThemeMode.light => 1,
    AppThemeMode.dark => 2,
  };
  static AppThemeMode fromIndex(int i) => switch (i) {
    1 => AppThemeMode.light,
    2 => AppThemeMode.dark,
    _ => AppThemeMode.system,
  };
}

/// Langue
enum AppLocaleMode { system, fr, en }
extension AppLocaleModePrefs on AppLocaleMode {
  int get indexForPrefs => switch (this) {
    AppLocaleMode.system => 0,
    AppLocaleMode.fr => 1,
    AppLocaleMode.en => 2,
  };
  static AppLocaleMode fromIndex(int i) => switch (i) {
    1 => AppLocaleMode.fr,
    2 => AppLocaleMode.en,
    _ => AppLocaleMode.system,
  };
}

/// Tri des activités
enum ActivitiesSort { name, runningFirst }
extension ActivitiesSortPrefs on ActivitiesSort {
  int get indexForPrefs => switch (this) {
    ActivitiesSort.name => 0,
    ActivitiesSort.runningFirst => 1,
  };
  static ActivitiesSort fromIndex(int i) => switch (i) {
    1 => ActivitiesSort.runningFirst,
    _ => ActivitiesSort.name,
  };
}

/// État global des réglages
class AppSettings {
  final bool showMiniHeatmapHome;
  final bool compactListTiles;
  final bool showSecondsInBadges;
  final bool hapticsOnControls;
  final bool confirmStop;
  final AppThemeMode themeMode;
  final AppLocaleMode localeMode;
  final ActivitiesSort activitiesSort;

  const AppSettings({
    required this.showMiniHeatmapHome,
    required this.compactListTiles,
    required this.showSecondsInBadges,
    required this.hapticsOnControls,
    required this.confirmStop,
    required this.themeMode,
    required this.localeMode,
    required this.activitiesSort,
  });

  AppSettings copyWith({
    bool? showMiniHeatmapHome,
    bool? compactListTiles,
    bool? showSecondsInBadges,
    bool? hapticsOnControls,
    bool? confirmStop,
    AppThemeMode? themeMode,
    AppLocaleMode? localeMode,
    ActivitiesSort? activitiesSort,
  }) {
    return AppSettings(
      showMiniHeatmapHome: showMiniHeatmapHome ?? this.showMiniHeatmapHome,
      compactListTiles: compactListTiles ?? this.compactListTiles,
      showSecondsInBadges: showSecondsInBadges ?? this.showSecondsInBadges,
      hapticsOnControls: hapticsOnControls ?? this.hapticsOnControls,
      confirmStop: confirmStop ?? this.confirmStop,
      themeMode: themeMode ?? this.themeMode,
      localeMode: localeMode ?? this.localeMode,
      activitiesSort: activitiesSort ?? this.activitiesSort,
    );
  }

  static const defaults = AppSettings(
    showMiniHeatmapHome: true,
    compactListTiles: false,
    showSecondsInBadges: true,
    hapticsOnControls: true,
    confirmStop: false,
    themeMode: AppThemeMode.system,
    localeMode: AppLocaleMode.system,
    activitiesSort: ActivitiesSort.name,
  );
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(AppSettings.defaults) {
    _load();
  }

  // Clés prefs
  static const _kMiniHeatmap = 'showMiniHeatmapHome';
  static const _kCompact = 'compactListTiles';
  static const _kShowSeconds = 'showSecondsInBadges';
  static const _kHaptics = 'hapticsOnControls';
  static const _kConfirmStop = 'confirmStop';
  static const _kThemeMode = 'themeMode';
  static const _kLocaleMode = 'localeMode';
  static const _kSort = 'activitiesSort';

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    state = state.copyWith(
      showMiniHeatmapHome: p.getBool(_kMiniHeatmap) ?? state.showMiniHeatmapHome,
      compactListTiles: p.getBool(_kCompact) ?? state.compactListTiles,
      showSecondsInBadges: p.getBool(_kShowSeconds) ?? state.showSecondsInBadges,
      hapticsOnControls: p.getBool(_kHaptics) ?? state.hapticsOnControls,
      confirmStop: p.getBool(_kConfirmStop) ?? state.confirmStop,
      themeMode: AppThemeModePrefs.fromIndex(p.getInt(_kThemeMode) ?? state.themeMode.indexForPrefs),
      localeMode: AppLocaleModePrefs.fromIndex(p.getInt(_kLocaleMode) ?? state.localeMode.indexForPrefs),
      activitiesSort: ActivitiesSortPrefs.fromIndex(p.getInt(_kSort) ?? state.activitiesSort.indexForPrefs),
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

  Future<void> setHapticsOnControls(bool v) async {
    state = state.copyWith(hapticsOnControls: v);
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kHaptics, v);
  }

  Future<void> setConfirmStop(bool v) async {
    state = state.copyWith(confirmStop: v);
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kConfirmStop, v);
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kThemeMode, mode.indexForPrefs);
  }

  Future<void> setLocaleMode(AppLocaleMode mode) async {
    state = state.copyWith(localeMode: mode);
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kLocaleMode, mode.indexForPrefs);
  }

  Future<void> setActivitiesSort(ActivitiesSort s) async {
    state = state.copyWith(activitiesSort: s);
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kSort, s.indexForPrefs);
  }
}

final settingsProvider =
StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});
