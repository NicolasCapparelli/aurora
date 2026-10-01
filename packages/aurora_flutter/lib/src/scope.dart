import 'package:aurora/aurora.dart';
import 'package:flutter/material.dart';
import 'binding.dart';
import 'controller.dart';
import 'material.dart';

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
      : variant = null;

  /// A snapshot preview with no controller or device-brightness subscription.
  const AuroraScope.fixed(
      {super.key,
      required AuroraThemeVariant variant,
      required this.child,
      this.themeBuilder})
      : variant = variant,
        controller = null;
  final AuroraController? controller;
  final AuroraThemeVariant? variant;
  final Widget child;
  final AuroraThemeBuilder? themeBuilder;

  @override
  Widget build(BuildContext context) {
    if (variant != null) {
      return AuroraInherited(
          variant: variant,
          child: Builder(
              builder: (context) => Theme(
                  data: themeBuilder?.call(context, variant!) ??
                      variant!.toThemeData(),
                  child: child)));
    }
    return AuroraBinding(
      controller: controller!,
      builder: (context) {
        final variant = Aurora.of(context);
        return Theme(
          data: themeBuilder?.call(context, variant) ?? variant.toThemeData(),
          child: child,
        );
      },
    );
  }
}
