import 'package:aurora_flutter/aurora_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const ticket =
    AuroraColorToken('theater.ticket', description: 'Ticket background.');

void main() {
  late AuroraContract contract;
  late List<AuroraTheme> themes;
  late AuroraController controller;

  setUp(() {
    contract = AuroraContract(id: 'integration', extensions: [ticket]);
    themes = [
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
                  AuroraFoundation.primary:
                      AuroraColor.hex(id == 'green' ? '#146c2e' : '#b3261e'),
                  ticket:
                      AuroraColor.hex(id == 'green' ? '#123456' : '#654321'),
                },
              )
          ],
        )
    ];
    controller = AuroraController(
        contract: contract,
        themes: themes,
        initialSelection: const AuroraSelection(themeId: 'green'),
        fallback: AuroraVariantFallback.reject);
  });
  tearDown(() => controller.dispose());

  Widget probe(String name) => Builder(
      builder: (context) => Container(
            key: Key(name),
            color: Theme.of(context).colorScheme.primary,
            child: Text(Aurora.tokensOf(context).read(ticket).hex),
          ));

  testWidgets('scope themes native consumers and leaves siblings alone',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Column(children: [
      Builder(
          builder: (context) => Container(
              key: const Key('outside'),
              color: Theme.of(context).colorScheme.primary)),
      AuroraScope(controller: controller, child: probe('inside')),
    ])));
    final outside =
        tester.widget<Container>(find.byKey(const Key('outside'))).color;
    expect(tester.widget<Container>(find.byKey(const Key('inside'))).color,
        const Color(0xff146c2e));
    controller.select(const AuroraSelection(themeId: 'red'));
    await tester.pumpAndSettle();
    expect(tester.widget<Container>(find.byKey(const Key('inside'))).color,
        const Color(0xffb3261e));
    expect(tester.widget<Container>(find.byKey(const Key('outside'))).color,
        outside);
    expect(find.text('#654321ff'), findsOneWidget);
  });

  testWidgets('nested scopes resolve independently and do not leak outward',
      (tester) async {
    final local = AuroraController(
        contract: contract,
        themes: themes,
        initialSelection: const AuroraSelection(themeId: 'red'),
        fallback: AuroraVariantFallback.reject);
    addTearDown(local.dispose);
    await tester.pumpWidget(AuroraEngine(
        controller: controller,
        builder: (context, theme) => MaterialApp(
              theme: theme,
              home: Column(children: [
                probe('outer'),
                AuroraScope(controller: local, child: probe('inner'))
              ]),
            )));
    expect(tester.widget<Container>(find.byKey(const Key('outer'))).color,
        const Color(0xff146c2e));
    expect(tester.widget<Container>(find.byKey(const Key('inner'))).color,
        const Color(0xffb3261e));
    local.select(const AuroraSelection(themeId: 'green'));
    await tester.pumpAndSettle();
    expect(controller.state.selection.themeId, 'green');
    controller.select(const AuroraSelection(themeId: 'red'));
    await tester.pumpAndSettle();
    expect(tester.widget<Container>(find.byKey(const Key('outer'))).color,
        const Color(0xffb3261e));
    expect(tester.widget<Container>(find.byKey(const Key('inner'))).color,
        const Color(0xff146c2e));
  });

  testWidgets('scope composition callback retains deliberate app styling',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: AuroraScope(
      controller: controller,
      themeBuilder: (context, variant) => variant.toThemeData().copyWith(
            visualDensity: VisualDensity.compact,
            textTheme: const TextTheme(bodyMedium: TextStyle(fontSize: 31)),
          ),
      child: probe('inside'),
    )));
    final theme = Theme.of(tester.element(find.byKey(const Key('inside'))));
    expect(theme.visualDensity, VisualDensity.compact);
    expect(theme.textTheme.bodyMedium!.fontSize, 31);
    expect(theme.colorScheme.primary, const Color(0xff146c2e));
  });

  testWidgets(
      'managed engine preserves selection on rebuild and disposes its controller',
      (tester) async {
    late AuroraController owned;
    Widget app() => AuroraEngine.managed(
          contract: contract,
          themes: themes,
          initialSelection: const AuroraSelection(themeId: 'green'),
          fallback: AuroraVariantFallback.reject,
          builder: (context, theme) {
            owned = Aurora.controllerOf(context);
            return MaterialApp(theme: theme, home: probe('managed'));
          },
        );
    await tester.pumpWidget(app());
    final original = owned;
    owned.select(const AuroraSelection(themeId: 'red'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(app());
    expect(owned, same(original));
    expect(owned.state.selection.themeId, 'red');
    await tester.pumpWidget(const SizedBox());
    expect(() => owned.select(const AuroraSelection(themeId: 'green')),
        throwsStateError);
  });

  testWidgets('managed configuration changes require a new engine key',
      (tester) async {
    Widget app(List<AuroraTheme> registry) => AuroraEngine.managed(
          contract: contract,
          themes: registry,
          initialSelection: const AuroraSelection(themeId: 'green'),
          fallback: AuroraVariantFallback.reject,
          builder: (context, theme) =>
              MaterialApp(theme: theme, home: probe('app')),
        );
    await tester.pumpWidget(app(themes));
    await tester.pumpWidget(app([themes.first]));
    expect(tester.takeException(), isA<FlutterError>());
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('replacing an injected controller detaches the previous one',
      (tester) async {
    final replacement = AuroraController(
        contract: contract,
        themes: themes,
        initialSelection: const AuroraSelection(themeId: 'red'),
        fallback: AuroraVariantFallback.reject);
    addTearDown(replacement.dispose);
    Widget app(AuroraController active) => AuroraEngine(
        controller: active,
        builder: (context, theme) =>
            MaterialApp(theme: theme, home: probe('app')));
    await tester.pumpWidget(app(controller));
    await tester.pumpWidget(app(replacement));
    await tester.pumpAndSettle();
    expect(tester.widget<Container>(find.byKey(const Key('app'))).color,
        const Color(0xffb3261e));
    controller.select(const AuroraSelection(themeId: 'red'));
    controller.select(const AuroraSelection(themeId: 'green'));
    await tester.pumpAndSettle();
    expect(tester.widget<Container>(find.byKey(const Key('app'))).color,
        const Color(0xffb3261e));
    replacement.select(const AuroraSelection(themeId: 'green'));
    await tester.pumpAndSettle();
    expect(tester.widget<Container>(find.byKey(const Key('app'))).color,
        const Color(0xff146c2e));
  });

  testWidgets('switching controller ownership disposes only owned controllers',
      (tester) async {
    late AuroraController owned;
    Widget builder(BuildContext context, ThemeData theme) {
      owned = Aurora.controllerOf(context);
      return MaterialApp(theme: theme, home: probe('app'));
    }

    Widget managed() => AuroraEngine.managed(
        contract: contract,
        themes: themes,
        initialSelection: const AuroraSelection(themeId: 'green'),
        fallback: AuroraVariantFallback.reject,
        builder: builder);
    await tester.pumpWidget(managed());
    final firstOwned = owned;
    await tester
        .pumpWidget(AuroraEngine(controller: controller, builder: builder));
    expect(() => firstOwned.select(const AuroraSelection(themeId: 'red')),
        throwsStateError);
    expect(owned, same(controller));
    await tester.pumpWidget(managed());
    expect(owned, isNot(same(controller)));
    controller.select(const AuroraSelection(themeId: 'red'));
    await tester.pumpWidget(const SizedBox());
    expect(() => owned.select(const AuroraSelection(themeId: 'red')),
        throwsStateError);
  });

  testWidgets('root dialogs can read and react to app-wide Aurora tokens',
      (tester) async {
    await tester.pumpWidget(AuroraEngine(
        controller: controller,
        builder: (context, theme) => MaterialApp(
            theme: theme,
            home: Builder(
                builder: (context) => Scaffold(
                      body: TextButton(
                          onPressed: () {
                            showDialog<void>(
                                context: context,
                                builder: (context) =>
                                    Dialog(child: probe('dialog')));
                          },
                          child: const Text('Open dialog')),
                    )))));
    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    expect(find.text('#123456ff'), findsOneWidget);
    controller.select(const AuroraSelection(themeId: 'red'));
    await tester.pumpAndSettle();
    expect(find.text('#654321ff'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('injected controller survives engine unmount', (tester) async {
    await tester.pumpWidget(AuroraEngine(
        controller: controller,
        builder: (context, theme) =>
            MaterialApp(theme: theme, home: probe('app'))));
    await tester.pumpWidget(const SizedBox());
    controller.select(const AuroraSelection(themeId: 'red'));
    expect(controller.state.selection.themeId, 'red');
  });

  testWidgets(
      'managed startup resolves device appearance before validating initial selection',
      (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final darkOnly = AuroraTheme(
        id: 'darkOnly',
        name: 'Dark only',
        variants: [themes.first.variants[AuroraAppearance.dark]!],
        preferredAppearance: AuroraAppearance.dark);
    await tester.pumpWidget(AuroraEngine.managed(
        contract: contract,
        themes: [darkOnly],
        initialSelection: const AuroraSelection(themeId: 'darkOnly'),
        fallback: AuroraVariantFallback.reject,
        builder: (context, theme) =>
            MaterialApp(theme: theme, home: probe('app'))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(Theme.of(tester.element(find.byKey(const Key('app')))).brightness,
        Brightness.dark);
    await tester.pumpWidget(const SizedBox());
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
    await tester.pumpAndSettle();
  });

  testWidgets('changing themes preserves navigation and page state',
      (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(AuroraEngine(
        controller: controller,
        builder: (context, theme) => MaterialApp(
            navigatorKey: navigator,
            theme: theme,
            home: const Scaffold(body: Text('Home')))));
    navigator.currentState!
        .push(MaterialPageRoute<void>(builder: (_) => const _CounterPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Increment'));
    await tester.pump();
    expect(find.text('Count 1'), findsOneWidget);
    controller.select(const AuroraSelection(themeId: 'red'));
    await tester.pumpAndSettle();
    expect(find.text('Count 1'), findsOneWidget);
    expect(navigator.currentState!.canPop(), isTrue);
    expect(Theme.of(tester.element(find.text('Count 1'))).colorScheme.primary,
        const Color(0xffb3261e));
  });

  testWidgets(
      'router integration retains router delegate and native app settings',
      (tester) async {
    final delegate = _TestRouter();
    addTearDown(delegate.dispose);
    final router = RouterConfig<Object>(routerDelegate: delegate);
    await tester.pumpWidget(AuroraEngine(
        controller: controller,
        themeBuilder: (context, variant) => variant
            .toThemeData()
            .copyWith(visualDensity: VisualDensity.compact),
        builder: (context, theme) => MaterialApp.router(
            routerConfig: router,
            theme: theme,
            locale: const Locale('en', 'GB'),
            supportedLocales: const [Locale('en', 'GB')],
            title: 'Existing app')));
    await tester.tap(find.text('Increment'));
    await tester.pump();
    controller.select(const AuroraSelection(themeId: 'red'));
    await tester.pumpAndSettle();
    expect(find.text('Count 1'), findsOneWidget);
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig,
        same(router));
    expect(Localizations.localeOf(tester.element(find.text('Count 1'))),
        const Locale('en', 'GB'));
    expect(Theme.of(tester.element(find.text('Count 1'))).visualDensity,
        VisualDensity.compact);
  });
}

class _CounterPage extends StatefulWidget {
  const _CounterPage();
  @override
  State<_CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<_CounterPage> {
  int count = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
          body: Column(children: [
        Text('Count $count'),
        TextButton(
            onPressed: () => setState(() => count++),
            child: const Text('Increment')),
      ]));
}

class _TestRouter extends RouterDelegate<Object>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<Object> {
  @override
  final navigatorKey = GlobalKey<NavigatorState>();
  @override
  Widget build(BuildContext context) => Navigator(
      key: navigatorKey,
      pages: const [MaterialPage<void>(child: _CounterPage())],
      onDidRemovePage: (_) {});
  @override
  Future<void> setNewRoutePath(Object configuration) async {}
}
