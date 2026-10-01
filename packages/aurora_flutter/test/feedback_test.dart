import 'package:aurora_flutter/aurora_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final contract = AuroraContract(id: 'test');
  final theme = AuroraGenerator.generate(AuroraGenerationRequest(
          contract: contract,
          id: 'brand',
          name: 'Brand',
          primary: AuroraColor.hex('#e60023')))
      .theme;
  AuroraController controller() => AuroraController(
      contract: contract,
      themes: [theme],
      initialSelection: const AuroraSelection(themeId: 'brand'),
      fallback: AuroraVariantFallback.reject);

  testWidgets('injected controller starts with platform brightness',
      (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final active = controller();
    addTearDown(active.dispose);
    expect(active.state.variant.appearance, AuroraAppearance.dark);
    expect(active.contract, same(contract));
  });

  test('notifications observe accepted state synchronously exactly once',
      () async {
    final active = controller();
    var calls = 0;
    active.addListener(() {
      calls++;
      expect(
          active.state.selection.appearance, AuroraAppearancePreference.dark);
    });
    active.select(const AuroraSelection(
        themeId: 'brand', appearance: AuroraAppearancePreference.dark));
    expect(calls, 1);
    active.select(const AuroraSelection(
        themeId: 'brand', appearance: AuroraAppearancePreference.dark));
    expect(() => active.select(const AuroraSelection(themeId: 'unknown')),
        throwsArgumentError);
    active.setSystemAppearance(AuroraAppearance.light);
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    active.dispose();
  });

  testWidgets(
      'fixed scope isolates lookups, updates snapshots and ignores device changes',
      (tester) async {
    final active = controller();
    addTearDown(active.dispose);
    final variants = AuroraGenerator.variants(AuroraColor.hex('#0061a4'));
    Widget app(AuroraAppearance appearance) => MaterialApp(
        home: AuroraScope(
            controller: active,
            child: AuroraScope.fixed(
                variant: variants[appearance]!,
                child: Builder(builder: (context) {
                  expect(() => Aurora.controllerOf(context),
                      throwsA(isA<FlutterError>()));
                  return Text(Aurora.of(context).appearance.name);
                }))));
    await tester.pumpWidget(app(AuroraAppearance.light));
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pump();
    expect(find.text('light'), findsOneWidget);
    await tester.pumpWidget(app(AuroraAppearance.dark));
    expect(find.text('dark'), findsOneWidget);
    final element = tester.element(find.text('dark'));
    expect(Theme.of(element).brightness, Brightness.dark);
    expect(Aurora.tokensOf(element).primary,
        variants[AuroraAppearance.dark]!.tokens.primary);
  });

  test('Flutter conversions preserve alpha and status extension interpolates',
      () {
    const color = Color(0x78123456);
    expect(color.auroraColor.flutterColor, color);
    expect(AuroraFlutterAppearance.fromBrightness(Brightness.dark).brightness,
        Brightness.dark);
    final light = theme.variants[AuroraAppearance.light]!;
    final dark = theme.variants[AuroraAppearance.dark]!;
    final status = light.toThemeData().extension<AuroraStatusColors>()!;
    final other = dark.toThemeData().extension<AuroraStatusColors>()!;
    expect(status.success, light.tokens.success.flutterColor);
    expect(status.lerp(other, 1).onInfoContainer, other.onInfoContainer);
    expect(status.copyWith(success: Colors.pink).success, Colors.pink);
  });
}
