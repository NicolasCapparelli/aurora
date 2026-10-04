import 'dart:convert';
import 'dart:io';
import 'package:aurora/aurora.dart';
import 'package:test/test.dart';

Object? readJson(String path) =>
    jsonDecode(File('../../spec/$path').readAsStringSync());

void main() {
  final recipe =
      readJson('fixtures/texture-recipe.json') as Map<String, dynamic>;
  final contract = AuroraTextureRecipe.decodeContract(
      Map<String, dynamic>.from(recipe['contract'] as Map));
  final fixture =
      File('../../spec/fixtures/texture.tokens.json').readAsStringSync();

  AuroraTexture decode(Map<String, Object?> document) =>
      AuroraTextureDtcg.decode(document,
          contract: contract, id: 'portable-soft', name: 'Portable Soft');

  test('texture foundation spec matches the Dart foundation and starter', () {
    final spec = readJson('texture-foundation-v1.json') as Map<String, dynamic>;
    expect(spec['version'], AuroraTextureFoundation.version);
    expect(spec['namespaces'], AuroraTextureFoundation.namespaces);
    final tokens = (spec['tokens'] as List).cast<Map<String, dynamic>>();
    expect(tokens.map((t) => t['path']),
        AuroraTextureFoundation.tokens.map((t) => t.path));
    for (final (i, token) in AuroraTextureFoundation.tokens.indexed) {
      expect(tokens[i]['type'], token.type);
      expect(tokens[i]['description'], token.description);
      expect(
          tokens[i]['starter'],
          AuroraTextureRecipe.encodeValue(
              AuroraTextureStarter.material[token]!));
    }
  });

  test('the recipe fixture builds the token fixture exactly', () {
    final fromRecipe = AuroraTextureRecipe.decode(recipe, contract: contract);
    final document = jsonDecode(fixture) as Map<String, Object?>;
    expect(
        jsonDecode(jsonEncode(AuroraTextureDtcg.encode(fromRecipe))), document);
    expect(AuroraTextureDtcg.encode(decode(document)),
        AuroraTextureDtcg.encode(fromRecipe));
  });

  final cases = (readJson('fixtures/texture-cases.json') as List)
      .cast<Map<String, Object?>>();
  for (final scenario in cases) {
    test('portable texture conformance: ${scenario['name']}', () {
      final document = jsonDecode(fixture) as Map<String, Object?>;
      for (final mutation
          in (scenario['mutations'] as List).cast<Map<String, Object?>>()) {
        final path = (mutation['path'] as List).cast<String>();
        var group = document;
        for (final part in path.take(path.length - 1)) {
          group = group[part] as Map<String, Object?>;
        }
        if (mutation['operation'] == 'remove') {
          group.remove(path.last);
        } else {
          group[path.last] = mutation['value'];
        }
      }
      switch (scenario['expected']) {
        case 'valid':
          final texture = decode(document);
          for (final entry
              in (scenario['values'] as Map<String, Object?>).entries) {
            final token = contract.tokens[entry.key]!;
            expect(AuroraTextureRecipe.encodeValue(texture.read(token)),
                entry.value,
                reason: entry.key);
          }
          if (scenario['colorReferences'] case final List references) {
            expect(texture.colorReferences, references.toSet());
          }
        case 'validation':
          expect(() => decode(document),
              throwsA(isA<AuroraValidationException>()));
        case 'format':
          expect(() => decode(document), throwsFormatException);
        default:
          fail('Unknown portable expectation ${scenario['expected']}');
      }
    });
  }
}
