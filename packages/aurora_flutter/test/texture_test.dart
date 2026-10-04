import 'package:aurora_flutter/aurora_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

abstract final class Feel {
  static const card =
      AuroraDimensionToken('feel.shape.card', description: 'Card radius.');
  static const gap =
      AuroraDimensionToken('feel.density.gap', description: 'Gap in rem.');
  static const title =
      AuroraTypographyToken('feel.type.title', description: 'Card title.');
  static const border =
      AuroraBorderToken('feel.lines.card', description: 'Card border.');
  static const shadow =
      AuroraShadowToken('feel.depth.card', description: 'Card shadow.');
  static const fade =
      AuroraDurationToken('feel.motion.fade', description: 'Fade duration.');
  static const ease =
      AuroraCubicBezierToken('feel.motion.ease', description: 'Fade easing.');
  static const weight =
      AuroraFontWeightToken('feel.type.weight', description: 'Odd weight.');
  static const layout = AuroraEnumToken('feel.variants.card',
      description: 'Card layout.', values: ['rich', 'compact']);
  static const all = <AuroraToken<Object>>[
    card,
    gap,
    title,
    border,
    shadow,
    fade,
    ease,
    weight,
    layout
  ];
}

enum CardLayout { rich, compact }

final textureContract = AuroraTextureContract(id: 'feel', extensions: Feel.all);

AuroraTexture feel(String id,
        {required double radius,
        required String family,
        required AuroraStrokeStyle stroke,
        String layout = 'rich'}) =>
    AuroraTextureStarter.texture(
        contract: textureContract,
        id: id,
        name: id,
        values: {
          AuroraTextureFoundation.plainFamily: AuroraFontFamily([family]),
          AuroraTextureFoundation.mediumShape: AuroraDimension.dp(radius),
          Feel.card: const AuroraAlias(AuroraTextureFoundation.mediumShape),
          Feel.gap: const AuroraDimension.rem(0.5),
          Feel.title: const AuroraTypography(
              fontFamily: AuroraAlias(AuroraTextureFoundation.plainFamily),
              fontSize: AuroraDimension.dp(18),
              fontWeight: AuroraAlias(Feel.weight),
              letterSpacing: AuroraDimension.dp(0.5),
              lineHeight: AuroraLiteral(1.25)),
          Feel.border: AuroraBorder(
              color: const AuroraAlias(AuroraFoundation.outline),
              width: const AuroraDimension.dp(2),
              style: stroke),
          Feel.shadow: AuroraShadow([
            const AuroraShadowLayer(
                color: AuroraAlias(AuroraFoundation.shadow),
                offsetX: AuroraDimension.dp(0),
                offsetY: AuroraDimension.dp(3),
                blur: AuroraDimension.dp(8),
                spread: AuroraDimension.dp(1)),
            const AuroraShadowLayer(
                color: AuroraAlias(AuroraFoundation.shadow),
                offsetX: AuroraDimension.dp(0),
                offsetY: AuroraDimension.dp(1),
                blur: AuroraDimension.dp(1),
                spread: AuroraDimension.dp(0),
                inset: true),
          ]),
          Feel.fade: const Duration(milliseconds: 180),
          Feel.ease: const AuroraCubicBezier(0.4, 0, 0.2, 1),
          Feel.weight: const AuroraFontWeight(550),
          Feel.layout: layout,
        });

