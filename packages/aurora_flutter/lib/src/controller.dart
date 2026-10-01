import 'dart:async';
import 'package:aurora/aurora.dart';
import 'package:flutter/widgets.dart';

/// Owns the pure Dart runtime and synchronously notifies accepted mutations.
final class AuroraController extends ChangeNotifier {
  AuroraController({
    required AuroraContract contract,
    required Iterable<AuroraTheme> themes,
    required AuroraSelection initialSelection,
    required AuroraVariantFallback fallback,
    AuroraAppearance? systemAppearance,
  }) : _runtime = AuroraRuntime(
          contract: contract,
          themes: themes,
          initialSelection: initialSelection,
          fallback: fallback,
          systemAppearance: systemAppearance ??
              (WidgetsFlutterBinding.ensureInitialized()
                          .platformDispatcher
                          .platformBrightness ==
                      Brightness.dark
                  ? AuroraAppearance.dark
                  : AuroraAppearance.light),
        );

  final AuroraRuntime _runtime;
  AuroraContract get contract => _runtime.contract;
  AuroraState get state => _runtime.state;
  Map<String, AuroraTheme> get themes => _runtime.themes;
  void select(AuroraSelection selection) {
    final previous = state;
    _runtime.select(selection);
    if (!identical(previous, state)) notifyListeners();
  }

  void setSystemAppearance(AuroraAppearance appearance) {
    final previous = state;
    _runtime.setSystemAppearance(appearance);
    if (!identical(previous, state)) notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_runtime.dispose());
    super.dispose();
  }
}
