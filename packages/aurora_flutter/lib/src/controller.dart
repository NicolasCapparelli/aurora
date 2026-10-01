import 'dart:async';
import 'package:aurora/aurora.dart';
import 'package:flutter/foundation.dart';

/// Owns the pure Dart runtime and bridges its changes to Flutter.
final class AuroraController extends ChangeNotifier {
  AuroraController({
    required AuroraContract contract,
    required Iterable<AuroraTheme> themes,
    required AuroraSelection initialSelection,
    required AuroraVariantFallback fallback,
    AuroraAppearance systemAppearance = AuroraAppearance.light,
  }) : _runtime = AuroraRuntime(
          contract: contract,
          themes: themes,
          initialSelection: initialSelection,
          fallback: fallback,
          systemAppearance: systemAppearance,
        ) {
    _subscription = _runtime.changes.listen((_) => notifyListeners());
  }

  final AuroraRuntime _runtime;
  late final StreamSubscription<AuroraState> _subscription;
  AuroraState get state => _runtime.state;
  Map<String, AuroraTheme> get themes => _runtime.themes;
  void select(AuroraSelection selection) => _runtime.select(selection);
  void setSystemAppearance(AuroraAppearance appearance) =>
      _runtime.setSystemAppearance(appearance);

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    unawaited(_runtime.dispose());
    super.dispose();
  }
}
