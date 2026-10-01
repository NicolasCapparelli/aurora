import 'dart:async';
import 'contract.dart';
import 'theme.dart';

/// A missing variant either fails or uses the theme's explicitly preferred one.
enum AuroraVariantFallback { reject, preferred }

final class AuroraSelection {
  const AuroraSelection(
      {required this.themeId,
      this.appearance = AuroraAppearancePreference.system});
  final String themeId;
  final AuroraAppearancePreference appearance;
}

/// Immutable snapshot of the requested selection and its resolved values.
final class AuroraState {
  const AuroraState(this.selection, this.theme, this.variant);
  final AuroraSelection selection;
  final AuroraTheme theme;
  final AuroraThemeVariant variant;
}

/// Pure Dart runtime. Rejected changes leave selection and active values intact.
final class AuroraRuntime {
  AuroraRuntime({
    required this.contract,
    required Iterable<AuroraTheme> themes,
    required AuroraSelection initialSelection,
    required this.fallback,
    AuroraAppearance systemAppearance = AuroraAppearance.light,
  }) : _systemAppearance = systemAppearance {
    final registry = <String, AuroraTheme>{};
    for (final theme in themes) {
      if (!identical(theme.contract, contract))
        throw ArgumentError('Theme ${theme.id} uses a different contract');
      if (registry.containsKey(theme.id))
        throw ArgumentError('Duplicate theme id ${theme.id}');
      registry[theme.id] = theme;
    }
    this.themes = Map.unmodifiable(registry);
    _state = _resolve(initialSelection, systemAppearance);
  }

  final AuroraContract contract;
  final AuroraVariantFallback fallback;
  late final Map<String, AuroraTheme> themes;
  AuroraAppearance _systemAppearance;
  late AuroraState _state;
  final _changes = StreamController<AuroraState>.broadcast();
  bool _disposed = false;

  AuroraState get state => _state;
  Stream<AuroraState> get changes => _changes.stream;

  AuroraState _resolve(AuroraSelection selection, AuroraAppearance system) {
    final theme = themes[selection.themeId];
    if (theme == null)
      throw ArgumentError('Unknown theme ${selection.themeId}');
    final appearance = switch (selection.appearance) {
      AuroraAppearancePreference.light => AuroraAppearance.light,
      AuroraAppearancePreference.dark => AuroraAppearance.dark,
      AuroraAppearancePreference.system => system,
    };
    final variant = theme.variants[appearance] ??
        (fallback == AuroraVariantFallback.preferred
            ? theme.variants[theme.preferredAppearance]
            : null);
    if (variant == null)
      throw StateError('Theme ${theme.id} has no ${appearance.name} variant');
    return AuroraState(selection, theme, variant);
  }

  void select(AuroraSelection selection) {
    _ensureOpen();
    final next = _resolve(selection, _systemAppearance);
    if (_state.selection.themeId == selection.themeId &&
        _state.selection.appearance == selection.appearance) return;
    _state = next;
    _changes.add(next);
  }

  void setSystemAppearance(AuroraAppearance appearance) {
    _ensureOpen();
    if (_systemAppearance == appearance) return;
    final next = _resolve(_state.selection, appearance);
    _systemAppearance = appearance;
    if (identical(next.variant, _state.variant)) return;
    _state = next;
    _changes.add(next);
  }

  void _ensureOpen() {
    if (_disposed) throw StateError('AuroraRuntime has been disposed');
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _changes.close();
  }
}
