import 'dart:convert';
import 'package:aurora/aurora.dart';
import 'package:test/test.dart';

const ticket =
    AuroraColorToken('theater.ticket', description: 'Ticket background.');

AuroraTheme theme(AuroraContract contract,
        {String id = 'wicked', bool dark = true}) =>
    AuroraTheme(
      id: id,
      name: id,
      preferredAppearance: AuroraAppearance.light,
      variants: [
        for (final appearance in AuroraAppearance.values)
          if (dark || appearance == AuroraAppearance.light)
            AuroraStarter.variant(
                contract: contract,
                appearance: appearance,
                values: contract.contains(ticket)
                    ? {ticket: AuroraColor.hex('#123456')}
                    : {}),
      ],
    );

void main() {
  group('color', () {
    test('CSS alpha order and ARGB round trip', () {
      final color = AuroraColor.hex('#12345678');
      expect(color.argb, 0x78123456);
      expect(color.hex, '#12345678');
      expect(AuroraColor(color.argb), color);
      expect(AuroraColor.hex('#ffffff').alpha, 255);
    });
    test('rejects malformed hex and out-of-range values', () {
      for (final value in ['ffffff', '#fff', '#zz1234', '#123456789']) {
        expect(() => AuroraColor.hex(value), throwsFormatException);
      }
      expect(() => AuroraColor(-1), throwsArgumentError);
      expect(() => AuroraColor(0x100000000), throwsArgumentError);
    });
  });

  group('contract and completeness', () {
    test('all Material and status roles are required and immutable', () {
      final contract = AuroraContract(id: 'app');
      expect(contract.tokens.length, 58);
      expect(contract.contains(AuroraFoundation.infoContainer), isTrue);
      expect(() => contract.tokens.clear(), throwsUnsupportedError);
      expect(() => AuroraFoundation.tokens.clear(), throwsUnsupportedError);
      expect(() => AuroraStarter.light.clear(), throwsUnsupportedError);
    });
    test('cannot redefine foundation, reserve its namespace, or collide paths',
        () {
      for (final additions in [
        [const AuroraColorToken('colors.primary', description: 'Replacement')],
        [const AuroraColorToken('colors.custom', description: 'Reserved')],
        [ticket, ticket],
        [
          ticket,
          const AuroraColorToken('theater.ticket.text',
              description: 'Collision')
        ],
        [const AuroraColorToken('bad.path-name', description: 'Bad path')],
        [const AuroraColorToken('blank', description: '')],
      ]) {
        expect(() => AuroraContract(id: 'app', extensions: additions),
            throwsArgumentError);
      }
    });
    test(
        'missing extension, wrong type and unknown fields are reported together',
        () {
      final contract = AuroraContract(id: 'app', extensions: [ticket]);
      final values = <AuroraColorToken, Object?>{...AuroraStarter.light};
      values[AuroraFoundation.primary] = 'green';
      values[const AuroraColorToken('other.value', description: 'Unknown')] =
          AuroraColor.hex('#000000');
      expect(
          () => AuroraThemeVariant(
              contract: contract,
              appearance: AuroraAppearance.light,
              values: values),
          throwsA(isA<AuroraValidationException>()
              .having((e) => e.issues.length, 'issue count', 3)));
    });
    test('presets never silently fill app extensions', () {
      final contract = AuroraContract(id: 'app', extensions: [ticket]);
      expect(
          () => AuroraStarter.variant(
              contract: contract, appearance: AuroraAppearance.light),
          throwsA(isA<AuroraValidationException>()));
    });
    test('variant copies inputs and supports typed reads', () {
      final contract = AuroraContract(id: 'app', extensions: [ticket]);
      final values = {
        ...AuroraStarter.light,
        ticket: AuroraColor.hex('#123456')
      };
      final variant = AuroraThemeVariant(
          contract: contract,
          appearance: AuroraAppearance.light,
          values: values);
      values.clear();
      expect(variant.read(ticket), AuroraColor.hex('#123456'));
      expect(variant.colors.primary,
          AuroraStarter.light[AuroraFoundation.primary]);
      expect(() => variant.values.clear(), throwsUnsupportedError);
      expect(
          () => variant.read(const AuroraColorToken('theater.ticket',
              description: 'Impostor')),
          throwsArgumentError);
    });
    test(
        'themes reject duplicates, mixed contracts, and unavailable preferred variants',
        () {
      final contract = AuroraContract(id: 'app');
      final light = AuroraStarter.variant(
          contract: contract, appearance: AuroraAppearance.light);
      expect(
          () => AuroraTheme(
              id: 'a',
              name: 'A',
              variants: [light, light],
              preferredAppearance: AuroraAppearance.light),
          throwsArgumentError);
      expect(
          () => AuroraTheme(
              id: 'a',
              name: 'A',
              variants: [],
              preferredAppearance: AuroraAppearance.light),
          throwsArgumentError);
      expect(
          () => AuroraTheme(
              id: 'a',
              name: 'A',
              variants: [light],
              preferredAppearance: AuroraAppearance.dark),
          throwsArgumentError);
      final dark = AuroraStarter.variant(
          contract: AuroraContract(id: 'other'),
          appearance: AuroraAppearance.dark);
      expect(
          () => AuroraTheme(
              id: 'a',
              name: 'A',
              variants: [light, dark],
              preferredAppearance: AuroraAppearance.light),
          throwsArgumentError);
    });
  });

  group('selection', () {
    late AuroraContract contract;
    late AuroraRuntime engine;
    setUp(() {
      contract = AuroraContract(id: 'app');
      engine = AuroraRuntime(
          contract: contract,
          themes: [
            theme(contract),
            theme(contract, id: 'lightOnly', dark: false)
          ],
          initialSelection: const AuroraSelection(themeId: 'wicked'),
          fallback: AuroraVariantFallback.reject);
    });
    tearDown(() => engine.dispose());
    test(
        'device appearance preserves identity and notifies once per effective change',
        () async {
      final events = <AuroraState>[];
      final sub = engine.changes.listen(events.add);
      engine.setSystemAppearance(AuroraAppearance.dark);
      engine.setSystemAppearance(AuroraAppearance.dark);
      await Future<void>.delayed(Duration.zero);
      expect(engine.state.selection.themeId, 'wicked');
      expect(engine.state.variant.appearance, AuroraAppearance.dark);
      expect(events.length, 1);
      await sub.cancel();
    });
    test('direct tokens remain a snapshot when the runtime switches variants',
        () {
      final tokens = engine.state.variant.tokens;
      final primary = tokens.primary;
      engine.setSystemAppearance(AuroraAppearance.dark);
      expect(tokens.primary, primary);
      expect(tokens.primary, isNot(engine.state.variant.tokens.primary));
    });
    test('rejected selection preserves active state', () {
      final previous = engine.state;
      expect(
          () => engine.select(const AuroraSelection(
              themeId: 'lightOnly',
              appearance: AuroraAppearancePreference.dark)),
          throwsStateError);
      expect(engine.state, same(previous));
      expect(() => engine.select(const AuroraSelection(themeId: 'unknown')),
          throwsArgumentError);
      expect(engine.state, same(previous));
    });
    test('rejected system changes do not commit device appearance', () {
      engine.select(const AuroraSelection(themeId: 'lightOnly'));
      expect(() => engine.setSystemAppearance(AuroraAppearance.dark),
          throwsStateError);
      engine.select(const AuroraSelection(themeId: 'wicked'));
      expect(engine.state.variant.appearance, AuroraAppearance.light);
    });
    test('preferred fallback retains requested preference', () async {
      final fallbackEngine = AuroraRuntime(
          contract: contract,
          themes: [theme(contract, dark: false)],
          initialSelection: const AuroraSelection(
              themeId: 'wicked', appearance: AuroraAppearancePreference.dark),
          fallback: AuroraVariantFallback.preferred);
      expect(fallbackEngine.state.variant.appearance, AuroraAppearance.light);
      expect(fallbackEngine.state.selection.appearance,
          AuroraAppearancePreference.dark);
      await fallbackEngine.dispose();
    });
    test('fixed appearance ignores device changes', () {
      engine.select(const AuroraSelection(
          themeId: 'wicked', appearance: AuroraAppearancePreference.light));
      engine.setSystemAppearance(AuroraAppearance.dark);
      expect(engine.state.variant.appearance, AuroraAppearance.light);
    });
    test('listeners may trigger a subsequent selection safely', () async {
      final done = engine.changes
          .firstWhere((event) => event.selection.themeId == 'lightOnly');
      final subscription = engine.changes.listen((state) {
        if (state.variant.appearance == AuroraAppearance.dark) {
          engine.select(const AuroraSelection(
              themeId: 'lightOnly',
              appearance: AuroraAppearancePreference.light));
        }
      });
      engine.setSystemAppearance(AuroraAppearance.dark);
      await done;
      expect(engine.state.selection.themeId, 'lightOnly');
      await subscription.cancel();
    });
    test('disposed engines reject writes', () async {
      await engine.dispose();
      expect(() => engine.select(const AuroraSelection(themeId: 'wicked')),
          throwsStateError);
    });
    test('registry rejects duplicate ids and foreign contracts', () {
      expect(
          () => AuroraRuntime(
              contract: contract,
              themes: [theme(contract), theme(contract)],
              initialSelection: const AuroraSelection(themeId: 'wicked'),
              fallback: AuroraVariantFallback.reject),
          throwsArgumentError);
      expect(
          () => AuroraRuntime(
              contract: contract,
              themes: [theme(AuroraContract(id: 'other'))],
              initialSelection: const AuroraSelection(themeId: 'wicked'),
              fallback: AuroraVariantFallback.reject),
          throwsArgumentError);
    });
  });

  group('DTCG profile', () {
    final contract = AuroraContract(id: 'theater', extensions: [ticket]);
    late Map<String, Object?> document;
    setUp(() {
      final variant = AuroraStarter.variant(
          contract: contract,
          appearance: AuroraAppearance.light,
          values: {ticket: AuroraColor.hex('#12345678')});
      document = jsonDecode(jsonEncode(AuroraDtcg.encode(variant)))
          as Map<String, Object?>;
    });
    AuroraThemeVariant decode() => AuroraDtcg.decode(document,
        contract: contract, appearance: AuroraAppearance.light);
    Map<String, Object?> colors() => document['colors'] as Map<String, Object?>;
    Map<String, Object?> primary() =>
        colors()['primary'] as Map<String, Object?>;
    test('JSON round trip preserves all values including transparency', () {
      expect(decode().read(ticket), AuroraColor.hex('#12345678'));
      for (final token in AuroraFoundation.tokens) {
        expect(decode().read(token), AuroraStarter.light[token]);
      }
    });
    test('inherited color type works', () {
      primary().remove(r'$type');
      colors()[r'$type'] = 'color';
      expect(decode().colors.primary,
          AuroraStarter.light[AuroraFoundation.primary]);
    });
    test('whole-token aliases derive their type from their target', () {
      primary().remove(r'$type');
      primary()[r'$value'] = '{colors.secondary}';
      expect(decode().colors.primary, decode().colors.secondary);
    });
    test('cycles and nonexistent targets are rejected', () {
      primary()[r'$value'] = '{colors.primary}';
      expect(decode, throwsFormatException);
      primary()[r'$value'] = '{colors.nonexistent}';
      expect(decode, throwsFormatException);
    });
    test('reports missing and undeclared tokens', () {
      colors().remove('primary');
      colors()['unknown'] = colors()['secondary'];
      expect(
          decode,
          throwsA(isA<AuroraValidationException>()
              .having((e) => e.issues.length, 'issues', 2)));
    });
    test('rejects unsupported color spaces and invalid channels', () {
      final value = primary()[r'$value'] as Map<String, Object?>;
      value['colorSpace'] = 'display-p3';
      expect(decode, throwsFormatException);
      value['colorSpace'] = 'srgb';
      for (final bad in [
        -0.1,
        1.1,
        double.nan,
        double.infinity,
        'none',
        null
      ]) {
        value['components'] = [bad, 0, 0];
        expect(decode, throwsFormatException);
      }
      value['components'] = [0, 0, 0];
      value['alpha'] = 2;
      expect(decode, throwsFormatException);
    });
    test('rejects explicit null alpha and malformed metadata', () {
      final value = primary()[r'$value'] as Map<String, Object?>;
      value['alpha'] = null;
      expect(decode, throwsFormatException);
      value.remove('alpha');
      primary()[r'$description'] = 42;
      expect(decode, throwsFormatException);
      primary().remove(r'$description');
      primary()[r'$type'] = null;
      expect(decode, throwsFormatException);
    });
    test('rejects noncolor types, legacy hex values and unsupported constructs',
        () {
      primary()[r'$type'] = 'number';
      expect(decode, throwsFormatException);
      primary()[r'$type'] = 'color';
      primary()[r'$value'] = '#ffffff';
      expect(decode, throwsFormatException);
      primary()[r'$extends'] = '{colors.secondary}';
      expect(decode, throwsFormatException);
    });
  });
}
