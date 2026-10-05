import 'dart:convert';
import 'dart:io';
import '../../aurora.dart';

/// A target explicitly chosen by the CLI user, never supplied by a web request.
final class AuroraProject {
  AuroraProject._(this.root, this.importPackage);
  final Directory root;
  final String importPackage;

  static Future<AuroraProject> open(String path) async {
    final root = Directory(await Directory(path).resolveSymbolicLinks());
    final pubspec = File('${root.path}/pubspec.yaml');
    if (!await pubspec.exists())
      throw const FormatException('Project needs a pubspec.yaml');
    final content = await pubspec.readAsString();
    final adapter =
        RegExp(r'^\s+aurora_flutter\s*:', multiLine: true).hasMatch(content);
    final core = RegExp(r'^\s+aurora\s*:', multiLine: true).hasMatch(content);
    if (!adapter && !core)
      throw const FormatException(
          'Add an aurora or aurora_flutter dependency to the project first');
    return AuroraProject._(root, adapter ? 'aurora_flutter' : 'aurora');
  }

  Future<Map<String, Object?>> install(
      AuroraGenerationResult result, Map<String, dynamic> recipe) async {
    final id = result.theme.id;
    final encoder = const JsonEncoder.withIndent('  ');
    final registration =
        "import 'package:$importPackage/$importPackage.dart';\n"
        "import 'aurora_themes/$id/theme.dart' as generated;\n\n"
        "// Paste in lib/main.dart (adjust the relative import in other files).\n"
        "// Add this entry to the registry before creating the controller/runtime.\n"
        "// appContract is your canonical contract; all required extensions must resolve.\n"
        "final generatedTheme = generated.createAuroraTheme(contract: appContract);\n"
        "// themes: [...existingThemes, generatedTheme]\n";
    final files = <String, String>{
      'theme.json': encoder.convert(result.toJson()),
      'recipe.json': encoder.convert(recipe),
      for (final entry in result.theme.variants.entries)
        '${entry.key.name}.tokens.json':
            encoder.convert(AuroraDtcg.encode(entry.value)),
      'theme.dart': _source(result.theme, result.algorithm),
      'README.md':
          'Import theme.dart and call createAuroraTheme(contract: yourContract).\n'
              'Supply every required app extension in extensionValues for each appearance.\n'
              'Register the returned theme with your Aurora runtime/controller.\n\n'
              '```dart\n$registration```\n',
    };
    final directory = await _stage(id, files);
    return {
      'directory': directory,
      'files': files.keys.toList(),
      'registrationSnippet': registration,
      'nextStep':
          'Import lib/aurora_themes/$id/theme.dart and register createAuroraTheme(contract: yourContract). Supply required app extensions through extensionValues.'
    };
  }

  /// Installs a portable bundle (`spec/bundle-v1.md`) produced outside Aurora,
  /// such as a TokenSeed export, into `lib/aurora_themes/<theme-id>/`. The
  /// bundle is validated foundation-only; required app extensions are supplied
  /// when the theme and texture are registered, as for generated themes.
  /// Existing files are never overwritten.
  Future<Map<String, Object?>> installBundle(Object? bundle) async {
    final contents = AuroraBundle.load(bundle);
    final theme = contents.theme;
    final texture = contents.texture;
    final pairing = contents.pairing;
    final id = theme.id;
    final encoder = const JsonEncoder.withIndent('  ');
    final provenance = contents.manifest['provenance'] as Map<String, Object?>;
    final generator = '${provenance['generator']}';
    final snippet = StringBuffer()
      ..writeln("import 'package:$importPackage/$importPackage.dart';")
      ..writeln("import 'aurora_themes/$id/theme.dart' as generated;");
    if (texture != null) {
      snippet.writeln(
          "import 'aurora_themes/$id/texture.dart' as generated_texture;");
    }
    snippet
      ..writeln()
      ..writeln(
          '// Paste in lib/main.dart (adjust the relative imports in other files).')
      ..writeln('// Add these entries before creating the controller/runtime.')
      ..writeln(
          '// appContract is your canonical contract; all required extensions must resolve.')
      ..writeln(
          'final generatedTheme = generated.createAuroraTheme(contract: appContract);');
    if (texture != null) {
      snippet
        ..writeln('// appTextureContract is your canonical texture contract.')
        ..writeln(
            'final generatedTexture = generated_texture.createAuroraTexture(')
        ..writeln('    contract: appTextureContract);');
    }
    snippet.writeln('// themes: [...existingThemes, generatedTheme]');
    if (texture != null) {
      snippet.writeln('// textures: [...existingTextures, generatedTexture]');
    }
    if (pairing != null) {
      snippet.writeln('// texturePairings: {...existingPairings, '
          '${_literal(pairing.themeId)}: ${_literal(pairing.textureId)}}');
    }
    final registration = snippet.toString();
    final files = <String, String>{
      'bundle.json': encoder.convert(contents.manifest),
      for (final entry in theme.variants.entries)
        '${entry.key.name}.tokens.json':
            encoder.convert(AuroraDtcg.encode(entry.value)),
      if (texture != null)
        'texture.tokens.json':
            encoder.convert(AuroraTextureDtcg.encode(texture)),
      'theme.dart': _source(theme, 'Bundle from $generator'),
      if (texture != null) 'texture.dart': _textureSource(texture, generator),
      'README.md':
          'Installed from an Aurora bundle produced by ${_comment(generator)}.\n'
              'Import theme.dart${texture == null ? '' : ' and texture.dart'} and register the results.\n'
              'Supply every required app extension in extensionValues.\n\n'
              '```dart\n$registration```\n',
    };
    final directory = await _stage(id, files);
    return {
      'directory': directory,
      'files': files.keys.toList(),
      'registrationSnippet': registration,
      if (pairing != null)
        'pairing': {'themeId': pairing.themeId, 'textureId': pairing.textureId},
      'nextStep': 'Import lib/aurora_themes/$id/theme.dart'
          '${texture == null ? '' : ' and texture.dart'}, register them as the '
          'snippet shows, and supply required app extensions through extensionValues.'
    };
  }

