// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// MRRP profile.v1 service handler.
///
/// Opt-in profile sharing over the mesh. The handler reads which fields
/// the local user has chosen to share from a configuration callback, and
/// returns only those fields. Contact card data requires the requesting
/// peer to have an identity-verified entry in [SipIdentityStore].
///
/// Actions:
/// - **get_summary** (0x0001): Display name, status, device class, availability.
/// - **get_contact_card** (0x0002): Contact fields (requires identity verification).
/// - **get_capabilities** (0x0003): Registered MRRP services + feature bitmaps.
library;

import 'dart:typed_data';

import '../../../core/logging.dart';
import 'mrrp_constants.dart';
import 'mrrp_frame.dart';
import 'mrrp_service_handler.dart';
import 'mrrp_types.dart';

/// Profile configuration — which fields the user has chosen to share.
class MrrpProfileConfig {
  /// Display name (max 32 bytes UTF-8).
  final String displayName;

  /// Status text (max 64 bytes UTF-8).
  final String statusText;

  /// Device class code (0=unknown, 1=phone, 2=tablet, 3=desktop).
  final int deviceClass;

  /// Availability code (0=unknown, 1=available, 2=busy, 3=away, 4=offline).
  final int availability;

  /// Contact card fields (max 80 bytes UTF-8, optional).
  final String? contactCard;

  /// List of registered MRRP service IDs.
  final List<int> registeredServices;

  /// SIP feature bitmap.
  final int sipFeatures;

  /// MRRP feature bitmap.
  final int mrrpFeatures;

  const MrrpProfileConfig({
    required this.displayName,
    this.statusText = '', // lint-allow: hardcoded-string
    this.deviceClass = 0,
    this.availability = 0,
    this.contactCard,
    this.registeredServices = const [],
    this.sipFeatures = 0,
    this.mrrpFeatures = 0,
  });
}

/// Callback to check if a peer has verified identity.
typedef PeerIdentityChecker = bool Function(int senderNodeId);

/// Callback to get the current profile configuration.
typedef ProfileConfigProvider = MrrpProfileConfig Function();

/// Max encoded lengths for profile fields.
abstract final class _ProfileLimits {
  static const int maxDisplayNameBytes = 32;
  static const int maxStatusTextBytes = 64;
  static const int maxContactCardBytes = 80;
}

/// profile.v1 handler.
class MrrpServiceProfile implements MrrpServiceHandler {
  final ProfileConfigProvider _configProvider;
  final PeerIdentityChecker? _identityChecker;

  /// Whether profile sharing is enabled.
  ///
  /// When `false` (default), all profile requests are rejected with
  /// FORBIDDEN. Wired from the mesh privacy "profile sharing" toggle
  /// via the provider layer.
  bool isProfileSharingEnabled = false;

  MrrpServiceProfile({
    required ProfileConfigProvider configProvider,
    PeerIdentityChecker? identityChecker,
  }) : _configProvider = configProvider,
       _identityChecker = identityChecker;

  @override
  int get serviceId => MrrpServiceId.profileV1;

  @override
  Set<int> get supportedActions => const {
    ProfileAction.getSummary,
    ProfileAction.getContactCard,
    ProfileAction.getCapabilities,
  };

  @override
  Future<MrrpFrame> handleRequest(MrrpFrame request, int senderNodeId) async {
    // Privacy gate: reject all profile requests when profile sharing is off.
    if (!isProfileSharingEnabled) {
      AppLogging.mrrp(
        'MRRP_SERVICE: profile.v1 request rejected — '
        'profile sharing disabled', // lint-allow: hardcoded-string
      );
      return _buildError(request, MrrpStatusCode.unauthorized);
    }

    switch (request.actionId) {
      case ProfileAction.getSummary:
        return _handleGetSummary(request);
      case ProfileAction.getContactCard:
        return _handleGetContactCard(request, senderNodeId);
      case ProfileAction.getCapabilities:
        return _handleGetCapabilities(request);
      default:
        return _buildError(request, MrrpStatusCode.unsupported);
    }
  }

  // ---------------------------------------------------------------------------
  // get_summary
  // ---------------------------------------------------------------------------

