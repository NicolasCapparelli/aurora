import 'dart:convert';
import 'dart:io';
import 'package:aurora/aurora.dart';
import 'package:test/test.dart';

/// Consumes spec/fixtures/bundle.json and bundle-cases.json exactly as
/// packages/aurora_ts/test/bundle.test.ts does.
void main() {
  final fixture = File('../../spec/fixtures/bundle.json').readAsStringSync();
  final cases = (jsonDecode(
              File('../../spec/fixtures/bundle-cases.json').readAsStringSync())
          as List)
      .cast<Map<String, Object?>>();

  Map<String, Object?> mutated(List<Object?> mutations) {
    final bundle = jsonDecode(fixture) as Map<String, Object?>;
    for (final mutation in mutations.cast<Map<String, Object?>>()) {
      final path = (mutation['path'] as List).cast<String>();
      var group = bundle;
      for (final part in path.take(path.length - 1)) {
        group = group[part] as Map<String, Object?>;
      }
      if (mutation['operation'] == 'remove') {
        group.remove(path.last);
      } else {
        group[path.last] = mutation['value'];
      }
    }
    return bundle;
  }

  for (final scenario in cases) {
    test('portable bundle: ${scenario['name']}', () {
      final bundle = mutated(scenario['mutations'] as List);
      final extensions = scenario['appExtensions'] as List?;
      final contract = extensions == null
          ? null
          : AuroraContract(id: 'app', extensions: [
              for (final token in extensions.cast<Map<String, Object?>>())
                AuroraColorToken(token['path'] as String,
                    description: token['description'] as String),
            ]);
      final report = AuroraBundle.validate(bundle, contract: contract);
      final expected = scenario['expected'];
      if (expected == 'valid') {
        expect(report.issues, isEmpty);
        final contents = report.contents!;
        final values = (scenario['values'] as Map<String, Object?>?) ?? {};
        for (final entry in values.entries) {
          for (final value in (entry.value as Map<String, Object?>).entries) {
            if (entry.key == 'texture') {
              final texture = contents.texture!;
              expect(
                  AuroraTextureRecipe.encodeValue(
                      texture.read(texture.contract.tokens[value.key]!)),
                  value.value);
            } else {
              final variant = contents
                  .theme.variants[AuroraAppearance.values.byName(entry.key)]!;
              expect(variant.read(variant.contract.tokens[value.key]!).hex,
                  value.value);
            }
          }
        }
      } else {
        expect(report.valid, isFalse);
        expect({
          for (final issue in report.issues) '${issue.category}:${issue.file}'
        }, {
          for (final issue in (expected as List).cast<Map<String, Object?>>())
            '${issue['category']}:${issue['file']}'
        });
      }
    });
  }

  test('loads into a runtime and round-trips through encode', () async {
    final contents = AuroraBundle.load(jsonDecode(fixture));
    expect(contents.pairing, (themeId: 'ocean', textureId: 'ocean-soft'));
    final runtime = AuroraRuntime(
      contract: AuroraBundle.foundationContract,
      themes: [contents.theme],
      textures: [contents.texture!],
      texturePairings: {contents.pairing!.themeId: contents.pairing!.textureId},
      initialSelection: const AuroraSelection(themeId: 'ocean'),
      fallback: AuroraVariantFallback.reject,
    );
    expect(runtime.state.texture, same(contents.texture));
    await runtime.dispose();
    final provenance = contents.manifest['provenance'] as Map<String, Object?>;
    final encoded = AuroraBundle.encode(
      theme: contents.theme,
      texture: contents.texture,
      generator: provenance['generator'] as String,
      sourceHash: provenance['sourceHash'] as String,
      createdAt: provenance['createdAt'] as String,
    );
    expect(jsonDecode(jsonEncode(encoded)), jsonDecode(fixture));
  });

  test('load throws by category', () {
    final version = mutated([
      {
        'path': ['manifest', 'bundleVersion'],
        'operation': 'set',
        'value': 2
      }
    ]);
    expect(() => AuroraBundle.load(version), throwsFormatException);
    final missing = mutated([
      {
        'path': ['files', 'light.tokens.json', 'colors', 'primary'],
        'operation': 'remove'
      }
    ]);
    expect(() => AuroraBundle.load(missing),
        throwsA(isA<AuroraValidationException>()));
    expect(AuroraBundle.validate(null).issues.single.file, 'bundle');
  });
}
