import 'dart:convert';
import 'dart:io';
import 'package:aurora/aurora.dart';
import 'package:aurora/src/tooling/server.dart';
import 'package:aurora/src/tooling/install.dart';
import 'package:test/test.dart';

void main() {
  test('tool inputs use the same generator and reject invalid fields', () {
    final input = {'id': 'demo', 'name': 'Demo', 'primary': '#246b35'};
    final result = generateToolTheme(input);
    final expected = AuroraGenerator.generate(AuroraGenerationRequest(
      contract: AuroraContract(id: 'aurora-foundation'),
      id: 'demo',
      name: 'Demo',
      primary: AuroraColor.hex('#246b35'),
    ));
    expect(result.toJson(), expected.toJson());
    expect(
        generateToolTheme({...input, 'appearance': 'dark'}).theme.variants.keys,
        [AuroraAppearance.dark]);
    for (final change in [
      {'primary': '#ffffff00'},
      {'primary': 'invalid'},
      {'name': 1},
      {'appearance': 'system'},
      {'undeclared': true},
    ]) {
      expect(() => generateToolTheme({...input, ...change}),
          throwsA(anyOf(isA<ArgumentError>(), isA<FormatException>())));
    }
  });

  test('local host serves UI, protects generation and exports decodable DTCG',
      () async {
    final root = await Directory.systemTemp.createTemp('aurora-http-');
    await File('${root.path}/pubspec.yaml')
        .writeAsString('name: app\ndependencies:\n  aurora: any\n');
    final server = await AuroraGeneratorServer.start(
        project: await AuroraProject.open(root.path));
    final client = HttpClient();
    addTearDown(() async {
      client.close(force: true);
      await server.close();
      await root.delete(recursive: true);
    });
    final page = await (await client.getUrl(server.url)).close();
    expect(page.statusCode, 200);
    final html = await utf8.decoder.bind(page).join();
    final token = RegExp('nonce="([a-f0-9]+)"').firstMatch(html)!.group(1)!;
    expect(html, contains('Theme inputs'));
    expect(page.headers.value('content-security-policy'),
        contains("frame-ancestors 'none'"));
    Future<HttpClientResponse> post(String body,
        {String? auth, String? origin, String route = 'generate'}) async {
      final request = await client.postUrl(server.url.resolve(route));
      if (auth != null) request.headers.set('x-aurora-token', auth);
      if (origin != null) request.headers.set('origin', origin);
      request.write(body);
      return request.close();
    }

    final missing = await post('{}');
    expect(missing.statusCode, 403);
    await missing.drain<void>();
    final crossOrigin =
        await post('{}', auth: token, origin: 'https://example.com');
    expect(crossOrigin.statusCode, 403);
    await crossOrigin.drain<void>();
    for (final body in [
      '{',
      '[]',
      jsonEncode({'primary': 'bad'}),
      'x' * 65537
    ]) {
      final response = await post(body, auth: token);
      expect(response.statusCode, 400);
      await response.drain<void>();
    }
    final response = await post(
        jsonEncode({'id': 'demo', 'name': 'Demo', 'primary': '#246b35'}),
        auth: token,
        origin: server.url.origin);
    expect(response.statusCode, 200);
    final output = jsonDecode(await utf8.decoder.bind(response).join()) as Map;
    for (final appearance in AuroraAppearance.values) {
      final document = output['manifest']['variants'][appearance.name]
          as Map<String, dynamic>;
      final variant = AuroraDtcg.decode(document,
          contract: AuroraContract(id: 'aurora-foundation'),
          appearance: appearance);
      expect(variant.values.length, 58);
      expect(output['colors'][appearance.name]['colors.primary'],
          variant.tokens.primary.hex);
    }
    final installed = await post(
        jsonEncode({'generationId': output['generationId']}),
        auth: token,
        route: 'install');
    expect(installed.statusCode, 200);
    final installation = jsonDecode(await utf8.decoder.bind(installed).join());
    expect(
        await File('${installation['directory']}/theme.dart').exists(), true);
    final duplicate = await post(
        jsonEncode({'generationId': output['generationId']}),
        auth: token,
        route: 'install');
    expect(duplicate.statusCode, 400);
    await duplicate.drain<void>();
    final traversal = await post(
        jsonEncode(
            {'generationId': output['generationId'], 'project': '../other'}),
        auth: token,
        route: 'install');
    expect(traversal.statusCode, 400);
    await traversal.drain<void>();
    final unknown =
        await (await client.getUrl(server.url.resolve('missing'))).close();
    expect(unknown.statusCode, 404);
    await unknown.drain<void>();
  });
}
