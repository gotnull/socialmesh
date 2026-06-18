// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Unified Incident Mode SPP codec.
///
/// Encodes / decodes a single [IncidentEvent] to and from a compact binary
/// payload for the incident.v1 MRRP service. Unlike the legacy
/// [SppIncidentCodec] (SPP type 0x10, [MeshIncidentReport] field-hazard
/// reports), this codec carries an explicit `workflow_kind` plus a `msg_type`
/// discriminator so the same envelope expresses both workflows:
///
/// - [IncidentWorkflowKind.hazardReport]
/// - [IncidentWorkflowKind.helpRequest]
///
/// The legacy codec is intentionally left untouched (its wire format and test
/// vectors are preserved). This unified envelope is the go-forward format; the
/// runtime switch from legacy to unified is a later wiring change and is NOT
/// part of this codec.
///
/// Wire format (little-endian), SPP type [SppPayloadType.incidentMode] (0x13):
/// ```
/// Offset  Field          Type        Size  Notes
/// 0       spp_type       uint8       1     0x13
/// 1       spp_version    uint8       1     sppIncidentModeVersion (1)
/// --- common envelope (13 bytes) ---
/// 2       workflow_kind  uint8       1     0=hazard_report, 1=help_request
/// 3       msg_type       uint8       1     see [IncidentModeWire]
/// 4-7     incident_id    uint32 LE   4     origin-allocated id
/// 8       seq            uint8       1     per-sender monotonic
/// 9       ref_seq        uint8       1     correction reference (0xFF = none)
/// 10      flags          uint8       1     reserved (0)
/// 11-14   timestamp      uint32 LE   4     event time, unix seconds UTC
/// --- msg_type-specific body ---
/// ...
/// ```
///
/// Identity discipline: the sender node id is supplied by the transport layer
/// via [decode]'s `senderNodeId` parameter and is NEVER read from the payload;
/// [encode] never writes it. Binding sender identity from MRRP/SIP context is
/// the responsibility of the service handler (a later change), not this codec.
///
/// Lifecycle projection is owned by `IncidentReducer`; this codec performs no
/// state projection.
///
/// Plan: docs/engineering/INCIDENT_MODE_SIP_MRRP_PLAN.md
library;

import 'dart:convert';
import 'dart:typed_data';

import '../../../core/logging.dart';
import '../../../features/incidents/models/incident_mode_models.dart';
import '../../../utils/text_sanitizer.dart';
import 'spp_constants.dart';
import 'spp_types.dart';

/// Centralized numeric wire codes for the unified Incident Mode envelope.
///
/// These are the single source of truth for the on-wire values. The domain
/// enums in `incident_mode_models.dart` deliberately carry no wire codes; the
/// mapping lives here in the codec layer.
abstract final class IncidentModeWire {
  // workflow_kind values.
  static const int workflowHazardReport = 0x00;
  static const int workflowHelpRequest = 0x01;

  // msg_type values (global across workflows).
  static const int msgHazardReport = 0x01;
  static const int msgCreate = 0x10;
  static const int msgAck = 0x11;
  static const int msgSeen = 0x12;
  static const int msgResponderAccept = 0x13;
  static const int msgResponderLeave = 0x14;
  static const int msgRequesterStatus = 0x15;
  static const int msgResponderStatus = 0x16;
  static const int msgLocation = 0x17;
  static const int msgMessage = 0x18;
  static const int msgResolve = 0x19;
  static const int msgCancel = 0x1A;
  // Note: IncidentEventType.expire has no wire code -- it is local-only.

  // Quick-update codes -- requester (0x01-0x07), responder (0x10-0x15).
  static const int quickImOk = 0x01;
  static const int quickImInjured = 0x02;
  static const int quickCantMove = 0x03;
  static const int quickNeedWater = 0x04;
  static const int quickNeedMedical = 0x05;
  static const int quickFalseAlarm = 0x06;
  static const int quickSituationWorse = 0x07;
  static const int quickOnMyWay = 0x10;
  static const int quickArrived = 0x11;
  static const int quickNeedBackup = 0x12;
  static const int quickBlocked = 0x13;
  static const int quickCantReachYou = 0x14;
  static const int quickLeavingResponse = 0x15;

