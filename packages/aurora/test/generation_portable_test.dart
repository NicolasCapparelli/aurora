import 'dart:convert';
import 'dart:io';
import 'package:aurora/aurora.dart';
import 'package:test/test.dart';

void main() {
  final fixture = jsonDecode(
          File('../../spec/fixtures/generation-v1.json').readAsStringSync())
      as Map<String, Object?>;
  test('generation fixture declares the supported algorithm', () {
    expect(fixture['algorithm'], AuroraGenerator.algorithm);
  });
  final contract = AuroraContract(id: 'generation-fixture');
  for (final scenario
      in (fixture['cases'] as List).cast<Map<String, Object?>>()) {
    final input = scenario['input'] as Map<String, Object?>;
    test('portable generation: ${input['name']}', () {
      final result = AuroraGenerator.generate(AuroraGenerationRequest(
        contract: contract,
        id: input['name'] as String,
        name: input['name'] as String,
        primary: AuroraColor.hex(input['primary'] as String),
        secondary: input['secondary'] == null
            ? null
            : AuroraColor.hex(input['secondary'] as String),
        tertiary: input['tertiary'] == null
            ? null
            : AuroraColor.hex(input['tertiary'] as String),
        appearances: (input['appearances'] as List)
            .map((name) => AuroraAppearance.values.byName(name as String)),
        preferredAppearance: AuroraAppearance.values
            .byName(input['preferredAppearance'] as String),
      ));
      final expectedVariants = scenario['values'] as Map<String, Object?>;
      expect(result.theme.variants.keys.map((appearance) => appearance.name),
          expectedVariants.keys);
      for (final entry in expectedVariants.entries) {
        final variant =
            result.theme.variants[AuroraAppearance.values.byName(entry.key)]!;
        final expected = entry.value as Map<String, Object?>;
        expect(variant.values.length, expected.length);
        for (final token in contract.tokens.values) {
          expect(variant.read(token).hex, expected[token.path],
              reason: '${entry.key}: ${token.path}');
        }
      }
      final expectedChecks =
          (scenario['contrast'] as List).cast<Map<String, Object?>>();
      expect(result.checks.length, expectedChecks.length);
      for (var i = 0; i < expectedChecks.length; i++) {
        final actual = result.checks[i].toJson();
        final expected = expectedChecks[i];
        for (final key in [
          'appearance',
          'foreground',
          'background',
          'minimumRatio',
          'status'
        ]) {
          expect(actual[key], expected[key]);
        }
        expect(actual['ratio'],
            closeTo((expected['ratio'] as num).toDouble(), 1e-6));
      }
    });
  }
}