  /// Response: name_len(1) + name(N) + status_len(1) + status(N) +
  /// device_class(1) + availability(1).
  MrrpFrame _handleGetSummary(MrrpFrame request) {
    final config = _configProvider();
    final nameBytes = _truncateUtf8(
      config.displayName,
      _ProfileLimits.maxDisplayNameBytes,
    );
    final statusBytes = _truncateUtf8(
      config.statusText,
      _ProfileLimits.maxStatusTextBytes,
    );

    final totalLen = 1 + nameBytes.length + 1 + statusBytes.length + 1 + 1;
    final payload = Uint8List(totalLen);
    var offset = 0;

    payload[offset++] = nameBytes.length;
    payload.setRange(offset, offset + nameBytes.length, nameBytes);
    offset += nameBytes.length;

    payload[offset++] = statusBytes.length;
    payload.setRange(offset, offset + statusBytes.length, statusBytes);
    offset += statusBytes.length;

    payload[offset++] = config.deviceClass & 0xFF;
    payload[offset++] = config.availability & 0xFF;

    AppLogging.mrrp(
      'MRRP_SERVICE: profile.v1 get_summary '
      '-> ${payload.length}B response', // lint-allow: hardcoded-string
    );

    return _buildResponse(request, payload);
  }

  // ---------------------------------------------------------------------------
  // get_contact_card
  // ---------------------------------------------------------------------------

  MrrpFrame _handleGetContactCard(MrrpFrame request, int senderNodeId) {
    // Identity verification required.
    final isVerified = _identityChecker?.call(senderNodeId) ?? false;
    if (!isVerified) {
      AppLogging.mrrp(
        'MRRP_SERVICE: profile.v1 get_contact_card '
        '-> UNAUTHORIZED (peer not verified)', // lint-allow: hardcoded-string
      );
      return _buildError(request, MrrpStatusCode.unauthorized);
    }

    final config = _configProvider();
    final contactText = config.contactCard ?? '';
    final contactBytes = _truncateUtf8(
      contactText,
      _ProfileLimits.maxContactCardBytes,
    );

    // Response: contact_len(1) + contact(N).
    final payload = Uint8List(1 + contactBytes.length);
    payload[0] = contactBytes.length;
    payload.setRange(1, 1 + contactBytes.length, contactBytes);

    AppLogging.mrrp(
      'MRRP_SERVICE: profile.v1 get_contact_card '
      '-> ${payload.length}B response', // lint-allow: hardcoded-string
    );

    return _buildResponse(request, payload);
  }

  // ---------------------------------------------------------------------------
  // get_capabilities
  // ---------------------------------------------------------------------------

  MrrpFrame _handleGetCapabilities(MrrpFrame request) {
    final config = _configProvider();

    // Response: sip_features(2, LE) + mrrp_features(2, LE) +
    // service_count(1) + service_ids(N*4).
    final serviceCount = config.registeredServices.length;
    final totalLen = 2 + 2 + 1 + (serviceCount * 4);
    final payload = Uint8List(totalLen);
    final bd = ByteData.sublistView(payload);
    var offset = 0;

    bd.setUint16(offset, config.sipFeatures & 0xFFFF, Endian.little);
    offset += 2;
    bd.setUint16(offset, config.mrrpFeatures & 0xFFFF, Endian.little);
    offset += 2;
    payload[offset++] = serviceCount & 0xFF;

    for (final svcId in config.registeredServices) {
      bd.setUint32(offset, svcId, Endian.little);
      offset += 4;
    }

    AppLogging.mrrp(
      'MRRP_SERVICE: profile.v1 get_capabilities '
      '-> ${payload.length}B response', // lint-allow: hardcoded-string
    );

    return _buildResponse(request, payload);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Uint8List _truncateUtf8(String text, int maxBytes) {
    var bytes = Uint8List.fromList(text.codeUnits);
    if (bytes.length > maxBytes) {
      bytes = Uint8List.sublistView(bytes, 0, maxBytes);
    }
    return bytes;
  }

  MrrpFrame _buildResponse(MrrpFrame request, Uint8List payload) {
    return MrrpFrame(
      versionMajor: MrrpConstants.mrrpVersionMajor,
      versionMinor: MrrpConstants.mrrpVersionMinor,
      msgType: MrrpMessageType.response,
      flags: MrrpFlags.isResponse,
      headerLen: MrrpConstants.mrrpHeaderMin,
      requestId: request.requestId,
      serviceId: serviceId,
      actionId: request.actionId,
      payloadLen: payload.length,
      payload: payload,
    );
  }

  MrrpFrame _buildError(MrrpFrame request, MrrpStatusCode status) {
    final payload = Uint8List(1)..[0] = status.code;
    return MrrpFrame(
      versionMajor: MrrpConstants.mrrpVersionMajor,
      versionMinor: MrrpConstants.mrrpVersionMinor,
      msgType: MrrpMessageType.error,
      flags: MrrpFlags.isResponse | MrrpFlags.isError,
      headerLen: MrrpConstants.mrrpHeaderMin,
      requestId: request.requestId,
      serviceId: serviceId,
      actionId: request.actionId,
      payloadLen: 1,
      payload: payload,
      headerExtensions: [
        MrrpTlvEntry(
          type: MrrpTlvType.statusCode.code,
          value: Uint8List.fromList([status.code]),
        ),
      ],
    );
  }
}
