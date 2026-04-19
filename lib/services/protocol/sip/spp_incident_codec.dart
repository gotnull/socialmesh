// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// SPP incident report codec for wire encoding / decoding.
///
/// Encodes [MeshIncidentReport] into compact binary payloads that fit within
/// the MRRP payload budget (195 bytes max, 193 after SPP header).
///
/// Wire format (little-endian):
/// ```
/// Offset  Field              Type        Size   Description
/// 0       spp_type           uint8       1      SppPayloadType.incidentReport (0x10)
/// 1       spp_version        uint8       1      Schema version (1)
/// --- SPP body (up to 193 bytes) ---
/// 2-5     case_id            uint32 LE   4      Stable case identifier
/// 6       seq_num            uint8       1      Per-case sequence (0-255)
/// 7       flags              uint8       1      [0:1] update_type, [2:3] confidence,
///                                               [4] has_location, [5:7] reserved
/// 8       classification     uint8       1      IncidentClassification index
/// 9       priority           uint8       1      IncidentPriority index
/// 10      status             uint8       1      IncidentMeshStatus index
/// 11      reporter_role      uint8       1      IncidentReporterRole index
/// 12-15   timestamp          uint32 LE   4      Unix epoch seconds
/// 16      ref_seq            uint8       1      Correction reference (0xFF = none)
/// --- Optional location (4 bytes, present if flags bit 4 set) ---
/// 17-18   lat_centi          int16 LE    2      Latitude * 100 (centidegree)
/// 19-20   lon_centi          int16 LE    2      Longitude * 100 (centidegree)
/// --- Body text ---
/// N       body_len           uint8       1      UTF-8 body byte count
/// N+1..   body               UTF-8       var    Summary text (truncated to fit)
/// ```
///
/// Spec: docs/protocol/INCIDENT_SPP_V0_1.md
library;

import 'dart:convert';
import 'dart:typed_data';

import '../../../core/logging.dart';
import '../../../features/incidents/models/incident.dart';
import '../../../features/incidents/models/mesh_incident_report.dart';
import 'spp_constants.dart';
import 'spp_types.dart';

/// Codec for SPP incident report payloads.
///
/// Provides static [encode] and [decode] methods.
/// All encoded payloads include the 2-byte SPP header.
abstract final class SppIncidentCodec {
  /// Encodes a [MeshIncidentReport] to wire bytes.
  ///
  /// Returns null if the report cannot fit within the payload budget
  /// (body text is truncated to fit, but if zero body bytes remain
  /// after headers, encoding fails).
  static Uint8List? encode(MeshIncidentReport report) {
    final hasLocation = report.latitude != null && report.longitude != null;
    final headerSize = hasLocation
        ? SppConstants.incidentHeaderWithLoc
        : SppConstants.incidentHeaderNoLoc;
    final maxBodyBytes = SppConstants.maxBody - headerSize - 1;

    if (maxBodyBytes < 0) return null;

    // Encode body text, truncating to fit
    var bodyBytes = utf8.encode(report.body);
    if (bodyBytes.length > maxBodyBytes) {
      bodyBytes = _truncateUtf8(report.body, maxBodyBytes);
    }

    final totalSize = sppHeaderSize + headerSize + 1 + bodyBytes.length;
    final buffer = ByteData(totalSize);
    var offset = 0;

    // SPP header
    buffer.setUint8(offset++, SppPayloadType.incidentReport.code);
    buffer.setUint8(offset++, sppIncidentVersion);

    // Case ID
    buffer.setUint32(offset, report.caseId, Endian.little);
    offset += 4;

    // Sequence number
    buffer.setUint8(offset++, report.seqNum);

    // Flags byte
    int flags = report.updateType.code & 0x03;
    flags |= (report.confidence.code & 0x03) << 2;
    if (hasLocation) flags |= 1 << 4;
    buffer.setUint8(offset++, flags);

    // Classification, priority, status, reporter role
    buffer.setUint8(offset++, report.classification.index);
    buffer.setUint8(offset++, report.priority.index);
    buffer.setUint8(offset++, report.status.code);
    buffer.setUint8(offset++, report.reporterRole.code);

    // Timestamp (unix seconds)
    final timestampS = report.timestamp.millisecondsSinceEpoch ~/ 1000;
    buffer.setUint32(offset, timestampS, Endian.little);
    offset += 4;

    // Correction reference
    buffer.setUint8(offset++, report.refSeq ?? SppConstants.noRefSeq);

    // Optional location
    if (hasLocation) {
      final latCenti = (report.latitude! * 100).round().clamp(-9000, 9000);
      final lonCenti = (report.longitude! * 100).round().clamp(-18000, 18000);
      buffer.setInt16(offset, latCenti, Endian.little);
      offset += 2;
      buffer.setInt16(offset, lonCenti, Endian.little);
      offset += 2;
    }

    // Body text
    buffer.setUint8(offset++, bodyBytes.length);
    final result = Uint8List(totalSize);
    result.setRange(0, offset, buffer.buffer.asUint8List());
    result.setRange(offset, offset + bodyBytes.length, bodyBytes);

    return result;
  }

