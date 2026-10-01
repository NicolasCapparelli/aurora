import 'package:aurora_flutter/aurora_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every supported role matches Flutter fromSeed for every scheme', () {
    for (final seed in [
      const Color(0xff246b35),
      const Color(0xffe60023),
      const Color(0xff808080)
    ]) {
      for (final scheme in AuroraGenerationScheme.values) {
        final variants =
            AuroraGenerator.variants(seed.auroraColor, scheme: scheme);
        for (final appearance in AuroraAppearance.values) {
          final actual = variants[appearance]!.toColorScheme();
          final expected = ColorScheme.fromSeed(
              seedColor: seed,
              brightness: appearance.brightness,
              dynamicSchemeVariant:
                  DynamicSchemeVariant.values.byName(scheme.name));
          expect(actual.primary, expected.primary,
              reason: '${scheme.name} $appearance $seed primary');
          expect(actual.onPrimary, expected.onPrimary,
              reason: '${scheme.name} $appearance $seed onPrimary');
          expect(actual.primaryContainer, expected.primaryContainer,
              reason: '${scheme.name} $appearance $seed primaryContainer');
          expect(actual.onPrimaryContainer, expected.onPrimaryContainer,
              reason: '${scheme.name} $appearance $seed onPrimaryContainer');
          expect(actual.primaryFixed, expected.primaryFixed,
              reason: '${scheme.name} $appearance $seed primaryFixed');
          expect(actual.primaryFixedDim, expected.primaryFixedDim,
              reason: '${scheme.name} $appearance $seed primaryFixedDim');
          expect(actual.onPrimaryFixed, expected.onPrimaryFixed,
              reason: '${scheme.name} $appearance $seed onPrimaryFixed');
          expect(actual.onPrimaryFixedVariant, expected.onPrimaryFixedVariant,
              reason: '${scheme.name} $appearance $seed onPrimaryFixedVariant');
          expect(actual.secondary, expected.secondary,
              reason: '${scheme.name} $appearance $seed secondary');
          expect(actual.onSecondary, expected.onSecondary,
              reason: '${scheme.name} $appearance $seed onSecondary');
          expect(actual.secondaryContainer, expected.secondaryContainer,
              reason: '${scheme.name} $appearance $seed secondaryContainer');
          expect(actual.onSecondaryContainer, expected.onSecondaryContainer,
              reason: '${scheme.name} $appearance $seed onSecondaryContainer');
          expect(actual.secondaryFixed, expected.secondaryFixed,
              reason: '${scheme.name} $appearance $seed secondaryFixed');
          expect(actual.secondaryFixedDim, expected.secondaryFixedDim,
              reason: '${scheme.name} $appearance $seed secondaryFixedDim');
          expect(actual.onSecondaryFixed, expected.onSecondaryFixed,
              reason: '${scheme.name} $appearance $seed onSecondaryFixed');
          expect(
              actual.onSecondaryFixedVariant, expected.onSecondaryFixedVariant,
              reason:
                  '${scheme.name} $appearance $seed onSecondaryFixedVariant');
          expect(actual.tertiary, expected.tertiary,
              reason: '${scheme.name} $appearance $seed tertiary');
          expect(actual.onTertiary, expected.onTertiary,
              reason: '${scheme.name} $appearance $seed onTertiary');
          expect(actual.tertiaryContainer, expected.tertiaryContainer,
              reason: '${scheme.name} $appearance $seed tertiaryContainer');
          expect(actual.onTertiaryContainer, expected.onTertiaryContainer,
              reason: '${scheme.name} $appearance $seed onTertiaryContainer');
          expect(actual.tertiaryFixed, expected.tertiaryFixed,
              reason: '${scheme.name} $appearance $seed tertiaryFixed');
          expect(actual.tertiaryFixedDim, expected.tertiaryFixedDim,
              reason: '${scheme.name} $appearance $seed tertiaryFixedDim');
          expect(actual.onTertiaryFixed, expected.onTertiaryFixed,
              reason: '${scheme.name} $appearance $seed onTertiaryFixed');
          expect(actual.onTertiaryFixedVariant, expected.onTertiaryFixedVariant,
              reason:
                  '${scheme.name} $appearance $seed onTertiaryFixedVariant');
          expect(actual.error, expected.error,
              reason: '${scheme.name} $appearance $seed error');
          expect(actual.onError, expected.onError,
              reason: '${scheme.name} $appearance $seed onError');
          expect(actual.errorContainer, expected.errorContainer,
              reason: '${scheme.name} $appearance $seed errorContainer');
          expect(actual.onErrorContainer, expected.onErrorContainer,
              reason: '${scheme.name} $appearance $seed onErrorContainer');
          expect(actual.surface, expected.surface,
              reason: '${scheme.name} $appearance $seed surface');
          expect(actual.onSurface, expected.onSurface,
              reason: '${scheme.name} $appearance $seed onSurface');
          expect(actual.surfaceDim, expected.surfaceDim,
              reason: '${scheme.name} $appearance $seed surfaceDim');
          expect(actual.surfaceBright, expected.surfaceBright,
              reason: '${scheme.name} $appearance $seed surfaceBright');
          expect(actual.surfaceContainerLowest, expected.surfaceContainerLowest,
              reason:
                  '${scheme.name} $appearance $seed surfaceContainerLowest');
          expect(actual.surfaceContainerLow, expected.surfaceContainerLow,
              reason: '${scheme.name} $appearance $seed surfaceContainerLow');
          expect(actual.surfaceContainer, expected.surfaceContainer,
              reason: '${scheme.name} $appearance $seed surfaceContainer');
          expect(actual.surfaceContainerHigh, expected.surfaceContainerHigh,
              reason: '${scheme.name} $appearance $seed surfaceContainerHigh');
          expect(
              actual.surfaceContainerHighest, expected.surfaceContainerHighest,
              reason:
                  '${scheme.name} $appearance $seed surfaceContainerHighest');
          expect(actual.onSurfaceVariant, expected.onSurfaceVariant,
              reason: '${scheme.name} $appearance $seed onSurfaceVariant');
          expect(actual.outline, expected.outline,
              reason: '${scheme.name} $appearance $seed outline');
          expect(actual.outlineVariant, expected.outlineVariant,
              reason: '${scheme.name} $appearance $seed outlineVariant');
          expect(actual.shadow, expected.shadow,
              reason: '${scheme.name} $appearance $seed shadow');
          expect(actual.scrim, expected.scrim,
              reason: '${scheme.name} $appearance $seed scrim');
          expect(actual.inverseSurface, expected.inverseSurface,
              reason: '${scheme.name} $appearance $seed inverseSurface');
          expect(actual.onInverseSurface, expected.onInverseSurface,
              reason: '${scheme.name} $appearance $seed onInverseSurface');
          expect(actual.inversePrimary, expected.inversePrimary,
              reason: '${scheme.name} $appearance $seed inversePrimary');
          expect(actual.surfaceTint, expected.surfaceTint,
              reason: '${scheme.name} $appearance $seed surfaceTint');
        }
      }
    }
  });
}
