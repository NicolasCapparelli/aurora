import 'package:aurora_flutter/aurora_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const ticket =
    AuroraColorToken('theater.ticket', description: 'Ticket background.');

void main() {
  late AuroraController controller;
  setUp(() {
    final contract = AuroraContract(id: 'theater', extensions: [ticket]);
    controller = AuroraController(
      contract: contract,
      themes: [
        for (final id in ['wicked', 'hadestown'])
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
                    ticket:
                        AuroraColor.hex(id == 'wicked' ? '#123456' : '#654321')
                  },
                )
            ],
          )
      ],
      initialSelection: const AuroraSelection(themeId: 'wicked'),
      fallback: AuroraVariantFallback.reject,
    );
  });
  tearDown(() => controller.dispose());

  Widget app() => AuroraEngine(
      controller: controller,
      builder: (context, theme) => MaterialApp(
            theme: theme,
            home: Builder(
                builder: (context) => Scaffold(
                        body: Column(children: [
                      Text(controller.state.theme.id),
                      Text(Aurora.of(context).appearance.name),
                      Container(
                          key: const Key('ticket'),
                          color: Aurora.of(context).read(ticket).flutterColor),
                      const FilledButton(
                          onPressed: null, child: Text('Reserve')),
                    ]))),
          ));

  testWidgets('switching updates custom tokens and dependent widgets',
      (tester) async {
    await tester.pumpWidget(app());
    expect(find.text('wicked'), findsOneWidget);
    controller.select(const AuroraSelection(themeId: 'hadestown'));
    await tester.pumpAndSettle();
    expect(find.text('hadestown'), findsOneWidget);
    expect(tester.widget<Container>(find.byKey(const Key('ticket'))).color,
        const Color(0xff654321));
  });

  testWidgets('device brightness updates Material and retains theme identity',
      (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(app());
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(find.text('wicked'), findsOneWidget);
    expect(find.text('dark'), findsOneWidget);
    expect(Theme.of(tester.element(find.byType(FilledButton))).brightness,
        Brightness.dark);
  });

  testWidgets('fixed preference ignores device brightness', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    controller.select(const AuroraSelection(
        themeId: 'wicked', appearance: AuroraAppearancePreference.light));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('light'), findsOneWidget);
  });

  testWidgets('lookup outside scope gives a clear error', (tester) async {
    await tester.pumpWidget(Builder(builder: (context) {
      Aurora.of(context);
      return const SizedBox();
    }));
    expect(tester.takeException(), isA<FlutterError>());
  });

  test('Material bridge preserves foundational colors and alpha', () {
    final variant = controller.state.variant;
    final material = variant.toColorScheme();
    expect(material.primary, variant.colors.primary.flutterColor);
    expect(material.onSurface, variant.colors.onSurface.flutterColor);
    expect(material.surfaceContainerHighest,
        variant.colors.surfaceContainerHighest.flutterColor);
    expect(
        material.primaryFixedDim, variant.colors.primaryFixedDim.flutterColor);
    expect(AuroraColor.hex('#12345678').flutterColor.toARGB32(), 0x78123456);
  });
}