  // ACK categories.
  static const int ackReceived = 0x01;
  static const int ackSurfaced = 0x02;
  static const int ackAccepted = 0x03;
  static const int ackResolved = 0x04;

  /// Sentinel for "no correction reference".
  static const int noRefSeq = 0xFF;

  /// Sentinel for "accuracy unknown".
  static const int unknownAccuracy = 0xFFFF;

  /// Scale factor for fixed-point lat/lon (1e7 degrees).
  static const int coordScale = 10000000;
}

/// Bytes in the SPP header (type + version).
const int _sppHeader = sppHeaderSize;

/// Bytes in the fixed common envelope after the SPP header.
const int _envelope = 13;

/// Total fixed prefix before any msg_type body.
const int _fixedPrefix = _sppHeader + _envelope;

/// Codec for the unified Incident Mode envelope.
///
/// Provides static [encode] and [decode] over a single [IncidentEvent].
abstract final class SppIncidentModeCodec {
  /// Maximum body bytes after the fixed prefix (shares the SPP body budget).
  static const int _maxBody = SppConstants.maxBody - _envelope;

  /// Maximum UTF-8 text bytes in a message body (after the 1-byte length).
  static const int _maxMessageBytes = _maxBody - 1;

  /// Encodes an [IncidentEvent] to wire bytes.
  ///
  /// Returns null when the event cannot be represented on the wire:
  /// - [IncidentEventType.expire] (local-only, never transmitted),
  /// - a workflow / msg_type mismatch,
  /// - a required typed payload field is missing,
  /// - the incident id is out of u32 range,
  /// - the encoded payload would exceed the SPP body budget.
  static Uint8List? encode(IncidentEvent event) {
    final workflowWire = _workflowToWire(event.workflowKind);
    final msgWire = _msgTypeToWire(event.type);
    if (msgWire == null) {
      AppLogging.protocol(
        'SPP_INCIDENT_MODE: encode skipped - non-wire msg_type '
        '${event.type.name}', // lint-allow: hardcoded-string
      );
      return null;
    }
    if (!_workflowMatchesType(event.workflowKind, event.type)) {
      AppLogging.protocol(
        'SPP_INCIDENT_MODE: encode failed - workflow/msg_type mismatch '
        '(${event.workflowKind.name}/${event.type.name})', // lint-allow: hardcoded-string
      );
      return null;
    }
    if (event.incidentId < 0 || event.incidentId > 0xFFFFFFFF) {
      return null;
    }

    final body = _encodeBody(event);
    if (body == null) {
      AppLogging.protocol(
        'SPP_INCIDENT_MODE: encode failed - missing payload for '
        '${event.type.name}', // lint-allow: hardcoded-string
      );
      return null;
    }
    if (body.length > _maxBody) return null;

    final total = _fixedPrefix + body.length;
    final out = Uint8List(total);
    final bd = ByteData.sublistView(out);
    var o = 0;

    bd.setUint8(o++, SppPayloadType.incidentMode.code);
    bd.setUint8(o++, sppIncidentModeVersion);
    bd.setUint8(o++, workflowWire);
    bd.setUint8(o++, msgWire);
    bd.setUint32(o, event.incidentId, Endian.little);
    o += 4;
    bd.setUint8(o++, event.seq & 0xFF);
    bd.setUint8(o++, event.refSeq ?? IncidentModeWire.noRefSeq);
    bd.setUint8(o++, 0); // flags (reserved)
    bd.setUint32(o, _toUnixSeconds(event.timestamp), Endian.little);
    o += 4;

    out.setRange(o, o + body.length, body);
    return out;
  }

