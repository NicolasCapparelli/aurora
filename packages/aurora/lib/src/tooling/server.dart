import 'dart:convert';
import 'dart:io';
import 'dart:math';
import '../../aurora.dart';
import 'ui.dart';
import 'install.dart';

/// Local CLI host, deliberately separate from the portable core barrel.
final class AuroraGeneratorServer {
  AuroraGeneratorServer._(this._server, this._token, this.project);
  final HttpServer _server;
  final String _token;
  final AuroraProject? project;
  final _generated = <String, (AuroraGenerationResult, Map<String, dynamic>)>{};
  var _generation = 0;
  Uri get url => Uri.parse('http://127.0.0.1:${_server.port}/');

  static Future<AuroraGeneratorServer> start(
      {int port = 0, AuroraProject? project}) async {
    final random = Random.secure();
    final token = List.generate(
            32, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
    final host = AuroraGeneratorServer._(
        await HttpServer.bind(InternetAddress.loopbackIPv4, port),
        token,
        project);
    host._server.listen(host._handle);
    return host;
  }

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    response.headers.set('Cache-Control', 'no-store');
    response.headers.set('X-Content-Type-Options', 'nosniff');
    response.headers.set('Content-Security-Policy',
        "default-src 'none'; script-src 'nonce-$_token'; style-src 'nonce-$_token'; connect-src 'self'; base-uri 'none'; frame-ancestors 'none'; form-action 'none'");
    try {
      if (request.headers.value('host') != url.authority) {
        response.statusCode = HttpStatus.forbidden;
      } else if (request.method == 'GET' && request.uri.path == '/') {
        response.headers.contentType = ContentType.html;
        response.write(generatorHtml.replaceAll('AURORA_NONCE', _token));
      } else if (request.method == 'GET' && request.uri.path == '/project') {
        response.headers.contentType = ContentType.json;
        response.write(jsonEncode({'path': project?.root.path}));
      } else if (request.method == 'POST' &&
          ['/generate', '/install'].contains(request.uri.path)) {
        if (request.headers.value('x-aurora-token') != _token ||
            (request.headers.value('origin') != null &&
                request.headers.value('origin') != url.origin)) {
          response.statusCode = HttpStatus.forbidden;
        } else {
          final bytes = <int>[];
          var oversized = false;
          await for (final chunk in request) {
            if (bytes.length + chunk.length > 65536) oversized = true;
            if (!oversized) bytes.addAll(chunk);
          }
          if (oversized) throw const FormatException('Input exceeds 64 KiB');
          final input = jsonDecode(utf8.decode(bytes));
          if (input is! Map<String, dynamic>)
            throw const FormatException('Expected a JSON object');
          if (request.uri.path == '/install') {
            if (input.keys.length != 1 || input['generationId'] is! String)
              throw const FormatException('Expected generationId');
            final snapshot = _generated[input['generationId']];
            if (snapshot == null)
              throw const FormatException(
                  'Generate again before adding this theme');
            if (project == null)
              throw const FormatException(
                  'Launch with --project PATH to enable installation');
            final installed = await project!.install(snapshot.$1, snapshot.$2);
            response.headers.contentType = ContentType.json;
            response.write(jsonEncode(installed));
            return;
          }
          final result = generateToolTheme(input);
          final generationId = '${++_generation}';
          if (_generated.length >= 16) _generated.remove(_generated.keys.first);
          _generated[generationId] = (result, {'schemaVersion': 1, ...input});
          response.headers.contentType = ContentType.json;
          response.write(jsonEncode({
            'generationId': generationId,
            'manifest': result.toJson(),
            'colors': {
              for (final entry in result.theme.variants.entries)
                entry.key.name: {
                  for (final token in entry.value.values.entries)
                    token.key.path: token.value.hex,
                },
            },
            'roles': {
              for (final token in AuroraFoundation.tokens)
                token.path: token.description
            },
          }));
        }
      } else {
        response.statusCode = HttpStatus.notFound;
      }
    } catch (error) {
      response.statusCode = error is FormatException ||
              error is ArgumentError ||
              error is AuroraValidationException ||
              error is FileSystemException
          ? HttpStatus.badRequest
          : HttpStatus.internalServerError;
      response.headers.contentType = ContentType.json;
      response.write(jsonEncode({
        'error':
            response.statusCode == 400 ? error.toString() : 'Generation failed'
      }));
    } finally {
      await response.close();
    }
  }
}

/// Foundation-only authoring inputs. Full app contracts remain in the core API.
AuroraGenerationResult generateToolTheme(Map<String, dynamic> input) {
  const allowed = {
    'id',
    'name',
    'primary',
    'scheme',
    'secondary',
    'tertiary',
    'success',
    'warning',
    'info',
    'appearance'
  };
  if (input.keys.any((key) => !allowed.contains(key)))
    throw const FormatException('Unknown input field');
  String text(String key, {String? fallback}) {
    final value = input[key] ?? fallback;
    if (value is! String || value.trim().isEmpty)
      throw FormatException('$key must be a nonempty string');
    return value.trim();
  }

  AuroraColor? optional(String key) => input[key] == null || input[key] == ''
      ? null
      : AuroraColor.hex(text(key));
  final mode = text('appearance', fallback: 'both');
  final scheme = text('scheme', fallback: 'tonalSpot');
  if (!AuroraGenerationScheme.values.any((value) => value.name == scheme)) {
    throw FormatException('Unknown scheme $scheme');
  }
  if (!{'both', 'light', 'dark'}.contains(mode))
    throw const FormatException('appearance must be both, light, or dark');
  return AuroraGenerator.generate(AuroraGenerationRequest(
    contract: AuroraContract(id: 'aurora-foundation'),
    id: text('id'),
    name: text('name'),
    primary: AuroraColor.hex(text('primary')),
    scheme: AuroraGenerationScheme.values.byName(scheme),
    secondary: optional('secondary'),
    tertiary: optional('tertiary'),
    success: optional('success'),
    warning: optional('warning'),
    info: optional('info'),
    appearances: mode == 'both'
        ? AuroraAppearance.values
        : [AuroraAppearance.values.byName(mode)],
    preferredAppearance:
        mode == 'dark' ? AuroraAppearance.dark : AuroraAppearance.light,
  ));
}
