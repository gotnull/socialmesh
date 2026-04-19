// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Service presentation layer for Mesh Explorer.
///
/// Maps raw MRRP service identifiers to public-facing card descriptions
/// suitable for display in the consumer UI. Unknown services get graceful
/// generic fallback rendering.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
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

/// Non-localized metadata for a known service.
class _ServiceMeta {
  final IconData icon;
  final bool requiresHandshake;
  final bool requiresIdentity;
  final ServicePrivacyClass privacyClass;

  const _ServiceMeta({
    required this.icon,
    required this.requiresHandshake,
    required this.requiresIdentity,
    required this.privacyClass,
  });
}

/// Catalog that maps MRRP service IDs to public-facing presentations.
///
/// Unknown services receive a graceful generic fallback.
abstract final class ServicePresentationCatalog {
  static const _meta = <int, _ServiceMeta>{
    MrrpServiceId.boardV1: _ServiceMeta(
      icon: Icons.dashboard_outlined,
      requiresHandshake: false,
      requiresIdentity: false,
      privacyClass: ServicePrivacyClass.open,
    ),
    MrrpServiceId.profileV1: _ServiceMeta(
      icon: Icons.person_outline,
      requiresHandshake: false,
      requiresIdentity: false,
      privacyClass: ServicePrivacyClass.open,
    ),
    MrrpServiceId.meetupV1: _ServiceMeta(
      icon: Icons.handshake_outlined,
      requiresHandshake: false,
      requiresIdentity: false,
      privacyClass: ServicePrivacyClass.open,
    ),
    _signalV1ServiceId: _ServiceMeta(
      icon: Icons.cell_tower_outlined,
      requiresHandshake: false,
      requiresIdentity: false,
      privacyClass: ServicePrivacyClass.open,
    ),
    kMeshServicesInstanceServiceId: _ServiceMeta(
      icon: Icons.miscellaneous_services_outlined,
      requiresHandshake: false,
      requiresIdentity: false,
      privacyClass: ServicePrivacyClass.open,
    ),
  };

  static const _fallbackMeta = _ServiceMeta(
    icon: Icons.extension_outlined,
    requiresHandshake: false,
    requiresIdentity: false,
    privacyClass: ServicePrivacyClass.open,
  );

  static (String, String, String) _localizedStrings(
    int serviceId,
    AppLocalizations l10n,
  ) {
    return switch (serviceId) {
      MrrpServiceId.boardV1 => (
        l10n.servicePresentationBoardTitle,
        l10n.servicePresentationBoardSubtitle,
        l10n.servicePresentationBoardAction,
      ),
      MrrpServiceId.profileV1 => (
        l10n.servicePresentationProfileTitle,
        l10n.servicePresentationProfileSubtitle,
        l10n.servicePresentationProfileAction,
      ),
      MrrpServiceId.meetupV1 => (
        l10n.servicePresentationMeetupTitle,
        l10n.servicePresentationMeetupSubtitle,
        l10n.servicePresentationMeetupAction,
      ),
      == _signalV1ServiceId => (
        l10n.servicePresentationSignalsTitle,
        l10n.servicePresentationSignalsSubtitle,
        l10n.servicePresentationSignalsAction,
      ),
      == kMeshServicesInstanceServiceId => (
        l10n.servicePresentationMeshServicesTitle,
        l10n.servicePresentationMeshServicesSubtitle,
        l10n.servicePresentationMeshServicesAction,
      ),
      _ => (
        l10n.servicePresentationFallbackTitle,
        l10n.servicePresentationFallbackSubtitle,
        l10n.servicePresentationFallbackAction,
      ),
    };
  }

  /// Look up the public-facing presentation for a service ID.
  ///
  /// Returns a generic card for unknown services. Test-only services
  /// (echo.test) are excluded from the public UI.
  static ServicePresentation forServiceId(
    int serviceId,
    AppLocalizations l10n,
  ) {
    // Hide test-only services from public UI
    final effectiveId = serviceId == MrrpServiceId.echoTest ? -1 : serviceId;
    final meta = _meta[effectiveId] ?? _fallbackMeta;
    final (title, subtitle, actionLabel) = _localizedStrings(effectiveId, l10n);
    return ServicePresentation(
      title: title,
      subtitle: subtitle,
      icon: meta.icon,
      requiresHandshake: meta.requiresHandshake,
      requiresIdentity: meta.requiresIdentity,
      actionLabel: actionLabel,
      privacyClass: meta.privacyClass,
    );
  }

  /// Whether a service should be displayed in the public UI.
  ///
  /// Excludes test-only services.
  static bool isPublicVisible(int serviceId, int serviceFlags) {
    if (serviceFlags & MrrpServiceFlags.testOnly != 0) return false;
    return true;
  }
}
