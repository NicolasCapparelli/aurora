import 'package:aurora/aurora.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'binding.dart';
import 'controller.dart';
import 'scope.dart';

/// Retain your MaterialApp or MaterialApp.router configuration in this builder.
typedef AuroraAppBuilder = Widget Function(
    BuildContext context, ThemeData theme);

/// Coordinates app-wide theme access and device appearance.
/// Pass the supplied ThemeData into your app's theme property.
class AuroraEngine extends StatefulWidget {
  /// Uses a caller-owned controller; never disposes it.
  const AuroraEngine({
    super.key,
    required AuroraController controller,
    required this.builder,
    this.themeBuilder,
  })  : controller = controller,
        contract = null,
        themes = null,
        initialSelection = null,
        fallback = null,
        textures = null,
        texturePairings = null;

  /// Creates and disposes a controller once for this engine's lifetime.
  /// Configuration is fixed while mounted; select themes via controllerOf.
  /// Use a new widget key to install a different contract or theme registry.
  AuroraEngine.managed({
    super.key,
    required AuroraContract contract,
    required Iterable<AuroraTheme> themes,
    required AuroraSelection initialSelection,
    required AuroraVariantFallback fallback,
    Iterable<AuroraTexture> textures = const [],
    Map<String, String> texturePairings = const {},
    required this.builder,
    this.themeBuilder,
  })  : controller = null,
        contract = contract,
        themes = List.unmodifiable(themes),
        initialSelection = initialSelection,
        fallback = fallback,
        textures = List.unmodifiable(textures),
        texturePairings = Map.unmodifiable(texturePairings);

  final AuroraController? controller;
  final AuroraContract? contract;
  final List<AuroraTheme>? themes;
  final AuroraSelection? initialSelection;
  final AuroraVariantFallback? fallback;

  /// Selectable textures for a managed engine; empty when the app uses none.
  final List<AuroraTexture>? textures;

  /// Initial theme-to-texture pairings for a managed engine. Change them at
  /// runtime with `Aurora.controllerOf(context).pairTexture`.
  final Map<String, String>? texturePairings;
  final AuroraAppBuilder builder;
  final AuroraThemeBuilder? themeBuilder;

  @override
  State<AuroraEngine> createState() => _AuroraEngineState();
}

class _AuroraEngineState extends State<AuroraEngine> {
  late AuroraController _controller;
  bool _ownsController = false;

  void _attach() {
    _ownsController = false;
    _controller = widget.controller ??
        AuroraController(
          contract: widget.contract!,
          themes: widget.themes!,
          initialSelection: widget.initialSelection!,
          fallback: widget.fallback!,
          textures: widget.textures!,
          texturePairings: widget.texturePairings!,
          systemAppearance:
              WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                      Brightness.dark
                  ? AuroraAppearance.dark
                  : AuroraAppearance.light,
        );
    _ownsController = widget.controller == null;
  }

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(AuroraEngine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller == null && oldWidget.controller == null) {
      final oldSelection = oldWidget.initialSelection!;
      final selection = widget.initialSelection!;
      if (!identical(widget.contract, oldWidget.contract) ||
          !listEquals(widget.themes, oldWidget.themes) ||
          !listEquals(widget.textures, oldWidget.textures) ||
          !mapEquals(widget.texturePairings, oldWidget.texturePairings) ||
          widget.fallback != oldWidget.fallback ||
          selection.themeId != oldSelection.themeId ||
          selection.appearance != oldSelection.appearance ||
          selection.textureId != oldSelection.textureId) {
        throw FlutterError(
            'AuroraEngine.managed configuration is fixed while mounted. '
            'Use Aurora.controllerOf(context).select(...) for selection changes, '
            'or a new engine key for a different configuration.');
      }
    } else if (!identical(widget.controller, oldWidget.controller)) {
      if (_ownsController) _controller.dispose();
      _attach();
    }
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuroraBinding(
        controller: _controller,
        builder: (context) {
          final variant = Aurora.of(context);
          final theme = widget.themeBuilder?.call(context, variant) ??
              auroraDefaultThemeData(context);
          return widget.builder(context, theme);
        },
      );
}
