// SPDX-License-Identifier: GPL-3.0-or-later

/// Repo-wide static analysis guards.
///
/// Scans ALL Dart source files under lib/ (excluding lib/generated/) to
/// ensure that MeshPacket construction never bypasses MeshPacketBuilder.
/// This prevents the "local admin with mesh-routing flags" bug class from
/// ever reappearing anywhere in the codebase.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Collects all .dart files under [root], excluding [excludeDirs].
List<File> _collectDartFiles(
  String root, {
  Set<String> excludeDirs = const {},
  Set<String> allowFiles = const {},
}) {
  final result = <File>[];
  final dir = Directory(root);
  if (!dir.existsSync()) return result;

  for (final entity in dir.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    if (!entity.path.endsWith('.dart')) continue;

    // Skip excluded directories
    final relativePath = entity.path.substring(root.length);
    if (excludeDirs.any((d) => relativePath.startsWith(d))) continue;

    // Skip explicitly allowed files
    if (allowFiles.any((f) => entity.path.endsWith(f))) continue;

    result.add(entity);
  }
  return result;
}

/// Format violation details for a test failure message with line numbers.
String _formatViolations(Map<String, List<String>> violations) {
  final buffer = StringBuffer();
  for (final entry in violations.entries) {
    buffer.writeln('  ${entry.key}:');
    for (final match in entry.value) {
      buffer.writeln('    $match');
    }
  }
  return buffer.toString();
}

/// Finds all regex matches in [source] and returns them with line numbers.
List<String> _matchesWithLineNumbers(RegExp pattern, String source) {
  final matches = pattern.allMatches(source).toList();
  if (matches.isEmpty) return [];

  return matches.map((m) {
    // Count newlines before the match start to determine the line number
    final lineNumber = source.substring(0, m.start).split('\n').length;
    final snippet = source
        .substring(m.start, (m.start + 80).clamp(0, source.length))
        .replaceAll('\n', ' ')
        .trim();
    return 'L$lineNumber: $snippet';
  }).toList();
}

