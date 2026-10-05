import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/storage_providers.dart';

/// Theme mode: light or dark only (no "follow system"), persisted in shared_preferences.
/// Default is dark ("ringside after dark").
class ThemeModeController extends Notifier<ThemeMode> {
  static const String storageKey = 'hvp_theme_mode';

  @override
  ThemeMode build() {
    try {
      final stored = ref.read(sharedPreferencesProvider).getString(storageKey);
      return parse(stored);
    } catch (_) {
      return ThemeMode.dark;
    }
  }

  /// Only `light` is recognised; unknown, missing or legacy `system` values fall back to dark.
  static ThemeMode parse(String? value) => value == ThemeMode.light.name ? ThemeMode.light : ThemeMode.dark;

  /// Flips between light and dark.
  Future<void> toggle() => setMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);

  Future<void> setMode(ThemeMode mode) async {
    final next = mode == ThemeMode.light ? ThemeMode.light : ThemeMode.dark;
    state = next;
    try {
      await ref.read(sharedPreferencesProvider).setString(storageKey, next.name);
    } catch (_) {
      // Persistence is a convenience; the choice still applies for this run.
    }
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
