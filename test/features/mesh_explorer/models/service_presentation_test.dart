// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/mesh_explorer/models/service_presentation.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_types.dart';

void main() {
  group('ServicePresentationCatalog', () {
    test('boardV1 returns known presentation', () {
      final p = ServicePresentationCatalog.forServiceId(MrrpServiceId.boardV1);
      expect(p.title, 'Bulletin Board');
      expect(p.requiresHandshake, isTrue);
      expect(p.requiresIdentity, isFalse);
      expect(p.privacyClass, ServicePrivacyClass.consentGated);
      expect(p.icon, Icons.dashboard_outlined);
    });

    test('profileV1 returns known presentation', () {
      final p = ServicePresentationCatalog.forServiceId(
        MrrpServiceId.profileV1,
      );
      expect(p.title, 'Peer Profile');
      expect(p.requiresHandshake, isTrue);
      expect(p.requiresIdentity, isTrue);
      expect(p.privacyClass, ServicePrivacyClass.identityGated);
    });

    test('meetupV1 returns known presentation', () {
      final p = ServicePresentationCatalog.forServiceId(MrrpServiceId.meetupV1);
      expect(p.title, 'Coordination');
      expect(p.requiresHandshake, isTrue);
      expect(p.requiresIdentity, isTrue);
    });

    test('unknown service returns generic fallback', () {
      final p = ServicePresentationCatalog.forServiceId(0x9999);
      expect(p.title, 'Service');
      expect(p.subtitle, 'Available nearby');
      expect(p.requiresHandshake, isFalse);
      expect(p.requiresIdentity, isFalse);
      expect(p.privacyClass, ServicePrivacyClass.open);
    });

    test('echoTest returns fallback (hidden from public UI)', () {
      final p = ServicePresentationCatalog.forServiceId(MrrpServiceId.echoTest);
      expect(p.title, 'Service');
      expect(p.privacyClass, ServicePrivacyClass.open);
    });

    test('isPublicVisible excludes testOnly services', () {
      expect(
        ServicePresentationCatalog.isPublicVisible(
          MrrpServiceId.boardV1,
          MrrpServiceFlags.userVisible,
        ),
        isTrue,
      );

      expect(
        ServicePresentationCatalog.isPublicVisible(
          MrrpServiceId.echoTest,
          MrrpServiceFlags.testOnly,
        ),
        isFalse,
      );
    });
  });

  group('ServicePrivacyClass', () {
    test('has expected values', () {
      expect(ServicePrivacyClass.values.length, 3);
      expect(ServicePrivacyClass.open.index, 0);
      expect(ServicePrivacyClass.consentGated.index, 1);
      expect(ServicePrivacyClass.identityGated.index, 2);
    });
  });
}