void main() {
  // Files that are ALLOWED to construct MeshPacket directly
  const allowedConstructionFiles = {
    'lib/services/protocol/mesh_packet_builder.dart',
  };

  // Files that are ALLOWED to set RELIABLE priority
  const allowedReliableFiles = {
    'lib/services/protocol/mesh_packet_builder.dart',
  };

  // Files that are ALLOWED to set ..wantAck = true
  const allowedWantAckFiles = {
    'lib/services/protocol/mesh_packet_builder.dart',
  };

  // Directories to exclude from scanning
  const excludeDirs = {
    '/generated/', // Generated protobuf code
  };

  group('Repo-wide guardrail: no inline MeshPacket construction', () {
    late List<File> dartFiles;

    setUpAll(() {
      dartFiles = _collectDartFiles(
        'lib/',
        excludeDirs: excludeDirs,
        allowFiles: allowedConstructionFiles,
      );
      // Sanity check: we should find a reasonable number of files
      expect(
        dartFiles.length,
        greaterThan(10),
        reason:
            'Too few Dart files found. Check that the test is running from '
            'the project root.',
      );
    });

    test('no file outside MeshPacketBuilder constructs pb.MeshPacket()', () {
      final constructionPattern = RegExp(
        r'pb\.MeshPacket\(\)\s*(\.\.|;)',
        multiLine: true,
      );

      final violations = <String, List<String>>{};

      for (final file in dartFiles) {
        final source = file.readAsStringSync();
        final matches = _matchesWithLineNumbers(constructionPattern, source);
        if (matches.isNotEmpty) {
          violations[file.path] = matches;
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Found inline pb.MeshPacket() construction outside '
            'MeshPacketBuilder. All packet construction must go through '
            'MeshPacketBuilder to enforce local/remote admin invariants.\n'
            'FIX: Replace pb.MeshPacket().. with the appropriate '
            'MeshPacketBuilder.localAdmin / .remoteAdmin / .admin call.\n'
            '${_formatViolations(violations)}',
      );
    });

    test(
      'no file outside MeshPacketBuilder references MeshPacket_Priority.RELIABLE',
      () {
        final reliablePattern = RegExp(
          r'MeshPacket_Priority\.RELIABLE',
          multiLine: true,
        );

        final files = _collectDartFiles(
          'lib/',
          excludeDirs: excludeDirs,
          allowFiles: allowedReliableFiles,
        );

        final violations = <String, List<String>>{};

        for (final file in files) {
          final source = file.readAsStringSync();
          final matches = _matchesWithLineNumbers(reliablePattern, source);
          if (matches.isNotEmpty) {
            violations[file.path] = matches;
          }
        }

        expect(
          violations,
          isEmpty,
          reason:
              'Found MeshPacket_Priority.RELIABLE outside MeshPacketBuilder. '
              'Priority assignment belongs exclusively in MeshPacketBuilder.\n'
              'FIX: Use MeshPacketBuilder.remoteAdmin() which sets RELIABLE '
              'automatically.\n'
              '${_formatViolations(violations)}',
        );
      },
    );

    test('no file outside MeshPacketBuilder sets ..wantAck = true', () {
      final wantAckPattern = RegExp(
        r'\.\.\s*wantAck\s*=\s*true',
        multiLine: true,
      );

      final files = _collectDartFiles(
        'lib/',
        excludeDirs: excludeDirs,
        allowFiles: allowedWantAckFiles,
      );

      final violations = <String, List<String>>{};

      for (final file in files) {
        final source = file.readAsStringSync();
        final matches = _matchesWithLineNumbers(wantAckPattern, source);
        if (matches.isNotEmpty) {
          violations[file.path] = matches;
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Found ..wantAck = true outside MeshPacketBuilder. '
            'Packet wantAck assignment belongs exclusively in '
            'MeshPacketBuilder.\n'
            'FIX: Use MeshPacketBuilder.remoteAdmin() or .userPayload() '
            'which handle wantAck automatically.\n'
            '${_formatViolations(violations)}',
      );
    });

    test(
      'no file outside MeshPacketBuilder sets ..priority = on a MeshPacket',
      () {
        // Catches any direct priority assignment (not just RELIABLE)
        final priorityPattern = RegExp(r'\.\.\s*priority\s*=', multiLine: true);

        final files = _collectDartFiles(
          'lib/',
          excludeDirs: excludeDirs,
          allowFiles: allowedReliableFiles,
        );

        final violations = <String, List<String>>{};

        for (final file in files) {
          final source = file.readAsStringSync();
          final matches = _matchesWithLineNumbers(priorityPattern, source);
          if (matches.isNotEmpty) {
            violations[file.path] = matches;
          }
        }

        expect(
          violations,
          isEmpty,
          reason:
              'Found direct ..priority = assignment outside MeshPacketBuilder. '
              'All packet priority assignment must go through '
              'MeshPacketBuilder.\n'
              'FIX: Use MeshPacketBuilder.remoteAdmin() which sets the '
              'priority automatically.\n'
              '${_formatViolations(violations)}',
        );
      },
    );
  });

  group('Repo-wide guardrail: AdminTarget-only API', () {
    test(
      'protocol_service.dart public methods do not accept int? targetNodeNum',
      () {
        final file = File('lib/services/protocol/protocol_service.dart');
        expect(file.existsSync(), isTrue);

        final source = file.readAsStringSync();

        // Match method signatures (Future<...> methodName({...int? targetNodeNum...}))
        // We scan for `int? targetNodeNum` in parameter positions.
        // The MeshPacketBuilder parameter `targetNodeNum: dest` is fine since
        // that's a resolved node number, not the public API surface.
        final paramPattern = RegExp(
          r'int\?\s+targetNodeNum\s*[,)]',
          multiLine: true,
        );

        final matches = _matchesWithLineNumbers(paramPattern, source);

        expect(
          matches,
          isEmpty,
          reason:
              'Found int? targetNodeNum parameter in protocol_service.dart. '
              'All public methods must use AdminTarget? target instead.\n'
              'FIX: Replace int? targetNodeNum with AdminTarget? target, '
              'and forward as target: target to the core get/setConfig '
              'methods.\n'
              '${matches.map((m) => '  $m').join('\n')}',
        );
      },
    );
  });
}
