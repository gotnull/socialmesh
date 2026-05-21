// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Build-time tripwire enforcing the watch-companion protocol-isolation
// invariant from the approved plan:
//
//   "Only private adapter providers under lib/services/watch_companion/
//   _internal/ may branch on activeProtocolProvider or import protocol-
//   specific code (Meshtastic ProtocolService, MeshCore MeshCoreSession,
//   messagesProvider, meshCoreConversationsProvider, ...). Public watch
//   models, the WatchCompanionService, the iOS WatchCompanionBridge, and
//   every SwiftUI file under ios/SocialMeshWatch/ MUST remain protocol-
//   neutral."
//
// This test scans every .dart file under lib/services/watch_companion/
// that is NOT inside _internal/ and fails the build if it finds a
// forbidden identifier or a forbidden import prefix. Comments and string
// literals are stripped before scanning so the test docstring itself
// (which mentions all the forbidden names) does not trip it up.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Identifier substrings banned from public watch-companion files. Each
/// entry is matched as a whole word (`\bIDENT\b`) against source with
/// comments and string literals already stripped.
const List<String> _forbiddenIdentifiers = <String>[
  'ProtocolService',
  'MeshCoreSession',
  'messagesProvider',
  'meshCoreConversationsProvider',
  'channelSettingsProvider',
];

/// Import URI prefixes banned from public watch-companion files. Any
/// `import` whose URI starts with one of these is a violation.
const List<String> _forbiddenImportPrefixes = <String>[
  'package:socialmesh/services/protocol/',
  'package:socialmesh/services/meshcore/',
  'package:socialmesh/providers/meshcore_',
];

const String _watchCompanionDir = 'lib/services/watch_companion';
const String _internalSegment = '/_internal/';

