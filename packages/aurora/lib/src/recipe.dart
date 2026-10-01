import 'color.dart';
import 'contract.dart';
import 'contrast.dart';
import 'generator.dart';
import 'theme.dart';

/// Portable authoring recipe shared by agents and other generator interfaces.
abstract final class AuroraRecipe {
  static AuroraGenerationRequest decode(Map<String, dynamic> input) {
    _fields(
        input,
        {
          'schemaVersion',
          'id',
          'name',
          'primary',
          'scheme',
          'secondary',
          'tertiary',
          'success',
          'warning',
          'info',
          'appearance',
          'preferredAppearance',
          'contract',
          'values',
          'variantValues',
          'rules',
          'contrastPairs'
        },
        'recipe');
    if (input['schemaVersion'] != 1)
      throw const FormatException('Expected recipe schemaVersion 1');
    final definition =
        _map(input['contract'] ?? {'id': 'aurora-foundation'}, 'contract');
    _fields(definition, {'id', 'version', 'extensions'}, 'contract');
    final version = definition['version'] ?? 1;
    if (version is! int)
      throw const FormatException('Contract version must be an integer');
    final extensions = <AuroraColorToken>[];
    for (final item in _list(definition['extensions'] ?? [], 'extensions')) {
      final token = _map(item, 'extension');
      _fields(token, {'path', 'description'}, 'extension');
      extensions.add(AuroraColorToken(_text(token['path'], 'path'),
          description: _text(token['description'], 'description')));
    }
    final contract = AuroraContract(
        id: _text(definition['id'], 'contract.id'),
        version: version,
        extensions: extensions);
    AuroraColorToken token(String path) =>
        contract.tokens[path] ??
        (throw FormatException('Undeclared token $path'));
    Map<AuroraColorToken, AuroraColor> values(Object? source) => {
          for (final entry in _map(source ?? {}, 'values').entries)
            token(entry.key): AuroraColor.hex(_text(entry.value, entry.key)),
        };
    AuroraAppearance appearance(Object? value) {
      final name = _text(value, 'appearance');
      if (!['light', 'dark'].contains(name))
        throw const FormatException('Expected light or dark');
      return AuroraAppearance.values.byName(name);
    }

    final mode = input['appearance'] ?? 'both';
    final modes = mode == 'both' ? AuroraAppearance.values : [appearance(mode)];
    final rules = <AuroraColorToken, AuroraTokenRule>{};
    for (final entry in _map(input['rules'] ?? {}, 'rules').entries) {
      final rule = _map(entry.value, 'rule');
      if (rule.containsKey('alias')) {
        _fields(rule, {'alias'}, 'alias rule');
        rules[token(entry.key)] =
            AuroraAliasRule(token(_text(rule['alias'], 'alias')));
      } else {
        _fields(rule, {'palette', 'lightTone', 'darkTone'}, 'tone rule');
        final palette = _text(rule['palette'], 'palette');
        if (!AuroraPalette.values.any((value) => value.name == palette))
          throw FormatException('Unknown palette $palette');
        rules[token(entry.key)] = AuroraToneRule(
            palette: AuroraPalette.values.byName(palette),
            lightTone: _number(rule['lightTone'], 'lightTone'),
            darkTone: _number(rule['darkTone'], 'darkTone'));
      }
    }
    final pairs = <AuroraContrastPair>[];
    for (final item in _list(input['contrastPairs'] ?? [], 'contrastPairs')) {
      final pair = _map(item, 'contrast pair');
      _fields(
          pair, {'foreground', 'background', 'minimumRatio'}, 'contrast pair');
      pairs.add(AuroraContrastPair(
          foreground: token(_text(pair['foreground'], 'foreground')),
          background: token(_text(pair['background'], 'background')),
          minimumRatio: _number(pair['minimumRatio'] ?? 4.5, 'minimumRatio')));
    }
    AuroraColor? seed(String key) => input[key] == null || input[key] == ''
        ? null
        : AuroraColor.hex(_text(input[key], key));
    final schemeName = input.containsKey('scheme')
        ? _text(input['scheme'], 'scheme')
        : 'tonalSpot';
    if (!AuroraGenerationScheme.values
        .any((value) => value.name == schemeName)) {
      throw FormatException('Unknown scheme $schemeName');
    }
    return AuroraGenerationRequest(
      contract: contract,
      id: _text(input['id'], 'id'),
      name: _text(input['name'], 'name'),
      primary: AuroraColor.hex(_text(input['primary'], 'primary')),
      scheme: AuroraGenerationScheme.values.byName(schemeName),
      secondary: seed('secondary'),
      tertiary: seed('tertiary'),
      success: seed('success'),
      warning: seed('warning'),
      info: seed('info'),
      appearances: modes,
      preferredAppearance: input.containsKey('preferredAppearance')
          ? appearance(input['preferredAppearance'])
          : modes.first,
      values: values(input['values']),
      variantValues: {
        for (final entry
            in _map(input['variantValues'] ?? {}, 'variantValues').entries)
          appearance(entry.key): values(entry.value)
      },
      rules: rules,
      contrastPairs: pairs,
    );
  }

  static Map<String, dynamic> _map(Object? value, String field) {
    if (value is! Map || value.keys.any((key) => key is! String))
      throw FormatException('$field must be an object');
    return Map<String, dynamic>.from(value);
  }

  static List<dynamic> _list(Object? value, String field) {
    if (value is! List) throw FormatException('$field must be an array');
    return value;
  }

  static String _text(Object? value, String field) {
    if (value is! String || value.trim().isEmpty)
      throw FormatException('$field must be a nonempty string');
    return value.trim();
  }

  static double _number(Object? value, String field) {
    if (value is! num || !value.isFinite)
      throw FormatException('$field must be a finite number');
    return value.toDouble();
  }

  static void _fields(
      Map<String, dynamic> value, Set<String> allowed, String field) {
    final unknown = value.keys.where((key) => !allowed.contains(key));
    if (unknown.isNotEmpty)
      throw FormatException('Unknown $field fields: ${unknown.join(', ')}');
  }
}
