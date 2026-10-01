import 'color.dart';
import 'contract.dart';
import 'foundation.dart';

enum AuroraAppearance { light, dark }

enum AuroraAppearancePreference {
  light,
  dark,
  system;

  /// Exact portable names; unknown values return null for caller-owned fallback.
  static AuroraAppearancePreference? tryParse(String? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }
}

/// Complete, validated values for a single concrete appearance.
final class AuroraThemeVariant {
  factory AuroraThemeVariant({
    required AuroraContract contract,
    required AuroraAppearance appearance,
    required Map<AuroraColorToken, Object?> values,
  }) {
    final issues = <String>[];
    for (final token in contract.tokens.values) {
      if (!values.containsKey(token)) {
        issues.add('Missing required token ${token.path}');
      } else if (values[token] is! AuroraColor) {
        issues.add('${token.path} must be an AuroraColor');
      }
    }
    for (final token in values.keys) {
      if (!contract.contains(token))
        issues.add('Undeclared token ${token.path}');
    }
    if (issues.isNotEmpty) throw AuroraValidationException(issues);
    return AuroraThemeVariant._(
        contract,
        appearance,
        Map.unmodifiable(
            values.map((key, value) => MapEntry(key, value as AuroraColor))));
  }

  AuroraThemeVariant._(this.contract, this.appearance, this.values);
  final AuroraContract contract;
  final AuroraAppearance appearance;
  final Map<AuroraColorToken, AuroraColor> values;

  AuroraColor read(AuroraColorToken token) {
    if (!contract.contains(token))
      throw ArgumentError('Token ${token.path} is not in this contract');
    return values[token]!;
  }

  /// Direct immutable token values, usable without any framework integration.
  AuroraTokens get tokens => AuroraTokens(this);

  /// Convenience alias for color-focused consumers.
  AuroraTokens get colors => tokens;
}

/// Identity plus available complete variants, all using the same app contract.
final class AuroraTheme {
  factory AuroraTheme({
    required String id,
    required String name,
    required Iterable<AuroraThemeVariant> variants,
    required AuroraAppearance preferredAppearance,
  }) {
    if (id.trim().isEmpty || name.trim().isEmpty)
      throw ArgumentError('Theme id and name cannot be empty');
    final byAppearance = <AuroraAppearance, AuroraThemeVariant>{};
    AuroraContract? contract;
    for (final variant in variants) {
      contract ??= variant.contract;
      if (!identical(contract, variant.contract))
        throw ArgumentError('Variants must use the same contract instance');
      if (byAppearance.containsKey(variant.appearance))
        throw ArgumentError('Duplicate ${variant.appearance.name} variant');
      byAppearance[variant.appearance] = variant;
    }
    if (!byAppearance.containsKey(preferredAppearance))
      throw ArgumentError('Preferred appearance must have a variant');
    return AuroraTheme._(id, name, contract!, Map.unmodifiable(byAppearance),
        preferredAppearance);
  }

  AuroraTheme._(this.id, this.name, this.contract, this.variants,
      this.preferredAppearance);
  final String id;
  final String name;
  final AuroraContract contract;
  final Map<AuroraAppearance, AuroraThemeVariant> variants;
  final AuroraAppearance preferredAppearance;
}
