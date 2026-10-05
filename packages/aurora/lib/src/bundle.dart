import 'contract.dart';
import 'dtcg.dart';
import 'texture.dart';
import 'texture_dtcg.dart';
import 'theme.dart';

/// One problem found in a bundle. See `spec/bundle-v1.md`.
final class AuroraBundleIssue {
  const AuroraBundleIssue(this.category, this.file, this.message);

  /// `format` or `validation`.
  final String category;

  /// `manifest`, `bundle`, or the token file name.
  final String file;
  final String message;

  Map<String, Object?> toJson() =>
      {'category': category, 'file': file, 'message': message};

  @override
  String toString() => '$file: $message';
}

/// A valid bundle's theme, optional texture and suggested pairing.
final class AuroraBundleContents {
  const AuroraBundleContents(
      this.manifest, this.theme, this.texture, this.pairing);

  /// The manifest as decoded JSON.
  final Map<String, Object?> manifest;
  final AuroraTheme theme;
  final AuroraTexture? texture;

  /// The producer's suggested `themeId` to `textureId` pairing, or null. The
  /// app decides whether to register it.
  final ({String themeId, String textureId})? pairing;
}

/// The result of [AuroraBundle.validate]: every issue, and the contents when
/// there are none.
final class AuroraBundleReport {
  AuroraBundleReport(Iterable<AuroraBundleIssue> issues, this.contents)
      : issues = List.unmodifiable(issues);
  final List<AuroraBundleIssue> issues;
  final AuroraBundleContents? contents;
  bool get valid => contents != null;
}

final _id = RegExp(r'^[a-z][a-z0-9_-]{0,79}$');
final _dateTime =
    RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$');
const _textureFile = 'texture.tokens.json';

String _variantFile(AuroraAppearance appearance) =>
    '${appearance.name}.tokens.json';

/// Portable bundle v1: one theme and an optional texture from an outside
/// producer. Pure: callers load the single-file JSON or a folder's
/// `manifest.json` and token files themselves. See `spec/bundle-v1.md`.
abstract final class AuroraBundle {
  static AuroraContract? _foundation;
  static AuroraTextureContract? _textureFoundation;

  /// The shared foundation-only theme contract used when no app contract is
  /// given.
  static AuroraContract get foundationContract =>
      _foundation ??= AuroraContract(id: 'aurora-foundation');

  /// The shared texture-foundation-only contract used when no app texture
  /// contract is given.
  static AuroraTextureContract get textureFoundationContract =>
      _textureFoundation ??=
          AuroraTextureContract(id: 'aurora-texture-foundation');

  /// Assembles the single-file form from a folder's manifest and token files.
  static Map<String, Object?> fromFolder(
          Object? manifest, Map<String, Object?> files) =>
      {'manifest': manifest, 'files': files};

  /// Validates a single-file bundle object and reports every issue. Never
  /// throws for invalid input.
  static AuroraBundleReport validate(Object? input,
      {AuroraContract? contract, AuroraTextureContract? textureContract}) {
    final themeContract = contract ?? foundationContract;
    final styles = textureContract ?? textureFoundationContract;
    final issues = <AuroraBundleIssue>[];
    AuroraBundleReport fail() => AuroraBundleReport(issues, null);
    if (input is! Map<String, Object?>) {
      issues.add(const AuroraBundleIssue('format', 'bundle',
          'A bundle must be an object with manifest and files'));
      return fail();
    }
    for (final key in input.keys) {
      if (key != 'manifest' && key != 'files') {
        issues.add(AuroraBundleIssue(
            'format', 'bundle', 'Unsupported bundle field $key'));
      }
    }
    final manifest = _checkManifest(input['manifest'], issues);
    final files = input['files'];
    if (files is! Map<String, Object?>) {
      issues.add(const AuroraBundleIssue(
          'format', 'bundle', 'files must be an object of token documents'));
      return fail();
    }
    final expected = <String>{};
    if (manifest != null) {
      for (final appearance in manifest.variants) {
        expected.add(_variantFile(appearance));
      }
      if (manifest.texture != null) expected.add(_textureFile);
      for (final name in expected) {
        if (!files.containsKey(name)) {
          issues.add(AuroraBundleIssue(
              'format', name, '$name is listed by the manifest but missing'));
        }
      }
      for (final name in files.keys) {
        if (!expected.contains(name)) {
          issues.add(AuroraBundleIssue(
              'format', name, '$name is not listed by the manifest'));
        }
      }
    }
    bool wanted(String name) =>
        files.containsKey(name) &&
        (manifest == null || expected.contains(name));
    final variants = <AuroraThemeVariant>[];
    for (final appearance in AuroraAppearance.values) {
      final name = _variantFile(appearance);
      if (!wanted(name)) continue;
      _collect(issues, name, () {
        final document = files[name];
        if (document is! Map<String, Object?>) {
          throw FormatException('$name must be a token document object');
        }
        variants.add(AuroraDtcg.decode(document,
            contract: themeContract, appearance: appearance));
      });
    }
    AuroraTexture? texture;
    if (wanted(_textureFile)) {
      _collect(issues, _textureFile, () {
        final document = files[_textureFile];
        if (document is! Map<String, Object?>) {
          throw const FormatException(
              '$_textureFile must be a token document object');
        }
        final decoded = AuroraTextureDtcg.decode(document,
            contract: styles,
            id: manifest?.texture?.id ?? 'texture',
            name: manifest?.texture?.name ?? 'Texture');
        decoded.validateColors(themeContract);
        texture = decoded;
      });
    }
    if (issues.isNotEmpty || manifest == null) return fail();
    return AuroraBundleReport(
        issues,
        AuroraBundleContents(
          input['manifest'] as Map<String, Object?>,
          AuroraTheme(
              id: manifest.id,
              name: manifest.name,
              variants: variants,
              preferredAppearance: manifest.preferred),
          texture,
          manifest.pairing,
        ));
  }

