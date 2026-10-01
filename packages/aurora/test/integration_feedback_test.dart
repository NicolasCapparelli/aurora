import 'package:aurora/aurora.dart';
import 'package:aurora/src/tooling/server.dart';
import 'package:test/test.dart';

void main() {
  final seed = AuroraColor.hex('#e60023');
  final contract = AuroraContract(id: 'test');
  AuroraGenerationResult generate(AuroraGenerationScheme scheme) =>
      AuroraGenerator.generate(AuroraGenerationRequest(
          contract: contract,
          id: 'brand',
          name: 'Brand',
          primary: seed,
          scheme: scheme));

  test(
      'per-entity variants are complete immutable snapshots outside app registry',
      () {
    final variants = AuroraGenerator.variants(seed);
    expect(variants.keys, AuroraAppearance.values);
    for (final appearance in AuroraAppearance.values) {
      expect(
          variants[appearance]!.values,
          generate(AuroraGenerationScheme.tonalSpot)
              .theme
              .variants[appearance]!
              .values);
      expect(variants[appearance]!.values.length, 58);
    }
    expect(() => variants.clear(), throwsUnsupportedError);
    expect(() => AuroraGenerator.variants(AuroraColor.hex('#12345680')),
        throwsArgumentError);
  });

  test(
      'all schemes have distinct metadata and keep status palettes independent',
      () {
    final baseline = generate(AuroraGenerationScheme.tonalSpot);
    final identifiers = <String>{};
    for (final scheme in AuroraGenerationScheme.values) {
      final result = generate(scheme);
      identifiers.add(result.algorithm);
      expect(result.toJson()['algorithm'], result.algorithm);
      for (final appearance in AuroraAppearance.values) {
        expect(result.theme.variants[appearance]!.tokens.success,
            baseline.theme.variants[appearance]!.tokens.success);
      }
    }
    expect(identifiers.length, AuroraGenerationScheme.values.length);
    expect(
        generate(AuroraGenerationScheme.fidelity)
            .theme
            .variants[AuroraAppearance.light]!
            .tokens
            .primaryContainer,
        isNot(baseline
            .theme.variants[AuroraAppearance.light]!.tokens.primaryContainer));
  });

  test('recipe and browser accept scheme names and reject unsupported input',
      () {
    final recipe = <String, dynamic>{
      'schemaVersion': 1,
      'id': 'brand',
      'name': 'Brand',
      'primary': seed.hex,
      'scheme': 'fidelity'
    };
    expect(AuroraRecipe.decode(recipe).scheme, AuroraGenerationScheme.fidelity);
    expect(generateToolTheme({...recipe}..remove('schemaVersion')).algorithm,
        generate(AuroraGenerationScheme.fidelity).algorithm);
    for (final invalid in ['unknown', 1, null]) {
      expect(() => AuroraRecipe.decode({...recipe, 'scheme': invalid}),
          throwsFormatException);
    }
  });

  test(
      'selection restoration and strict JSON preserve preference and validate fallback',
      () {
    final themes = [generate(AuroraGenerationScheme.tonalSpot).theme];
    final selection = AuroraSelection.restore(
        themeId: 'retired',
        preference: 'invalid',
        themes: themes,
        fallbackId: 'brand');
    expect(selection.themeId, 'brand');
    expect(selection.appearance, AuroraAppearancePreference.system);
    final malformed = AuroraSelection.restoreJson(
        {'themeId': 12, 'appearance': null},
        themes: themes, fallbackId: 'brand');
    expect(malformed.toJson(), selection.toJson());
    final valid = AuroraSelection.restore(
        themeId: 'brand',
        preference: 'dark',
        themes: themes,
        fallbackId: 'brand');
    expect(AuroraSelection.fromJson(valid.toJson()).appearance,
        AuroraAppearancePreference.dark);
    expect(() => AuroraSelection.restore(themes: themes, fallbackId: 'missing'),
        throwsArgumentError);
    expect(
        () => AuroraSelection.fromJson(
            {'themeId': 'brand', 'appearance': 'invalid'}),
        throwsFormatException);
    expect(() => AuroraSelection.fromJson({'themeId': 3, 'appearance': 'dark'}),
        throwsFormatException);
  });

  test('readable foreground handles alpha, ties, and unknown backgrounds', () {
    final black = AuroraColor.hex('#000000');
    final white = AuroraColor.hex('#ffffff');
    expect(AuroraContrast.bestOn(black, [black, white]), white);
    expect(AuroraContrast.bestOn(white, [white, black]), black);
    expect(AuroraContrast.bestOn(black, [white, white]), white);
    expect(() => AuroraContrast.bestOn(black, []), throwsArgumentError);
    expect(() => AuroraContrast.bestOn(AuroraColor.hex('#ffffff80'), [white]),
        throwsArgumentError);
    expect(AuroraContrast.bestOn(black, [AuroraColor.hex('#ffffff80'), white]),
        white);
  });

  test('debug report includes failed and unknown final-value checks', () {
    final result = AuroraGenerator.generate(AuroraGenerationRequest(
        contract: contract,
        id: 'bad',
        name: 'Bad',
        primary: seed,
        values: {
          AuroraFoundation.primary: AuroraColor.hex('#ffffff'),
          AuroraFoundation.onPrimary: AuroraColor.hex('#ffffff'),
          AuroraFoundation.surface: AuroraColor.hex('#ffffff80'),
        }));
    expect(result.debugReport(),
        contains('colors.onPrimary / colors.primary: fail'));
    expect(result.debugReport(), contains('unknown'));
  });
}