  /// Writes [files] to a new `lib/aurora_themes/<id>` directory atomically.
  Future<String> _stage(String id, Map<String, String> files) async {
    if (!RegExp(r'^[a-z][a-z0-9_-]{0,79}$').hasMatch(id)) {
      throw const FormatException(
          'Installation needs an ID of 1–80 lowercase letters, digits, underscores or hyphens, starting with a letter');
    }
    // Check each parent before creating anything. Never traverse project links.
    for (final path in ['${root.path}/lib', '${root.path}/lib/aurora_themes']) {
      final type = await FileSystemEntity.type(path, followLinks: false);
      if (type != FileSystemEntityType.notFound &&
          type != FileSystemEntityType.directory) {
        throw const FormatException(
            'Theme output parents must be ordinary directories');
      }
    }
    final parent = Directory('${root.path}/lib/aurora_themes');
    await parent.create(recursive: true);
    final target = Directory('${parent.path}/$id');
    if (await FileSystemEntity.type(target.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw FormatException(
          'Theme $id already exists. Choose a new ID; existing files are never overwritten');
    }
    final staging = await parent.createTemp('.aurora-');
    try {
      for (final entry in files.entries) {
        await File('${staging.path}/${entry.key}')
            .writeAsString('${entry.value}\n');
      }
      // Recheck after preparing the bundle; do not replace a concurrent install.
      if (await FileSystemEntity.type(target.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw const FormatException('Theme destination already exists');
      }
      await staging.rename(target.path);
      return target.path;
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  static String _literal(String value) =>
      jsonEncode(value).replaceAll(r'$', r'\$');

  static String _comment(String value) =>
      value.replaceAll(RegExp(r'[\r\n]'), ' ');

  String _textureSource(AuroraTexture texture, String generator) {
    final document = jsonEncode(AuroraTextureDtcg.encode(texture));
    return '''// Generated by Aurora. Bundle from ${_comment(generator)}
import 'dart:convert';
import 'package:$importPackage/$importPackage.dart';

const _document = ${_literal(document)};

/// Bind this texture's foundation values to your app's texture contract.
/// Supply every app extension of [contract] in [extensionValues].
AuroraTexture createAuroraTexture({
  required AuroraTextureContract contract,
  Map<AuroraToken<Object>, Object> extensionValues = const {},
}) {
  final foundation = AuroraTextureDtcg.decode(
    jsonDecode(_document) as Map<String, Object?>,
    contract: AuroraBundle.textureFoundationContract,
    id: ${_literal(texture.id)},
    name: ${_literal(texture.name)},
  );
  return AuroraTexture(
    contract: contract,
    id: ${_literal(texture.id)},
    name: ${_literal(texture.name)},
    values: {
      for (final token in AuroraTextureFoundation.tokens)
        token: foundation.authored(token),
      ...extensionValues,
    },
  );
}
''';
  }

  String _source(AuroraTheme theme, String origin) {
    String literal(String value) => _literal(value);
    return '''// Generated by Aurora. ${_comment(origin)}
import 'package:$importPackage/$importPackage.dart';

/// Bind these foundation colors to your app's existing contract.
AuroraTheme createAuroraTheme({
  required AuroraContract contract,
  Map<AuroraAppearance, Map<AuroraColorToken, AuroraColor>> extensionValues = const {},
}) => AuroraTheme(
  id: ${literal(theme.id)},
  name: ${literal(theme.name)},
  preferredAppearance: AuroraAppearance.${theme.preferredAppearance.name},
  variants: [
${theme.variants.entries.map((entry) => '''    AuroraThemeVariant(
      contract: contract,
      appearance: AuroraAppearance.${entry.key.name},
      values: {
${entry.value.values.entries.map((value) => '        contract.tokens[${literal(value.key.path)}]!: AuroraColor.hex(${literal(value.value.hex)}),').join('\n')}
        ...?extensionValues[AuroraAppearance.${entry.key.name}],
      },
    ),''').join('\n')}
  ],
);
''';
  }
}