  /// Decodes wire bytes into an [IncidentEvent], binding [senderNodeId] from
  /// the transport context.
  ///
  /// Returns null for any malformed, truncated, unknown-workflow,
  /// unknown-msg_type, or version-mismatched payload. Never throws.
  static IncidentEvent? decode(Uint8List data, int senderNodeId) {
    try {
      if (data.length < _fixedPrefix) {
        return _fail('too short (${data.length} bytes)');
      }

      final bd = ByteData.sublistView(data);
      var o = 0;

      final typeCode = bd.getUint8(o++);
      if (typeCode != SppPayloadType.incidentMode.code) {
        return _fail('wrong spp_type 0x${typeCode.toRadixString(16)}');
      }
      final version = bd.getUint8(o++);
      if (version != sppIncidentModeVersion) {
        return _fail('unsupported version $version');
      }

      final workflowWire = bd.getUint8(o++);
      final workflow = _workflowFromWire(workflowWire);
      if (workflow == null) {
        return _fail(
          'unknown workflow_kind 0x${workflowWire.toRadixString(16)}',
        );
      }

      final msgWire = bd.getUint8(o++);
      final type = _msgTypeFromWire(msgWire);
      if (type == null) {
        return _fail('unknown msg_type 0x${msgWire.toRadixString(16)}');
      }
      if (!_workflowMatchesType(workflow, type)) {
        return _fail('workflow/msg_type mismatch');
      }

      final incidentId = bd.getUint32(o, Endian.little);
      o += 4;
      final seq = bd.getUint8(o++);
      final refSeqRaw = bd.getUint8(o++);
      final refSeq = refSeqRaw == IncidentModeWire.noRefSeq ? null : refSeqRaw;
      o++; // flags (reserved, ignored)
      final timestamp = _fromUnixSeconds(bd.getUint32(o, Endian.little));
      o += 4;

      return _decodeBody(
        data: data,
        bodyOffset: o,
        type: type,
        workflow: workflow,
        incidentId: incidentId,
        seq: seq,
        refSeq: refSeq,
        timestamp: timestamp,
        senderNodeId: senderNodeId,
      );
    } catch (e) {
      return _fail('exception during decode: $e');
    }
  }

  // --- body encode -------------------------------------------------------

  static Uint8List? _encodeBody(IncidentEvent e) {
    switch (e.type) {
      case IncidentEventType.hazardReport:
        final status = e.hazardStatus;
        final update = e.hazardUpdateType;
        if (status == null || update == null) return null;
        return Uint8List.fromList([status.code, update.code]);

      case IncidentEventType.create:
        final b = ByteData(4);
        b.setUint32(
          0,
          e.expiresAt != null ? _toUnixSeconds(e.expiresAt!) : 0,
          Endian.little,
        );
        return b.buffer.asUint8List();

      case IncidentEventType.ack:
        final cat = e.ackCategory;
        if (cat == null) return null;
        return Uint8List.fromList([_ackToWire(cat)]);

      case IncidentEventType.requesterStatus:
        final q = e.quickUpdate;
        if (q == null || !q.isRequesterCode) return null;
        return Uint8List.fromList([_quickToWire(q)]);

      case IncidentEventType.responderStatus:
        final q = e.quickUpdate;
        if (q == null || !q.isResponderCode) return null;
        return Uint8List.fromList([_quickToWire(q)]);

      case IncidentEventType.location:
        final loc = e.location;
        if (loc == null || !loc.isFinite) return null;
        final b = ByteData(14);
        b.setInt32(
          0,
          (loc.latitude * IncidentModeWire.coordScale).round(),
          Endian.little,
        );
        b.setInt32(
          4,
          (loc.longitude * IncidentModeWire.coordScale).round(),
          Endian.little,
        );
        b.setUint16(
          8,
          loc.accuracyMeters != null
              ? loc.accuracyMeters!.round().clamp(0, 0xFFFE)
              : IncidentModeWire.unknownAccuracy,
          Endian.little,
        );
        b.setUint32(10, _toUnixSeconds(loc.fixedAt), Endian.little);
        return b.buffer.asUint8List();

      case IncidentEventType.message:
        final m = e.message;
        if (m == null) return null;
        var textBytes = utf8.encode(m.text);
        if (textBytes.length > _maxMessageBytes) {
          textBytes = _truncateUtf8(m.text, _maxMessageBytes);
        }
        final out = Uint8List(1 + textBytes.length);
        out[0] = textBytes.length;
        out.setRange(1, 1 + textBytes.length, textBytes);
        return out;

      case IncidentEventType.seen:
      case IncidentEventType.responderAccept:
      case IncidentEventType.responderLeave:
      case IncidentEventType.resolve:
      case IncidentEventType.cancel:
        return Uint8List(0);

      case IncidentEventType.expire:
        return null; // local-only, never on wire
    }
  }

