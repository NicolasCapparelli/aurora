import 'package:material_color_utilities/material_color_utilities.dart';
import 'color.dart';
import 'contract.dart';
import 'contrast.dart';
import 'dtcg.dart';
import 'foundation.dart';
import 'material_roles.dart';
import 'theme.dart';

enum AuroraPalette {
  primary,
  secondary,
  tertiary,
  neutral,
  neutralVariant,
  error,
  success,
  warning,
  info
}

/// Declarative, portable rules for required app tokens. No framework callbacks.
sealed class AuroraTokenRule {
  const AuroraTokenRule();
}

/// Copy an already resolved token, including a deliberate override.
final class AuroraAliasRule extends AuroraTokenRule {
  const AuroraAliasRule(this.target);
  final AuroraColorToken target;
}

/// Select an HCT tone from a generated palette for each appearance.
final class AuroraToneRule extends AuroraTokenRule {
  factory AuroraToneRule(
      {required AuroraPalette palette,
      required double lightTone,
      required double darkTone}) {
    for (final tone in [lightTone, darkTone]) {
      if (!tone.isFinite || tone < 0 || tone > 100)
        throw ArgumentError('Tone must be finite and in [0, 100]');
    }
    return AuroraToneRule._(palette, lightTone, darkTone);
  }
  const AuroraToneRule._(this.palette, this.lightTone, this.darkTone);
  final AuroraPalette palette;
  final double lightTone;
  final double darkTone;
}

/// Immutable input. Explicit values override rules and generated defaults.
final class AuroraGenerationRequest {
  factory AuroraGenerationRequest({
    required AuroraContract contract,
    required String id,
    required String name,
    required AuroraColor primary,
    AuroraColor? secondary,
    AuroraColor? tertiary,
    AuroraColor? success,
    AuroraColor? warning,
    AuroraColor? info,
    Iterable<AuroraAppearance> appearances = const [
      AuroraAppearance.light,
      AuroraAppearance.dark
    ],
    AuroraAppearance preferredAppearance = AuroraAppearance.light,
    Map<AuroraColorToken, AuroraColor> values = const {},
    Map<AuroraAppearance, Map<AuroraColorToken, AuroraColor>> variantValues =
        const {},
    Map<AuroraColorToken, AuroraTokenRule> rules = const {},
    Iterable<AuroraContrastPair> contrastPairs = const [],
  }) {
    if (id.trim().isEmpty || name.trim().isEmpty)
      throw ArgumentError('Theme identity must not be empty');
    final requested = List<AuroraAppearance>.of(appearances);
    if (requested.isEmpty ||
        requested.toSet().length != requested.length ||
        !requested.contains(preferredAppearance)) {
      throw ArgumentError(
          'Choose unique appearances including the preferred appearance');
    }
    // Canonical order makes output independent of the caller's input ordering.
    requested.sort((a, b) => a.index.compareTo(b.index));
    final seeds = <AuroraPalette, AuroraColor>{
      AuroraPalette.primary: primary,
      if (secondary != null) AuroraPalette.secondary: secondary,
      if (tertiary != null) AuroraPalette.tertiary: tertiary,
      AuroraPalette.success: success ?? AuroraColor.hex('#146c2e'),
      AuroraPalette.warning: warning ?? AuroraColor.hex('#805600'),
      AuroraPalette.info: info ?? AuroraColor.hex('#0061a4'),
    };
    if (seeds.values.any((color) => color.alpha != 255))
      throw ArgumentError('Seed colors must be opaque');
    void validateToken(AuroraColorToken token) {
      if (!contract.contains(token))
        throw ArgumentError('Undeclared generation token ${token.path}');
    }

    for (final token in values.keys) {
      validateToken(token);
    }
    for (final entry in variantValues.entries) {
      if (!requested.contains(entry.key))
        throw ArgumentError('Values supplied for an unrequested appearance');
      for (final token in entry.value.keys) {
        validateToken(token);
      }
    }
    for (final entry in rules.entries) {
      validateToken(entry.key);
      if (AuroraFoundation.tokens.contains(entry.key))
        throw ArgumentError(
            'Rules are for app extensions; use values to override foundation tokens');
      if (entry.value case AuroraAliasRule(:final target)) {
        validateToken(target);
      }
    }
    final pairs = List<AuroraContrastPair>.of(contrastPairs);
    for (final pair in pairs) {
      validateToken(pair.foreground);
      validateToken(pair.background);
    }
    return AuroraGenerationRequest._(
        contract,
        id,
        name,
        Map.unmodifiable(seeds),
        List.unmodifiable(requested),
        preferredAppearance,
        Map.unmodifiable(values),
        Map.unmodifiable(variantValues.map((key, value) => MapEntry(
            key, Map<AuroraColorToken, AuroraColor>.unmodifiable(value)))),
        Map.unmodifiable(rules),
        List.unmodifiable(pairs));
  }

  AuroraGenerationRequest._(
      this.contract,
      this.id,
      this.name,
      this.seeds,
      this.appearances,
      this.preferredAppearance,
      this.values,
      this.variantValues,
      this.rules,
      this.contrastPairs);
  final AuroraContract contract;
  final String id;
  final String name;
  final Map<AuroraPalette, AuroraColor> seeds;
  final List<AuroraAppearance> appearances;
  final AuroraAppearance preferredAppearance;
  final Map<AuroraColorToken, AuroraColor> values;
  final Map<AuroraAppearance, Map<AuroraColorToken, AuroraColor>> variantValues;
  final Map<AuroraColorToken, AuroraTokenRule> rules;
  final List<AuroraContrastPair> contrastPairs;
}

