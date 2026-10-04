import 'dart:async';
import 'contract.dart';
import 'texture.dart';
import 'theme.dart';

/// A missing variant either fails or uses the theme's explicitly preferred one.
enum AuroraVariantFallback { reject, preferred }

final class AuroraSelection {
  const AuroraSelection(
      {required this.themeId,
      this.appearance = AuroraAppearancePreference.system,
      this.textureId});
  final String themeId;
  final AuroraAppearancePreference appearance;

  /// The texture the user chose explicitly. Null uses the theme's paired
  /// texture, or no texture when the theme has no pairing.
  final String? textureId;

  /// Restore settings without performing IO or resolving missing variants.
  /// The fallback identity must exist; variant policy remains the runtime's job.
  /// A [textureId] that is not among the registered [textures] restores to
  /// null, which uses the theme's paired texture.
  factory AuroraSelection.restore({
    String? themeId,
    String? preference,
    required Iterable<AuroraTheme> themes,
    required String fallbackId,
    String? textureId,
    Iterable<AuroraTexture> textures = const [],
  }) {
    final ids = themes.map((theme) => theme.id).toSet();
    if (!ids.contains(fallbackId)) {
      throw ArgumentError('Unknown fallback theme $fallbackId');
    }
    return AuroraSelection(
      themeId: ids.contains(themeId) ? themeId! : fallbackId,
      appearance: AuroraAppearancePreference.tryParse(preference) ??
          AuroraAppearancePreference.system,
      textureId:
          textures.any((texture) => texture.id == textureId) ? textureId : null,
    );
  }

  Map<String, Object?> toJson() => {
        'themeId': themeId,
        'appearance': appearance.name,
        if (textureId != null) 'textureId': textureId,
      };

  /// Forgiving stored-data boundary; malformed fields use restore defaults.
  factory AuroraSelection.restoreJson(
    Map<String, dynamic> json, {
    required Iterable<AuroraTheme> themes,
    required String fallbackId,
    Iterable<AuroraTexture> textures = const [],
  }) =>
      AuroraSelection.restore(
        themeId: json['themeId'] is String ? json['themeId'] as String : null,
        preference:
            json['appearance'] is String ? json['appearance'] as String : null,
        themes: themes,
        fallbackId: fallbackId,
        textureId:
            json['textureId'] is String ? json['textureId'] as String : null,
        textures: textures,
      );

  factory AuroraSelection.fromJson(Map<String, dynamic> json) {
    final id = json['themeId'];
    final preference = json['appearance'];
    final textureId = json['textureId'];
    final appearance = preference is String
        ? AuroraAppearancePreference.tryParse(preference)
        : null;
    if (id is! String ||
        id.trim().isEmpty ||
        appearance == null ||
        (json.containsKey('textureId') &&
            (textureId is! String || textureId.trim().isEmpty)) ||
        json.keys.any((key) =>
            key != 'themeId' && key != 'appearance' && key != 'textureId')) {
      throw const FormatException(
          'Expected themeId, appearance and optional textureId selection fields');
    }
    return AuroraSelection(
        themeId: id, appearance: appearance, textureId: textureId as String?);
  }
}

/// Immutable snapshot of the requested selection and its resolved values.
final class AuroraState {
  const AuroraState(this.selection, this.theme, this.variant, {this.texture});
  final AuroraSelection selection;
  final AuroraTheme theme;
  final AuroraThemeVariant variant;

  /// The active texture: the selected one, else the theme's paired one, else
  /// null.
  final AuroraTexture? texture;
}

/// Pure Dart runtime. Rejected changes leave selection and active values intact.
final class AuroraRuntime {
  AuroraRuntime({
    required this.contract,
    required Iterable<AuroraTheme> themes,
    required AuroraSelection initialSelection,
    required this.fallback,
    AuroraAppearance systemAppearance = AuroraAppearance.light,
    Iterable<AuroraTexture> textures = const [],
    Map<String, String> texturePairings = const {},
  }) : _systemAppearance = systemAppearance {
    final textureRegistry = <String, AuroraTexture>{};
    for (final texture in textures) {
      if (!identical(texture.contract, textures.first.contract)) {
        throw ArgumentError(
            'Textures must use the same texture contract instance');
      }
      if (textureRegistry.containsKey(texture.id)) {
        throw ArgumentError('Duplicate texture id ${texture.id}');
      }
      texture.validateColors(contract);
      textureRegistry[texture.id] = texture;
    }
    this.textures = Map.unmodifiable(textureRegistry);
    final registry = <String, AuroraTheme>{};
    for (final theme in themes) {
      if (!identical(theme.contract, contract))
        throw ArgumentError('Theme ${theme.id} uses a different contract');
      if (registry.containsKey(theme.id))
        throw ArgumentError('Duplicate theme id ${theme.id}');
      registry[theme.id] = theme;
    }
    this.themes = Map.unmodifiable(registry);
    for (final entry in texturePairings.entries) {
      _checkPairing(entry.key, entry.value);
      _pairings[entry.key] = entry.value;
    }
    _state = _resolve(initialSelection, systemAppearance);
  }

  final AuroraContract contract;
  final AuroraVariantFallback fallback;
  late final Map<String, AuroraTheme> themes;

  /// Registered textures by id; empty when the app does not use textures.
  late final Map<String, AuroraTexture> textures;

  /// The shared texture contract, or null when no textures are registered.
  AuroraTextureContract? get textureContract =>
      textures.isEmpty ? null : textures.values.first.contract;

  final _pairings = <String, String>{};

  /// Theme id to paired texture id. A theme without an entry has no texture
  /// unless the selection names one.
  Map<String, String> get texturePairings => Map.unmodifiable(_pairings);
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
    final textureId = selection.textureId ?? _pairings[theme.id];
    final texture = textureId == null
        ? null
        : textures[textureId] ??
            (throw ArgumentError(textures.isEmpty
                ? 'Texture $textureId selected, but no textures are registered'
                : 'Unknown texture $textureId'));
    return AuroraState(selection, theme, variant, texture: texture);
  }

  void _checkPairing(String themeId, String? textureId) {
    if (!themes.containsKey(themeId)) {
      throw ArgumentError('Unknown theme $themeId');
    }
    if (textureId != null && !textures.containsKey(textureId)) {
      throw ArgumentError('Unknown texture $textureId');
    }
  }

  /// Pairs [themeId] with [textureId], or removes its pairing when null.
  /// Selections without an explicit texture use the active theme's pairing.
  void pairTexture(String themeId, String? textureId) {
    _ensureOpen();
    _checkPairing(themeId, textureId);
    if (_pairings[themeId] == textureId) return;
    if (textureId == null) {
      _pairings.remove(themeId);
    } else {
      _pairings[themeId] = textureId;
    }
    final next = _resolve(_state.selection, _systemAppearance);
    if (identical(next.texture, _state.texture)) return;
    _state = next;
    _changes.add(next);
  }

  void select(AuroraSelection selection) {
    _ensureOpen();
    final next = _resolve(selection, _systemAppearance);
    if (_state.selection.themeId == selection.themeId &&
        _state.selection.appearance == selection.appearance &&
        _state.selection.textureId == selection.textureId) return;
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
