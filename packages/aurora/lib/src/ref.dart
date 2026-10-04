import 'token.dart';

/// A value or a reference to another token of the same value type.
///
/// Aurora's texture value classes (such as `AuroraDimension`) are their own
/// literal references, so they can be used directly wherever a reference is
/// accepted. Wrap primitive values (numbers, booleans, strings, durations) in
/// [AuroraLiteral]. Use [AuroraAlias] to refer to another declared token.
abstract class AuroraRef<T> {
  const AuroraRef();
}

/// A literal primitive value, such as a line height of `1.4`.
final class AuroraLiteral<T> extends AuroraRef<T> {
  const AuroraLiteral(this.value);
  final T value;

  @override
  bool operator ==(Object other) =>
      other is AuroraLiteral && other.value == value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => '$value';
}

/// A reference to [target]. Aliases between texture tokens resolve when a texture
/// is constructed. An alias to a colour token inside a texture refers to the
/// active theme and resolves against the active theme variant.
final class AuroraAlias<T> extends AuroraRef<T> {
  const AuroraAlias(this.target);
  final AuroraToken<T> target;

  @override
  bool operator ==(Object other) =>
      other is AuroraAlias &&
      other.target.path == target.path &&
      other.target.runtimeType == target.runtimeType;
  @override
  int get hashCode => Object.hash(target.path, target.runtimeType);
  @override
  String toString() => '{${target.path}}';
}
