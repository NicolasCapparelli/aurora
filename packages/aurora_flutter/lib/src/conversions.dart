import 'package:aurora/aurora.dart';
import 'package:flutter/material.dart';

extension AuroraColorFromFlutter on Color {
  AuroraColor get auroraColor => AuroraColor(toARGB32());
}

/// Flutter-specific conversion stays outside the pure Dart appearance enum.
extension AuroraFlutterAppearance on AuroraAppearance {
  Brightness get brightness =>
      this == AuroraAppearance.dark ? Brightness.dark : Brightness.light;

  static AuroraAppearance fromBrightness(Brightness brightness) =>
      brightness == Brightness.dark
          ? AuroraAppearance.dark
          : AuroraAppearance.light;
}
