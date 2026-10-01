import 'dart:io';
import 'dart:convert';
import 'package:aurora/aurora.dart';
import 'package:aurora/src/tooling/server.dart';
import 'package:aurora/src/tooling/install.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    stdout.writeln('Aurora theme generator\n'
        'Usage: aurora generate [--no-open] [--port PORT] [--project PATH]\n'
        '       aurora generate --json --input RECIPE.json|- [--project PATH]\n'
        'Opens a local browser UI. Ctrl+C stops the server.\n'
        'Default port: automatically assigned.');
    return;
  }
  try {
    if (args.first != 'generate')
      throw FormatException('Unknown command ${args.first}');
    var open = true;
    var port = 0;
    var json = false;
    String? inputPath;
    String? projectPath;
    for (var i = 1; i < args.length; i++) {
      switch (args[i]) {
        case '--json':
          json = true;
        case '--input':
          if (++i >= args.length)
            throw const FormatException('Missing input path');
          inputPath = args[i];
        case '--project':
          if (++i >= args.length)
            throw const FormatException('Missing project path');
          projectPath = args[i];
        case '--no-open':
          open = false;
        case '--port':
          if (++i >= args.length) throw const FormatException('Missing port');
          port = int.tryParse(args[i]) ?? -1;
          if (port < 0 || port > 65535)
            throw const FormatException('Port must be in [0, 65535]');
        default:
          throw FormatException('Unknown option ${args[i]}');
      }
    }
    if (json) {
      if (inputPath == null)
        throw const FormatException(
            '--json requires --input FILE or --input -');
      if (!open || port != 0)
        throw const FormatException(
            'Browser options cannot be used with --json');
      final content = inputPath == '-'
          ? await utf8.decoder.bind(stdin).join()
          : await File(inputPath).readAsString();
      final recipe = jsonDecode(content);
      if (recipe is! Map<String, dynamic>)
        throw const FormatException('Expected a JSON recipe object');
      final result = AuroraGenerator.generate(AuroraRecipe.decode(recipe));
      final installed = projectPath == null
          ? null
          : await (await AuroraProject.open(projectPath))
              .install(result, recipe);
      stdout.writeln(jsonEncode({
        'schemaVersion': 1,
        'theme': result.toJson(),
        if (installed != null) 'installation': installed
      }));
      return;
    }
    if (inputPath != null)
      throw const FormatException('--input requires --json');
    final project =
        projectPath == null ? null : await AuroraProject.open(projectPath);
    final server =
        await AuroraGeneratorServer.start(port: port, project: project);
    stdout.writeln('Aurora generator: ${server.url}\nPress Ctrl+C to stop.');
    if (open) {
      try {
        final result = await Process.run(
          Platform.isWindows
              ? 'rundll32'
              : Platform.isMacOS
                  ? 'open'
                  : 'xdg-open',
          Platform.isWindows
              ? ['url.dll,FileProtocolHandler', server.url.toString()]
              : [server.url.toString()],
        );
        if (result.exitCode != 0)
          stdout.writeln('Open the URL above in your browser.');
      } catch (_) {
        stdout.writeln('Open the URL above in your browser.');
      }
    }
  } on FormatException catch (error) {
    stderr.writeln(jsonEncode({
      'error': {'code': 'invalid_input', 'message': error.message}
    }));
    exitCode = 64;
  } on ArgumentError catch (error) {
    stderr.writeln(jsonEncode({
      'error': {'code': 'invalid_input', 'message': error.toString()}
    }));
    exitCode = 65;
  } on AuroraValidationException catch (error) {
    stderr.writeln(jsonEncode({
      'error': {
        'code': 'validation',
        'message': error.toString(),
        'issues': error.issues
      }
    }));
    exitCode = 65;
  } on FileSystemException catch (error) {
    stderr.writeln(jsonEncode({
      'error': {'code': 'io', 'message': error.message}
    }));
    exitCode = 74;
  } on SocketException catch (error) {
    stderr.writeln('Could not start Aurora: ${error.message}');
    exitCode = 1;
  }
}
