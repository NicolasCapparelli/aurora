import 'dart:convert';
import 'dart:io';
import 'package:aurora/src/tooling/install.dart';
import 'package:test/test.dart';

Future<ProcessResult> dartRun(String script, [List<String> args = const []]) =>
    Process.run(Platform.resolvedExecutable, [
      '--packages=${Directory.current.path}/.dart_tool/package_config.json',
      script,
      ...args,
    ]);

void main() {
  final fixture = File('../../spec/fixtures/bundle.json').readAsStringSync();

  Future<Directory> project() async {
    final root = await Directory.systemTemp.createTemp('aurora-bundle-');
    addTearDown(() => root.delete(recursive: true));
    await File('${root.path}/pubspec.yaml')
        .writeAsString('name: test_app\ndependencies:\n  aurora: any\n');
    return root;
  }

  test(
      'installs theme, texture and pairing; the snippet runs and app extensions stay required',
      () async {
    final root = await project();
    final installed = await (await AuroraProject.open(root.path))
        .installBundle(jsonDecode(fixture));
    final destination = installed['directory'] as String;
    expect(installed['files'], [
      'bundle.json',
      'light.tokens.json',
      'dark.tokens.json',
      'texture.tokens.json',
      'theme.dart',
      'texture.dart',
      'README.md',
    ]);
    expect(
        installed['pairing'], {'themeId': 'ocean', 'textureId': 'ocean-soft'});
    final snippet = installed['registrationSnippet'] as String;
    expect(
        snippet,
        contains(
            "texturePairings: {...existingPairings, \"ocean\": \"ocean-soft\"}"));
    expect(
        await File('$destination/README.md').readAsString(), contains(snippet));

    final script = File('${root.path}/lib/verify_bundle.dart');
    await script.writeAsString('''$snippet
const ticket = AuroraColorToken('app.ticket', description: 'Ticket.');
const card = AuroraDimensionToken('app.card', description: 'Card corners.');
final appContract = AuroraContract(id: 'app', extensions: [ticket]);
final appTextureContract = AuroraTextureContract(id: 'feel', extensions: [card]);
void main() {
  // Extensions are required: the bundle alone does not satisfy the app.
  try {
    generated.createAuroraTheme(contract: appContract);
    throw StateError('Missing theme extension accepted');
  } on AuroraValidationException {}
  try {
    generated_texture.createAuroraTexture(contract: appTextureContract);
    throw StateError('Missing texture extension accepted');
  } on AuroraValidationException {}
  final theme = generated.createAuroraTheme(contract: appContract, extensionValues: {
    for (final appearance in AuroraAppearance.values)
      appearance: {ticket: AuroraColor.hex('#ffffff')},
  });
  final texture = generated_texture.createAuroraTexture(
      contract: appTextureContract,
      extensionValues: {card: const AuroraAlias(AuroraTextureFoundation.mediumShape)});
  final runtime = AuroraRuntime(
    contract: appContract,
    themes: [theme],
    textures: [texture],
    texturePairings: {'ocean': 'ocean-soft'},
    initialSelection: const AuroraSelection(themeId: 'ocean'),
    fallback: AuroraVariantFallback.reject,
  );
  if (!identical(runtime.state.texture, texture)) throw StateError('No pairing');
  if (texture.read(card) != const AuroraDimension.dp(16)) throw StateError('Bad texture');
  if (texture.read(AuroraTextureFoundation.brandFamily).primary != 'Fraunces') {
    throw StateError('Bad family');
  }
  if (theme.variants[AuroraAppearance.light]!.read(AuroraFoundation.primary).hex != '#36618eff') {
    throw StateError('Bad colour');
  }
}
''');
    final run = await dartRun(script.path);
    expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');

    final before = await File('$destination/theme.dart').readAsString();
    await expectLater(
        (await AuroraProject.open(root.path))
            .installBundle(jsonDecode(fixture)),
        throwsFormatException);
    expect(await File('$destination/theme.dart').readAsString(), before);
  });

  test('CLI installs a folder bundle and reports invalid bundles', () async {
    final root = await project();
    final bundle = jsonDecode(fixture) as Map<String, Object?>;
    final folder = await Directory('${root.path}/export').create();
    await File('${folder.path}/manifest.json')
        .writeAsString(jsonEncode(bundle['manifest']));
    for (final entry in (bundle['files'] as Map<String, Object?>).entries) {
      await File('${folder.path}/${entry.key}')
          .writeAsString(jsonEncode(entry.value));
    }
    final ok = await dartRun('bin/aurora.dart',
        ['install', '--bundle', folder.path, '--project', root.path]);
    expect(ok.exitCode, 0, reason: '${ok.stdout}\n${ok.stderr}');
    final output = jsonDecode(ok.stdout as String) as Map<String, Object?>;
    expect((output['installation'] as Map)['pairing'],
        {'themeId': 'ocean', 'textureId': 'ocean-soft'});
    expect(
        File('${root.path}/lib/aurora_themes/ocean/texture.dart').existsSync(),
        isTrue);

    final light = (bundle['files'] as Map)['light.tokens.json'] as Map;
    (light['colors'] as Map).remove('primary');
    bundle['manifest'] = {
      ...(bundle['manifest'] as Map<String, Object?>),
      'theme': {
        ...((bundle['manifest'] as Map)['theme'] as Map),
        'id': 'broken'
      },
      'pairing': {'themeId': 'broken', 'textureId': 'ocean-soft'},
    };
    final file = File('${root.path}/broken.aurora.json');
    await file.writeAsString(jsonEncode(bundle));
    final invalid = await dartRun('bin/aurora.dart',
        ['install', '--bundle', file.path, '--project', root.path]);
    expect(invalid.exitCode, 65,
        reason: '${invalid.stdout}\n${invalid.stderr}');
    expect(invalid.stderr, contains('validation'));
    expect(Directory('${root.path}/lib/aurora_themes/broken').existsSync(),
        isFalse);
  });
}