void main() {
  final contract = AuroraContract(id: 'feel-app');
  final themes = [
    for (final id in ['green', 'red'])
      AuroraTheme(
        id: id,
        name: id,
        preferredAppearance: AuroraAppearance.light,
        variants: [
          for (final appearance in AuroraAppearance.values)
            AuroraStarter.variant(
                contract: contract,
                appearance: appearance,
                values: {
                  AuroraFoundation.outline: AuroraColor.hex(id == 'green'
                      ? (appearance == AuroraAppearance.light
                          ? '#146c2e'
                          : '#8bd996')
                      : '#b3261e'),
                })
        ],
      )
  ];
  final soft = feel('soft',
      radius: 24, family: 'Nunito', stroke: AuroraStrokeStyle.solid);
  final sharp = feel('sharp',
      radius: 0,
      family: 'Georgia',
      stroke: AuroraStrokeStyle.dashed,
      layout: 'compact');

  group('conversions', () {
    final variant = themes.first.variants[AuroraAppearance.light]!;
    final tokens = AuroraTextureTokens(soft, variant);

    test('dimensions, durations, curves and weights', () {
      expect(tokens.dimension(Feel.card), 24);
      expect(tokens.dimension(Feel.gap), 8);
      expect(
          AuroraTextureTokens(soft, variant, rootFontSize: 20)
              .dimension(Feel.gap),
          10);
      expect(tokens.borderRadius(Feel.card), BorderRadius.circular(24));
      expect(tokens.duration(Feel.fade), const Duration(milliseconds: 180));
      final curve = tokens.curve(Feel.ease);
      expect([curve.a, curve.b, curve.c, curve.d], [0.4, 0, 0.2, 1]);
      expect(tokens.fontWeight(Feel.weight), FontWeight.w600);
      expect(nearestFontWeight(const AuroraFontWeight(1)), FontWeight.w100);
      expect(nearestFontWeight(const AuroraFontWeight(1000)), FontWeight.w900);
      expect(tokens.option(Feel.layout, CardLayout.values), CardLayout.rich);
    });

    test('typography becomes a TextStyle', () {
      final texture = tokens.textStyle(Feel.title);
      expect(texture.fontFamily, 'Nunito');
      expect(texture.fontSize, 18);
      expect(texture.fontWeight, FontWeight.w600);
      expect(texture.fontVariations, [const FontVariation.weight(550)]);
      expect(texture.letterSpacing, 0.5);
      expect(texture.height, 1.25);
    });

    test('borders, strokes and shadows use theme colours', () {
      expect(tokens.borderSide(Feel.border),
          const BorderSide(color: Color(0xff146c2e), width: 2));
      expect(tokens.border(Feel.border).top.width, 2);
      expect(
          AuroraTextureTokens(
                  feel('none',
                      radius: 0, family: 'x', stroke: AuroraStrokeStyle.none),
                  variant)
              .borderSide(Feel.border),
          BorderSide.none);
      final dashed = AuroraTextureTokens(sharp, variant);
      final stroke = dashed.read(Feel.border).style;
      expect(stroke.keyword, AuroraStrokeKeyword.dashed);
      expect(dashed.dashPattern(stroke, width: 2), [6, 6]);
      expect(
          tokens.dashPattern(
              AuroraStrokeStyle.dashes(
                  dashArray: const [AuroraDimension.rem(0.25)],
                  lineCap: AuroraLineCap.round),
              width: 1),
          [4]);
      expect(tokens.shadows(Feel.shadow), [
        BoxShadow(
            color: variant.colors.shadow.flutterColor,
            offset: const Offset(0, 3),
            blurRadius: 8,
            spreadRadius: 1),
      ]);
    });

    test('texture colours must exist in the theme contract', () {
      const ticket = AuroraColorToken('app.ticket', description: 'Ticket.');
      final needsTicket = AuroraTextureStarter.texture(
          contract: textureContract,
          id: 'x',
          name: 'x',
          values: {
            ...{
              for (final token in Feel.all) token: soft.authored(token),
            },
            Feel.border: const AuroraBorder(
                color: AuroraAlias(ticket),
                width: AuroraDimension.dp(1),
                style: AuroraStrokeStyle.solid),
          });
      expect(() => AuroraTextureTokens(needsTicket, variant),
          throwsA(isA<AuroraValidationException>()));
    });
  });

  group('reactive access', () {
    late AuroraController controller;
    setUp(() => controller = AuroraController(
        contract: contract,
        themes: themes,
        textures: [soft, sharp],
        initialSelection: const AuroraSelection(
            themeId: 'green',
            textureId: 'soft',
            appearance: AuroraAppearancePreference.light),
        fallback: AuroraVariantFallback.reject));
    tearDown(() => controller.dispose());

    Widget card() => Builder(builder: (context) {
          final texture = Aurora.textureOf(context);
          return DecoratedBox(
            key: const Key('card'),
            decoration: BoxDecoration(
                borderRadius: texture.borderRadius(Feel.card),
                border: texture.border(Feel.border)),
            child: Text('Title', style: texture.textStyle(Feel.title)),
          );
        });

    BoxDecoration decoration(WidgetTester tester) =>
        tester.widget<DecoratedBox>(find.byKey(const Key('card'))).decoration
            as BoxDecoration;

    testWidgets('switching texture, theme and appearance rebuilds dependents',
        (tester) async {
      await tester.pumpWidget(AuroraScope(
          controller: controller,
          child: MaterialApp(home: Material(child: card()))));
      expect(decoration(tester).borderRadius, BorderRadius.circular(24));
      expect(
          tester.widget<Text>(find.text('Title')).style!.fontFamily, 'Nunito');

      controller.select(const AuroraSelection(
          themeId: 'green',
          textureId: 'sharp',
          appearance: AuroraAppearancePreference.light));
      await tester.pump();
      expect(decoration(tester).borderRadius, BorderRadius.zero);
      expect(
          tester.widget<Text>(find.text('Title')).style!.fontFamily, 'Georgia');
      expect((decoration(tester).border! as Border).top.color,
          const Color(0xff146c2e));

      controller.select(const AuroraSelection(
          themeId: 'green',
          textureId: 'sharp',
          appearance: AuroraAppearancePreference.dark));
      await tester.pump();
      expect(decoration(tester).borderRadius, BorderRadius.zero);
      expect((decoration(tester).border! as Border).top.color,
          const Color(0xff8bd996));

      controller.select(const AuroraSelection(
          themeId: 'red',
          textureId: 'sharp',
          appearance: AuroraAppearancePreference.dark));
      await tester.pump();
      expect(decoration(tester).borderRadius, BorderRadius.zero);
      expect((decoration(tester).border! as Border).top.color,
          const Color(0xffb3261e));
      expect(controller.state.texture, same(sharp));
    });

    testWidgets('pairings follow the theme and can change at runtime',
        (tester) async {
      final paired = AuroraController(
          contract: contract,
          themes: themes,
          textures: [soft, sharp],
          texturePairings: {'green': 'soft', 'red': 'sharp'},
          initialSelection: const AuroraSelection(themeId: 'green'),
          fallback: AuroraVariantFallback.reject);
      addTearDown(paired.dispose);
      String? family;
      await tester.pumpWidget(AuroraScope(
          controller: paired,
          child: Builder(builder: (context) {
            family = Aurora.maybeTextureOf(context)
                ?.textStyle(AuroraTextureFoundation.bodyMedium)
                .fontFamily;
            return const SizedBox();
          })));
      expect(family, 'Nunito');

      paired.select(const AuroraSelection(themeId: 'red'));
      await tester.pump();
      expect(family, 'Georgia');

      paired.pairTexture('red', null);
      await tester.pump();
      expect(family, isNull);
      expect(paired.state.texture, isNull);

      paired.pairTexture('red', 'soft');
      await tester.pump();
      expect(family, 'Nunito');
    });

    testWidgets('managed engine applies the texture foundation to ThemeData',
        (tester) async {
      await tester.pumpWidget(AuroraEngine.managed(
        contract: contract,
        themes: themes,
        textures: [soft, sharp],
        initialSelection:
            const AuroraSelection(themeId: 'green', textureId: 'soft'),
        fallback: AuroraVariantFallback.reject,
        builder: (context, theme) => MaterialApp(
            theme: theme,
            home: Builder(
                builder: (context) => Text('x',
                    key: const Key('probe'),
                    style: Theme.of(context).textTheme.bodyMedium))),
      ));
      final context = tester.element(find.byKey(const Key('probe')));
      final theme = Theme.of(context);
      expect(theme.textTheme.bodyMedium!.fontFamily, 'Nunito');
      expect(theme.textTheme.bodyMedium!.color, isNotNull);
      expect(theme.textTheme.displayLarge!.fontFamily, 'Roboto');
      expect((theme.cardTheme.shape! as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(24));

      Aurora.controllerOf(context)
          .select(const AuroraSelection(themeId: 'green', textureId: 'sharp'));
      await tester.pumpAndSettle();
      final after = Theme.of(tester.element(find.byKey(const Key('probe'))));
      expect(after.textTheme.bodyMedium!.fontFamily, 'Georgia');
      expect((after.cardTheme.shape! as RoundedRectangleBorder).borderRadius,
          BorderRadius.zero);
    });

    testWidgets('fixed scopes preview a texture; colour-only apps have none',
        (tester) async {
      final variant = themes.first.variants[AuroraAppearance.light]!;
      AuroraTextureTokens? seen;
      await tester.pumpWidget(AuroraScope.fixed(
          variant: variant,
          texture: sharp,
          child: Builder(builder: (context) {
            seen = Aurora.textureOf(context);
            return const SizedBox();
          })));
      expect(seen!.texture, same(sharp));

      AuroraTextureTokens? none = seen;
      await tester.pumpWidget(AuroraScope.fixed(
          variant: variant,
          child: Builder(builder: (context) {
            none = Aurora.maybeTextureOf(context);
            expect(() => Aurora.textureOf(context), throwsFlutterError);
            expect(Theme.of(context).cardTheme.shape, isNull);
            return const SizedBox();
          })));
      expect(none, isNull);
    });
  });
}
