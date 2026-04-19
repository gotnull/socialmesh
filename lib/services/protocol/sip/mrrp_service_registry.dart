// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// MRRP service registry — manages the set of locally registered services.
///
/// The registry tracks which [MrrpServiceHandler] instances are active and
/// generates SERVICE_ADVERT payloads describing them. It does not handle
/// network transmission — that is the [MrrpAdvertEngine]'s responsibility.
library;

import 'dart:typed_data';

import '../../../core/logging.dart';
import 'mrrp_constants.dart';
import 'mrrp_service_handler.dart';
import 'mrrp_types.dart';

/// Descriptor for a registered MRRP service.
///
/// Carries the metadata needed to build a SERVICE_ADVERT payload entry.
class MrrpServiceDescriptor {
  /// The 32-bit service identifier.
  final int serviceId;

  /// Service type (app, system, test).
  final MrrpServiceType serviceType;

  /// Major version of the service.
  final int versionMajor;

  /// Minor version of the service.
  final int versionMinor;

  /// Service flags bitfield (see [MrrpServiceFlags]).
  final int serviceFlags;

  /// Optional opaque metadata bytes (max 32 bytes).
  final Uint8List metadata;

  MrrpServiceDescriptor({
    required this.serviceId,
    required this.serviceType,
    this.versionMajor = 0,
    this.versionMinor = 1,
    this.serviceFlags = 0,
    Uint8List? metadata,
  }) : metadata = metadata ?? Uint8List(0);

  /// Wire size of this descriptor entry.
  int get wireSize => MrrpConstants.mrrpServiceDescriptorMin + metadata.length;
}

/// Local registry of MRRP services.
///
/// Used by the advertisement engine to build SERVICE_ADVERT payloads
/// and by the dispatcher to look up handlers by service ID.
class MrrpServiceRegistry {
  final Map<int, MrrpServiceHandler> _handlers = {};
  final Map<int, MrrpServiceDescriptor> _descriptors = {};

  /// Register a service handler with its descriptor.
  ///
  /// Returns false if max services would be exceeded.
  bool register(MrrpServiceHandler handler, MrrpServiceDescriptor descriptor) {
    if (_handlers.length >= MrrpConstants.mrrpServiceAdvertMaxServices &&
        !_handlers.containsKey(handler.serviceId)) {
      AppLogging.mrrp(
        'MRRP_REGISTRY: cannot register service '
        '${MrrpServiceId.nameOf(handler.serviceId)}, '
        'max ${MrrpConstants.mrrpServiceAdvertMaxServices} reached', // lint-allow: hardcoded-string
      );
      return false;
    }
    _handlers[handler.serviceId] = handler;
    _descriptors[handler.serviceId] = descriptor;
    AppLogging.mrrp(
      'MRRP_REGISTRY: registered ${MrrpServiceId.nameOf(handler.serviceId)}', // lint-allow: hardcoded-string
    );
    return true;
  }

  /// Unregister a service handler by service ID.
  void unregister(int serviceId) {
    _handlers.remove(serviceId);
    _descriptors.remove(serviceId);
    AppLogging.mrrp(
      'MRRP_REGISTRY: unregistered ${MrrpServiceId.nameOf(serviceId)}', // lint-allow: hardcoded-string
    );
  }

  /// Update the descriptor for an already-registered service.
  ///
  /// Returns false if the service ID is not registered.
  bool updateDescriptor(MrrpServiceDescriptor descriptor) {
    if (!_descriptors.containsKey(descriptor.serviceId)) return false;
    _descriptors[descriptor.serviceId] = descriptor;
    return true;
  }

  /// Instance-level descriptors that expand a single base service ID into
  /// multiple advert entries (one per active instance).
  ///
  /// When set, [getAdvertDescriptors] replaces the base descriptor for
  /// [_instanceBaseServiceId] with these. Handler dispatch is unaffected —
  /// all instances still route to the same [MrrpServiceHandler].
  final List<MrrpServiceDescriptor> _instanceDescriptors = [];
  int? _instanceBaseServiceId;

  /// Set instance-level descriptors for a service ID.
  ///
  /// The base descriptor for [baseServiceId] is replaced in advert payloads
  /// with one descriptor per instance (different metadata per instance).
  /// Pass an empty list to revert to the single base descriptor.
  void setInstanceDescriptors(
    int baseServiceId,
    List<MrrpServiceDescriptor> descriptors,
  ) {
    _instanceBaseServiceId = descriptors.isEmpty ? null : baseServiceId;
    _instanceDescriptors
      ..clear()
      ..addAll(descriptors);
  }

  /// Get all descriptors for advertisement, expanding instance descriptors.
  List<MrrpServiceDescriptor> getAdvertDescriptors() {
    final base = _descriptors.values.toList();
    if (_instanceBaseServiceId == null || _instanceDescriptors.isEmpty) {
      return base;
    }
    // Replace the base entry with the per-instance entries.
    base.removeWhere((d) => d.serviceId == _instanceBaseServiceId);
    base.addAll(_instanceDescriptors);
    return base;
  }

  /// Get all registered descriptors.
  List<MrrpServiceDescriptor> getAll() =>
      _descriptors.values.toList(growable: false);

  /// Look up a handler by service ID.
  MrrpServiceHandler? getHandler(int serviceId) => _handlers[serviceId];

  /// Number of registered services.
  int get count => _handlers.length;

  /// Whether any services are registered.
  bool get isEmpty => _handlers.isEmpty;

  /// Build the SERVICE_ADVERT payload bytes.
  ///
  /// Returns null if no services registered or payload would exceed max.
  Uint8List? buildAdvertPayload() {
    final descriptors = getAdvertDescriptors();
    if (descriptors.isEmpty) return null;

    // Calculate total payload size: 1 (count) + sum of descriptor sizes.
    var totalPayload = 1;
    for (final d in descriptors) {
      totalPayload += d.wireSize;
    }

    if (totalPayload > MrrpConstants.mrrpMaxPayload) {
      AppLogging.mrrp(
        'MRRP_REGISTRY: advert payload $totalPayload B > '
        '${MrrpConstants.mrrpMaxPayload} B max, truncating', // lint-allow: hardcoded-string
      );
      return null;
    }

    final buffer = Uint8List(totalPayload);
    buffer[0] = descriptors.length;

    var offset = 1;
    for (final d in descriptors) {
      final bd = ByteData.sublistView(buffer, offset);
      bd.setUint32(0, d.serviceId, Endian.little);
      buffer[offset + 4] = d.serviceType.code;
      buffer[offset + 5] = d.versionMajor;
      buffer[offset + 6] = d.versionMinor;
      bd.setUint16(7, d.serviceFlags, Endian.little);
      buffer[offset + 9] = d.metadata.length;
      if (d.metadata.isNotEmpty) {
        buffer.setRange(
          offset + MrrpConstants.mrrpServiceDescriptorMin,
          offset + MrrpConstants.mrrpServiceDescriptorMin + d.metadata.length,
          d.metadata,
        );
      }
      offset += d.wireSize;
    }

    return buffer;
  }
}
