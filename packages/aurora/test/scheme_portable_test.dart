import 'dart:convert';
import 'dart:io';
import 'package:aurora/aurora.dart';
import 'package:test/test.dart';

void main() {
  final fixture = jsonDecode(
      File('../../spec/fixtures/generation-schemes-v1.json')
          .readAsStringSync()) as Map<String, dynamic>;
  for (final scenario in fixture['cases'] as List) {
    test('portable additional scheme: ${scenario['input']['scheme']}', () {
      final result = AuroraGenerator.generate(AuroraRecipe.decode(
          Map<String, dynamic>.from(scenario['input'] as Map)));
      expect(result.algorithm, scenario['algorithm']);
      expect({
        for (final entry in result.theme.variants.entries)
          entry.key.name: {
            for (final value in entry.value.values.entries)
              value.key.path: value.value.hex
          }
      }, scenario['values']);
    });
  }
}