  /// Validates and returns the contents. Throws [FormatException] when any
  /// issue is a format issue, otherwise [AuroraValidationException] listing
  /// every issue as `file: message`.
  static AuroraBundleContents load(Object? input,
      {AuroraContract? contract, AuroraTextureContract? textureContract}) {
    final report =
        validate(input, contract: contract, textureContract: textureContract);
    if (report.contents case final contents?) return contents;
    final lines = report.issues.map((issue) => issue.toString());
    if (report.issues.any((issue) => issue.category == 'format')) {
      throw FormatException(lines.join('\n'));
    }
    throw AuroraValidationException(lines);
  }

  /// Produces a single-file bundle from a theme and an optional texture.
  static Map<String, Object?> encode({
    required AuroraTheme theme,
    AuroraTexture? texture,
    bool? pair,
    required String generator,
    required String sourceHash,
    required String createdAt,
  }) {
    final variants = AuroraAppearance.values
        .where((appearance) => theme.variants.containsKey(appearance))
        .toList();
    final paired = texture != null && (pair ?? true);
    return {
      'manifest': {
        'bundleVersion': 1,
        'theme': {
          'id': theme.id,
          'name': theme.name,
          'preferredAppearance': theme.preferredAppearance.name,
          'variants': [for (final appearance in variants) appearance.name],
        },
        if (texture != null)
          'texture': {'id': texture.id, 'name': texture.name},
        if (paired) 'pairing': {'themeId': theme.id, 'textureId': texture.id},
        'provenance': {
          'generator': generator,
          'sourceHash': sourceHash,
          'createdAt': createdAt,
        },
      },
      'files': {
        for (final appearance in variants)
          _variantFile(appearance):
              AuroraDtcg.encode(theme.variants[appearance]!),
        if (texture != null) _textureFile: AuroraTextureDtcg.encode(texture),
      },
    };
  }

  static void _collect(
      List<AuroraBundleIssue> issues, String file, void Function() decode) {
    try {
      decode();
    } on AuroraValidationException catch (error) {
      issues.addAll(error.issues
          .map((message) => AuroraBundleIssue('validation', file, message)));
    } on FormatException catch (error) {
      issues.add(AuroraBundleIssue('format', file, error.message));
    } on ArgumentError catch (error) {
      issues.add(AuroraBundleIssue('format', file, '${error.message}'));
    }
  }

