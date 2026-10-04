import 'dart:convert';
import 'package:aurora/aurora.dart';
import 'package:test/test.dart';

abstract final class Demo {
  static const serif = AuroraFontFamilyToken('demo.type.serif',
      description: 'Serif family for headings.');
  static const heading =
      AuroraTypographyToken('demo.type.heading', description: 'Card headings.');
  static const card = AuroraDimensionToken('demo.shape.card',
      description: 'Card corner radius.');
  static const chip =
      AuroraDimensionToken('demo.shape.chip', description: 'Chip radius.');
  static const elevation =
      AuroraNumberToken('demo.depth.card', description: 'Card elevation.');
  static const divider = AuroraStrokeStyleToken('demo.lines.divider',
      description: 'Divider stroke texture.');
  static const cardBorder =
      AuroraBorderToken('demo.lines.cardBorder', description: 'Card border.');
  static const cardShadow =
      AuroraShadowToken('demo.depth.cardShadow', description: 'Card shadow.');
  static const bordered = AuroraBooleanToken('demo.lines.bordered',
      description: 'Whether cards draw a border.');
  static const layout = AuroraEnumToken('demo.variants.card',
      description: 'Default card layout.', values: ['rich', 'compact']);
  static const fade =
      AuroraDurationToken('demo.motion.fade', description: 'Fade duration.');
  static const ease =
      AuroraCubicBezierToken('demo.motion.ease', description: 'Fade easing.');
  static const weight =
      AuroraFontWeightToken('demo.type.weight', description: 'Heading weight.');

  static const all = <AuroraToken<Object>>[
    serif,
    heading,
    card,
    chip,
    elevation,
    divider,
    cardBorder,
    cardShadow,
    bordered,
    layout,
    fade,
    ease,
    weight,
  ];
}

enum CardLayout { rich, compact }

final contract = AuroraTextureContract(id: 'demo', extensions: Demo.all);

Map<AuroraToken<Object>, Object> demoValues() => {
      Demo.serif: AuroraFontFamily(['Fraunces', 'Georgia', 'serif']),
      Demo.weight: AuroraFontWeight.semiBold,
      Demo.heading: const AuroraTypography(
          fontFamily: AuroraAlias(Demo.serif),
          fontSize: AuroraDimension.dp(20),
          fontWeight: AuroraAlias(Demo.weight),
          letterSpacing: AuroraDimension.dp(0),
          lineHeight: AuroraLiteral(1.3)),
      Demo.card: const AuroraAlias(AuroraTextureFoundation.mediumShape),
      Demo.chip: const AuroraDimension.dp(999),
      Demo.elevation: 1,
      Demo.divider: AuroraStrokeStyle.dashes(
          dashArray: const [AuroraDimension.dp(4), AuroraDimension.dp(2)],
          lineCap: AuroraLineCap.round),
      Demo.cardBorder: const AuroraBorder(
          color: AuroraAlias(AuroraFoundation.outlineVariant),
          width: AuroraDimension.dp(1),
          style: AuroraStrokeStyle.solid),
      Demo.cardShadow: AuroraShadow([
        AuroraShadowLayer(
            color: AuroraColor.hex('#00000033'),
            offsetX: const AuroraDimension.dp(0),
            offsetY: const AuroraDimension.dp(2),
            blur: const AuroraDimension.dp(6),
            spread: const AuroraDimension.dp(0)),
      ]),
      Demo.bordered: true,
      Demo.layout: 'compact',
      Demo.fade: const Duration(milliseconds: 200),
      Demo.ease: const AuroraAlias(AuroraTextureFoundation.easingStandard),
    };

AuroraTexture demoTexture(
        [Map<AuroraToken<Object>, Object> overrides = const {}]) =>
    AuroraTextureStarter.texture(
        contract: contract,
        id: 'soft',
        name: 'Soft',
        values: {...demoValues(), ...overrides});

