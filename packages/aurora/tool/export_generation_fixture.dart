import 'dart:convert';
import 'dart:io';
import 'package:aurora/aurora.dart';

/// Deliberately refresh pinned cross-language generation expectations.
void main() {
  final contract = AuroraContract(id: 'generation-fixture');
  final cases = <Map<String, Object?>>[];
  for (final input in [
    {
      'name': 'emerald',
      'primary': '#246b35',
      'appearances': ['light', 'dark'],
      'preferredAppearance': 'light'
    },
    {
      'name': 'three-seeds',
      'primary': '#246b35',
      'secondary': '#b3261e',
      'tertiary': '#0061a4',
      'appearances': ['light', 'dark'],
      'preferredAppearance': 'light'
    },
    {
      'name': 'dark-only',
      'primary': '#ffffff',
      'appearances': ['dark'],
      'preferredAppearance': 'dark'
    },
  ]) {
    final request = AuroraGenerationRequest(
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
    );
    final result = AuroraGenerator.generate(request);
    cases.add({
      'input': input,
      'values': {
        for (final variant in result.theme.variants.values)
          variant.appearance.name: {
            for (final entry in variant.values.entries)
              entry.key.path: entry.value.hex,
          }
      },
      'contrast': result.checks.map((check) => check.toJson()).toList(),
    });
  }
  final target = File.fromUri(
      Platform.script.resolve('../../../spec/fixtures/generation-v1.json'));
  target.parent.createSync(recursive: true);
  target.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert({
        'algorithm': AuroraGenerator.algorithm,
        'cases': cases,
      })}\n');
}
