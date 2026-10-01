import 'dart:convert';
import 'dart:io';
import 'package:aurora/aurora.dart';
import 'package:aurora/src/tooling/install.dart';
import 'package:test/test.dart';

void main() {
  final basic = <String, dynamic>{
    'schemaVersion': 1,
    'id': 'demo',
    'name': 'Demo',
    'primary': '#246b35'
  };
  final extended = <String, dynamic>{
    ...basic,
    'contract': {
      'id': 'tickets',
      'version': 2,
      'extensions': [
        {'path': 'app.ticket', 'description': 'Ticket background'},
        {'path': 'app.onTicket', 'description': 'Ticket content'},
      ]
    },
    'rules': {
      'app.ticket': {'alias': 'colors.primaryContainer'},
      'app.onTicket': {'palette': 'primary', 'lightTone': 0, 'darkTone': 100}
    },
    'variantValues': {
      'dark': {'app.ticket': '#000000'}
    },
    'contrastPairs': [
      {'foreground': 'app.onTicket', 'background': 'app.ticket'}
    ],
  };
  test('portable recipe constructs complete typed app contracts', () {
    final request = AuroraRecipe.decode(extended);
    final result = AuroraGenerator.generate(request);
    final token = request.contract.tokens['app.ticket']!;
    expect(result.theme.contract.version, 2);
    expect(result.theme.variants[AuroraAppearance.light]!.read(token),
        result.theme.variants[AuroraAppearance.light]!.tokens.primaryContainer);
    expect(result.theme.variants[AuroraAppearance.dark]!.read(token),
        AuroraColor.hex('#000000'));
    expect(
        result.checks
            .any((check) => check.pair.foreground.path == 'app.onTicket'),
        true);
    expect(
        AuroraGenerator.generate(AuroraRecipe.decode(basic))
            .theme
            .variants
            .length,
        2);
  });
  test(
      'recipe rejects unknown fields, malformed types, missing extensions and cycles',
      () {
    for (final input in [
      {...basic, 'schemaVersion': 2},
      {...basic, 'surprise': true},
      {
        ...basic,
        'contract': {'id': 'app', 'extensions': {}}
      },
      {
        ...basic,
        'values': {'app.unknown': '#ffffff'}
      },
      {
        ...extended,
        'rules': {
          'app.ticket': {'alias': 'colors.primary', 'extra': true}
        }
      },
      {...extended, 'rules': {}},
      {
        ...extended,
        'rules': {
          'app.ticket': {'alias': 'app.onTicket'},
          'app.onTicket': {'alias': 'app.ticket'}
        }
      },
    ]) {
      expect(
          () => AuroraGenerator.generate(AuroraRecipe.decode(input)),
          throwsA(anyOf(isA<FormatException>(), isA<ArgumentError>(),
              isA<AuroraValidationException>())));
    }
  });
  test(
      'project bundle is runnable, preserves extensions and refuses overwrites',
      () async {
    final root = await Directory.systemTemp.createTemp('aurora-project-');
    addTearDown(() => root.delete(recursive: true));
    await File('${root.path}/pubspec.yaml')
        .writeAsString('name: test_app\ndependencies:\n  aurora: any\n');
    final project = await AuroraProject.open(root.path);
    final request = AuroraRecipe.decode({...basic, 'name': r'Demo $name'});
    final result = AuroraGenerator.generate(request);
    final installed = await project.install(result, basic);
    final destination = installed['directory'] as String;
    final snippet = installed['registrationSnippet'] as String;
    final snippetFile = File('${root.path}/lib/verify_registration.dart');
    await snippetFile.writeAsString('''$snippet
final appContract = AuroraContract(id: 'app');
void main() {
  final themes = [generatedTheme];
  if (themes.single.id != 'demo') throw StateError('Missing registration');
}
''');
    final registered = await Process.run(Platform.resolvedExecutable, [
      '--packages=${Directory.current.path}/.dart_tool/package_config.json',
      snippetFile.path,
    ]);
    expect(registered.exitCode, 0,
        reason: '${registered.stdout}\n${registered.stderr}');
    expect(
        await File('$destination/README.md').readAsString(), contains(snippet));
    final before = await File('$destination/theme.dart').readAsString();
    await expectLater(project.install(result, basic), throwsFormatException);
    expect(await File('$destination/theme.dart').readAsString(), before);
    await expectLater(
        project.install(
            AuroraGenerator.generate(
                AuroraRecipe.decode({...basic, 'id': '../escape'})),
            basic),
        throwsFormatException);
    final script = File('${root.path}/verify.dart');
    await script.writeAsString('''import 'package:aurora/aurora.dart';
import 'lib/aurora_themes/demo/theme.dart';
void main() {
  const ticket = AuroraColorToken('app.ticket', description: 'Ticket');
  final contract = AuroraContract(id: 'app', extensions: [ticket]);
  final theme = createAuroraTheme(contract: contract, extensionValues: {
    for (final appearance in AuroraAppearance.values) appearance: {ticket: AuroraColor.hex('#ffffff')},
  });
  if (!identical(theme.contract, contract) || theme.name != r'Demo \$name') throw StateError('Bad binding');
  try { createAuroraTheme(contract: contract); } on AuroraValidationException { return; }
  throw StateError('Missing extensions accepted');
}
''');
    final execution = await Process.run(Platform.resolvedExecutable, [
      '--packages=${Directory.current.path}/.dart_tool/package_config.json',
      script.path
    ]);
    expect(execution.exitCode, 0,
        reason: '${execution.stdout}\n${execution.stderr}');
    expect(jsonDecode(await File('$destination/recipe.json').readAsString()),
        basic);
  });
  test('installer rejects linked output parents', () async {
    final root = await Directory.systemTemp.createTemp('aurora-links-');
    addTearDown(() => root.delete(recursive: true));
    await File('${root.path}/pubspec.yaml')
        .writeAsString('name: app\ndependencies:\n  aurora: any\n');
    // A regular file is also an invalid parent; link creation may require Windows privileges.
    await File('${root.path}/lib').writeAsString('existing content');
    final project = await AuroraProject.open(root.path);
    await expectLater(
        project.install(
            AuroraGenerator.generate(AuroraRecipe.decode(basic)), basic),
        throwsFormatException);
    expect(await File('${root.path}/lib').readAsString(), 'existing content');
  });
  test(
      'agent command emits JSON only and structured errors with nonzero status',
      () async {
    final root = await Directory.systemTemp.createTemp('aurora-agent-');
    addTearDown(() => root.delete(recursive: true));
    final file = File('${root.path}/recipe.json');
    await file.writeAsString(jsonEncode(extended));
    Future<ProcessResult> run() => Process.run(Platform.resolvedExecutable,
        ['bin/aurora.dart', 'generate', '--json', '--input', file.path]);
    final success = await run();
    expect(success.exitCode, 0, reason: success.stderr.toString());
    expect(success.stderr, '');
    final output = jsonDecode(success.stdout as String);
    expect(output['schemaVersion'], 1);
    expect(output['theme'],
        AuroraGenerator.generate(AuroraRecipe.decode(extended)).toJson());
    await file.writeAsString(jsonEncode({...basic, 'primary': 'bad'}));
    final failure = await run();
    expect(failure.exitCode, isNot(0));
    expect(failure.stdout, '');
    expect(
        jsonDecode(failure.stderr as String)['error']['code'], 'invalid_input');
  });
}
