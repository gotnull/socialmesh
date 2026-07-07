// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:socialmesh/services/firmware/firmware_api_service.dart';

// Release-check error surfacing.
//
// fetchLatestRelease used to swallow every failure (non-200, timeout,
// no network) into `null`, which the screen rendered as the benign
// "no update available" card - the error banner was dead code and a
// failed check was indistinguishable from being up to date. It now
// throws FirmwareFetchException so firmwareReleaseProvider lands in
// AsyncError and the screen shows the real failure state.
void main() {
  http.Response jsonResponse(Map<String, dynamic> body, {int status = 200}) {
    return http.Response(
      json.encode(body),
      status,
      headers: {'content-type': 'application/json'},
    );
  }

  test('200 parses tag, version, and assets', () async {
    final service = FirmwareApiService(
      client: MockClient((request) async {
        expect(request.url.path, contains('/releases/latest'));
        return jsonResponse({
          'tag_name': 'v2.7.26.54e0d8d',
          'published_at': '2026-06-30T10:00:00Z',
          'body': 'Notes',
          'html_url': 'https://github.com/meshtastic/firmware/releases/x',
          'assets': [
            {
              'name': 'firmware-nrf52840-2.7.26.54e0d8d.zip',
              'browser_download_url': 'https://example.com/fw.zip',
              'size': 1024,
            },
          ],
        });
      }),
    );

    final release = await service.fetchLatestRelease();

    expect(release, isNotNull);
    expect(release!.version, '2.7.26.54e0d8d');
    expect(release.tagName, 'v2.7.26.54e0d8d');
    expect(release.assets, hasLength(1));
    expect(release.assets.single.name, 'firmware-nrf52840-2.7.26.54e0d8d.zip');
  });

  test('missing optional JSON fields parse safely', () async {
    final service = FirmwareApiService(
      client: MockClient((_) async => jsonResponse({'tag_name': 'v1.0.0'})),
    );

    final release = await service.fetchLatestRelease();

    expect(release!.version, '1.0.0');
    expect(release.releaseNotes, isEmpty);
    expect(release.assets, isEmpty);
  });

  test('non-200 throws FirmwareFetchException with the status code', () async {
    final service = FirmwareApiService(
      client: MockClient((_) async => http.Response('rate limited', 403)),
    );

    await expectLater(
      service.fetchLatestRelease(),
      throwsA(
        isA<FirmwareFetchException>().having(
          (e) => e.toString(),
          'message',
          contains('403'),
        ),
      ),
    );
  });

  test('network failure throws FirmwareFetchException', () async {
    final service = FirmwareApiService(
      client: MockClient((_) async => throw http.ClientException('down')),
    );

    await expectLater(
      service.fetchLatestRelease(),
      throwsA(isA<FirmwareFetchException>()),
    );
  });
}