void main() {
  group('texture contract', () {
    test('includes the texture foundation and extensions', () {
      expect(
          contract.tokens.length, AuroraTextureFoundation.tokens.length + 13);
      expect(AuroraTextureFoundation.tokens.length, 29);
      expect(contract.contains(Demo.card), isTrue);
      expect(
          contract.contains(
              const AuroraDimensionToken('demo.shape.card', description: 'x')),
          isFalse);
    });

    test('rejects colour tokens, reserved namespaces and collisions', () {
      expect(
          () => AuroraTextureContract(id: 'x', extensions: [
                const AuroraColorToken('demo.color', description: 'Colour.')
              ]),
          throwsArgumentError);
      expect(
          () => AuroraTextureContract(id: 'x', extensions: [
                const AuroraDimensionToken('shape.huge', description: 'Huge.')
              ]),
          throwsArgumentError);
      expect(
          () => AuroraTextureContract(id: 'x', extensions: [
                const AuroraBooleanToken('demo.a', description: 'A.'),
                const AuroraBooleanToken('demo.a.b', description: 'B.'),
              ]),
          throwsArgumentError);
      expect(
          () => AuroraTextureContract(id: 'x', extensions: [
                const AuroraEnumToken('demo.e',
                    description: 'E.', values: ['a', 'a'])
              ]),
          throwsArgumentError);
    });
  });

  group('texture values', () {
    test('reads typed, resolved values', () {
      final texture = demoTexture();
      expect(texture.read(Demo.card), const AuroraDimension.dp(12));
      expect(texture.read(Demo.elevation), 1.0);
      expect(texture.read(Demo.bordered), isTrue);
      expect(
          texture.readEnum(Demo.layout, CardLayout.values), CardLayout.compact);
      final heading = texture.read(Demo.heading);
      expect(heading.fontFamily.names, ['Fraunces', 'Georgia', 'serif']);
      expect(heading.fontWeight, AuroraFontWeight.semiBold);
      expect(heading.lineHeight, 1.3);
      expect(
          texture.read(AuroraTextureFoundation.bodyMedium).fontFamily.primary,
          'Roboto');
      expect(texture.read(Demo.ease), const AuroraCubicBezier(0.2, 0, 0, 1));
      expect(texture.read(Demo.divider).dashArray,
          [const AuroraDimension.dp(4), const AuroraDimension.dp(2)]);
      expect(texture.colorReferences, {'colors.outlineVariant'});
      expect(texture.authored(Demo.card),
          const AuroraAlias(AuroraTextureFoundation.mediumShape));
    });

    test('resolves theme colour aliases against a variant', () {
      final texture = demoTexture();
      final themeContract = AuroraContract(id: 'app');
      texture.validateColors(themeContract);
      for (final appearance in AuroraAppearance.values) {
        final variant = AuroraStarter.variant(
            contract: themeContract, appearance: appearance);
        expect(variant.resolveColor(texture.read(Demo.cardBorder).color),
            variant.colors.outlineVariant);
      }
    });

    test('rejects colour references the theme contract lacks', () {
      const ticket =
          AuroraColorToken('app.ticket', description: 'Ticket colour.');
      final texture = demoTexture({
        Demo.cardBorder: const AuroraBorder(
            color: AuroraAlias(ticket),
            width: AuroraDimension.dp(1),
            style: AuroraStrokeStyle.solid),
      });
      expect(() => texture.validateColors(AuroraContract(id: 'app')),
          throwsA(isA<AuroraValidationException>()));
      texture.validateColors(AuroraContract(id: 'app', extensions: [ticket]));
    });

    test('reports every problem at once', () {
      try {
        AuroraTexture(
            contract: contract,
            id: 'bad',
            name: 'Bad',
            values: {
              ...AuroraTextureStarter.material,
              ...demoValues(),
              Demo.chip: 4,
              Demo.layout: 'grid',
              Demo.weight: const AuroraFontWeight(0),
              Demo.ease: const AuroraCubicBezier(2, 0, 0, 1),
              Demo.fade: const Duration(milliseconds: -1),
              AuroraTextureFoundation.smallShape:
                  const AuroraAlias(AuroraTextureFoundation.mediumDuration),
            }..remove(Demo.bordered));
        fail('expected validation failure');
      } on AuroraValidationException catch (error) {
        expect(error.issues, hasLength(7));
        expect(error.issues,
            contains('Missing required token demo.lines.bordered'));
        expect(error.issues,
            contains('demo.variants.card must be one of rich, compact'));
      }
    });

    test('rejects alias cycles and undeclared targets', () {
      const a = AuroraDimensionToken('demo.a', description: 'A.');
      const b = AuroraDimensionToken('demo.b', description: 'B.');
      const outside = AuroraDimensionToken('other.c', description: 'C.');
      final cyclic = AuroraTextureContract(id: 'c', extensions: [a, b]);
      expect(
          () => AuroraTextureStarter.texture(
              contract: cyclic,
              id: 'c',
              name: 'C',
              values: {a: const AuroraAlias(b), b: const AuroraAlias(a)}),
          throwsA(isA<AuroraValidationException>()
              .having((e) => e.issues.join(), 'issues', contains('Cyclic'))));
      expect(
          () => AuroraTextureStarter.texture(
                  contract: cyclic,
                  id: 'c',
                  name: 'C',
                  values: {
                    a: const AuroraAlias(outside),
                    b: const AuroraDimension.dp(1)
                  }),
          throwsA(isA<AuroraValidationException>()));
    });

    test('values are immutable snapshots', () {
      final values = demoValues();
      final texture = demoTexture(values);
      values[Demo.chip] = const AuroraDimension.dp(1);
      expect(texture.read(Demo.chip), const AuroraDimension.dp(999));
      expect(() => texture.read(Demo.heading).fontFamily.names.add('x'),
          throwsUnsupportedError);
    });
  });

  group('texture DTCG', () {
    Map<String, Object?> json(Object value) =>
        jsonDecode(jsonEncode(value)) as Map<String, Object?>;
    AuroraTexture decode(Map<String, Object?> document) =>
        AuroraTextureDtcg.decode(document,
            contract: contract, id: 'soft', name: 'Soft');

    test('round-trips exactly, keeping aliases', () {
      final texture = demoTexture({
        Demo.chip: const AuroraDimension.px(999),
        AuroraTextureFoundation.smallShape: const AuroraDimension.rem(0.5),
        Demo.divider: AuroraStrokeStyle.none,
      });
      final document = json(AuroraTextureDtcg.encode(texture));
      final again = decode(document);
      expect(json(AuroraTextureDtcg.encode(again)), document);
      for (final token in contract.tokens.values) {
        expect(again.read(token), texture.read(token), reason: token.path);
        expect(again.authored(token), texture.authored(token),
            reason: token.path);
      }
      final demo = document['demo'] as Map<String, Object?>;
      final shape = demo['shape'] as Map<String, Object?>;
      expect((shape['card'] as Map)[r'$value'], '{shape.medium}');
      expect((shape['chip'] as Map)[r'$extensions'], isNull);
      final type = demo['type'] as Map<String, Object?>;
      expect(((type['heading'] as Map)[r'$value'] as Map)['fontFamily'],
          '{demo.type.serif}');
      expect((type['heading'] as Map)[r'$extensions'], {
        'dev.aurora': {'unit': 'dp'}
      });
      final variants = demo['variants'] as Map<String, Object?>;
      expect(variants['card'], {
        r'$description': 'Default card layout.',
        r'$value': 'compact',
        r'$extensions': {
          'dev.aurora': {
            'type': 'enum',
            'values': ['rich', 'compact']
          }
        },
      });
      final lines = demo['lines'] as Map<String, Object?>;
      expect(((lines['cardBorder'] as Map)[r'$value'] as Map)['color'],
          '{colors.outlineVariant}');
      expect(again.read(Demo.divider).isNone, isTrue);
    });

    test('accepts DTCG input forms and normalizes them', () {
      final document = json(AuroraTextureDtcg.encode(demoTexture()));
      final motion = (document['demo'] as Map)['motion'] as Map;
      (motion['fade'] as Map)[r'$value'] = {'value': 0.25, 'unit': 's'};
      (((document['demo'] as Map)['type'] as Map)['weight'] as Map)[r'$value'] =
          'semi-bold';
      final texture = decode(document);
      expect(texture.read(Demo.fade), const Duration(milliseconds: 250));
      expect(texture.read(Demo.weight), AuroraFontWeight.semiBold);
    });

    test('rejects malformed and mismatched documents', () {
      Map<String, Object?> doc() =>
          json(AuroraTextureDtcg.encode(demoTexture()));
      Map<String, Object?> token(Map<String, Object?> d, String path) {
        Map<String, Object?> node = d;
        for (final part in path.split('.')) {
          node = node[part] as Map<String, Object?>;
        }
        return node;
      }

      final wrongType = doc();
      token(wrongType, 'demo.shape.chip')[r'$type'] = 'number';
      expect(() => decode(wrongType), throwsFormatException);

      final unmarked = doc();
      (token(unmarked, 'demo.lines.bordered')).remove(r'$extensions');
      expect(() => decode(unmarked), throwsFormatException);

      final otherSet = doc();
      ((token(otherSet, 'demo.variants.card')[r'$extensions']
          as Map)['dev.aurora'] as Map)['values'] = ['rich'];
      expect(() => decode(otherSet), throwsFormatException);

      final unknownAlias = doc();
      token(unknownAlias, 'demo.shape.chip')[r'$value'] = '{demo.nope}';
      expect(() => decode(unknownAlias), throwsFormatException);

      final dpUnit = doc();
      token(dpUnit, 'demo.shape.chip')[r'$value'] = {'value': 1, 'unit': 'dp'};
      expect(() => decode(dpUnit), throwsFormatException);

      final outOfSet = doc();
      token(outOfSet, 'demo.variants.card')[r'$value'] = 'grid';
      expect(() => decode(outOfSet), throwsA(isA<AuroraValidationException>()));

      final missing = doc();
      (missing['demo'] as Map).remove('motion');
      expect(() => decode(missing), throwsA(isA<AuroraValidationException>()));
    });
  });

  group('texture selection', () {
    final themeContract = AuroraContract(id: 'app');
    AuroraTheme theme(String id) => AuroraTheme(
            id: id,
            name: id,
            preferredAppearance: AuroraAppearance.light,
            variants: [
              for (final appearance in AuroraAppearance.values)
                AuroraStarter.variant(
                    contract: themeContract, appearance: appearance)
            ]);
    final themes = [theme('a'), theme('b')];
    final soft = demoTexture();
    final sharp = AuroraTextureStarter.texture(
        contract: contract,
        id: 'sharp',
        name: 'Sharp',
        values: {...demoValues(), Demo.chip: const AuroraDimension.dp(0)});

    AuroraRuntime runtime(
            {Iterable<AuroraTexture> textures = const [],
            Map<String, String> pairings = const {},
            String? textureId}) =>
        AuroraRuntime(
            contract: themeContract,
            themes: themes,
            textures: textures,
            texturePairings: pairings,
            initialSelection: AuroraSelection(
                themeId: 'a',
                textureId: textureId ??
                    (textures.isEmpty || pairings.isNotEmpty
                        ? null
                        : textures.first.id)),
            fallback: AuroraVariantFallback.reject);

    test('apps without textures behave as before', () {
      final r = runtime();
      expect(r.state.texture, isNull);
      expect(r.textureContract, isNull);
      expect(
          () => r.select(const AuroraSelection(themeId: 'a', textureId: 'x')),
          throwsArgumentError);
    });

    test('texture and theme switch independently', () async {
      final r = runtime(textures: [soft, sharp]);
      final changes = <AuroraState>[];
      final sub = r.changes.listen(changes.add);
      expect(r.state.texture, same(soft));
      r.select(const AuroraSelection(themeId: 'a', textureId: 'sharp'));
      expect(r.state.texture, same(sharp));
      expect(r.state.theme.id, 'a');
      r.select(const AuroraSelection(themeId: 'b', textureId: 'sharp'));
      expect(r.state.texture, same(sharp));
      r.select(const AuroraSelection(
          themeId: 'b',
          textureId: 'sharp',
          appearance: AuroraAppearancePreference.dark));
      expect(r.state.texture, same(sharp));
      expect(r.state.variant.appearance, AuroraAppearance.dark);
      await Future<void>.delayed(Duration.zero);
      expect(changes, hasLength(3));
      await sub.cancel();
    });

    test('rejects unknown textures without changing state', () {
      final r = runtime(textures: [soft, sharp]);
      final before = r.state;
      expect(
          () =>
              r.select(const AuroraSelection(themeId: 'b', textureId: 'nope')),
          throwsArgumentError);
      expect(r.state, same(before));
    });

    test('a theme without a pairing or selection has no texture', () {
      final r = runtime(textures: [soft, sharp]);
      r.select(const AuroraSelection(themeId: 'b'));
      expect(r.state.texture, isNull);
    });

    test('pairings give themes a texture; explicit selection wins', () async {
      final r = runtime(textures: [soft, sharp], pairings: {'a': 'soft'});
      expect(r.state.texture, same(soft));
      r.select(const AuroraSelection(themeId: 'b'));
      expect(r.state.texture, isNull);
      r.select(const AuroraSelection(themeId: 'a', textureId: 'sharp'));
      expect(r.state.texture, same(sharp));
      r.select(const AuroraSelection(themeId: 'a'));
      expect(r.state.texture, same(soft));
      expect(r.texturePairings, {'a': 'soft'});
    });

    test('pairings can be changed or removed at runtime', () async {
      final r = runtime(textures: [soft, sharp], pairings: {'a': 'soft'});
      final changes = <AuroraState>[];
      final sub = r.changes.listen(changes.add);
      r.pairTexture('a', 'sharp');
      expect(r.state.texture, same(sharp));
      r.pairTexture('b', 'soft'); // inactive theme: no change
      expect(r.state.texture, same(sharp));
      r.pairTexture('a', null);
      expect(r.state.texture, isNull);
      expect(r.texturePairings, {'b': 'soft'});
      expect(() => r.pairTexture('nope', 'soft'), throwsArgumentError);
      expect(() => r.pairTexture('a', 'nope'), throwsArgumentError);
      await Future<void>.delayed(Duration.zero);
      expect(changes, hasLength(2));
      await sub.cancel();

      // An explicit selection is not affected by pairing changes.
      final explicit = runtime(
          textures: [soft, sharp], pairings: {'a': 'soft'}, textureId: 'sharp');
      explicit.pairTexture('a', null);
      expect(explicit.state.texture, same(sharp));
    });

    test('pairings are validated at construction', () {
      expect(() => runtime(textures: [soft], pairings: {'zzz': 'soft'}),
          throwsArgumentError);
      expect(() => runtime(textures: [soft], pairings: {'a': 'zzz'}),
          throwsArgumentError);
    });

    test('registration validates contracts, ids and colours', () {
      expect(() => runtime(textures: [soft, soft]), throwsArgumentError);
      final other = AuroraTextureStarter.texture(
          contract: AuroraTextureContract(id: 'other'), id: 'o', name: 'O');
      expect(() => runtime(textures: [soft, other]), throwsArgumentError);
      const ticket = AuroraColorToken('app.ticket', description: 'Ticket.');
      final needsTicket = demoTexture({
        Demo.cardBorder: const AuroraBorder(
            color: AuroraAlias(ticket),
            width: AuroraDimension.dp(1),
            style: AuroraStrokeStyle.solid),
      });
      expect(() => runtime(textures: [needsTicket]),
          throwsA(isA<AuroraValidationException>()));
    });

    test('selection JSON carries the texture additively', () {
      const selection = AuroraSelection(themeId: 'a', textureId: 'sharp');
      expect(selection.toJson(),
          {'themeId': 'a', 'appearance': 'system', 'textureId': 'sharp'});
      expect(
          const AuroraSelection(themeId: 'a').toJson().containsKey('textureId'),
          isFalse);
      expect(AuroraSelection.fromJson(selection.toJson()).textureId, 'sharp');
      expect(
          () => AuroraSelection.fromJson(
              {'themeId': 'a', 'appearance': 'system', 'textureId': 3}),
          throwsFormatException);
      final restored = AuroraSelection.restoreJson(
          {'themeId': 'a', 'textureId': 'gone'},
          themes: themes,
          fallbackId: 'a',
          textures: [soft, sharp]);
      expect(restored.textureId, isNull);
      expect(
          AuroraSelection.restoreJson({'themeId': 'a', 'textureId': 'sharp'},
              themes: themes,
              fallbackId: 'a',
              textures: [soft, sharp]).textureId,
          'sharp');
      expect(
          AuroraSelection.restoreJson({'themeId': 'a', 'textureId': 'sharp'},
                  themes: themes, fallbackId: 'a')
              .textureId,
          isNull);
    });
  });

  group('texture recipe', () {
    Map<String, Object?> recipe() => {
          'schemaVersion': 1,
          'kind': 'texture',
          'id': 'soft',
          'name': 'Soft',
          'contract': {
            'id': 'demo',
            'extensions': [
              for (final token in Demo.all)
                {
                  'path': token.path,
                  'description': token.description,
                  'type': token.type,
                  if (token is AuroraEnumToken) 'values': token.values,
                }
            ],
          },
          'values': {
            'demo.type.serif': ['Fraunces', 'Georgia', 'serif'],
            'demo.type.weight': 600,
            'demo.type.heading': {
              'fontFamily': '{demo.type.serif}',
              'fontSize': {'value': 20, 'unit': 'dp'},
              'fontWeight': '{demo.type.weight}',
              'letterSpacing': {'value': 0, 'unit': 'dp'},
              'lineHeight': 1.3,
            },
            'demo.shape.card': '{shape.medium}',
            'demo.shape.chip': {'value': 999, 'unit': 'dp'},
            'demo.depth.card': 1,
            'demo.lines.divider': {
              'dashArray': [
                {'value': 4, 'unit': 'dp'},
                {'value': 2, 'unit': 'dp'}
              ],
              'lineCap': 'round'
            },
            'demo.lines.cardBorder': {
              'color': '{colors.outlineVariant}',
              'width': {'value': 1, 'unit': 'dp'},
              'style': 'solid',
            },
            'demo.depth.cardShadow': [
              {
                'color': {
                  'colorSpace': 'srgb',
                  'components': [0, 0, 0],
                  'alpha': 0x33 / 255
                },
                'offsetX': {'value': 0, 'unit': 'dp'},
                'offsetY': {'value': 2, 'unit': 'dp'},
                'blur': {'value': 6, 'unit': 'dp'},
                'spread': {'value': 0, 'unit': 'dp'},
              }
            ],
            'demo.lines.bordered': true,
            'demo.variants.card': 'compact',
            'demo.motion.fade': {'value': 200, 'unit': 'ms'},
            'demo.motion.ease': '{motion.easing.standard}',
          },
        };

    test('builds the same texture as Dart, on the shared contract', () {
      final fromJson = AuroraTextureRecipe.decode(recipe(), contract: contract);
      final fromDart = demoTexture();
      expect(fromJson.contract, same(contract));
      for (final token in contract.tokens.values) {
        expect(fromJson.authored(token), fromDart.authored(token),
            reason: token.path);
      }
      expect(AuroraTextureDtcg.encode(fromJson),
          AuroraTextureDtcg.encode(fromDart));
    });

    test('builds its own contract when none is given', () {
      final texture = AuroraTextureRecipe.decode(recipe());
      expect(texture.contract.id, 'demo');
      expect(
          texture.read(texture.contract.tokens['demo.shape.card']!
              as AuroraDimensionToken),
          const AuroraDimension.dp(12));
    });

    test('rejects mismatched contracts and bad input', () {
      expect(
          () => AuroraTextureRecipe.decode({
                ...recipe(),
                'contract': {'id': 'demo'}
              }, contract: contract),
          throwsFormatException);
      expect(() => AuroraTextureRecipe.decode({...recipe(), 'kind': 'theme'}),
          throwsFormatException);
      expect(() => AuroraTextureRecipe.decode({...recipe(), 'base': 'none'}),
          throwsA(isA<AuroraValidationException>()));
      expect(
          () => AuroraTextureRecipe.decode({
                ...recipe(),
                'values': {'demo.nope': 1}
              }),
          throwsFormatException);
    });
  });
}
