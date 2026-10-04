import 'dart:convert';
import 'dart:io';
import 'package:aurora_flutter/aurora_flutter.dart';
import 'package:aurora_textures_example/main.dart';
import 'package:aurora_textures_example/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the two textures differ in every extension token', () {
    for (final token in FeelTokens.all) {
      if (token == FeelTokens.cardBorder) continue; // both draw a border
      expect(softTexture.read(token), isNot(editorialTexture.read(token)),
          reason: token.path);
    }
  });

  test('DTCG export and re-import round-trips both textures exactly', () {
    for (final texture in feelTextures) {
      final document = jsonDecode(jsonEncode(AuroraTextureDtcg.encode(texture)))
          as Map<String, Object?>;
      final again = AuroraTextureDtcg.decode(document,
          contract: feelTextureContract, id: texture.id, name: texture.name);
      expect(
          AuroraTextureDtcg.encode(again), AuroraTextureDtcg.encode(texture));
      for (final token in feelTextureContract.tokens.values) {
        expect(again.authored(token), texture.authored(token),
            reason: token.path);
      }
    }
  });

  test('recipes build the same textures from JSON', () {
    for (final texture in feelTextures) {
      final recipe = jsonDecode(
              File('../recipes/texture-${texture.id}.json').readAsStringSync())
          as Map<String, dynamic>;
      final built =
          AuroraTextureRecipe.decode(recipe, contract: feelTextureContract);
      expect(built.id, texture.id);
      expect(
          AuroraTextureDtcg.encode(built), AuroraTextureDtcg.encode(texture));
    }
  });

  testWidgets('textures change font, corners and border style', (tester) async {
    await tester.pumpWidget(const TexturesApp());
    final card = find.byKey(const Key('flight-card')).first;
    final route = find.text('LHR → JFK');

    BoxDecoration decoration() => tester
        .widget<Container>(
            find.descendant(of: card, matching: find.byType(Container)).first)
        .decoration! as BoxDecoration;
    StrokePainter painter() =>
        tester.widget<CustomPaint>(card).foregroundPainter! as StrokePainter;

    expect(tester.widget<Text>(route).style!.fontFamily, 'Nunito');
    expect(decoration().borderRadius, BorderRadius.circular(20));
    expect(painter().pattern, isNull);
    expect(decoration().boxShadow, isNotEmpty);

    // Ember is paired with Editorial.
    await tester.tap(find.text('Ember'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(route).style!.fontFamily, 'Georgia');
    expect(decoration().borderRadius, BorderRadius.zero);
    expect(painter().pattern, [4.5, 4.5]);
    expect(decoration().boxShadow, isEmpty);

    // An explicit texture wins over the pairing and survives theme changes.
    await tester.tap(find.byKey(const Key('texture-soft')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(route).style!.fontFamily, 'Nunito');
    await tester.tap(find.text('Harbor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ember'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(route).style!.fontFamily, 'Nunito');

    // Back to the theme's default; appearance changes keep the texture.
    await tester.tap(find.byKey(const Key('texture-default')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(route).style!.fontFamily, 'Georgia');
    final controller = Aurora.controllerOf(tester.element(card));
    controller.select(const AuroraSelection(
        themeId: 'ember', appearance: AuroraAppearancePreference.dark));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(route).style!.fontFamily, 'Georgia');
    expect(painter().color,
        controller.state.variant.colors.onSurface.flutterColor);

    // The developer can re-pair a theme at runtime.
    controller.pairTexture('ember', 'soft');
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(route).style!.fontFamily, 'Nunito');
  });
}
