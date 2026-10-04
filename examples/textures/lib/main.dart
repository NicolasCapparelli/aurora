import 'package:aurora_flutter/aurora_flutter.dart';
import 'package:flutter/material.dart';
import 'tokens.dart';

void main() => runApp(const TexturesApp());

/// Theme (colours) and texture (type, shape, lines, layout). Each theme is
/// paired with a default texture; the user can pick another one explicitly.
class TexturesApp extends StatelessWidget {
  const TexturesApp({super.key});
  @override
  Widget build(BuildContext context) => AuroraEngine.managed(
        contract: feelThemeContract,
        themes: feelThemes,
        textures: feelTextures,
        texturePairings: const {'harbor': 'soft', 'ember': 'editorial'},
        initialSelection: const AuroraSelection(themeId: 'harbor'),
        fallback: AuroraVariantFallback.preferred,
        builder: (context, theme) => MaterialApp(
          title: 'Aurora Textures',
          theme: theme,
          home: const TexturesHome(),
        ),
      );
}

class TexturesHome extends StatelessWidget {
  const TexturesHome({super.key});

  @override
  Widget build(BuildContext context) {
    final texture = Aurora.textureOf(context);
    final controller = Aurora.controllerOf(context);
    final selection = controller.state.selection;
    // An empty texture id means "use the theme's paired texture".
    void select(
            {String? theme,
            String? textureId,
            AuroraAppearancePreference? appearance}) =>
        controller.select(AuroraSelection(
            themeId: theme ?? selection.themeId,
            textureId: textureId == null
                ? selection.textureId
                : (textureId.isEmpty ? null : textureId),
            appearance: appearance ?? selection.appearance));

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.symmetric(
              horizontal: texture.dimension(FeelTokens.screenMargin),
              vertical: 24),
          children: [
            Text('Trips', style: texture.textStyle(FeelTokens.pageTitle)),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final theme in controller.themes.values)
                _Choice(
                    label: theme.name,
                    selected: theme.id == selection.themeId,
                    onTap: () => select(theme: theme.id)),
              _Choice(
                  key: const Key('texture-default'),
                  label: 'Theme default',
                  selected: selection.textureId == null,
                  onTap: () => select(textureId: '')),
              for (final item in controller.textures.values)
                _Choice(
                    key: Key('texture-${item.id}'),
                    label: item.name,
                    selected: item.id == selection.textureId,
                    onTap: () => select(textureId: item.id)),
              for (final appearance in AuroraAppearancePreference.values)
                _Choice(
                    label: appearance.name,
                    selected: appearance == selection.appearance,
                    onTap: () => select(appearance: appearance)),
            ]),
            const SizedBox(height: 24),
            const FlightCard(from: 'LHR', to: 'JFK', airline: 'Aurora Air'),
            const SizedBox(height: 16),
            const FlightCard(from: 'JFK', to: 'SFO', airline: 'Aurora Air'),
          ],
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final texture = Aurora.textureOf(context);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      shape: RoundedRectangleBorder(
          borderRadius: texture.borderRadius(FeelTokens.chipRadius)),
    );
  }
}

/// A card whose font, corners, border texture, padding and layout all come from
/// the active texture, and whose colours come from the active theme.
class FlightCard extends StatelessWidget {
  const FlightCard(
      {super.key, required this.from, required this.to, required this.airline});
  final String from;
  final String to;
  final String airline;

  @override
  Widget build(BuildContext context) {
    final texture = Aurora.textureOf(context);
    final colors = Theme.of(context).colorScheme;
    final layout =
        texture.option(FeelTokens.flightCard, FlightCardLayout.values);
    final radius = texture.borderRadius(FeelTokens.cardRadius);
    final border = texture.read(FeelTokens.card);
    final emblem = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: colors.primary,
        shape: texture.option(FeelTokens.emblemShape, EmblemShape.values) ==
                EmblemShape.circle
            ? BoxShape.circle
            : BoxShape.rectangle,
        borderRadius:
            texture.option(FeelTokens.emblemShape, EmblemShape.values) ==
                    EmblemShape.circle
                ? null
                : BorderRadius.circular(6),
      ),
    );
    final route =
        Text('$from → $to', style: texture.textStyle(FeelTokens.routeCode));
    final kicker = Text(airline.toUpperCase(),
        style: texture
            .textStyle(FeelTokens.kicker)
            .copyWith(color: colors.onSurfaceVariant));
    final divider = DashedLine(
        color: colors.outlineVariant,
        pattern: texture.dashPattern(texture.strokeStyle(FeelTokens.divider),
            width: 1));
    return CustomPaint(
      key: const Key('flight-card'),
      foregroundPainter: texture.flag(FeelTokens.cardBorder)
          ? StrokePainter(
              color: texture.color(border.color),
              width: texture.toLogical(border.width),
              radius: radius,
              pattern: texture.dashPattern(border.style,
                  width: texture.toLogical(border.width)))
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: radius,
          boxShadow: texture.shadows(FeelTokens.cardShadow),
        ),
        padding: EdgeInsets.all(texture.dimension(FeelTokens.cardPadding)),
        child: switch (layout) {
          FlightCardLayout.compact => Row(children: [
              emblem,
              const SizedBox(width: 12),
              Expanded(child: route),
              kicker,
            ]),
          _ => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [emblem, const SizedBox(width: 12), kicker]),
              const SizedBox(height: 12),
              divider,
              const SizedBox(height: 12),
              route,
              Text('Departs 09:40 · Gate 22',
                  style: texture.textStyle(FeelTokens.body)),
            ]),
        },
      ),
    );
  }
}

/// Paints a rounded-rectangle outline, dashed when [pattern] is nonempty and
/// nothing when it is empty (`none`).
class StrokePainter extends CustomPainter {
  StrokePainter(
      {required this.color,
      required this.width,
      required this.radius,
      required this.pattern});
  final Color color;
  final double width;
  final BorderRadius radius;
  final List<double>? pattern;

  @override
  void paint(Canvas canvas, Size size) {
    if (width == 0 || (pattern?.isEmpty ?? false)) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    final path = Path()
      ..addRRect(radius.toRRect(Offset.zero & size).deflate(width / 2));
    canvas.drawPath(pattern == null ? path : _dash(path, pattern!), paint);
  }

  @override
  bool shouldRepaint(StrokePainter old) =>
      old.color != color ||
      old.width != width ||
      old.radius != radius ||
      old.pattern != pattern;
}

class DashedLine extends StatelessWidget {
  const DashedLine({super.key, required this.color, required this.pattern});
  final Color color;
  final List<double>? pattern;
  @override
  Widget build(BuildContext context) => SizedBox(
      height: 1,
      width: double.infinity,
      child: CustomPaint(painter: _LinePainter(color, pattern)));
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.color, this.pattern);
  final Color color;
  final List<double>? pattern;
  @override
  void paint(Canvas canvas, Size size) {
    if (pattern?.isEmpty ?? false) return;
    final path = Path()
      ..moveTo(0, 0.5)
      ..lineTo(size.width, 0.5);
    canvas.drawPath(
        pattern == null ? path : _dash(path, pattern!),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.color != color || old.pattern != pattern;
}

Path _dash(Path source, List<double> pattern) {
  final result = Path();
  for (final metric in source.computeMetrics()) {
    var distance = 0.0;
    var index = 0;
    while (distance < metric.length) {
      final length = pattern[index % pattern.length];
      if (index.isEven) {
        result.addPath(
            metric.extractPath(distance, distance + length), Offset.zero);
      }
      distance += length == 0 ? 1 : length;
      index++;
    }
  }
  return result;
}
