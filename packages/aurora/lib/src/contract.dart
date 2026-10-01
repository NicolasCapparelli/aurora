import 'foundation.dart';

/// A typed color field. Declare app tokens once, then reuse those declarations.
final class AuroraColorToken {
  const AuroraColorToken(this.path, {required this.description});
  final String path;
  final String description;
  @override
  String toString() => path;
}

/// Foundation plus app-owned additions. Every declared token is required.
final class AuroraContract {
  factory AuroraContract({
    required String id,
    int version = 1,
    Iterable<AuroraColorToken> extensions = const [],
  }) {
    if (id.trim().isEmpty || version < 1) {
      throw ArgumentError(
          'Contract needs a nonempty id and a positive version');
    }
    final tokens = <String, AuroraColorToken>{};
    for (final token in [...AuroraFoundation.tokens, ...extensions]) {
      if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)*$')
              .hasMatch(token.path) ||
          token.description.trim().isEmpty) {
        throw ArgumentError(
            'Token ${token.path} needs a valid dotted path and description');
      }
      if (tokens.containsKey(token.path)) {
        throw ArgumentError('Duplicate or redefined token: ${token.path}');
      }
      if (!AuroraFoundation.tokens.contains(token) &&
          token.path.startsWith('colors.')) {
        throw ArgumentError(
            'The colors namespace belongs to Aurora: ${token.path}');
      }
      if (tokens.keys.any((path) =>
          path.startsWith('${token.path}.') ||
          token.path.startsWith('$path.'))) {
        throw ArgumentError('Token/group path collision: ${token.path}');
      }
      tokens[token.path] = token;
    }
    return AuroraContract._(id, version, Map.unmodifiable(tokens));
  }

  AuroraContract._(this.id, this.version, this.tokens);
  final String id;
  final int version;
  final Map<String, AuroraColorToken> tokens;

  bool contains(AuroraColorToken token) => identical(tokens[token.path], token);
}

/// Reports all completeness/type errors rather than failing at the first field.
final class AuroraValidationException implements Exception {
  AuroraValidationException(Iterable<String> issues)
      : issues = List.unmodifiable(issues);
  final List<String> issues;
  @override
  String toString() =>
      'Aurora validation failed:\n${issues.map((e) => '- $e').join('\n')}';
}