  // --- body decode -------------------------------------------------------

  static IncidentEvent? _decodeBody({
    required Uint8List data,
    required int bodyOffset,
    required IncidentEventType type,
    required IncidentWorkflowKind workflow,
    required int incidentId,
    required int seq,
    required int? refSeq,
    required DateTime timestamp,
    required int senderNodeId,
  }) {
    final bd = ByteData.sublistView(data);
    final bodyLen = data.length - bodyOffset;

    IncidentEvent build({
      IncidentQuickUpdate? quickUpdate,
      IncidentAckCategory? ackCategory,
      IncidentLocation? location,
      IncidentMessage? message,
      DateTime? expiresAt,
      IncidentMeshStatus? hazardStatus,
      IncidentUpdateType? hazardUpdateType,
    }) {
      return IncidentEvent(
        incidentId: incidentId,
        workflowKind: workflow,
        type: type,
        senderNodeId: senderNodeId,
        seq: seq,
        timestamp: timestamp,
        refSeq: refSeq,
        quickUpdate: quickUpdate,
        ackCategory: ackCategory,
        location: location,
        message: message,
        expiresAt: expiresAt,
        hazardStatus: hazardStatus,
        hazardUpdateType: hazardUpdateType,
      );
    }

    switch (type) {
      case IncidentEventType.hazardReport:
        if (bodyLen < 2) return _fail('hazard body too short');
        final status = IncidentMeshStatus.fromCode(bd.getUint8(bodyOffset));
        final update = IncidentUpdateType.fromCode(bd.getUint8(bodyOffset + 1));
        if (status == null || update == null) {
          return _fail('invalid hazard status/update');
        }
        return build(hazardStatus: status, hazardUpdateType: update);

      case IncidentEventType.create:
        if (bodyLen < 4) return _fail('create body too short');
        final expiry = bd.getUint32(bodyOffset, Endian.little);
        return build(expiresAt: expiry == 0 ? null : _fromUnixSeconds(expiry));

      case IncidentEventType.ack:
        if (bodyLen < 1) return _fail('ack body too short');
        final cat = _ackFromWire(bd.getUint8(bodyOffset));
        if (cat == null) return _fail('invalid ack category');
        return build(ackCategory: cat);

      case IncidentEventType.requesterStatus:
        if (bodyLen < 1) return _fail('requester status body too short');
        final q = _quickFromWire(bd.getUint8(bodyOffset));
        if (q == null || !q.isRequesterCode) {
          return _fail('invalid requester quick code');
        }
        return build(quickUpdate: q);

      case IncidentEventType.responderStatus:
        if (bodyLen < 1) return _fail('responder status body too short');
        final q = _quickFromWire(bd.getUint8(bodyOffset));
        if (q == null || !q.isResponderCode) {
          return _fail('invalid responder quick code');
        }
        return build(quickUpdate: q);

      case IncidentEventType.location:
        if (bodyLen < 14) return _fail('location body too short');
        final latE7 = bd.getInt32(bodyOffset, Endian.little);
        final lonE7 = bd.getInt32(bodyOffset + 4, Endian.little);
        final accRaw = bd.getUint16(bodyOffset + 8, Endian.little);
        final fixedAt = _fromUnixSeconds(
          bd.getUint32(bodyOffset + 10, Endian.little),
        );
        final loc = IncidentLocation(
          incidentId: incidentId,
          nodeId: senderNodeId,
          latitude: latE7 / IncidentModeWire.coordScale,
          longitude: lonE7 / IncidentModeWire.coordScale,
          accuracyMeters: accRaw == IncidentModeWire.unknownAccuracy
              ? null
              : accRaw.toDouble(),
          fixedAt: fixedAt,
        );
        return build(location: loc);

      case IncidentEventType.message:
        if (bodyLen < 1) return _fail('message body too short');
        final textLen = bd.getUint8(bodyOffset);
        if (bodyOffset + 1 + textLen > data.length) {
          return _fail('message text overruns payload');
        }
        final text = sanitizeExternalText(
          utf8.decode(
            data.sublist(bodyOffset + 1, bodyOffset + 1 + textLen),
            allowMalformed: true,
          ),
        );
        return build(
          message: IncidentMessage(
            incidentId: incidentId,
            senderNodeId: senderNodeId,
            seq: seq,
            text: text,
            timestamp: timestamp,
          ),
        );

      case IncidentEventType.seen:
      case IncidentEventType.responderAccept:
      case IncidentEventType.responderLeave:
      case IncidentEventType.resolve:
      case IncidentEventType.cancel:
        return build();

      case IncidentEventType.expire:
        // Not a wire type; mapped out before reaching here.
        return _fail('expire is local-only');
    }
  }