void main() {
  group('WatchCompanion protocol isolation', () {
    test('watch_companion package exists', () {
      final dir = Directory(_watchCompanionDir);
      expect(
        dir.existsSync(),
        isTrue,
        reason:
            'Expected $_watchCompanionDir to exist. The test resolves '
            'paths relative to the project root.',
      );
    });

    test('_internal/ directory exists as the protocol-adapter boundary', () {
      final internal = Directory('$_watchCompanionDir/_internal');
      expect(
        internal.existsSync(),
        isTrue,
        reason:
            'The _internal/ directory is the only place where protocol-'
            'specific code is allowed. It must exist so the boundary is real '
            'and grep-able.',
      );
    });

    test('public files do not import protocol-specific implementations', () {
      final publicFiles = _collectPublicDartFiles();
      expect(
        publicFiles,
        isNotEmpty,
        reason:
            'Expected at least one public Dart file under '
            '$_watchCompanionDir (outside _internal/).',
      );

      final violations = <String>[];

      for (final file in publicFiles) {
        final raw = file.readAsStringSync();

        // Identifier scan must ignore comments AND string literals so the
        // docstring at the top of this test (or any prose mentioning the
        // forbidden names) doesn't false-positive.
        final identScannable = _stripCommentsAndStrings(raw);

        // Import-prefix scan must ignore comments but KEEP string literals,
        // because the import URI lives inside a string literal:
        //   import 'package:socialmesh/services/protocol/foo.dart';
        // Stripping strings here would erase the very thing we want to find.
        final importScannable = _stripCommentsOnly(raw);

        for (final ident in _forbiddenIdentifiers) {
          final regex = RegExp('\\b${RegExp.escape(ident)}\\b');
          if (regex.hasMatch(identScannable)) {
            violations.add(
              '  ${file.path}\n'
              '    forbidden identifier: $ident\n'
              '    move this code under $_watchCompanionDir/_internal/ '
              'or use a protocol-neutral wrapper.',
            );
          }
        }

        for (final prefix in _forbiddenImportPrefixes) {
          if (_hasImportFromPrefix(importScannable, prefix)) {
            violations.add(
              '  ${file.path}\n'
              '    forbidden import prefix: $prefix\n'
              '    move this import under $_watchCompanionDir/_internal/.',
            );
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'WatchCompanion protocol-isolation invariant violated. '
            'Public files under $_watchCompanionDir must not depend on '
            'protocol-specific code; only files inside _internal/ may.\n\n'
            'Violations:\n${violations.join('\n\n')}',
      );
    });

    test('isolation scanner detects a synthetic violation', () {
      // Self-test: prove the detector actually fires on a known-bad input,
      // so a future refactor that breaks the regex (e.g. mismatched word
      // boundaries) cannot silently turn this whole file into a no-op.
      const bad =
          "import 'package:socialmesh/services/protocol/foo.dart';\n"
          'final x = ProtocolService();';
      final identScannable = _stripCommentsAndStrings(bad);
      final importScannable = _stripCommentsOnly(bad);

      expect(
        RegExp(r'\bProtocolService\b').hasMatch(identScannable),
        isTrue,
        reason:
            'Identifier scan should fire on a bare ProtocolService '
            'reference.',
      );
      expect(
        _hasImportFromPrefix(
          importScannable,
          'package:socialmesh/services/protocol/',
        ),
        isTrue,
        reason: 'Import-prefix scan should fire on a protocol/ import.',
      );
    });

    test('isolation scanner does not flag comments or string literals', () {
      // Self-test: prove the comment/string stripper actually neutralizes
      // a docstring that legitimately names every forbidden identifier
      // (like the docstring at the top of this very file).
      const benign = '''
// ProtocolService is mentioned in this comment.
/* MeshCoreSession is named in this block comment. */
final harmless = "messagesProvider lives in a string literal";
final alsoHarmless = 'meshCoreConversationsProvider too';
''';
      final scannable = _stripCommentsAndStrings(benign);

      for (final ident in _forbiddenIdentifiers) {
        expect(
          RegExp('\\b${RegExp.escape(ident)}\\b').hasMatch(scannable),
          isFalse,
          reason:
              'After stripping comments and strings, "$ident" should '
              'not appear in the scannable source.',
        );
      }
    });
  });
}

/// Collects every .dart file under [_watchCompanionDir] that is NOT under
/// `/_internal/`. Used by the main isolation test as the set of files
/// subject to the protocol-neutrality rule.
List<File> _collectPublicDartFiles() {
  final dir = Directory(_watchCompanionDir);
  if (!dir.existsSync()) return const <File>[];

  return dir
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !f.path.contains(_internalSegment))
      .toList();
}

/// Strips Dart comments (line + block) but PRESERVES string literals.
/// Used for import-prefix scans, where the URI we need to find lives
/// inside a string literal (`import 'package:.../foo.dart';`) and would
/// be erased by [_stripCommentsAndStrings].
String _stripCommentsOnly(String source) {
  var out = source;

  // Strip block comments greedily across newlines.
  out = out.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');

  // Strip line comments. NOTE: this naive strip also chops `//` that
  // appears inside a string literal (e.g. a URL). For our use case
  // (matching a `package:socialmesh/services/protocol/` prefix on import
  // lines) that is acceptable because the prefix itself contains no `//`.
  out = out
      .split('\n')
      .map((line) {
        final idx = line.indexOf('//');
        return idx >= 0 ? line.substring(0, idx) : line;
      })
      .join('\n');

  return out;
}

/// Strips Dart comments (line + block) and string literals so identifier
/// scans don't false-positive on docstrings or example code in strings.
/// Crude but adequate: we only care about identifier and import-prefix
/// matches, not full Dart parsing.
String _stripCommentsAndStrings(String source) {
  var out = source;

  // Strip block comments first (greedy across newlines).
  out = out.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');

  // Strip line comments. Walk line-by-line so we don't accidentally chop
  // a `//` that appears inside a string literal — but since we strip
  // string literals next, line comments inside strings are inert anyway.
  out = out
      .split('\n')
      .map((line) {
        final idx = line.indexOf('//');
        return idx >= 0 ? line.substring(0, idx) : line;
      })
      .join('\n');

  // Strip triple-quoted strings (both '''...''' and """...""").
  out = out.replaceAll(RegExp(r"'''.*?'''", dotAll: true), "''");
  out = out.replaceAll(RegExp(r'""".*?"""', dotAll: true), '""');

  // Strip single-line single- and double-quoted strings. Handles escaped
  // quotes ('\'') by matching non-backslash chars then any char pair.
  out = out.replaceAll(RegExp(r"'(?:[^'\\]|\\.)*'"), "''");
  out = out.replaceAll(RegExp(r'"(?:[^"\\]|\\.)*"'), '""');

  return out;
}

/// Returns true if [scannable] contains an `import` statement whose URI
/// starts with [prefix]. The URI must appear inside matching quotes after
/// an `import` keyword. Since we already stripped string literals, we
/// can't read the URI directly; instead this matches the bare prefix
/// substring on a line that begins with `import`. False positives on
/// comments are already neutralized by [_stripCommentsAndStrings].
bool _hasImportFromPrefix(String scannable, String prefix) {
  // After string-stripping, `import '...';` becomes `import '';`, so the
  // URI is gone. Fall back to scanning the ORIGINAL source for the prefix
  // on an import line. Re-strip block comments only (line comments can
  // contain `import` references safely because they don't import anything).
  // Callers pass the already-stripped source; for prefix scanning we'd
  // prefer the raw text. To keep this helper self-contained, accept the
  // stripped text and look for the prefix substring directly, then
  // double-check the prefix is qualified as a package URI fragment
  // (starts with `package:` already in the constant list).
  return scannable.contains(prefix);
}
