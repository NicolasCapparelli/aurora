import 'dart:convert';
import 'dart:io';
import 'package:aurora/aurora.dart';

/// Refresh only when deliberately updating `spec/fixtures/bundle.json`, the
/// valid portable bundle that `bundle-cases.json` mutates.
void main() {
  final theme = AuroraGenerator.generate(AuroraGenerationRequest(
    contract: AuroraBundle.foundationContract,
    id: 'ocean',
    name: 'Ocean',
    primary: AuroraColor.hex('#0061a4'),
    tertiary: AuroraColor.hex('#7d5260'),
  )).theme;
  final texture = AuroraTextureStarter.texture(
    contract: AuroraBundle.textureFoundationContract,
    id: 'ocean-soft',
    name: 'Ocean Soft',
    values: {
      AuroraTextureFoundation.brandFamily:
          AuroraFontFamily(['Fraunces', 'Georgia', 'serif']),
      AuroraTextureFoundation.mediumShape: const AuroraDimension.dp(16),
      AuroraTextureFoundation.largeShape:
          const AuroraAlias(AuroraTextureFoundation.mediumShape),
      AuroraTextureFoundation.shortDuration: const Duration(milliseconds: 120),
    },
  );
  final bundle = AuroraBundle.encode(
    theme: theme,
    texture: texture,
    generator: 'aurora-fixture@1',
    sourceHash:
        'sha256:0000000000000000000000000000000000000000000000000000000000000000',
    createdAt: '2026-10-05T00:00:00Z',
  );
  File.fromUri(Platform.script.resolve('../../../spec/fixtures/bundle.json'))
      .writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert(bundle)}\n');
}
