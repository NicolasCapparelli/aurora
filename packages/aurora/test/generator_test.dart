import 'dart:convert';
import 'package:aurora/aurora.dart';
import 'package:test/test.dart';

const ticket =
    AuroraColorToken('theater.ticket', description: 'Ticket background.');
const onTicket =
    AuroraColorToken('theater.onTicket', description: 'Ticket text.');

void main() {
  final basic = AuroraContract(id: 'basic');
  final theater = AuroraContract(id: 'theater', extensions: [ticket, onTicket]);
  final primary = AuroraColor.hex('#246b35');
  AuroraGenerationRequest request(
          {String seed = '#246b35',
          AuroraColor? secondary,
          AuroraColor? tertiary}) =>
      AuroraGenerationRequest(
          contract: basic,
          id: 'generated',
          name: 'Generated',
          primary: AuroraColor.hex(seed),
          secondary: secondary,
          tertiary: tertiary);

  test('generates complete validated light and dark variants deterministically',
      () {
    final first = AuroraGenerator.generate(request());
    final second = AuroraGenerator.generate(request());
    expect(jsonEncode(first.toJson()), jsonEncode(second.toJson()));
    expect(first.algorithm, AuroraGenerator.algorithm);
    expect(first.theme.variants.keys, AuroraAppearance.values);
    for (final variant in first.theme.variants.values) {
      expect(variant.values.length, 58);
      expect(
          variant.values.values.every((value) => value.alpha == 255), isTrue);
      expect(
          AuroraDtcg.decode(AuroraDtcg.encode(variant),
                  contract: basic, appearance: variant.appearance)
              .values,
          variant.values);
    }
    expect(first.theme.variants[AuroraAppearance.light]!.tokens.primary,
        isNot(first.theme.variants[AuroraAppearance.dark]!.tokens.primary));
    expect(() => first.checks.clear(), throwsUnsupportedError);
    expect(() => first.theme.variants.clear(), throwsUnsupportedError);
  });

  test('generated fixed roles agree across appearances', () {
    final result = AuroraGenerator.generate(request());
    for (final token in AuroraFoundation.tokens
        .where((token) => token.path.contains('Fixed'))) {
      expect(result.theme.variants[AuroraAppearance.light]!.read(token),
          result.theme.variants[AuroraAppearance.dark]!.read(token));
    }
  });

  test('optional accent seeds influence only their corresponding families', () {
    final baseline = AuroraGenerator.generate(request())
        .theme
        .variants[AuroraAppearance.light]!;
    final custom = AuroraGenerator.generate(request(
            secondary: AuroraColor.hex('#b3261e'),
            tertiary: AuroraColor.hex('#0061a4')))
        .theme
        .variants[AuroraAppearance.light]!;
    expect(custom.tokens.primary, baseline.tokens.primary);
    expect(custom.tokens.surface, baseline.tokens.surface);
    expect(custom.tokens.secondary, isNot(baseline.tokens.secondary));
    expect(custom.tokens.tertiary, isNot(baseline.tokens.tertiary));
    expect(custom.tokens.error, baseline.tokens.error);
    expect(custom.tokens.success, baseline.tokens.success);
  });

  test('extreme seeds still generate complete themes with passing known pairs',
      () {
    for (final seed in [
      '#000000',
      '#ffffff',
      '#ff0000',
      '#00ff00',
      '#0000ff',
      '#ffff00',
      '#808080'
    ]) {
      final result = AuroraGenerator.generate(request(seed: seed));
      expect(result.issues, isEmpty,
          reason: '$seed: ${result.issues.map((issue) => issue.toJson())}');
    }
  });

  test('status seeds are explicit and independent from the brand seed', () {
    final baseline = AuroraGenerator.generate(request())
        .theme
        .variants[AuroraAppearance.light]!;
    final changed = AuroraGenerator.generate(AuroraGenerationRequest(
            contract: basic,
            id: 'a',
            name: 'A',
            primary: primary,
            success: AuroraColor.hex('#0061a4')))
        .theme
        .variants[AuroraAppearance.light]!;
    expect(changed.tokens.success, isNot(baseline.tokens.success));
    expect(changed.tokens.primary, baseline.tokens.primary);
    expect(changed.tokens.warning, baseline.tokens.warning);
  });

  test('can request only dark and never creates an unrequested variant', () {
    final result = AuroraGenerator.generate(AuroraGenerationRequest(
        contract: basic,
        id: 'dark',
        name: 'Dark',
        primary: primary,
        appearances: [AuroraAppearance.dark],
        preferredAppearance: AuroraAppearance.dark));
    expect(result.theme.variants.keys, [AuroraAppearance.dark]);
    expect(
        result.checks
            .every((check) => check.appearance == AuroraAppearance.dark),
        isTrue);
  });

  test(
      'app tokens require values or explicit rules for every requested appearance',
      () {
    expect(
        () => AuroraGenerator.generate(AuroraGenerationRequest(
            contract: theater, id: 'a', name: 'A', primary: primary)),
        throwsA(isA<AuroraValidationException>()));
    expect(
        () => AuroraGenerator.generate(AuroraGenerationRequest(
                contract: theater,
                id: 'a',
                name: 'A',
                primary: primary,
                variantValues: {
                  AuroraAppearance.light: {ticket: primary, onTicket: primary}
                })),
        throwsA(isA<AuroraValidationException>()));
  });

  test('aliases follow final overrides and tone rules are appearance-aware',
      () {
    final explicit = AuroraColor.hex('#123456');
    final result = AuroraGenerator.generate(AuroraGenerationRequest(
        contract: theater,
        id: 'a',
        name: 'A',
        primary: primary,
        values: {
          AuroraFoundation.primaryContainer: explicit
        },
        rules: {
          ticket: const AuroraAliasRule(AuroraFoundation.primaryContainer),
          onTicket: AuroraToneRule(
              palette: AuroraPalette.neutral, lightTone: 0, darkTone: 100),
        }));
    expect(
        result.theme.variants[AuroraAppearance.light]!.read(ticket), explicit);
    expect(
        result.theme.variants[AuroraAppearance.dark]!.read(ticket), explicit);
    expect(result.theme.variants[AuroraAppearance.light]!.read(onTicket),
        AuroraColor.hex('#000000'));
    expect(result.theme.variants[AuroraAppearance.dark]!.read(onTicket),
        AuroraColor.hex('#ffffff'));
  });

  test('per-variant values win over shared values and rules', () {
    final shared = AuroraColor.hex('#111111');
    final dark = AuroraColor.hex('#222222');
    final result = AuroraGenerator.generate(AuroraGenerationRequest(
        contract: theater,
        id: 'a',
        name: 'A',
        primary: primary,
        values: {
          ticket: shared,
          onTicket: shared
        },
        variantValues: {
          AuroraAppearance.dark: {ticket: dark}
        },
        rules: {
          ticket: const AuroraAliasRule(AuroraFoundation.primary)
        }));
    expect(result.theme.variants[AuroraAppearance.light]!.read(ticket), shared);
    expect(result.theme.variants[AuroraAppearance.dark]!.read(ticket), dark);
  });

  test('cycles are rejected; a supplied value may deliberately break a cycle',
      () {
    final rules = {
      ticket: const AuroraAliasRule(onTicket),
      onTicket: const AuroraAliasRule(ticket)
    };
    expect(
        () => AuroraGenerator.generate(AuroraGenerationRequest(
            contract: theater,
            id: 'a',
            name: 'A',
            primary: primary,
            rules: rules)),
        throwsA(isA<AuroraValidationException>()));
    final result = AuroraGenerator.generate(AuroraGenerationRequest(
        contract: theater,
        id: 'a',
        name: 'A',
        primary: primary,
        rules: rules,
        values: {ticket: primary}));
    expect(
        result.theme.variants[AuroraAppearance.light]!.read(onTicket), primary);
  });

  test(
      'overrides are preserved and low contrast is reported rather than repaired',
      () {
    final white = AuroraColor.hex('#ffffff');
    final result = AuroraGenerator.generate(AuroraGenerationRequest(
        contract: basic,
        id: 'a',
        name: 'A',
        primary: primary,
        values: {
          AuroraFoundation.primary: white,
          AuroraFoundation.onPrimary: white
        }));
    expect(
        result.theme.variants[AuroraAppearance.light]!.tokens.primary, white);
    final failed = result.issues
        .where((issue) => issue.pair.foreground == AuroraFoundation.onPrimary);
    expect(failed.length, 2);
    expect(
        failed.every((issue) =>
            issue.status == AuroraContrastStatus.fail && issue.ratio == 1),
        isTrue);
  });

  test('custom extension pairs are checked, including translucent backgrounds',
      () {
    final result = AuroraGenerator.generate(AuroraGenerationRequest(
        contract: theater,
        id: 'a',
        name: 'A',
        primary: primary,
        values: {
          ticket: AuroraColor.hex('#12345678'),
          onTicket: primary
        },
        contrastPairs: [
          AuroraContrastPair(foreground: onTicket, background: ticket)
        ]));
    final custom = result.issues
        .where((issue) => issue.pair.background == ticket)
        .toList();
    expect(custom.length, 2);
    expect(
        custom.every((issue) => issue.status == AuroraContrastStatus.unknown),
        isTrue);
    expect(custom.first.toJson()['reason'], 'transparentBackground');
  });

  test('request defensively copies maps, nested maps, lists, and rules', () {
    final values = {ticket: primary, onTicket: primary};
    final dark = {ticket: AuroraColor.hex('#123456')};
    final variants = {AuroraAppearance.dark: dark};
    final appearances = [AuroraAppearance.dark, AuroraAppearance.light];
    final rules = <AuroraColorToken, AuroraTokenRule>{};
    final input = AuroraGenerationRequest(
        contract: theater,
        id: 'a',
        name: 'A',
        primary: primary,
        values: values,
        variantValues: variants,
        appearances: appearances,
        rules: rules);
    values.clear();
    dark.clear();
    variants.clear();
    appearances.clear();
    rules[ticket] = const AuroraAliasRule(onTicket);
    expect(input.appearances, AuroraAppearance.values);
    expect(input.values.length, 2);
    expect(input.rules, isEmpty);
    expect(() => input.variantValues[AuroraAppearance.dark]!.clear(),
        throwsUnsupportedError);
    expect(
        AuroraGenerator.generate(input)
            .theme
            .variants[AuroraAppearance.dark]!
            .read(ticket),
        AuroraColor.hex('#123456'));
  });

  test('rejects ambiguous or invalid inputs before generation', () {
    expect(() => request(seed: '#12345678'), throwsArgumentError);
    expect(
        () => AuroraGenerationRequest(
            contract: basic, id: '', name: 'A', primary: primary),
        throwsArgumentError);
    for (final appearances in [
      <AuroraAppearance>[],
      [AuroraAppearance.light, AuroraAppearance.light],
      [AuroraAppearance.dark]
    ]) {
      expect(
          () => AuroraGenerationRequest(
              contract: basic,
              id: 'a',
              name: 'A',
              primary: primary,
              appearances: appearances),
          throwsArgumentError);
    }
    expect(
        () => AuroraGenerationRequest(
            contract: basic,
            id: 'a',
            name: 'A',
            primary: primary,
            values: {ticket: primary}),
        throwsArgumentError);
    expect(
        () => AuroraGenerationRequest(
                contract: basic,
                id: 'a',
                name: 'A',
                primary: primary,
                rules: {
                  AuroraFoundation.primary:
                      const AuroraAliasRule(AuroraFoundation.secondary)
                }),
        throwsArgumentError);
    expect(
        () => AuroraGenerationRequest(
                contract: theater,
                id: 'a',
                name: 'A',
                primary: primary,
                rules: {
                  ticket: const AuroraAliasRule(
                      AuroraColorToken('unknown', description: 'Unknown'))
                }),
        throwsArgumentError);
    expect(
        () => AuroraGenerationRequest(
            contract: basic,
            id: 'a',
            name: 'A',
            primary: primary,
            appearances: [AuroraAppearance.light],
            variantValues: {AuroraAppearance.dark: {}}),
        throwsArgumentError);
    for (final tone in [-1.0, 101.0, double.nan, double.infinity]) {
      expect(
          () => AuroraToneRule(
              palette: AuroraPalette.primary, lightTone: tone, darkTone: 50),
          throwsArgumentError);
    }
  });

  group('contrast math', () {
    test(
        'black/white is 21, identical is 1, and order is symmetric for opaque colors',
        () {
      final black = AuroraColor.hex('#000000');
      final white = AuroraColor.hex('#ffffff');
      expect(AuroraContrast.ratio(black, white), closeTo(21, 1e-10));
      expect(AuroraContrast.ratio(white, black), closeTo(21, 1e-10));
      expect(AuroraContrast.ratio(white, white), 1);
    });
    test('foreground alpha is composited; unknown backplates are never assumed',
        () {
      final white = AuroraColor.hex('#ffffff');
      expect(AuroraContrast.ratio(AuroraColor.hex('#00000000'), white), 1);
      expect(AuroraContrast.ratio(AuroraColor.hex('#00000080'), white),
          closeTo(4.004, 0.01));
      expect(AuroraContrast.ratio(white, AuroraColor.hex('#00000080')), isNull);
    });
    test('custom thresholds and token membership are validated', () {
      expect(
          () => AuroraContrastPair(
              foreground: ticket,
              background: onTicket,
              minimumRatio: double.nan),
          throwsArgumentError);
      expect(
          () => AuroraGenerationRequest(
                  contract: basic,
                  id: 'a',
                  name: 'A',
                  primary: primary,
                  contrastPairs: [
                    AuroraContrastPair(foreground: ticket, background: onTicket)
                  ]),
          throwsArgumentError);
    });
  });
}
