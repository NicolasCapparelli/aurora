import 'dart:convert';
import 'package:aurora/aurora.dart';

/// Run with `dart run example/generate.dart`. No Flutter initialization needed.
void main() {
  const ticket =
      AuroraColorToken('theater.ticket', description: 'Ticket background.');
  const onTicket =
      AuroraColorToken('theater.onTicket', description: 'Ticket foreground.');
  final contract =
      AuroraContract(id: 'theater', extensions: [ticket, onTicket]);
  final result = AuroraGenerator.generate(AuroraGenerationRequest(
    contract: contract,
    id: 'wicked',
    name: 'Wicked',
    primary: AuroraColor.hex('#246b35'),
    rules: {
      ticket: const AuroraAliasRule(AuroraFoundation.primaryContainer),
      onTicket: const AuroraAliasRule(AuroraFoundation.onPrimaryContainer),
    },
    contrastPairs: [
      AuroraContrastPair(foreground: onTicket, background: ticket)
    ],
  ));
  print(const JsonEncoder.withIndent('  ').convert(result.toJson()));
}
