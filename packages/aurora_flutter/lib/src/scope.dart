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
  static AuroraThemeVariant of(BuildContext context) =>
      controllerOf(context).state.variant;
  static AuroraTokens tokensOf(BuildContext context) => of(context).tokens;

  static AuroraController controllerOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuroraInherited>();
    if (scope == null)
      throw FlutterError(
          'Aurora access requires an AuroraScope or AuroraEngine ancestor.');
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
      this.themeBuilder});
  final AuroraController controller;
  final Widget child;
  final AuroraThemeBuilder? themeBuilder;

  @override
  Widget build(BuildContext context) => AuroraBinding(
        controller: controller,
        builder: (context) {
          final variant = Aurora.of(context);
          return Theme(
            data: themeBuilder?.call(context, variant) ?? variant.toThemeData(),
            child: child,
          );
        },
      );
}
