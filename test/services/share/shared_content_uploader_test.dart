// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pins the duplicate-detection fingerprint: key-order independent,
// ignored keys excluded, and any content difference changes the value.
// The fingerprint decides whether a re-share reuses an existing
// Firestore document, so a regression silently forks shared content.

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/share/shared_content_uploader.dart';

void main() {
  test('fingerprint is independent of key insertion order', () {
    const uploader = SharedContentUploader(
      collection: 'shared_test',
      log: _noop,
    );
    final a = uploader.fingerprintOf({
      'name': 'My Automation',
      'description': 'd',
      'trigger': 'x',
    });
    final b = uploader.fingerprintOf({
      'trigger': 'x',
      'name': 'My Automation',
      'description': 'd',
    });
    expect(a, b);
  });

  test('ignored keys do not affect the fingerprint', () {
    const uploader = SharedContentUploader(
      collection: 'shared_test',
      log: _noop,
      fingerprintIgnoredKeys: {'createdBy', 'createdAt', 'isPublic'},
    );
    final stored = uploader.fingerprintOf({
      'name': 'W',
      'layout': 'grid',
      'createdBy': 'user-1',
      'createdAt': 'server-time',
      'isPublic': true,
    });
    final fresh = uploader.fingerprintOf({'name': 'W', 'layout': 'grid'});
    expect(stored, fresh);
  });

  test('content differences change the fingerprint', () {
    const uploader = SharedContentUploader(
      collection: 'shared_test',
      log: _noop,
    );
    final a = uploader.fingerprintOf({'name': 'W', 'layout': 'grid'});
    final b = uploader.fingerprintOf({'name': 'W', 'layout': 'list'});
    expect(a, isNot(b));
  });

  test('non-ignored extra keys change the fingerprint', () {
    const uploader = SharedContentUploader(
      collection: 'shared_test',
      log: _noop,
    );
    final a = uploader.fingerprintOf({'name': 'W'});
    final b = uploader.fingerprintOf({'name': 'W', 'conditions': []});
    expect(a, isNot(b));
  });
}

void _noop(String _) {}