  // --- mappings ----------------------------------------------------------

  static int _workflowToWire(IncidentWorkflowKind kind) {
    return switch (kind) {
      IncidentWorkflowKind.hazardReport =>
        IncidentModeWire.workflowHazardReport,
      IncidentWorkflowKind.helpRequest => IncidentModeWire.workflowHelpRequest,
    };
  }

  static IncidentWorkflowKind? _workflowFromWire(int wire) {
    return switch (wire) {
      IncidentModeWire.workflowHazardReport =>
        IncidentWorkflowKind.hazardReport,
      IncidentModeWire.workflowHelpRequest => IncidentWorkflowKind.helpRequest,
      _ => null,
    };
  }

  /// Returns the wire msg_type for an event type, or null if the type is not
  /// representable on the wire (e.g. local-only [IncidentEventType.expire]).
  static int? _msgTypeToWire(IncidentEventType type) {
    return switch (type) {
      IncidentEventType.hazardReport => IncidentModeWire.msgHazardReport,
      IncidentEventType.create => IncidentModeWire.msgCreate,
      IncidentEventType.ack => IncidentModeWire.msgAck,
      IncidentEventType.seen => IncidentModeWire.msgSeen,
      IncidentEventType.responderAccept => IncidentModeWire.msgResponderAccept,
      IncidentEventType.responderLeave => IncidentModeWire.msgResponderLeave,
      IncidentEventType.requesterStatus => IncidentModeWire.msgRequesterStatus,
      IncidentEventType.responderStatus => IncidentModeWire.msgResponderStatus,
      IncidentEventType.location => IncidentModeWire.msgLocation,
      IncidentEventType.message => IncidentModeWire.msgMessage,
      IncidentEventType.resolve => IncidentModeWire.msgResolve,
      IncidentEventType.cancel => IncidentModeWire.msgCancel,
      IncidentEventType.expire => null,
    };
  }

  static IncidentEventType? _msgTypeFromWire(int wire) {
    return switch (wire) {
      IncidentModeWire.msgHazardReport => IncidentEventType.hazardReport,
      IncidentModeWire.msgCreate => IncidentEventType.create,
      IncidentModeWire.msgAck => IncidentEventType.ack,
      IncidentModeWire.msgSeen => IncidentEventType.seen,
      IncidentModeWire.msgResponderAccept => IncidentEventType.responderAccept,
      IncidentModeWire.msgResponderLeave => IncidentEventType.responderLeave,
      IncidentModeWire.msgRequesterStatus => IncidentEventType.requesterStatus,
      IncidentModeWire.msgResponderStatus => IncidentEventType.responderStatus,
      IncidentModeWire.msgLocation => IncidentEventType.location,
      IncidentModeWire.msgMessage => IncidentEventType.message,
      IncidentModeWire.msgResolve => IncidentEventType.resolve,
      IncidentModeWire.msgCancel => IncidentEventType.cancel,
      _ => null,
    };
  }

  /// Whether a workflow and event type belong together.
  static bool _workflowMatchesType(
    IncidentWorkflowKind workflow,
    IncidentEventType type,
  ) {
    final expected = type == IncidentEventType.hazardReport
        ? IncidentWorkflowKind.hazardReport
        : IncidentWorkflowKind.helpRequest;
    return workflow == expected;
  }

