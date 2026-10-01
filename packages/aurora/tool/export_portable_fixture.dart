import 'dart:convert';
import 'dart:io';
import 'package:aurora/aurora.dart';

/// Refresh only when deliberately updating the portable conformance fixture.
void main() {
  const ticket =
      AuroraColorToken('demo.ticket', description: 'Ticket background.');
  final contract = AuroraContract(id: 'portable-demo', extensions: [ticket]);
  final variant = AuroraStarter.variant(
      contract: contract,
      appearance: AuroraAppearance.light,
      values: {ticket: AuroraColor.hex('#12345678')});
  final target = File.fromUri(
      Platform.script.resolve('../../../spec/fixtures/light.tokens.json'));
  target.parent.createSync(recursive: true);
  target.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(AuroraDtcg.encode(variant))}\n');
}