final class AuroraGenerationResult {
  AuroraGenerationResult._(this.theme, Iterable<AuroraContrastCheck> checks)
      : checks = List.unmodifiable(checks);
  final AuroraTheme theme;
  final List<AuroraContrastCheck> checks;
  String get algorithm => AuroraGenerator.algorithm;
  List<AuroraContrastCheck> get issues => List.unmodifiable(
      checks.where((check) => check.status != AuroraContrastStatus.pass));

  /// An Aurora manifest with DTCG variant documents; not itself a DTCG document.
  Map<String, Object?> toJson() => {
        'algorithm': algorithm,
        'foundationVersion': AuroraFoundation.version,
        'contract': {
          'id': theme.contract.id,
          'version': theme.contract.version
        },
        'id': theme.id,
        'name': theme.name,
        'preferredAppearance': theme.preferredAppearance.name,
        'variants': {
          for (final entry in theme.variants.entries)
            entry.key.name: AuroraDtcg.encode(entry.value)
        },
        'contrast': checks.map((check) => check.toJson()).toList(),
      };
}

/// Deterministic generation, independent of widgets, storage, network, or device.
abstract final class AuroraGenerator {
  static const algorithm = 'aurora-tonal-v1-mcu-0.11.1';

  static AuroraGenerationResult generate(AuroraGenerationRequest request) {
    final variants = <AuroraThemeVariant>[];
    final checks = <AuroraContrastCheck>[];
    for (final appearance in request.appearances) {
      final scheme = _scheme(request.seeds[AuroraPalette.primary]!, appearance);
      final primaryScheme = DynamicScheme(
          sourceColorArgb: scheme.sourceColorArgb,
          variant: scheme.variant,
          isDark: scheme.isDark,
          primaryPalette: scheme.primaryPalette,
          secondaryPalette: request.seeds[AuroraPalette.secondary] == null
              ? scheme.secondaryPalette
              : TonalPalette.fromHct(
                  Hct.fromInt(request.seeds[AuroraPalette.secondary]!.argb)),
          tertiaryPalette: request.seeds[AuroraPalette.tertiary] == null
              ? scheme.tertiaryPalette
              : TonalPalette.fromHct(
                  Hct.fromInt(request.seeds[AuroraPalette.tertiary]!.argb)),
          neutralPalette: scheme.neutralPalette,
          neutralVariantPalette: scheme.neutralVariantPalette);
      final status = {
        for (final palette in [
          AuroraPalette.success,
          AuroraPalette.warning,
          AuroraPalette.info
        ])
          palette: _scheme(request.seeds[palette]!, appearance)
      };
      final values = materialRoleValues(primaryScheme);
      for (final palette in status.keys) {
        final prefix = palette.name;
        final cap = '${prefix[0].toUpperCase()}${prefix.substring(1)}';
        final statusScheme = status[palette]!;
        final tokens = request.contract.tokens;
        values[tokens['colors.$prefix']!] = AuroraColor(statusScheme.primary);
        values[tokens['colors.on$cap']!] = AuroraColor(statusScheme.onPrimary);
        values[tokens['colors.${prefix}Container']!] =
            AuroraColor(statusScheme.primaryContainer);
        values[tokens['colors.on${cap}Container']!] =
            AuroraColor(statusScheme.onPrimaryContainer);
      }
      values.addAll(request.values);
      values.addAll(request.variantValues[appearance] ?? {});
      final palettes = <AuroraPalette, TonalPalette>{
        AuroraPalette.primary: primaryScheme.primaryPalette,
        AuroraPalette.secondary: primaryScheme.secondaryPalette,
        AuroraPalette.tertiary: primaryScheme.tertiaryPalette,
        AuroraPalette.neutral: primaryScheme.neutralPalette,
        AuroraPalette.neutralVariant: primaryScheme.neutralVariantPalette,
        AuroraPalette.error: primaryScheme.errorPalette,
        for (final entry in status.entries)
          entry.key: entry.value.primaryPalette,
      };
      final visiting = <AuroraColorToken>{};
      final issues = <String>[];
      AuroraColor? resolve(AuroraColorToken token) {
        if (values.containsKey(token)) return values[token]!;
        if (!visiting.add(token)) {
          throw AuroraValidationException(
              ['Cyclic generation rule at ${token.path} (${appearance.name})']);
        }
        final rule = request.rules[token];
        final AuroraColor? color = switch (rule) {
          AuroraAliasRule(:final target) => resolve(target),
          AuroraToneRule(:final palette, :final lightTone, :final darkTone) =>
            _toneColor(palettes[palette]!,
                appearance == AuroraAppearance.light ? lightTone : darkTone),
          null => null,
        };
        visiting.remove(token);
        if (color != null) values[token] = color;
        return color;
      }

      for (final token in request.contract.tokens.values) {
        if (resolve(token) == null)
          issues.add(
              'Missing value or generation rule for ${token.path} (${appearance.name})');
      }
      if (issues.isNotEmpty) throw AuroraValidationException(issues);
      final variant = AuroraThemeVariant(
          contract: request.contract, appearance: appearance, values: values);
      variants.add(variant);
      checks.addAll(AuroraContrast.check(variant,
          additionalPairs: request.contrastPairs));
    }
    return AuroraGenerationResult._(
        AuroraTheme(
            id: request.id,
            name: request.name,
            variants: variants,
            preferredAppearance: request.preferredAppearance),
        checks);
  }

  static AuroraColor _toneColor(TonalPalette palette, double tone) =>
      AuroraColor(Hct.from(palette.hue, palette.chroma, tone).toInt());

  static DynamicScheme _scheme(AuroraColor seed, AuroraAppearance appearance) =>
      SchemeTonalSpot(
        sourceColorHct: Hct.fromInt(seed.argb),
        isDark: appearance == AuroraAppearance.dark,
        contrastLevel: 0,
      );
}
