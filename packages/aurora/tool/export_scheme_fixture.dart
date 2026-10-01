// Deliberate maintenance command. Normal tests only read the fixture.
import 'dart:convert';
import 'dart:io';
import 'package:aurora/aurora.dart';

void main() {
  final cases = <Object?>[];
  for (final scheme in AuroraGenerationScheme.values) {
    if (scheme == AuroraGenerationScheme.tonalSpot) continue;
    final recipe = <String, dynamic>{
      'schemaVersion': 1,
      'id': 'scheme-fixture',
      'name': 'Scheme fixture',
      'primary': '#e60023',
      'scheme': scheme.name,
    };
    final result = AuroraGenerator.generate(AuroraRecipe.decode(recipe));
    cases.add({
      'input': recipe,
      'algorithm': result.algorithm,
      'values': {
        for (final entry in result.theme.variants.entries)
          entry.key.name: {
            for (final value in entry.value.values.entries)
              value.key.path: value.value.hex
          }
      }
    });
  }
  File('../../spec/fixtures/generation-schemes-v1.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert({'cases': cases})}\n');
}