  static _Manifest? _checkManifest(
      Object? raw, List<AuroraBundleIssue> issues) {
    void issue(String message) =>
        issues.add(AuroraBundleIssue('format', 'manifest', message));
    if (raw is! Map<String, Object?>) {
      issue('manifest must be an object');
      return null;
    }
    void fields(Map<String, Object?> value, List<String> allowed, String at) {
      final unknown = value.keys.where((key) => !allowed.contains(key));
      if (unknown.isNotEmpty) {
        issue('$at has unsupported fields ${unknown.join(', ')}');
      }
    }

    String? text(Object? value, String at) {
      if (value is String && value.trim().isNotEmpty) return value;
      issue('$at must be a nonempty string');
      return null;
    }

    String? id(Object? value, String at) {
      if (value is String && _id.hasMatch(value)) return value;
      issue(
          '$at must be 1-80 lowercase letters, digits, _ or -, starting with a letter');
      return null;
    }

    fields(raw, ['bundleVersion', 'theme', 'texture', 'pairing', 'provenance'],
        'manifest');
    // `==` so that 1 and 1.0 agree with JavaScript.
    if (raw['bundleVersion'] != 1) issue('bundleVersion must be 1');
    var usable = true;

    String? themeId;
    String? themeName;
    List<AuroraAppearance>? variants;
    AuroraAppearance? preferred;
    final theme = raw['theme'];
    if (theme is! Map<String, Object?>) {
      issue('theme must be an object');
      usable = false;
    } else {
      fields(theme, ['id', 'name', 'preferredAppearance', 'variants'], 'theme');
      themeId = id(theme['id'], 'theme.id');
      themeName = text(theme['name'], 'theme.name');
      final list = theme['variants'];
      if (list is! List ||
          list.isEmpty ||
          list.any((v) => v != 'light' && v != 'dark') ||
          list.toSet().length != list.length) {
        issue('theme.variants must be a nonempty array of unique light/dark');
      } else {
        variants = [
          for (final name in list)
            AuroraAppearance.values.byName(name as String)
        ];
        final named = theme['preferredAppearance'];
        preferred = variants
            .where((appearance) => appearance.name == named)
            .firstOrNull;
        if (preferred == null) {
          issue('theme.preferredAppearance must be one of theme.variants');
        }
      }
      if (themeId == null ||
          themeName == null ||
          variants == null ||
          preferred == null) {
        usable = false;
      }
    }

    ({String id, String name})? texture;
    if (raw.containsKey('texture')) {
      final value = raw['texture'];
      if (value is! Map<String, Object?>) {
        issue('texture must be an object');
        usable = false;
      } else {
        fields(value, ['id', 'name'], 'texture');
        final textureId = id(value['id'], 'texture.id');
        final name = text(value['name'], 'texture.name');
        if (textureId != null && name != null) {
          texture = (id: textureId, name: name);
        } else {
          usable = false;
        }
      }
    }

    ({String themeId, String textureId})? pairing;
    if (raw.containsKey('pairing')) {
      final value = raw['pairing'];
      if (value is! Map<String, Object?>) {
        issue('pairing must be an object');
      } else {
        fields(value, ['themeId', 'textureId'], 'pairing');
        if (!raw.containsKey('texture')) issue('pairing needs a texture');
        if (themeId != null && value['themeId'] != themeId) {
          issue('pairing.themeId must equal theme.id');
        }
        if (texture != null && value['textureId'] != texture.id) {
          issue('pairing.textureId must equal texture.id');
        }
        if (value['themeId'] case final String pairedTheme) {
          if (value['textureId'] case final String pairedTexture) {
            pairing = (themeId: pairedTheme, textureId: pairedTexture);
          }
        }
      }
    }

    var provenance = false;
    final source = raw['provenance'];
    if (source is! Map<String, Object?>) {
      issue('provenance must be an object');
    } else {
      fields(source, ['generator', 'sourceHash', 'createdAt'], 'provenance');
      final generator = text(source['generator'], 'provenance.generator');
      final hash = text(source['sourceHash'], 'provenance.sourceHash');
      final createdAt = source['createdAt'];
      if (createdAt is! String || !_dateTime.hasMatch(createdAt)) {
        issue('provenance.createdAt must be an RFC 3339 date-time');
      } else {
        provenance = generator != null && hash != null;
      }
    }
    if (!usable || !provenance) return null;
    return _Manifest(
        themeId!, themeName!, variants!, preferred!, texture, pairing);
  }
}

final class _Manifest {
  const _Manifest(this.id, this.name, this.variants, this.preferred,
      this.texture, this.pairing);
  final String id;
  final String name;
  final List<AuroraAppearance> variants;
  final AuroraAppearance preferred;
  final ({String id, String name})? texture;
  final ({String themeId, String textureId})? pairing;
}
