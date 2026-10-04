import 'package:aurora/aurora.dart';
import 'package:flutter/material.dart';
import 'binding.dart';
import 'controller.dart';
import 'material.dart';
import 'texture.dart';

/// Compose app typography, shapes, and deliberate overrides with active colors.
typedef AuroraThemeBuilder = ThemeData Function(
    BuildContext context, AuroraThemeVariant variant);

/// Reactive access to the nearest scope or engine. Call inside build.
abstract final class Aurora {
  static AuroraThemeVariant of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuroraInherited>();
    if (scope == null) {
      throw FlutterError(
          'Aurora access requires an AuroraScope or AuroraEngine ancestor.');
    }
    return scope.variant ?? scope.notifier!.state.variant;
  }

  static AuroraTokens tokensOf(BuildContext context) => of(context).tokens;

  /// The active texture, bound to the active variant. Rebuilds on theme,
  /// appearance and texture changes. Throws when no texture is active.
  static AuroraTextureTokens textureOf(BuildContext context) =>
      maybeTextureOf(context) ??
      (throw FlutterError(
          'No Aurora texture is active. Register textures on the '
          'engine or controller, or pass a texture to AuroraScope.fixed.'));

  /// [textureOf], or null when the app uses no textures.
  static AuroraTextureTokens? maybeTextureOf(BuildContext context) {
    final scope = _scope(context);
    final variant = scope.variant ?? scope.notifier!.state.variant;
    final texture =
        scope.variant != null ? scope.texture : scope.notifier!.state.texture;
    return texture == null ? null : _textureTokens(texture, variant);
  }

  static AuroraInherited _scope(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AuroraInherited>() ??
      (throw FlutterError(
          'Aurora access requires an AuroraScope or AuroraEngine ancestor.'));

  static final _cache = Expando<Map<AuroraTexture, AuroraTextureTokens>>();
  static AuroraTextureTokens _textureTokens(
          AuroraTexture texture, AuroraThemeVariant variant) =>
      (_cache[variant] ??= {})[texture] ??=
          AuroraTextureTokens(texture, variant);

  static AuroraController controllerOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuroraInherited>();
    if (scope == null)
      throw FlutterError(
          'Aurora access requires an AuroraScope or AuroraEngine ancestor.');
    if (scope.notifier == null) {
      throw FlutterError('AuroraScope.fixed has no selection controller.');
    }
    return scope.notifier!;
  }
}

/// Applies Aurora tokens and native Material theming to a subtree.
/// The caller owns the controller. Nested scopes may use independent controllers.
class AuroraScope extends StatelessWidget {
  const AuroraScope(
      {super.key,
      required this.controller,
      required this.child,
      this.themeBuilder})
      : variant = null,
        texture = null;

  /// A snapshot preview with no controller or device-brightness subscription.
  /// Pass [texture] to preview a texture with this variant.
  const AuroraScope.fixed(
      {super.key,
      required AuroraThemeVariant variant,
      this.texture,
      required this.child,
      this.themeBuilder})
      : variant = variant,
        controller = null;
  final AuroraController? controller;
  final AuroraThemeVariant? variant;
  final AuroraTexture? texture;
  final Widget child;
  final AuroraThemeBuilder? themeBuilder;

  @override
  Widget build(BuildContext context) {
    if (variant != null) {
      return AuroraInherited(
          variant: variant,
          texture: texture,
          child: Builder(
              builder: (context) => Theme(
                  data: themeBuilder?.call(context, variant!) ??
                      auroraDefaultThemeData(context),
                  child: child)));
    }
    return AuroraBinding(
      controller: controller!,
      builder: (context) {
        final variant = Aurora.of(context);
        return Theme(
          data: themeBuilder?.call(context, variant) ??
              auroraDefaultThemeData(context),
          child: child,
        );
      },
    );
  }
}

/// Colour-only ThemeData, with the texture foundation applied when a texture is
/// active.
ThemeData auroraDefaultThemeData(BuildContext context) {
  final theme = Aurora.of(context).toThemeData();
  return Aurora.maybeTextureOf(context)?.applyTo(theme) ?? theme;
}
