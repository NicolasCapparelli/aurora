import 'dart:convert';
import 'dart:io';
import 'package:aurora/aurora.dart';
import 'package:test/test.dart';

void main() {
  const ticket =
      AuroraColorToken('demo.ticket', description: 'Ticket background.');
  final contract = AuroraContract(id: 'portable-demo', extensions: [ticket]);
  final fixture =
      File('../../spec/fixtures/light.tokens.json').readAsStringSync();
  final cases = jsonDecode(
          File('../../spec/fixtures/variant-cases.json').readAsStringSync())
      as List;
  for (final scenario in cases.cast<Map<String, Object?>>()) {
    test('portable conformance: ${scenario['name']}', () {
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
      AuroraThemeVariant decode() => AuroraDtcg.decode(document,
          contract: contract, appearance: AuroraAppearance.light);
      switch (scenario['expected']) {
        case 'valid':
          final variant = decode();
          final tokens = variant.tokens;
          expect(tokens, isA<AuroraTokens>());
          for (final entry
              in (scenario['values'] as Map<String, Object?>).entries) {
            expect(tokens.read(contract.tokens[entry.key]!).hex, entry.value);
          }
          expect(tokens.primary, variant.colors.primary);
        case 'validation':
          expect(decode, throwsA(isA<AuroraValidationException>()));
        case 'format':
          expect(decode, throwsFormatException);
        default:
          fail('Unknown portable expectation ${scenario['expected']}');
      }
    });
  }
}
