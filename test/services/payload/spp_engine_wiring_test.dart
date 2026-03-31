// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/file_transfer/file_transfer_engine.dart';
import 'package:socialmesh/services/payload/payload_negotiation.dart';
import 'package:socialmesh/services/payload/spp_constants.dart';
import 'package:socialmesh/services/payload/spp_protocol.dart';
import 'package:socialmesh/services/payload/spp_types.dart';
import 'package:socialmesh/services/protocol/socialmesh/sm_file_transfer.dart';

/// Integration tests verifying the wiring between PayloadNegotiation
/// and FileTransferEngine: offerPending surfaces in the engine,
/// accept/reject routes through negotiation, and duplicates are handled.
void main() {
  // ─── Helpers ─────────────────────────────────────────────────────

  Uint8List makePayloadId([int seed = 0x10]) =>
      Uint8List.fromList(List.generate(16, (i) => seed + i));

  SmFileOffer makeOffer({
    Uint8List? fileId,
    String mimeType = 'image/webp',
    int totalBytes = 2048,
    String filename = 'test.webp',
  }) {
    return SmFileOffer(
      fileId: fileId ?? makePayloadId(),
      filename: filename,
      mimeType: mimeType,
      totalBytes: totalBytes,
      chunkSize: SppLimits.defaultChunkSize,
      chunkCount: (totalBytes / SppLimits.defaultChunkSize).ceil(),
      sha256Hash: Uint8List(32),
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      expiresAt:
          DateTime.now()
              .add(const Duration(hours: 24))
              .millisecondsSinceEpoch ~/
          1000,
    );
  }

  // Shared state for each test.
  late List<Uint8List> sentPackets;
  late List<FileTransferState> engineStateChanges;
  late FileTransferEngine engine;
  late PayloadNegotiation negotiation;
  late StreamSubscription<SppPayloadOffer> negotiationSub;

  /// Wire negotiation → engine exactly as the provider does.
  void wireNegotiationToEngine() {
    negotiationSub = negotiation.stateChanges.listen((offer) {
      switch (offer.state) {
        case SppNegotiationState.accepted:
          final transfer = engine.getTransfer(offer.payloadIdHex);
          if (transfer?.state == TransferState.offerPending) {
            engine.acceptTransfer(offer.payloadIdHex);
          } else if (transfer?.state == TransferState.awaitingAccept) {
            engine.resumeTransfer(offer.payloadIdHex);
          }
        case SppNegotiationState.declined:
        case SppNegotiationState.aborted:
          engine.cancelTransfer(offer.payloadIdHex);
        case SppNegotiationState.timedOut:
          engine.cancelTransfer(offer.payloadIdHex);
        case SppNegotiationState.offerSent:
        case SppNegotiationState.offerPending:
          break;
      }
    });
  }

  /// Simulate the provider's v1 offer routing logic.
  void routeV1Offer(SmFileOffer offer, {int sourceNodeNum = 1}) {
    final result = negotiation.handleIncomingOffer(
      offer,
      sourceNodeNum: sourceNodeNum,
    );
    if (result == SppNegotiationState.accepted) {
      engine.handleIncomingOffer(
        offer,
        sourceNodeNum: sourceNodeNum,
        autoAccept: true,
      );
    } else if (result == SppNegotiationState.offerPending) {
      engine.handleIncomingOffer(
        offer,
        sourceNodeNum: sourceNodeNum,
        autoAccept: false,
      );
    }
  }

  setUp(() {
    sentPackets = [];
    engineStateChanges = [];

    engine = FileTransferEngine(
      sendPacket: (payload, portnum, {destinationNode, hopLimit = 3}) async {
        sentPackets.add(Uint8List.fromList(payload));
        return true;
      },
      onStateChanged: (state) {
        engineStateChanges.add(state);
      },
    );
  });

  tearDown(() {
    negotiationSub.cancel();
    negotiation.dispose();
    engine.dispose();
  });

  // ─── Tests ───────────────────────────────────────────────────────

  group('SPP v1 offer → engine wiring', () {
    test('offerPending creates visible transfer in engine', () {
      // Auto-accept disabled, untrusted sender → offerPending.
      negotiation = PayloadNegotiation(
        sendPacket: (p, {destinationNode, hopLimit = 3}) async {
          sentPackets.add(Uint8List.fromList(p));
          return true;
        },
        isTrusted: (_) => false,
        getStorageUsed: () => 0,
        autoAcceptConfig: const SppAutoAcceptConfig(enabled: false),
      );
      wireNegotiationToEngine();

      final offer = makeOffer();
      routeV1Offer(offer, sourceNodeNum: 42);

      // Engine should have a transfer in offerPending state.
      final idHex = fileIdToHex(offer.fileId);
      final transfer = engine.getTransfer(idHex);
      expect(transfer, isNotNull);
      expect(transfer!.state, TransferState.offerPending);
      expect(transfer.direction, TransferDirection.inbound);
      expect(transfer.filename, 'test.webp');
      expect(transfer.sourceNodeNum, 42);

      // Should appear in state changes.
      expect(
        engineStateChanges.any(
          (s) => s.fileIdHex == idHex && s.state == TransferState.offerPending,
        ),
        isTrue,
      );
    });

    test(
      'accept triggers negotiation.acceptOffer and transitions engine',
      () async {
        negotiation = PayloadNegotiation(
          sendPacket: (p, {destinationNode, hopLimit = 3}) async {
            sentPackets.add(Uint8List.fromList(p));
            return true;
          },
          isTrusted: (_) => false,
          getStorageUsed: () => 0,
          autoAcceptConfig: const SppAutoAcceptConfig(enabled: false),
        );
        wireNegotiationToEngine();

        final offer = makeOffer();
        routeV1Offer(offer, sourceNodeNum: 1);

        final idHex = fileIdToHex(offer.fileId);
        expect(engine.getTransfer(idHex)!.state, TransferState.offerPending);

        // Accept via negotiation (as the notifier does for v1).
        negotiation.acceptOffer(idHex);

        // Allow the async stream event to propagate.
        await Future<void>.delayed(Duration.zero);

        // Engine should now be in chunking state.
        final transfer = engine.getTransfer(idHex);
        expect(transfer!.state, TransferState.chunking);

        // An ACCEPT packet should have been sent.
        expect(
          sentPackets.any((p) => p.isNotEmpty && (p[0] & 0x0F) == 8),
          isTrue,
          reason: 'ACCEPT packet (kind=8) should have been sent',
        );
      },
    );

    test(
      'reject triggers negotiation.declineOffer and cancels engine',
      () async {
        negotiation = PayloadNegotiation(
          sendPacket: (p, {destinationNode, hopLimit = 3}) async {
            sentPackets.add(Uint8List.fromList(p));
            return true;
          },
          isTrusted: (_) => false,
          getStorageUsed: () => 0,
          autoAcceptConfig: const SppAutoAcceptConfig(enabled: false),
        );
        wireNegotiationToEngine();

        final offer = makeOffer();
        routeV1Offer(offer, sourceNodeNum: 1);

        final idHex = fileIdToHex(offer.fileId);
        expect(engine.getTransfer(idHex)!.state, TransferState.offerPending);

        // Decline via negotiation.
        negotiation.declineOffer(idHex);

        // Allow the async stream event to propagate.
        await Future<void>.delayed(Duration.zero);

        // Engine transfer should be cancelled.
        final transfer = engine.getTransfer(idHex);
        expect(transfer!.state, TransferState.cancelled);

        // A DECLINE packet should have been sent.
        expect(
          sentPackets.any((p) => p.isNotEmpty && (p[0] & 0x0F) == 9),
          isTrue,
          reason: 'DECLINE packet (kind=9) should have been sent',
        );
      },
    );

    test('duplicate offer does not create duplicate engine entry', () {
      negotiation = PayloadNegotiation(
        sendPacket: (p, {destinationNode, hopLimit = 3}) async {
          sentPackets.add(Uint8List.fromList(p));
          return true;
        },
        isTrusted: (_) => false,
        getStorageUsed: () => 0,
        autoAcceptConfig: const SppAutoAcceptConfig(enabled: false),
      );
      wireNegotiationToEngine();

      final offer = makeOffer();
      routeV1Offer(offer, sourceNodeNum: 1);

      final idHex = fileIdToHex(offer.fileId);
      expect(engine.getTransfer(idHex), isNotNull);

      // Route the same offer again — should be a no-op.
      final countBefore = engine.transfers.length;
      routeV1Offer(offer, sourceNodeNum: 1);
      expect(engine.transfers.length, countBefore);
    });

    test('auto-accept skips pending state', () {
      // Trusted sender with auto-accept enabled.
      negotiation = PayloadNegotiation(
        sendPacket: (p, {destinationNode, hopLimit = 3}) async {
          sentPackets.add(Uint8List.fromList(p));
          return true;
        },
        isTrusted: (_) => true,
        getStorageUsed: () => 0,
        autoAcceptConfig: const SppAutoAcceptConfig(
          enabled: true,
          trustedOnly: true,
          maxSizeBytes: 8192,
        ),
      );
      wireNegotiationToEngine();

      final offer = makeOffer(totalBytes: 2048);
      routeV1Offer(offer, sourceNodeNum: 1);

      final idHex = fileIdToHex(offer.fileId);
      final transfer = engine.getTransfer(idHex);
      expect(transfer, isNotNull);
      // Should be in chunking (auto-accepted), NOT offerPending.
      expect(transfer!.state, TransferState.chunking);
    });

    test('hasSession returns true for tracked offers', () {
      negotiation = PayloadNegotiation(
        sendPacket: (p, {destinationNode, hopLimit = 3}) async {
          sentPackets.add(Uint8List.fromList(p));
          return true;
        },
        isTrusted: (_) => false,
        getStorageUsed: () => 0,
        autoAcceptConfig: const SppAutoAcceptConfig(enabled: false),
      );
      wireNegotiationToEngine();

      final offer = makeOffer();
      final idHex = fileIdToHex(offer.fileId);

      expect(negotiation.hasSession(idHex), isFalse);

      routeV1Offer(offer, sourceNodeNum: 1);

      expect(negotiation.hasSession(idHex), isTrue);
    });

    test('v0 legacy offer goes directly to engine (no negotiation)', () {
      negotiation = PayloadNegotiation(
        sendPacket: (p, {destinationNode, hopLimit = 3}) async {
          sentPackets.add(Uint8List.fromList(p));
          return true;
        },
        isTrusted: (_) => false,
        getStorageUsed: () => 0,
        autoAcceptConfig: const SppAutoAcceptConfig(enabled: false),
      );
      wireNegotiationToEngine();

      final offer = makeOffer();
      final idHex = fileIdToHex(offer.fileId);

      // Simulate v0 path: direct to engine with auto-accept.
      engine.handleIncomingOffer(offer, sourceNodeNum: 1, autoAccept: true);

      final transfer = engine.getTransfer(idHex);
      expect(transfer, isNotNull);
      expect(transfer!.state, TransferState.chunking);
      // Negotiation should not know about it.
      expect(negotiation.hasSession(idHex), isFalse);
    });

    test('accept after auto-decline is a no-op '
        '(negotiation rejects the accept)', () {
      negotiation = PayloadNegotiation(
        sendPacket: (p, {destinationNode, hopLimit = 3}) async {
          sentPackets.add(Uint8List.fromList(p));
          return true;
        },
        isTrusted: (_) => false,
        getStorageUsed: () => SppLimits.maxTotalStorage,
        autoAcceptConfig: const SppAutoAcceptConfig(enabled: false),
      );
      wireNegotiationToEngine();

      final offer = makeOffer(totalBytes: 1024);
      routeV1Offer(offer, sourceNodeNum: 1);

      final idHex = fileIdToHex(offer.fileId);
      // Auto-declined due to storage → no engine entry.
      expect(engine.getTransfer(idHex), isNull);
      // Trying to accept should be a no-op.
      negotiation.acceptOffer(idHex);
      expect(engine.getTransfer(idHex), isNull);
    });
  });

  // ─── Outbound Transfer Gating ────────────────────────────────────

  group('Outbound transfer gating', () {
    test('startTransfer transitions to awaitingAccept, not chunking', () async {
      negotiation = PayloadNegotiation(
        sendPacket: (p, {destinationNode, hopLimit = 3}) async {
          sentPackets.add(Uint8List.fromList(p));
          return true;
        },
        isTrusted: (_) => false,
        getStorageUsed: () => 0,
      );
      wireNegotiationToEngine();

      final fileBytes = Uint8List.fromList(List.generate(512, (i) => i % 256));
      final transfer = engine.initiateTransfer(
        filename: 'outbound.bin',
        mimeType: 'application/octet-stream',
        fileBytes: fileBytes,
        targetNodeNum: 99,
      );
      expect(transfer, isNotNull);

      final idHex = transfer!.fileIdHex;
      await engine.startTransfer(idHex);

      // Should be awaitingAccept, NOT chunking.
      final state = engine.getTransfer(idHex);
      expect(state, isNotNull);
      expect(state!.state, TransferState.awaitingAccept);
      expect(state.isActive, isTrue);
    });

    test('no chunks sent while in awaitingAccept state', () async {
      negotiation = PayloadNegotiation(
        sendPacket: (p, {destinationNode, hopLimit = 3}) async {
          sentPackets.add(Uint8List.fromList(p));
          return true;
        },
        isTrusted: (_) => false,
        getStorageUsed: () => 0,
      );
      wireNegotiationToEngine();

      final fileBytes = Uint8List.fromList(List.generate(512, (i) => i % 256));
      final transfer = engine.initiateTransfer(
        filename: 'outbound.bin',
        mimeType: 'application/octet-stream',
        fileBytes: fileBytes,
        targetNodeNum: 99,
      );
      final idHex = transfer!.fileIdHex;
      await engine.startTransfer(idHex);

      // Only the offer packet should have been sent (no chunks).
      // Offer is the first packet; chunks come after.
      final offerPackets = sentPackets.where((p) {
        if (p.isEmpty) return false;
        final kind = p[0] & 0x0F;
        return kind == 4; // OFFER kind
      }).toList();
      final chunkPackets = sentPackets.where((p) {
        if (p.isEmpty) return false;
        final kind = p[0] & 0x0F;
        return kind == 5; // CHUNK kind
      }).toList();

      expect(offerPackets.length, 1, reason: 'Exactly one OFFER sent');
      expect(chunkPackets.length, 0, reason: 'No chunks sent before ACCEPT');
    });

    test('ACCEPT from receiver triggers chunk transmission', () async {
      negotiation = PayloadNegotiation(
        sendPacket: (p, {destinationNode, hopLimit = 3}) async {
          sentPackets.add(Uint8List.fromList(p));
          return true;
        },
        isTrusted: (_) => false,
        getStorageUsed: () => 0,
      );
      wireNegotiationToEngine();

      final fileBytes = Uint8List.fromList(List.generate(512, (i) => i % 256));
      final transfer = engine.initiateTransfer(
        filename: 'outbound.bin',
        mimeType: 'application/octet-stream',
        fileBytes: fileBytes,
        targetNodeNum: 99,
      );
      final idHex = transfer!.fileIdHex;
      await engine.startTransfer(idHex);

      // Register outbound offer (as the provider does).
      final offer = makeOffer(fileId: transfer.fileId, totalBytes: 512);
      negotiation.registerOutboundOffer(offer, targetNodeNum: 99);

      expect(engine.getTransfer(idHex)!.state, TransferState.awaitingAccept);

      // Simulate receiver's ACCEPT.
      negotiation.handleIncomingAccept(SppAccept(payloadId: transfer.fileId));

      // Allow stream event to propagate.
      await Future<void>.delayed(Duration.zero);

      // Engine should now be in chunking state.
      final updated = engine.getTransfer(idHex);
      expect(updated!.state, TransferState.chunking);
    });

    test('DECLINE from receiver cancels transfer', () async {
      negotiation = PayloadNegotiation(
        sendPacket: (p, {destinationNode, hopLimit = 3}) async {
          sentPackets.add(Uint8List.fromList(p));
          return true;
        },
        isTrusted: (_) => false,
        getStorageUsed: () => 0,
      );
      wireNegotiationToEngine();

      final fileBytes = Uint8List.fromList(List.generate(512, (i) => i % 256));
      final transfer = engine.initiateTransfer(
        filename: 'outbound.bin',
        mimeType: 'application/octet-stream',
        fileBytes: fileBytes,
        targetNodeNum: 99,
      );
      final idHex = transfer!.fileIdHex;
      await engine.startTransfer(idHex);

      final offer = makeOffer(fileId: transfer.fileId, totalBytes: 512);
      negotiation.registerOutboundOffer(offer, targetNodeNum: 99);

      // Simulate receiver's DECLINE.
      negotiation.handleIncomingDecline(
        SppDecline(payloadId: transfer.fileId, reason: 0),
      );

      await Future<void>.delayed(Duration.zero);

      final updated = engine.getTransfer(idHex);
      expect(updated!.state, TransferState.cancelled);
    });

    test('resumeTransfer is a no-op if not in awaitingAccept', () {
      negotiation = PayloadNegotiation(
        sendPacket: (p, {destinationNode, hopLimit = 3}) async {
          sentPackets.add(Uint8List.fromList(p));
          return true;
        },
        isTrusted: (_) => false,
        getStorageUsed: () => 0,
      );
      wireNegotiationToEngine();

      // Create an inbound transfer in offerPending.
      final offer = makeOffer();
      routeV1Offer(offer, sourceNodeNum: 1);

      final idHex = fileIdToHex(offer.fileId);
      expect(engine.getTransfer(idHex)!.state, TransferState.offerPending);

      // resumeTransfer should do nothing on a non-awaitingAccept state.
      engine.resumeTransfer(idHex);
      expect(engine.getTransfer(idHex)!.state, TransferState.offerPending);
    });

    test('isAccepted returns correct status', () {
      negotiation = PayloadNegotiation(
        sendPacket: (p, {destinationNode, hopLimit = 3}) async {
          sentPackets.add(Uint8List.fromList(p));
          return true;
        },
        isTrusted: (_) => false,
        getStorageUsed: () => 0,
      );
      wireNegotiationToEngine();

      final offer = makeOffer();
      final idHex = fileIdToHex(offer.fileId);

      // No session → not accepted.
      expect(negotiation.isAccepted(idHex), isFalse);

      // Register outbound → offerSent, not accepted.
      negotiation.registerOutboundOffer(offer, targetNodeNum: 99);
      expect(negotiation.isAccepted(idHex), isFalse);

      // Simulate ACCEPT → accepted.
      negotiation.handleIncomingAccept(SppAccept(payloadId: offer.fileId));
      expect(negotiation.isAccepted(idHex), isTrue);
    });
  });

  // ─── End-to-end v1 wire format verification ──────────────────────

  group('End-to-end v1 verification', () {
    test('trusted auto-accept sends ACCEPT packet to sender', () {
      // Trusted sender with auto-accept enabled.
      negotiation = PayloadNegotiation(
        sendPacket: (p, {destinationNode, hopLimit = 3}) async {
          sentPackets.add(Uint8List.fromList(p));
          return true;
        },
        isTrusted: (_) => true,
        getStorageUsed: () => 0,
        autoAcceptConfig: const SppAutoAcceptConfig(
          enabled: true,
          trustedOnly: true,
          maxSizeBytes: 8192,
        ),
      );
      wireNegotiationToEngine();

      final offer = makeOffer(totalBytes: 2048);
      routeV1Offer(offer, sourceNodeNum: 42);

      final idHex = fileIdToHex(offer.fileId);
      // Engine should be in chunking (auto-accepted).
      expect(engine.getTransfer(idHex)!.state, TransferState.chunking);

      // An ACCEPT packet should have been sent back to the sender.
      final acceptPackets = sentPackets.where((p) {
        if (p.isEmpty) return false;
        return (p[0] & 0x0F) == SppPacketKind.accept;
      }).toList();
      expect(
        acceptPackets.length,
        1,
        reason: 'Auto-accept must send exactly one ACCEPT packet',
      );

      // The ACCEPT packet should contain the correct payloadId.
      final acceptData = acceptPackets.first;
      final decoded = SppAccept.decode(acceptData);
      expect(decoded, isNotNull);
      expect(fileIdToHex(decoded!.payloadId), idHex);
    });

    test(
      'manual-accept inbound v1 offer stays pending, never enters chunking',
      () {
        negotiation = PayloadNegotiation(
          sendPacket: (p, {destinationNode, hopLimit = 3}) async {
            sentPackets.add(Uint8List.fromList(p));
            return true;
          },
          isTrusted: (_) => false,
          getStorageUsed: () => 0,
          autoAcceptConfig: const SppAutoAcceptConfig(enabled: false),
        );
        wireNegotiationToEngine();

        final offer = makeOffer();
        routeV1Offer(offer, sourceNodeNum: 1);

        final idHex = fileIdToHex(offer.fileId);
        final transfer = engine.getTransfer(idHex);

        // MUST be offerPending, NEVER chunking.
        expect(transfer!.state, TransferState.offerPending);
        expect(transfer.direction, TransferDirection.inbound);

        // No ACCEPT packet should have been sent.
        final acceptPackets = sentPackets.where((p) {
          if (p.isEmpty) return false;
          return (p[0] & 0x0F) == SppPacketKind.accept;
        }).toList();
        expect(
          acceptPackets,
          isEmpty,
          reason: 'No ACCEPT before user decision',
        );

        // Verify state changes: only offerPending, no chunking.
        final chunkingEvents = engineStateChanges.where(
          (s) => s.fileIdHex == idHex && s.state == TransferState.chunking,
        );
        expect(
          chunkingEvents,
          isEmpty,
          reason: 'Must not transition to chunking without user action',
        );
      },
    );

    test(
      'outbound offer stays in awaitingAccept when receiver never responds',
      () async {
        // Verifies the timeout mechanism is armed — the transfer stays in
        // awaitingAccept until either ACCEPT/DECLINE arrives or the 60s timer
        // fires. We can't wait 60s in a unit test, so we verify state doesn't
        // change prematurely and that the transfer remains gated.
        negotiation = PayloadNegotiation(
          sendPacket: (p, {destinationNode, hopLimit = 3}) async {
            sentPackets.add(Uint8List.fromList(p));
            return true;
          },
          isTrusted: (_) => false,
          getStorageUsed: () => 0,
        );
        wireNegotiationToEngine();

        final fileBytes = Uint8List.fromList(
          List.generate(512, (i) => i % 256),
        );
        final transfer = engine.initiateTransfer(
          filename: 'timeout.bin',
          mimeType: 'application/octet-stream',
          fileBytes: fileBytes,
          targetNodeNum: 99,
        );
        final idHex = transfer!.fileIdHex;
        await engine.startTransfer(idHex);

        final offer = makeOffer(fileId: transfer.fileId, totalBytes: 512);
        negotiation.registerOutboundOffer(offer, targetNodeNum: 99);

        expect(engine.getTransfer(idHex)!.state, TransferState.awaitingAccept);

        // After a short delay (well within 60s timeout), should still be
        // awaitingAccept — no premature state change.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(
          engine.getTransfer(idHex)!.state,
          TransferState.awaitingAccept,
          reason: 'Must stay in awaitingAccept until ACCEPT or timeout',
        );

        // No chunks should have been sent.
        final chunkPackets = sentPackets.where((p) {
          if (p.isEmpty) return false;
          return (p[0] & 0x0F) == SppPacketKind.chunk;
        }).toList();
        expect(
          chunkPackets,
          isEmpty,
          reason: 'No chunks while awaiting accept',
        );
      },
    );

    test(
      'decline of inbound offer sends DECLINE and cancels cleanly',
      () async {
        negotiation = PayloadNegotiation(
          sendPacket: (p, {destinationNode, hopLimit = 3}) async {
            sentPackets.add(Uint8List.fromList(p));
            return true;
          },
          isTrusted: (_) => false,
          getStorageUsed: () => 0,
          autoAcceptConfig: const SppAutoAcceptConfig(enabled: false),
        );
        wireNegotiationToEngine();

        final offer = makeOffer();
        routeV1Offer(offer, sourceNodeNum: 1);

        final idHex = fileIdToHex(offer.fileId);
        expect(engine.getTransfer(idHex)!.state, TransferState.offerPending);

        // User declines.
        negotiation.declineOffer(idHex);
        await Future<void>.delayed(Duration.zero);

        // Engine cancelled.
        expect(engine.getTransfer(idHex)!.state, TransferState.cancelled);

        // DECLINE packet sent.
        final declinePackets = sentPackets.where((p) {
          if (p.isEmpty) return false;
          return (p[0] & 0x0F) == SppPacketKind.decline;
        }).toList();
        expect(
          declinePackets.length,
          1,
          reason: 'Exactly one DECLINE packet sent',
        );

        // No ACCEPT should have been sent.
        final acceptPackets = sentPackets.where((p) {
          if (p.isEmpty) return false;
          return (p[0] & 0x0F) == SppPacketKind.accept;
        }).toList();
        expect(acceptPackets, isEmpty, reason: 'No ACCEPT after decline');
      },
    );

    test('v0 legacy offer bypasses negotiation (backward compatibility)', () {
      // This documents intentional v0 backward compatibility:
      // Older Socialmesh versions send v0 offers (header 0x04).
      // These go directly to the engine with settings-based auto-accept,
      // bypassing SPP negotiation entirely.
      negotiation = PayloadNegotiation(
        sendPacket: (p, {destinationNode, hopLimit = 3}) async {
          sentPackets.add(Uint8List.fromList(p));
          return true;
        },
        isTrusted: (_) => false,
        getStorageUsed: () => 0,
        autoAcceptConfig: const SppAutoAcceptConfig(enabled: false),
      );
      wireNegotiationToEngine();

      final offer = makeOffer();
      final idHex = fileIdToHex(offer.fileId);

      // Simulate v0 path: direct to engine with auto-accept=true
      // (legacy behavior: settings-based, defaults to true).
      engine.handleIncomingOffer(offer, sourceNodeNum: 1, autoAccept: true);

      final transfer = engine.getTransfer(idHex);
      expect(transfer, isNotNull);
      // v0 goes straight to chunking (no negotiation).
      expect(transfer!.state, TransferState.chunking);
      // Negotiation layer has no knowledge of this transfer.
      expect(negotiation.hasSession(idHex), isFalse);

      // No ACCEPT/DECLINE packets sent (v0 has no negotiation).
      final negotiationPackets = sentPackets.where((p) {
        if (p.isEmpty) return false;
        final kind = p[0] & 0x0F;
        return kind == SppPacketKind.accept || kind == SppPacketKind.decline;
      }).toList();
      expect(
        negotiationPackets,
        isEmpty,
        reason: 'v0 path must not send negotiation packets',
      );
    });

    test('sender resumes chunking only after ACCEPT, not before', () async {
      negotiation = PayloadNegotiation(
        sendPacket: (p, {destinationNode, hopLimit = 3}) async {
          sentPackets.add(Uint8List.fromList(p));
          return true;
        },
        isTrusted: (_) => false,
        getStorageUsed: () => 0,
      );
      wireNegotiationToEngine();

      final fileBytes = Uint8List.fromList(List.generate(512, (i) => i % 256));
      final transfer = engine.initiateTransfer(
        filename: 'gated.bin',
        mimeType: 'application/octet-stream',
        fileBytes: fileBytes,
        targetNodeNum: 99,
      );
      final idHex = transfer!.fileIdHex;
      await engine.startTransfer(idHex);

      final offer = makeOffer(fileId: transfer.fileId, totalBytes: 512);
      negotiation.registerOutboundOffer(offer, targetNodeNum: 99);

      // At this point: awaitingAccept, no chunks sent.
      expect(engine.getTransfer(idHex)!.state, TransferState.awaitingAccept);
      final chunksBefore = sentPackets.where((p) {
        if (p.isEmpty) return false;
        return (p[0] & 0x0F) == SppPacketKind.chunk;
      }).length;
      expect(chunksBefore, 0, reason: 'No chunks before ACCEPT');

      // Simulate ACCEPT from receiver.
      negotiation.handleIncomingAccept(SppAccept(payloadId: transfer.fileId));
      await Future<void>.delayed(Duration.zero);

      // Now in chunking state — the transfer is unblocked.
      final updated = engine.getTransfer(idHex);
      expect(
        updated!.state,
        TransferState.chunking,
        reason: 'Must transition to chunking after ACCEPT',
      );

      // Verify state change events show the correct sequence:
      // created → offerSent → awaitingAccept → chunking
      final states = engineStateChanges
          .where((s) => s.fileIdHex == idHex)
          .map((s) => s.state)
          .toList();
      expect(states, contains(TransferState.awaitingAccept));
      expect(states, contains(TransferState.chunking));
      final awIdx = states.indexOf(TransferState.awaitingAccept);
      final chIdx = states.indexOf(TransferState.chunking);
      expect(
        chIdx,
        greaterThan(awIdx),
        reason: 'chunking must come after awaitingAccept',
      );
    });
  });
}
