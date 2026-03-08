// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Service presentation layer for Mesh Explorer.
///
/// Maps raw MRRP service identifiers to public-facing card descriptions
/// suitable for display in the consumer UI. Unknown services get graceful
/// generic fallback rendering.
library;

import 'package:flutter/material.dart';

import '../../../services/protocol/sip/mrrp_types.dart';
import '../../mesh_services/services/mesh_service_engine.dart';

/// Signal service ID (signal.v1 = 0x00000004).
const int _signalV1ServiceId = 0x00000004;

/// A public-facing card representation of an MRRP service.
class ServicePresentation {
  /// Human-readable service title (e.g., "Bulletin Board").
  final String title;

  /// Short description of the service.
  final String subtitle;

  /// Icon to display on the card.
  final IconData icon;

  /// Whether a SIP handshake is required to use this service.
  final bool requiresHandshake;

  /// Whether a verified identity is required.
  final bool requiresIdentity;

  /// Public action label (e.g., "Open Board", "View Profile").
  final String actionLabel;

  /// Privacy class: public, consent-gated, or identity-gated.
  final ServicePrivacyClass privacyClass;

  const ServicePresentation({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.requiresHandshake,
    required this.requiresIdentity,
    required this.actionLabel,
    required this.privacyClass,
  });
}

/// Privacy classification for public UI rendering.
enum ServicePrivacyClass {
  /// No consent required (e.g., signals).
  open,

  /// SIP handshake required.
  consentGated,

  /// Verified identity required.
  identityGated,
}

/// Catalog that maps MRRP service IDs to public-facing presentations.
///
/// Unknown services receive a graceful generic fallback.
abstract final class ServicePresentationCatalog {
  static const _known = <int, ServicePresentation>{
    MrrpServiceId.boardV1: ServicePresentation(
      title: 'Bulletin Board', // lint-allow: hardcoded-string
      subtitle: 'Local mesh posts', // lint-allow: hardcoded-string
      icon: Icons.dashboard_outlined,
      requiresHandshake: true,
      requiresIdentity: false,
      actionLabel: 'Open Board', // lint-allow: hardcoded-string
      privacyClass: ServicePrivacyClass.consentGated,
    ),
    MrrpServiceId.profileV1: ServicePresentation(
      title: 'Peer Profile', // lint-allow: hardcoded-string
      subtitle: 'Shared identity info', // lint-allow: hardcoded-string
      icon: Icons.person_outline,
      requiresHandshake: true,
      requiresIdentity: true,
      actionLabel: 'View Profile', // lint-allow: hardcoded-string
      privacyClass: ServicePrivacyClass.identityGated,
    ),
    MrrpServiceId.meetupV1: ServicePresentation(
      title: 'Coordination', // lint-allow: hardcoded-string
      subtitle: 'Rendezvous tokens', // lint-allow: hardcoded-string
      icon: Icons.handshake_outlined,
      requiresHandshake: true,
      requiresIdentity: true,
      actionLabel: 'Details', // lint-allow: hardcoded-string
      privacyClass: ServicePrivacyClass.identityGated,
    ),
    _signalV1ServiceId: ServicePresentation(
      title: 'Signals', // lint-allow: hardcoded-string
      subtitle: 'Anonymous status broadcasts', // lint-allow: hardcoded-string
      icon: Icons.cell_tower_outlined,
      requiresHandshake: false,
      requiresIdentity: false,
      actionLabel: 'View', // lint-allow: hardcoded-string
      privacyClass: ServicePrivacyClass.open,
    ),
    kMeshServicesInstanceServiceId: ServicePresentation(
      title: 'Mesh Services', // lint-allow: hardcoded-string
      subtitle: 'User-created services', // lint-allow: hardcoded-string
      icon: Icons.miscellaneous_services_outlined,
      requiresHandshake: false,
      requiresIdentity: false,
      actionLabel: 'Browse', // lint-allow: hardcoded-string
      privacyClass: ServicePrivacyClass.open,
    ),
  };

  /// Generic fallback for unknown services.
  static const _fallback = ServicePresentation(
    title: 'Service', // lint-allow: hardcoded-string
    subtitle: 'Available nearby', // lint-allow: hardcoded-string
    icon: Icons.extension_outlined,
    requiresHandshake: false,
    requiresIdentity: false,
    actionLabel: 'Details', // lint-allow: hardcoded-string
    privacyClass: ServicePrivacyClass.open,
  );

  /// Look up the public-facing presentation for a service ID.
  ///
  /// Returns a generic card for unknown services. Test-only services
  /// (echo.test) are excluded from the public UI.
  static ServicePresentation forServiceId(int serviceId) {
    // Hide test-only services from public UI
    if (serviceId == MrrpServiceId.echoTest) return _fallback;
    return _known[serviceId] ?? _fallback;
  }

  /// Whether a service should be displayed in the public UI.
  ///
  /// Excludes test-only services.
  static bool isPublicVisible(int serviceId, int serviceFlags) {
    if (serviceFlags & MrrpServiceFlags.testOnly != 0) return false;
    return true;
  }
}
