import 'package:aurora_flutter/aurora_flutter.dart';
import 'package:flutter/material.dart';

/// Declare extensions once, as part of the app's single contract.
abstract final class TheaterTokens {
  static const ticketBackground = AuroraColorToken(
    'theater.ticketBackground',
    description: 'Background of a theater ticket.',
  );
  static const onTicket = AuroraColorToken(
    'theater.onTicket',
    description: 'Text and icons on a theater ticket.',
  );
}

final theaterContract = AuroraContract(
  id: 'theater',
  extensions: [TheaterTokens.ticketBackground, TheaterTokens.onTicket],
);

/// Illustrative palettes inspired by the shows, not official brand palettes.
AuroraTheme showTheme(
    String id, String name, String accent, String darkAccent) {
  return AuroraTheme(
    id: id,
    name: name,
    preferredAppearance: AuroraAppearance.dark,
    variants: [
      for (final appearance in AuroraAppearance.values)
        AuroraStarter.variant(
          contract: theaterContract,
          appearance: appearance,
          values: {
            AuroraFoundation.primary: AuroraColor.hex(
                appearance == AuroraAppearance.light ? accent : darkAccent),
            AuroraFoundation.onPrimary: AuroraColor.hex(
                appearance == AuroraAppearance.light ? '#ffffff' : '#101510'),
            AuroraFoundation.surfaceTint: AuroraColor.hex(
                appearance == AuroraAppearance.light ? accent : darkAccent),
            TheaterTokens.ticketBackground: AuroraColor.hex(
                appearance == AuroraAppearance.light ? '#fff4d6' : '#342b18'),
            TheaterTokens.onTicket: AuroraColor.hex(
                appearance == AuroraAppearance.light ? '#302713' : '#fff4d6'),
          },
        ),
    ],
  );
}

void main() => runApp(const TheaterApp());

final theaterThemes = [
  showTheme('wicked', 'Wicked', '#246b35', '#8bd996'),
  showTheme('hadestown', 'Hadestown', '#9a3412', '#ffb59c'),
];

class TheaterApp extends StatelessWidget {
  const TheaterApp({super.key});
  @override
  Widget build(BuildContext context) => AuroraEngine.managed(
        contract: theaterContract,
        themes: theaterThemes,
        initialSelection: const AuroraSelection(themeId: 'wicked'),
        fallback: AuroraVariantFallback.preferred,
        builder: (context, theme) => MaterialApp(
          title: 'Aurora Theater',
          theme: theme,
          home: const TheaterHome(),
        ),
      );
}

class TheaterHome extends StatelessWidget {
  const TheaterHome({super.key});
  @override
  Widget build(BuildContext context) {
    final tokens = Aurora.tokensOf(context);
    final controller = Aurora.controllerOf(context);
    final selection = controller.state.selection;
    return Scaffold(
      appBar: AppBar(title: Text('Aurora · ${controller.state.theme.name}')),
      body: Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButton<String>(
              value: selection.themeId,
              isExpanded: true,
              items: controller.themes.values
                  .map((theme) => DropdownMenuItem(
                      value: theme.id, child: Text(theme.name)))
                  .toList(),
              onChanged: (id) {
                if (id != null)
                  controller.select(AuroraSelection(
                      themeId: id, appearance: selection.appearance));
              },
            ),
            DropdownButton<AuroraAppearancePreference>(
              value: selection.appearance,
              isExpanded: true,
              items: AuroraAppearancePreference.values
                  .map((appearance) => DropdownMenuItem(
                      value: appearance, child: Text(appearance.name)))
                  .toList(),
              onChanged: (appearance) {
                if (appearance != null)
                  controller.select(AuroraSelection(
                      themeId: selection.themeId, appearance: appearance));
              },
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              color: tokens.read(TheaterTokens.ticketBackground).flutterColor,
              child: Text('Your seat is waiting.',
                  style: TextStyle(
                      color: tokens.read(TheaterTokens.onTicket).flutterColor)),
            ),
            const SizedBox(height: 24),
            FilledButton(
                onPressed: () {}, child: const Text('Reserve a ticket')),
          ]),
        ),
      )),
    );
  }
}