  /// Decodes wire bytes into a [MeshIncidentReport].
  ///
  /// Returns null if the payload is malformed, too short, or has an
  /// unsupported version.
  static MeshIncidentReport? decode(Uint8List data, int senderNodeId) {
    if (data.length < sppHeaderSize + SppConstants.incidentHeaderNoLoc + 1) {
      AppLogging.protocol(
        'SPP_INCIDENT: decode failed - too short '
        '(${data.length} bytes)', // lint-allow: hardcoded-string
      );
      return null;
    }

    final bd = ByteData.sublistView(data);
    var offset = 0;

    // SPP header
    final typeCode = bd.getUint8(offset++);
    if (typeCode != SppPayloadType.incidentReport.code) {
      AppLogging.protocol(
        'SPP_INCIDENT: decode failed - wrong type '
        '0x${typeCode.toRadixString(16)}', // lint-allow: hardcoded-string
      );
      return null;
    }

    final version = bd.getUint8(offset++);
    if (version != sppIncidentVersion) {
      AppLogging.protocol(
        'SPP_INCIDENT: decode failed - unsupported version '
        '$version', // lint-allow: hardcoded-string
      );
      return null;
    }

    // Case ID
    final caseId = bd.getUint32(offset, Endian.little);
    offset += 4;

    // Sequence number
    final seqNum = bd.getUint8(offset++);

    // Flags byte
    final flags = bd.getUint8(offset++);
    final updateTypeCode = flags & 0x03;
    final confidenceCode = (flags >> 2) & 0x03;
    final hasLocation = (flags >> 4) & 0x01 == 1;

    final updateType = IncidentUpdateType.fromCode(updateTypeCode);
    final confidence = IncidentConfidence.fromCode(confidenceCode);
    if (updateType == null || confidence == null) {
      AppLogging.protocol(
        'SPP_INCIDENT: decode failed - invalid flags '
        '0x${flags.toRadixString(16)}', // lint-allow: hardcoded-string
      );
      return null;
    }

    // Classification
    final classIdx = bd.getUint8(offset++);
    if (classIdx >= IncidentClassification.values.length) return null;
    final classification = IncidentClassification.values[classIdx];

    // Priority
    final prioIdx = bd.getUint8(offset++);
    if (prioIdx >= IncidentPriority.values.length) return null;
    final priority = IncidentPriority.values[prioIdx];

    // Status
    final statusCode = bd.getUint8(offset++);
    final status = IncidentMeshStatus.fromCode(statusCode);
    if (status == null) return null;

    // Reporter role
    final roleCode = bd.getUint8(offset++);
    final reporterRole = IncidentReporterRole.fromCode(roleCode);
    if (reporterRole == null) return null;

    // Timestamp
    final timestampS = bd.getUint32(offset, Endian.little);
    offset += 4;
    final timestamp = DateTime.fromMillisecondsSinceEpoch(
      timestampS * 1000,
      isUtc: true,
    );

    // Correction reference
    final refSeqRaw = bd.getUint8(offset++);
    final refSeq = refSeqRaw == SppConstants.noRefSeq ? null : refSeqRaw;

    // Optional location
    double? latitude;
    double? longitude;
    if (hasLocation) {
      if (data.length < offset + 4) return null;
      final latCenti = bd.getInt16(offset, Endian.little);
      offset += 2;
      final lonCenti = bd.getInt16(offset, Endian.little);
      offset += 2;
      latitude = latCenti / 100.0;
      longitude = lonCenti / 100.0;
    }

    // Body text
    if (offset >= data.length) return null;
    final bodyLen = bd.getUint8(offset++);
    if (offset + bodyLen > data.length) return null;

    final body = utf8.decode(
      data.sublist(offset, offset + bodyLen),
      allowMalformed: true,
    );

    return MeshIncidentReport(
      caseId: caseId,
      seqNum: seqNum,
      updateType: updateType,
      confidence: confidence,
      classification: classification,
      priority: priority,
      status: status,
      reporterRole: reporterRole,
      timestamp: timestamp,
      refSeq: refSeq,
      latitude: latitude,
      longitude: longitude,
      body: body,
      senderNodeId: senderNodeId,
    );
  }

  /// Truncates a UTF-8 string to at most [maxBytes] without splitting
  /// multi-byte characters.
  static Uint8List _truncateUtf8(String text, int maxBytes) {
    final encoded = utf8.encode(text);
    if (encoded.length <= maxBytes) return Uint8List.fromList(encoded);

    var end = maxBytes;
    // Walk back to avoid splitting a multi-byte character
    while (end > 0 && (encoded[end] & 0xC0) == 0x80) {
      end--;
    }
    return Uint8List.fromList(encoded.sublist(0, end));
  }

  /// Returns the encoded size of a report without actually encoding it.
  ///
  /// Useful for pre-flight payload budget checks.
  static int estimateSize(MeshIncidentReport report) {
    final hasLocation = report.latitude != null && report.longitude != null;
    final headerSize = hasLocation
        ? SppConstants.incidentHeaderWithLoc
        : SppConstants.incidentHeaderNoLoc;
    final bodyBytes = utf8.encode(report.body);
    final usableBody = bodyBytes.length.clamp(
      0,
      SppConstants.maxBody - headerSize - 1,
    );
    return sppHeaderSize + headerSize + 1 + usableBody;
  }
}
