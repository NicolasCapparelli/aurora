import 'color.dart';
import 'contract.dart';
import 'theme.dart';

/// DTCG 2025.10 color profile: groups, sRGB colors, and whole-token aliases.
/// One document represents one variant. Identity/appearance live outside it.
/// Unsupported constructs fail explicitly; this is not a full DTCG resolver.
abstract final class AuroraDtcg {
  static Map<String, Object?> encode(AuroraThemeVariant variant) {
    final document = <String, Object?>{};
    for (final entry in variant.values.entries) {
      var group = document;
      final parts = entry.key.path.split('.');
      for (final part in parts.take(parts.length - 1)) {
        group = group.putIfAbsent(part, () => <String, Object?>{})
            as Map<String, Object?>;
      }
      group[parts.last] = <String, Object?>{
        r'$type': 'color',
        r'$description': entry.key.description,
        r'$value': encodeColorValue(entry.value),
      };
    }
    return document;
  }

  static AuroraThemeVariant decode(
    Map<String, Object?> document, {
    required AuroraContract contract,
    required AuroraAppearance appearance,
  }) {
    final raw = <String, ({Object? value, Object? type})>{};
    void visit(Map<String, Object?> node, String path, Object? inheritedType) {
      if (node.containsKey(r'$type') && node[r'$type'] is! String) {
        throw FormatException('Invalid token type at $path');
      }
      if (node.containsKey(r'$description') &&
          node[r'$description'] is! String) {
        throw FormatException('Invalid description at $path');
      }
      if (node.containsKey(r'$extensions') &&
          node[r'$extensions'] is! Map<String, Object?>) {
        throw FormatException('Invalid extensions metadata at $path');
      }
      if (node.containsKey(r'$deprecated') &&
          node[r'$deprecated'] is! bool &&
          node[r'$deprecated'] is! String) {
        throw FormatException('Invalid deprecation metadata at $path');
      }
      final type = node[r'$type'] ?? inheritedType;
      for (final key in node.keys.where((key) => key.startsWith(r'$'))) {
        if (!{
          r'$type',
          r'$value',
          r'$description',
          r'$extensions',
          r'$deprecated'
        }.contains(key)) {
          throw FormatException('Unsupported DTCG property $key at $path');
        }
      }
      if (node.containsKey(r'$value')) {
        if (path.isEmpty || node.keys.any((key) => !key.startsWith(r'$'))) {
          throw FormatException('Invalid token/group structure at $path');
        }
        if (type != null && type != 'color')
          throw FormatException('Unsupported type $type at $path');
        raw[path] = (value: node[r'$value'], type: type);
        return;
      }
      for (final entry
          in node.entries.where((entry) => !entry.key.startsWith(r'$'))) {
        if (entry.key.contains('.') || entry.value is! Map<String, Object?>) {
          throw FormatException(
              'Expected a named group or token at $path.${entry.key}');
        }
        visit(entry.value as Map<String, Object?>,
            path.isEmpty ? entry.key : '$path.${entry.key}', type);
      }
    }

    visit(document, '', null);
    final issues = <String>[];
    for (final path in contract.tokens.keys) {
      if (!raw.containsKey(path)) issues.add('Missing required token $path');
    }
    for (final path in raw.keys) {
      if (!contract.tokens.containsKey(path))
        issues.add('Undeclared token $path');
    }
    if (issues.isNotEmpty) throw AuroraValidationException(issues);

    final resolved = <String, AuroraColor>{};
    final visiting = <String>{};
    AuroraColor resolve(String path) {
      if (resolved.containsKey(path)) return resolved[path]!;
      final token = raw[path];
      if (token == null) throw FormatException('Unknown alias target $path');
      if (!visiting.add(path))
        throw FormatException('Cyclic token alias at $path');
      final value = token.value;
      AuroraColor color;
      if (value is String) {
        final reference =
            RegExp(r'^\{([a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)*)\}$')
                .firstMatch(value);
        if (reference == null)
          throw FormatException('Expected a whole-token alias at $path');
        color = resolve(reference.group(1)!);
      } else {
        if (token.type != 'color')
          throw FormatException('Missing color type at $path');
        color = decodeColorValue(value, path);
      }
      visiting.remove(path);
      return resolved[path] = color;
    }

    return AuroraThemeVariant(
      contract: contract,
      appearance: appearance,
      values: {
        for (final token in contract.tokens.values) token: resolve(token.path)
      },
    );
  }

  /// The structured sRGB `$value` for [color].
  static Map<String, Object?> encodeColorValue(AuroraColor color) =>
      <String, Object?>{
        'colorSpace': 'srgb',
        'components': [color.red / 255, color.green / 255, color.blue / 255],
        'alpha': color.alpha / 255,
      };

  /// Decodes a structured sRGB `$value`; [path] names it in errors.
  static AuroraColor decodeColorValue(Object? raw, String path) {
    if (raw is! Map<String, Object?> || raw['colorSpace'] != 'srgb') {
      throw FormatException('Expected a structured sRGB color at $path');
    }
    if (raw.keys.any(
        (key) => !{'colorSpace', 'components', 'alpha', 'hex'}.contains(key))) {
      throw FormatException('Unsupported color property at $path');
    }
    final components = raw['components'];
    if (components is! List || components.length != 3) {
      throw FormatException('Expected three sRGB components at $path');
    }
    int channel(Object? value) {
      if (value is! num || !value.isFinite || value < 0 || value > 1) {
        throw FormatException(
            'Expected a finite color channel in [0, 1] at $path');
      }
      return (value * 255).round();
    }

    final red = channel(components[0]);
    final green = channel(components[1]);
    final blue = channel(components[2]);
    final alpha = channel(raw.containsKey('alpha') ? raw['alpha'] : 1);
    if (raw.containsKey('hex')) {
      final hex = raw['hex'];
      if (hex is! String || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) {
        throw FormatException('Invalid optional hex fallback at $path');
      }
    }
    return AuroraColor((alpha << 24) | (red << 16) | (green << 8) | blue);
  }
}
