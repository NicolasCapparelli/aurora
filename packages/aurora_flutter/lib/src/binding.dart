import 'package:aurora/aurora.dart';
import 'package:flutter/widgets.dart';
import 'controller.dart';

/// Adapter plumbing shared by scope and engine; not part of the public API.
class AuroraBinding extends StatefulWidget {
  const AuroraBinding(
      {super.key, required this.controller, required this.builder});
  final AuroraController controller;
  final WidgetBuilder builder;
  @override
  State<AuroraBinding> createState() => _AuroraBindingState();
}

class _AuroraBindingState extends State<AuroraBinding>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    _syncAppearance();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(AuroraBinding oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) _syncAppearance();
  }

  void _syncAppearance() => widget.controller.setSystemAppearance(
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                Brightness.dark
            ? AuroraAppearance.dark
            : AuroraAppearance.light,
      );

  @override
  void didChangePlatformBrightness() => _syncAppearance();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuroraInherited(
        notifier: widget.controller,
        child: Builder(builder: widget.builder),
      );
}

class AuroraInherited extends InheritedNotifier<AuroraController> {
  const AuroraInherited({super.notifier, this.variant, required super.child});
  final AuroraThemeVariant? variant;

  @override
  bool updateShouldNotify(AuroraInherited oldWidget) =>
      !identical(variant, oldWidget.variant) ||
      super.updateShouldNotify(oldWidget);
}
