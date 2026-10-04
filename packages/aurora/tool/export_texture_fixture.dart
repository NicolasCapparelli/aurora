import 'dart:convert';
import 'dart:io';
import 'package:aurora/aurora.dart';

/// Refresh only when deliberately updating the portable texture references:
/// `spec/texture-foundation-v1.json` and `spec/fixtures/texture.tokens.json`
/// (the DTCG export of `spec/fixtures/texture-recipe.json`).
void main() {
  const encoder = JsonEncoder.withIndent('  ');
  File write(String path, Object json) =>
      File.fromUri(Platform.script.resolve('../../../spec/$path'))
        ..writeAsStringSync('${encoder.convert(json)}\n');

  write('texture-foundation-v1.json', {
    'version': AuroraTextureFoundation.version,
    'namespaces': AuroraTextureFoundation.namespaces,
    'tokens': [
      for (final token in AuroraTextureFoundation.tokens)
        {
          'path': token.path,
          'type': token.type,
          'description': token.description,
          'starter': AuroraTextureRecipe.encodeValue(
              AuroraTextureStarter.material[token]!),
        }
    ],
  });

  final recipe = jsonDecode(File.fromUri(
          Platform.script.resolve('../../../spec/fixtures/texture-recipe.json'))
      .readAsStringSync()) as Map<String, dynamic>;
  write('fixtures/texture.tokens.json',
      AuroraTextureDtcg.encode(AuroraTextureRecipe.decode(recipe)));
}