  static int _quickToWire(IncidentQuickUpdate q) {
    return switch (q) {
      IncidentQuickUpdate.imOk => IncidentModeWire.quickImOk,
      IncidentQuickUpdate.imInjured => IncidentModeWire.quickImInjured,
      IncidentQuickUpdate.cantMove => IncidentModeWire.quickCantMove,
      IncidentQuickUpdate.needWater => IncidentModeWire.quickNeedWater,
      IncidentQuickUpdate.needMedical => IncidentModeWire.quickNeedMedical,
      IncidentQuickUpdate.falseAlarm => IncidentModeWire.quickFalseAlarm,
      IncidentQuickUpdate.situationWorse =>
        IncidentModeWire.quickSituationWorse,
      IncidentQuickUpdate.onMyWay => IncidentModeWire.quickOnMyWay,
      IncidentQuickUpdate.arrived => IncidentModeWire.quickArrived,
      IncidentQuickUpdate.needBackup => IncidentModeWire.quickNeedBackup,
      IncidentQuickUpdate.blocked => IncidentModeWire.quickBlocked,
      IncidentQuickUpdate.cantReachYou => IncidentModeWire.quickCantReachYou,
      IncidentQuickUpdate.leavingResponse =>
        IncidentModeWire.quickLeavingResponse,
    };
  }

  static IncidentQuickUpdate? _quickFromWire(int wire) {
    return switch (wire) {
      IncidentModeWire.quickImOk => IncidentQuickUpdate.imOk,
      IncidentModeWire.quickImInjured => IncidentQuickUpdate.imInjured,
      IncidentModeWire.quickCantMove => IncidentQuickUpdate.cantMove,
      IncidentModeWire.quickNeedWater => IncidentQuickUpdate.needWater,
      IncidentModeWire.quickNeedMedical => IncidentQuickUpdate.needMedical,
      IncidentModeWire.quickFalseAlarm => IncidentQuickUpdate.falseAlarm,
      IncidentModeWire.quickSituationWorse =>
        IncidentQuickUpdate.situationWorse,
      IncidentModeWire.quickOnMyWay => IncidentQuickUpdate.onMyWay,
      IncidentModeWire.quickArrived => IncidentQuickUpdate.arrived,
      IncidentModeWire.quickNeedBackup => IncidentQuickUpdate.needBackup,
      IncidentModeWire.quickBlocked => IncidentQuickUpdate.blocked,
      IncidentModeWire.quickCantReachYou => IncidentQuickUpdate.cantReachYou,
      IncidentModeWire.quickLeavingResponse =>
        IncidentQuickUpdate.leavingResponse,
      _ => null,
    };
  }

  static int _ackToWire(IncidentAckCategory cat) {
    return switch (cat) {
      IncidentAckCategory.received => IncidentModeWire.ackReceived,
      IncidentAckCategory.surfaced => IncidentModeWire.ackSurfaced,
      IncidentAckCategory.accepted => IncidentModeWire.ackAccepted,
      IncidentAckCategory.resolved => IncidentModeWire.ackResolved,
    };
  }

  static IncidentAckCategory? _ackFromWire(int wire) {
    return switch (wire) {
      IncidentModeWire.ackReceived => IncidentAckCategory.received,
      IncidentModeWire.ackSurfaced => IncidentAckCategory.surfaced,
      IncidentModeWire.ackAccepted => IncidentAckCategory.accepted,
      IncidentModeWire.ackResolved => IncidentAckCategory.resolved,
      _ => null,
    };
  }

  // --- helpers -----------------------------------------------------------

  static int _toUnixSeconds(DateTime dt) =>
      dt.toUtc().millisecondsSinceEpoch ~/ 1000;

  static DateTime _fromUnixSeconds(int s) =>
      DateTime.fromMillisecondsSinceEpoch(s * 1000, isUtc: true);

  /// Truncates a UTF-8 string to at most [maxBytes] without splitting a
  /// multi-byte character.
  static Uint8List _truncateUtf8(String text, int maxBytes) {
    final encoded = utf8.encode(text);
    if (encoded.length <= maxBytes) return Uint8List.fromList(encoded);
    var end = maxBytes;
    while (end > 0 && (encoded[end] & 0xC0) == 0x80) {
      end--;
    }
    return Uint8List.fromList(encoded.sublist(0, end));
  }

  static Null _fail(String reason) {
    AppLogging.protocol(
      'SPP_INCIDENT_MODE: decode failed - $reason', // lint-allow: hardcoded-string
    );
    return null;
  }
}
