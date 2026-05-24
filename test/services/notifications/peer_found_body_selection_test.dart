// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Regression pin for `selectPeerFoundBody` in NotificationService.
//
// The "peer found nearby" OS notification body must match what the
// user actually has enabled in `.env`. Before item 7 of the
// MeshCanvas explanation pass, every fired notification said
// "A Handshake peer is in range. Open Handshake to connect." even
// when the operator had only `MESH_CANVAS_ENABLED=true` (which now
// implicitly turns SIP transport on so the notification fires).
//
// This test pins the four branches:
//   - Handshake ON  + MeshCanvas OFF -> Handshake-specific body
//   - Handshake OFF + MeshCanvas ON  -> MeshCanvas-specific body
//   - Both ON                        -> Generic combined body
//   - Both OFF                       -> null (caller drops the
//                                            notification entirely)

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/services/notifications/notification_service.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('MeshCanvas only -> body speaks about MeshCanvas, never Handshake', () {
    final body = selectPeerFoundBody(
      handshakeEnabled: false,
      meshCanvasEnabled: true,
      l10n: l10n,
    );
    expect(body, isNotNull);
    expect(body, equals(l10n.notificationMeshCanvasPeerFoundBody));
    expect(
      body,
      isNot(contains('Handshake')),
      reason:
          'When MESH_CANVAS_ENABLED=true and HANDSHAKE_ENABLED=false the '
          'notification body must direct the user to MeshCanvas, never '
          'mention the Handshake feature.',
    );
    expect(body, contains('MeshCanvas'));
  });

  test('Handshake only -> body speaks about Handshake, never MeshCanvas', () {
    final body = selectPeerFoundBody(
      handshakeEnabled: true,
      meshCanvasEnabled: false,
      l10n: l10n,
    );
    expect(body, isNotNull);
    expect(body, equals(l10n.notificationSipPeerFoundBody));
    expect(body, contains('Handshake'));
    expect(
      body,
      isNot(contains('MeshCanvas')),
      reason:
          'Handshake-only configs should not mention MeshCanvas in the '
          'peer-found notification body.',
    );
  });

  test('Both enabled -> combined body mentions both surfaces', () {
    final body = selectPeerFoundBody(
      handshakeEnabled: true,
      meshCanvasEnabled: true,
      l10n: l10n,
    );
    expect(body, isNotNull);
    expect(body, equals(l10n.notificationMeshPeerFoundBody));
    expect(body, contains('Handshake'));
    expect(body, contains('MeshCanvas'));
  });

  test('Neither enabled -> null so caller drops the notification', () {
    final body = selectPeerFoundBody(
      handshakeEnabled: false,
      meshCanvasEnabled: false,
      l10n: l10n,
    );
    expect(
      body,
      isNull,
      reason:
          'With no actionable surface available, the helper must return '
          'null so NotificationService can silently drop the discovery '
          'notification instead of leaking stale wording.',
    );
  });
}
