// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../core/logging.dart';
import '../features/nodedex/providers/nodedex_providers.dart';
import '../features/nodedex/services/trust_score.dart';
import '../services/file_transfer/file_transfer_database.dart';
import '../services/file_transfer/file_transfer_engine.dart';
import '../services/payload/payload_negotiation.dart';
import '../services/payload/spp_protocol.dart';
import '../services/payload/spp_types.dart';
import '../services/protocol/protocol_service.dart';
import '../services/protocol/socialmesh/sm_codec.dart';
import '../services/protocol/socialmesh/sm_constants.dart';
import '../services/protocol/socialmesh/sm_file_transfer.dart';
import 'app_providers.dart';
import 'countdown_providers.dart';
import 'sip_providers.dart';
import 'stl_providers.dart';
import '../services/security/stl_envelope.dart';

import 'package:socialmesh/l10n/l10n_utils.dart';
import 'radio_scope_providers.dart';

// ---------------------------------------------------------------------------
// Database provider
// ---------------------------------------------------------------------------

final fileTransferDatabaseProvider = Provider<FileTransferDatabase>((ref) {
  ref.watch(radioScopeProvider);
  AppLogging.fileTransfer('Provider: creating FileTransferDatabase');
  final db = FileTransferDatabase();
  bindStoreToRadioScope(ref, db, db.close);
  return db;
});

// ---------------------------------------------------------------------------
// SPP payload negotiation provider
// ---------------------------------------------------------------------------

final payloadNegotiationProvider = Provider<PayloadNegotiation>((ref) {
  AppLogging.spp('Provider: creating PayloadNegotiation');

  final negotiation = PayloadNegotiation(
    sendPacket: (payload, {destinationNode, hopLimit = 3}) async {
      final protocol = ref.read(protocolServiceProvider);
      return protocol.sendSmFileTransferPacket(
        payload,
        destinationNode: destinationNode,
        hopLimit: hopLimit,
      );
    },
    isTrusted: (nodeNum) {
      final trust = ref.read(nodeDexTrustProvider(nodeNum));
      return trust.level.index >= TrustLevel.trusted.index;
    },
    getStorageUsed: () {
      final transfers = ref.read(fileTransferStateProvider).transfers;
      var total = 0;
      for (final t in transfers.values) {
        if (t.direction == TransferDirection.inbound && t.isActive) {
          total += t.totalBytes;
        }
      }
      return total;
    },
    autoAcceptConfig: SppAutoAcceptConfig(
      enabled: ref
          .read(settingsServiceProvider)
          .maybeWhen(
            data: (s) => s.fileTransferAutoAccept,
            orElse: () => false,
          ),
    ),
  );

  ref.onDispose(() {
    AppLogging.spp('Provider: disposing PayloadNegotiation');
    negotiation.dispose();
  });

  return negotiation;
});

// ---------------------------------------------------------------------------
// Engine provider
// ---------------------------------------------------------------------------

final fileTransferEngineProvider = Provider<FileTransferEngine>((ref) {
  late final FileTransferEngine engine;
  StreamSubscription<SmFileTransferEvent>? subscription;

  AppLogging.fileTransfer('Provider: creating FileTransferEngine');

  void subscribeToProtocol(ProtocolService protocol) {
    subscription?.cancel();
    subscription = protocol.fileTransferStream.listen((event) {
      AppLogging.fileTransfer(
        'Provider: routing ${event.type.name} from '
        '${event.senderNodeNum.toRadixString(16)} to engine',
      );
      switch (event.type) {
        case SmPacketType.fileOffer:
          final offer = event.packet as SmFileOffer;
          if (event.version >= 1) {
            // SPP v1 offer — route through negotiation layer.
            final negotiation = ref.read(payloadNegotiationProvider);
            final result = negotiation.handleIncomingOffer(
              offer,
              sourceNodeNum: event.senderNodeNum,
            );
            if (result == SppNegotiationState.accepted) {
              // Auto-accepted: pass directly to engine.
              AppLogging.spp(
                'offer auto-accepted, forwarding to engine '
                '(payload=${fileIdToHex(offer.fileId)})',
              );
              engine.handleIncomingOffer(
                offer,
                sourceNodeNum: event.senderNodeNum,
                autoAccept: true,
              );
            } else if (result == SppNegotiationState.offerPending) {
              // User must decide — create a visible transfer entry
              // in offerPending state so the UI can show accept/reject.
              AppLogging.spp(
                'offer surfaced to UI '
                '(payload=${fileIdToHex(offer.fileId)})',
              );
              engine.handleIncomingOffer(
                offer,
                sourceNodeNum: event.senderNodeNum,
                autoAccept: false,
              );
            }
            // declined → negotiation already sent DECLINE
          } else {
            // Legacy v0 offer — existing behavior.
            final settingsAsync = ref.read(settingsServiceProvider);
            final autoAccept = settingsAsync.maybeWhen(
              data: (s) => s.fileTransferAutoAccept,
              orElse: () => true,
            );
            engine.handleIncomingOffer(
              offer,
              sourceNodeNum: event.senderNodeNum,
              autoAccept: autoAccept,
            );
          }
        case SmPacketType.fileChunk:
          engine.handleIncomingChunk(
            event.packet as SmFileChunk,
            sourceNodeNum: event.senderNodeNum,
          );
        case SmPacketType.fileNack:
          engine.handleIncomingNack(event.packet as SmFileNack);
        case SmPacketType.fileAck:
          engine.handleIncomingAck(event.packet as SmFileAck);
        case SmPacketType.sppAccept:
          ref
              .read(payloadNegotiationProvider)
              .handleIncomingAccept(event.packet as SppAccept);
        case SmPacketType.sppDecline:
          ref
              .read(payloadNegotiationProvider)
              .handleIncomingDecline(event.packet as SppDecline);
        case SmPacketType.sppAbort:
          ref
              .read(payloadNegotiationProvider)
              .handleIncomingAbort(event.packet as SppAbort);
        default:
          break;
      }
    });
  }

  final db = ref.read(fileTransferDatabaseProvider);

  engine = FileTransferEngine(
    database: db,
    sendPacket: (payload, portnum, {destinationNode, hopLimit = 3}) async {
      // Always read the CURRENT protocol service for sending so that
      // reconnect-created instances are used transparently.
      var outboundPayload = payload;

      // STL: wrap with Ed25519 signature if enabled.
      final stlEnabled = ref.read(stlSigningEnabledProvider);
      if (stlEnabled) {
        final keypairAsync = ref.read(sipKeypairProvider);
        final keypair = keypairAsync.maybeWhen(
          data: (kp) => kp,
          orElse: () => null,
        );
        if (keypair != null && keypair.isInitialized) {
          final stl = ref.read(stlMiddlewareProvider);
          outboundPayload = await stl.wrapOutbound(
            payload: payload,
            signFn: keypair.sign,
            senderPubKey: keypair.getPublicKeyBytes(),
          );
        }
      }

      final protocol = ref.read(protocolServiceProvider);
      final sent = await protocol.sendSmFileTransferPacket(
        outboundPayload,
        destinationNode: destinationNode,
        hopLimit: hopLimit,
      );
      if (!sent) {
        AppLogging.fileTransfer(
          'Provider sendPacket FAILED: ${payload.length} bytes, '
          'dest=${destinationNode?.toRadixString(16) ?? "broadcast"}, '
          'hopLimit=$hopLimit',
        );
      }
      return sent;
    },
    onStateChanged: (state) {
      AppLogging.fileTransfer(
        'Provider onStateChanged: ${state.fileIdHex} → '
        '${state.state.name} '
        '(${state.direction.name}, ${state.filename})',
      );
      if (!ref.mounted) return;
      // Engine updates never include savedFilePath (it's managed by the
      // notifier's auto-save logic). Preserve the existing savedFilePath
      // from the notifier state so db.saveTransfer doesn't overwrite it
      // to null with each chunk/state update.
      final existing = ref
          .read(fileTransferStateProvider)
          .transfers[state.fileIdHex];
      final toSave =
          existing?.savedFilePath != null && state.savedFilePath == null
          ? state.copyWith(savedFilePath: existing!.savedFilePath)
          : state;

      // Persist state changes to database.
      final db = ref.read(fileTransferDatabaseProvider);
      db.saveTransfer(toSave);

      // Notify the state notifier.
      ref.read(fileTransferStateProvider.notifier).updateTransfer(state);

      // Drive the countdown banner for active transfers.
      _updateFileTransferCountdown(ref, state);
    },
  );

  // Subscribe to the initial protocol service's file-transfer stream.
  subscribeToProtocol(ref.read(protocolServiceProvider));

  // When the protocol service is recreated (transport reconnect), tear down
  // the old stream subscription and subscribe to the new instance. This keeps
  // the engine alive with its in-memory transfer state intact.
  ref.listen<ProtocolService>(protocolServiceProvider, (previous, next) {
    AppLogging.fileTransfer(
      'Provider: protocol service changed — re-subscribing stream',
    );
    subscribeToProtocol(next);
  });

  // Listen to negotiation state changes to route accepted/declined offers
  // to the engine.
  final negotiation = ref.read(payloadNegotiationProvider);
  final negotiationSub = negotiation.stateChanges.listen((offer) {
    switch (offer.state) {
      case SppNegotiationState.accepted:
        // Determine if this is inbound (offerPending) or outbound
        // (awaitingAccept).
        final transfer = engine.getTransfer(offer.payloadIdHex);
        if (transfer?.state == TransferState.offerPending) {
          // Inbound: user accepted → transition engine to chunking.
          AppLogging.spp(
            'user accepted inbound offer ${offer.payloadIdHex} — '
            'transitioning engine to chunking',
          );
          engine.acceptTransfer(offer.payloadIdHex);
        } else if (transfer?.state == TransferState.awaitingAccept) {
          // Outbound: receiver sent ACCEPT → resume chunk transmission.
          AppLogging.spp(
            'receiver accepted outbound offer ${offer.payloadIdHex} — '
            'resuming transfer',
          );
          engine.resumeTransfer(offer.payloadIdHex);
        }
      case SppNegotiationState.declined:
      case SppNegotiationState.aborted:
        AppLogging.spp(
          'offer ${offer.payloadIdHex} '
          '${offer.state == SppNegotiationState.declined ? "declined" : "aborted"} — '
          'cancelling engine transfer',
        );
        engine.cancelTransfer(offer.payloadIdHex);
      case SppNegotiationState.timedOut:
        AppLogging.spp(
          'offer ${offer.payloadIdHex} timed out — cancelling engine transfer',
        );
        engine.cancelTransfer(offer.payloadIdHex);
      case SppNegotiationState.offerSent:
      case SppNegotiationState.offerPending:
        break;
    }
  });

  ref.onDispose(() {
    AppLogging.fileTransfer('Provider: disposing FileTransferEngine');
    subscription?.cancel();
    negotiationSub.cancel();
    engine.dispose();
  });

  return engine;
});

/// Starts or cancels the countdown banner for a file transfer based on its
/// current [TransferState].
///
/// - **awaitingAccept**: countdown shows the negotiation timeout (60 s).
/// - **chunking** (outbound): estimated time = remaining chunks × 2 s.
/// - **chunking** (inbound): estimated time = remaining chunks × 2 s.
/// - Terminal states: cancel any running countdown.
void _updateFileTransferCountdown(Ref ref, FileTransferState transfer) {
  final countdown = ref.read(countdownProvider.notifier);
  final l10n = safeL10n();

  switch (transfer.state) {
    case TransferState.awaitingAccept:
      countdown.startFileTransferCountdown(
        fileIdHex: transfer.fileIdHex,
        label: l10n.countdownAwaitingAccept(transfer.filename),
        totalSeconds: CountdownNotifier.fileTransferNegotiationSeconds,
      );
    case TransferState.chunking:
      final remaining = transfer.chunkCount - transfer.completedChunks.length;
      final seconds = remaining * CountdownNotifier.fileTransferSecondsPerChunk;
      if (seconds > 0) {
        countdown.startFileTransferCountdown(
          fileIdHex: transfer.fileIdHex,
          label: transfer.direction == TransferDirection.outbound
              ? l10n.countdownSendingFile(transfer.filename)
              : l10n.countdownReceivingFile(transfer.filename),
          totalSeconds: seconds,
        );
      }
    case TransferState.complete:
    case TransferState.failed:
    case TransferState.cancelled:
      countdown.cancelFileTransferCountdown(transfer.fileIdHex);
    case TransferState.created:
    case TransferState.offerSent:
    case TransferState.offerPending:
    case TransferState.waitingMissing:
      break;
  }
}

// ---------------------------------------------------------------------------
// Transfer state notifier
// ---------------------------------------------------------------------------

/// Immutable state of all file transfers.
class FileTransferListState {
  final Map<String, FileTransferState> transfers;
  final bool isLoading;

  const FileTransferListState({
    this.transfers = const {},
    this.isLoading = false,
  });

  List<FileTransferState> get sortedTransfers {
    final list = transfers.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<FileTransferState> get activeTransfers =>
      sortedTransfers.where((t) => t.isActive).toList();

  List<FileTransferState> get completedTransfers =>
      sortedTransfers.where((t) => t.state == TransferState.complete).toList();

  FileTransferListState copyWith({
    Map<String, FileTransferState>? transfers,
    bool? isLoading,
  }) {
    return FileTransferListState(
      transfers: transfers ?? this.transfers,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class FileTransferStateNotifier extends Notifier<FileTransferListState> {
  @override
  FileTransferListState build() {
    // Ensure the engine is alive so the broadcast stream has a listener.
    // This is the primary creation path — _initializeBackgroundServices
    // may not have run yet (Android timing), and broadcast streams
    // silently drop events with no listener.
    try {
      ref.read(fileTransferEngineProvider);
    } catch (e) {
      AppLogging.fileTransfer('Notifier: engine ensure failed: $e');
    }
    _loadFromDatabase();
    return const FileTransferListState(isLoading: true);
  }

  Future<void> _loadFromDatabase() async {
    AppLogging.fileTransfer('Notifier: loading transfers from database');
    final db = ref.read(fileTransferDatabaseProvider);
    await db.init();
    final transfers = await db.loadAllTransfers();

    // Resolve stored file paths to absolute paths for the current install.
    // Paths are stored as relative strings (e.g. 'file_transfers/<id>/file.txt')
    // so they survive iOS container UUID rotation across builds/reinstalls.
    // Any legacy absolute path that no longer exists is cleared.
    final docsDir = await getApplicationDocumentsDirectory();
    final resolved = <FileTransferState>[];
    for (final t in transfers) {
      if (t.savedFilePath == null) {
        // Recovery: for completed transfers or active outbound transfers
        // with no savedFilePath, check if the file exists at the expected
        // path on disk. This covers the race condition where the app was
        // killed after the eager auto-save wrote the file but before
        // db.updateSavedPath completed.
        if (t.state == TransferState.complete ||
            (t.isActive && t.direction == TransferDirection.outbound)) {
          final rel = _relativePathFor(t);
          final abs = p.join(docsDir.path, rel);
          if (File(abs).existsSync()) {
            await db.updateSavedPath(t.fileIdHex, rel);
            resolved.add(t.copyWith(savedFilePath: abs));
            continue;
          }
        }
        resolved.add(t);
      } else if (t.savedFilePath!.startsWith('/')) {
        // Legacy absolute path — validate, then either keep or clear.
        if (File(t.savedFilePath!).existsSync()) {
          resolved.add(t);
        } else {
          // Try to recover by rebuilding from relative path.
          final rel = _relativePathFor(t);
          final abs = p.join(docsDir.path, rel);
          if (File(abs).existsSync()) {
            // Rewrite DB with the now-relative path.
            await db.updateSavedPath(t.fileIdHex, rel);
            resolved.add(t.copyWith(savedFilePath: abs));
          } else {
            // File truly gone — clear the stale path.
            await db.updateSavedPath(t.fileIdHex, null);
            resolved.add(t.copyWith(clearSavedFilePath: true));
          }
        }
      } else {
        // Relative path — resolve to absolute for in-memory use.
        final abs = p.join(docsDir.path, t.savedFilePath!);
        resolved.add(
          File(abs).existsSync()
              ? t.copyWith(savedFilePath: abs)
              : t.copyWith(clearSavedFilePath: true),
        );
      }
    }

    final map = {for (final t in resolved) t.fileIdHex: t};
    AppLogging.fileTransfer(
      'Notifier: loaded ${transfers.length} transfers from database',
    );
    state = state.copyWith(transfers: map, isLoading: false);

    // Recover active inbound transfers — rehydrate engine with persisted
    // chunks so transfers survive app restart.
    await _recoverActiveTransfers(db, resolved);
  }

  /// Rehydrate engine state for active transfers from the database.
  ///
  /// For each active transfer:
  /// 1. Expire stale transfers (past expiresAt).
  /// 2. Inbound: load persisted chunks, inject via
  ///    [FileTransferEngine.restoreInboundTransfer].
  /// 3. Outbound: load source file bytes from disk, inject via
  ///    [FileTransferEngine.restoreOutboundTransfer]. If the source file
  ///    is missing, the transfer is failed cleanly.
  /// 4. Engine handles completion, NACK timers, or completion timeouts.
  Future<void> _recoverActiveTransfers(
    FileTransferDatabase db,
    List<FileTransferState> transfers,
  ) async {
    final engine = ref.read(fileTransferEngineProvider);
    final now = DateTime.now();
    var recovered = 0;
    var expired = 0;

    for (final t in transfers) {
      if (!t.isActive) continue;

      // Expire stale transfers instead of recovering them.
      if (t.expiresAt.isBefore(now)) {
        AppLogging.fileTransfer(
          'Recovery: ${t.fileIdHex} expired — marking failed',
        );
        final failed = t.copyWith(
          state: TransferState.failed,
          failReason: TransferFailReason.expired,
        );
        await db.saveTransfer(failed);
        if (t.direction == TransferDirection.inbound) {
          await db.deleteChunks(t.fileIdHex);
        }
        final updated = Map<String, FileTransferState>.from(state.transfers)
          ..[t.fileIdHex] = failed;
        state = state.copyWith(transfers: updated);
        expired++;
        continue;
      }

      if (t.direction == TransferDirection.inbound) {
        // Inbound: only post-accept transfers (chunking / waitingMissing)
        // are eligible for active chunk recovery. Transfers in offerPending
        // were never accepted by the user — restoring them to chunking
        // would silently bypass consent. Negotiation state is not persisted,
        // so the offer cannot be re-presented. Fail them cleanly.
        if (t.state != TransferState.chunking &&
            t.state != TransferState.waitingMissing) {
          AppLogging.fileTransfer(
            'Recovery: ${t.fileIdHex} inbound — '
            'pre-accept state ${t.state.name}, marking failed',
          );
          final failed = t.copyWith(
            state: TransferState.failed,
            failReason: TransferFailReason.invalid,
          );
          await db.saveTransfer(failed);
          await db.deleteChunks(t.fileIdHex);
          final updated = Map<String, FileTransferState>.from(state.transfers)
            ..[t.fileIdHex] = failed;
          state = state.copyWith(transfers: updated);
          expired++;
          continue;
        }

        // Load persisted chunks for this transfer.
        final chunks = await db.loadChunks(t.fileIdHex);

        AppLogging.fileTransfer(
          'Recovery: ${t.fileIdHex} inbound — '
          '${chunks.length}/${t.chunkCount} chunks found in DB',
        );

        final ok = engine.restoreInboundTransfer(t, chunks);
        if (ok) recovered++;
      } else {
        // Outbound: only post-accept transfers (chunking / waitingMissing)
        // are eligible for chunk-level resumability. Pre-accept transfers
        // (created, offerSent, awaitingAccept) cannot be restored because
        // the negotiation state is not persisted and the receiver may never
        // have accepted. Fail them cleanly instead of pretending the
        // handshake already happened.
        if (t.state != TransferState.chunking &&
            t.state != TransferState.waitingMissing) {
          AppLogging.fileTransfer(
            'Recovery: ${t.fileIdHex} outbound — '
            'pre-accept state ${t.state.name}, marking failed',
          );
          final failed = t.copyWith(
            state: TransferState.failed,
            failReason: TransferFailReason.invalid,
          );
          await db.saveTransfer(failed);
          final updated = Map<String, FileTransferState>.from(state.transfers)
            ..[t.fileIdHex] = failed;
          state = state.copyWith(transfers: updated);
          expired++;
          continue;
        }

        // Outbound post-accept: reload source file bytes from disk so
        // the engine can reconstruct chunks for NACK retransmission.
        Uint8List? fileBytes;
        if (t.savedFilePath != null) {
          try {
            final file = File(t.savedFilePath!);
            if (file.existsSync()) {
              fileBytes = await file.readAsBytes();
            }
          } catch (e) {
            AppLogging.fileTransfer(
              'Recovery: ${t.fileIdHex} outbound — '
              'failed to read source file: $e',
            );
          }
        }

        if (fileBytes == null) {
          // Source file is gone — transfer cannot be resumed.
          AppLogging.fileTransfer(
            'Recovery: ${t.fileIdHex} outbound — '
            'source file missing, marking failed',
          );
          final failed = t.copyWith(
            state: TransferState.failed,
            failReason: TransferFailReason.invalid,
          );
          await db.saveTransfer(failed);
          final updated = Map<String, FileTransferState>.from(state.transfers)
            ..[t.fileIdHex] = failed;
          state = state.copyWith(transfers: updated);
          expired++;
          continue;
        }

        AppLogging.fileTransfer(
          'Recovery: ${t.fileIdHex} outbound — '
          '${fileBytes.length} bytes loaded from disk',
        );

        final withBytes = t.copyWith(fileBytes: fileBytes);
        final ok = engine.restoreOutboundTransfer(withBytes);
        if (ok) recovered++;
      }
    }

    if (recovered > 0 || expired > 0) {
      AppLogging.fileTransfer(
        'Recovery complete: $recovered restored, $expired expired',
      );
    }
  }

  /// Update a single transfer state (called by engine callback).
  void updateTransfer(FileTransferState transfer) {
    final prev = state.transfers[transfer.fileIdHex];

    // Engine updates never include savedFilePath — preserve it from the
    // previous notifier state so auto-save results aren't lost.
    final merged = transfer.savedFilePath == null && prev?.savedFilePath != null
        ? transfer.copyWith(savedFilePath: prev!.savedFilePath)
        : transfer;

    final updated = Map<String, FileTransferState>.from(state.transfers)
      ..[transfer.fileIdHex] = merged;
    state = state.copyWith(transfers: updated);

    // Auto-save bytes to disk when a transfer completes.
    // Covers both outbound (sender) and inbound (receiver).
    final justCompleted =
        merged.state == TransferState.complete &&
        merged.fileBytes != null &&
        merged.savedFilePath == null &&
        (prev == null || prev.state != TransferState.complete);
    if (justCompleted) {
      Future.microtask(() => _autoSaveFile(merged));
    }
  }

  /// Write file bytes to the app documents directory and persist the path.
  Future<void> _autoSaveFile(FileTransferState transfer) async {
    if (transfer.fileBytes == null) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final rel = _relativePathFor(transfer);
      final absDir = Directory(
        p.join(dir.path, 'file_transfers', transfer.fileIdHex),
      );
      if (!absDir.existsSync()) {
        await absDir.create(recursive: true);
      }
      final absPath = p.join(dir.path, rel);
      await File(absPath).writeAsBytes(transfer.fileBytes!);

      AppLogging.fileTransfer('Auto-saved: ${transfer.filename} → $rel');

      // Persist relative path to DB — survives iOS container UUID rotation.
      final db = ref.read(fileTransferDatabaseProvider);
      await db.updateSavedPath(transfer.fileIdHex, rel);

      // Update in-memory state with absolute path. Read the CURRENT state
      // (not the captured transfer) so we don't revert state/chunks that
      // the engine updated while the async save was in progress.
      final current = state.transfers[transfer.fileIdHex];
      if (current == null) return;
      final withPath = current.copyWith(savedFilePath: absPath);
      final updated = Map<String, FileTransferState>.from(state.transfers)
        ..[transfer.fileIdHex] = withPath;
      state = state.copyWith(transfers: updated);
    } catch (e) {
      AppLogging.fileTransfer('Auto-save failed for ${transfer.fileIdHex}: $e');
    }
  }

  /// Returns the relative file path for a transfer (relative to docs dir).
  String _relativePathFor(FileTransferState transfer) =>
      p.join('file_transfers', transfer.fileIdHex, transfer.filename);

  /// Initiate a new outbound file transfer.
  Future<FileTransferState?> sendFile({
    required String filename,
    required String mimeType,
    required Uint8List fileBytes,
    int? targetNodeNum,
    FileTransportMode transportMode = FileTransportMode.auto,
  }) async {
    // Validate size.
    if (fileBytes.length > SmFileTransferLimits.maxFileSize) {
      AppLogging.fileTransfer(
        'sendFile REJECTED: size ${fileBytes.length} exceeds max '
        '${SmFileTransferLimits.maxFileSize}',
      );
      return null;
    }
    if (fileBytes.isEmpty) {
      AppLogging.fileTransfer('sendFile REJECTED: empty file');
      return null;
    }

    final engine = ref.read(fileTransferEngineProvider);

    // STL: compute chunk payload size via the single authoritative API.
    final stlEnabled = ref.read(stlSigningEnabledProvider);
    final chunkSize = stlEnabled
        ? computeStlAwareChunkSize(
            mtu: SmPayloadLimit.loraMtu,
            sppHeaderOverhead: SmFileTransferLimits.chunkHeaderOverhead,
            stlEnabled: true,
          )
        : SmFileTransferLimits.defaultChunkSize;

    AppLogging.fileTransfer(
      'sendFile: initiating transfer '
      '(file=$filename, mime=$mimeType, size=${fileBytes.length}, '
      'target=${targetNodeNum?.toRadixString(16) ?? "broadcast"}, '
      'mode=${transportMode.name}, chunkSize=$chunkSize)',
    );
    final transfer = engine.initiateTransfer(
      filename: filename,
      mimeType: mimeType,
      fileBytes: fileBytes,
      targetNodeNum: targetNodeNum,
      chunkSize: chunkSize,
      transportMode: transportMode,
    );

    if (transfer == null) {
      AppLogging.fileTransfer(
        'sendFile FAILED: engine.initiateTransfer returned null '
        '(file=$filename, size=${fileBytes.length})',
      );
      return null;
    }

    AppLogging.protocol(
      'File transfer initiated: ${transfer.fileIdHex} '
      '(${transfer.filename}, ${transfer.totalBytes} bytes, '
      '${transfer.chunkCount} chunks)',
    );

    // Eagerly persist outbound bytes to disk before the transfer starts.
    // This ensures sent files are previewable after restart even if the app
    // is killed before the receiver's ACK arrives (which normally triggers
    // the auto-save microtask). Voice messages especially need this.
    unawaited(_autoSaveFile(transfer));

    // Start sending (offer only — chunks gated on ACCEPT).
    await engine.startTransfer(transfer.fileIdHex);

    // Register with negotiation layer so we get ACCEPT/DECLINE/TIMEOUT
    // callbacks via stateChanges stream.
    final negotiation = ref.read(payloadNegotiationProvider);
    final offer = SmFileOffer(
      fileId: transfer.fileId,
      filename: transfer.filename,
      mimeType: transfer.mimeType,
      totalBytes: transfer.totalBytes,
      chunkCount: transfer.chunkCount,
      chunkSize: transfer.chunkSize,
      sha256Hash: transfer.sha256Hash,
      createdAt: transfer.createdAt.millisecondsSinceEpoch ~/ 1000,
      expiresAt: transfer.expiresAt.millisecondsSinceEpoch ~/ 1000,
    );
    negotiation.registerOutboundOffer(offer, targetNodeNum: targetNodeNum);

    return transfer;
  }

  /// Pick a file and initiate transfer.
  Future<FileTransferState?> pickAndSendFile({
    int? targetNodeNum,
    FileTransportMode transportMode = FileTransportMode.auto,
  }) async {
    final result = await FilePicker.pickFiles(
      type: FileType.any,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    if (file.bytes == null) {
      // Read from path if bytes not available.
      if (file.path == null) return null;
      final bytes = await File(file.path!).readAsBytes();
      return sendFile(
        filename: file.name,
        mimeType: _guessMimeType(file.name),
        fileBytes: bytes,
        targetNodeNum: targetNodeNum,
        transportMode: transportMode,
      );
    }

    return sendFile(
      filename: file.name,
      mimeType: _guessMimeType(file.name),
      fileBytes: Uint8List.fromList(file.bytes!),
      targetNodeNum: targetNodeNum,
      transportMode: transportMode,
    );
  }

  /// Pick an image from gallery and compress it to fit within mesh limits.
  ///
  /// Picks at full quality to preserve source fidelity, then uses
  /// [_compressImageToFit] which binary-searches for the highest WebP
  /// quality at each dimension step that fits within
  /// [SmFileTransferLimits.maxFileSize]. WebP produces significantly
  /// better visual results than JPEG at these tiny sizes. Falls back
  /// to JPEG if native WebP encoding is unavailable.
  Future<FileTransferState?> pickAndSendImage({
    int? targetNodeNum,
    FileTransportMode transportMode = FileTransportMode.auto,
  }) async {
    AppLogging.fileTransfer(
      'pickAndSendImage: initiated '
      '(target=${targetNodeNum != null ? "!${targetNodeNum.toRadixString(16)}" : "none"})',
    );
    final imagePicker = ImagePicker();
    // Pick at full quality — we handle all compression ourselves so we
    // can binary-search for the optimal quality/dimension trade-off.
    final pickedFile = await imagePicker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) {
      AppLogging.fileTransfer('pickAndSendImage: user cancelled selection');
      return null;
    }

    AppLogging.fileTransfer(
      'pickAndSendImage: picked "${pickedFile.name}" '
      'path=${pickedFile.path}',
    );

    final sourceBytes = await File(pickedFile.path).readAsBytes();
    final initialSize = sourceBytes.length;
    AppLogging.fileTransfer(
      'pickAndSendImage: initial size $initialSize bytes '
      '(limit=${SmFileTransferLimits.maxFileSize})',
    );

    // Try WebP first (native encoder, much better at tiny sizes), then
    // fall back to JPEG (pure-Dart encoder) if native encoding fails.
    AppLogging.fileTransfer(
      'pickAndSendImage: $initialSize bytes, starting binary-search '
      'compression (WebP primary, JPEG fallback)',
    );

    var result = await _compressImageNative(
      sourceBytes,
      format: CompressFormat.webp,
    );

    String extension;
    String mimeType;

    if (result != null) {
      extension = 'webp';
      mimeType = 'image/webp';
      AppLogging.fileTransfer(
        'pickAndSendImage: WebP compression succeeded '
        '$initialSize -> ${result.length} bytes',
      );
    } else {
      AppLogging.fileTransfer(
        'pickAndSendImage: WebP failed, falling back to JPEG',
      );
      result = await _compressImageNative(
        sourceBytes,
        format: CompressFormat.jpeg,
      );

      if (result == null) {
        // Native JPEG also failed — fall back to pure-Dart encoder.
        AppLogging.fileTransfer(
          'pickAndSendImage: native JPEG failed, trying pure-Dart fallback',
        );
        result = await _compressImagePureDart(sourceBytes);
      }

      extension = 'jpg';
      mimeType = 'image/jpeg';

      if (result != null) {
        AppLogging.fileTransfer(
          'pickAndSendImage: JPEG compression succeeded '
          '$initialSize -> ${result.length} bytes',
        );
      } else {
        AppLogging.fileTransfer(
          'pickAndSendImage: all compression attempts failed',
        );
      }
    }

    if (result == null ||
        result.isEmpty ||
        result.length > SmFileTransferLimits.maxFileSize) {
      AppLogging.fileTransfer(
        'pickAndSendImage REJECTED: final size '
        '${result?.length ?? 0} exceeds '
        'max ${SmFileTransferLimits.maxFileSize}',
      );
      return null;
    }

    // Generate a short filename — ImagePicker temp names can exceed
    // SmFileTransferLimits.maxFilenameBytes (64 bytes).
    final filename = 'img_${DateTime.now().millisecondsSinceEpoch}.$extension';

    AppLogging.fileTransfer(
      'pickAndSendImage: sending "$filename" (${result.length} bytes) '
      'to target=${targetNodeNum != null ? "!${targetNodeNum.toRadixString(16)}" : "none"}',
    );

    return sendFile(
      filename: filename,
      mimeType: mimeType,
      fileBytes: result,
      targetNodeNum: targetNodeNum,
      transportMode: transportMode,
    );
  }

  /// Send a Codec2 voice message payload produced by [VoiceMessageService].
  ///
  /// [c2Payload] is the raw `.c2` wire-format bytes (header + encoded frames).
  /// Returns null if the payload is empty or exceeds the mesh transfer limit.
  Future<FileTransferState?> sendVoiceMessage(
    Uint8List c2Payload, {
    int? targetNodeNum,
    FileTransportMode transportMode = FileTransportMode.auto,
  }) async {
    AppLogging.voice(
      'sendVoiceMessage: ${c2Payload.length} bytes '
      '(target=${targetNodeNum != null ? "!${targetNodeNum.toRadixString(16)}" : "none"})',
    );
    final result = await sendFile(
      filename: 'voice_${DateTime.now().millisecondsSinceEpoch}.c2',
      mimeType: 'audio/x-codec2',
      fileBytes: c2Payload,
      targetNodeNum: targetNodeNum,
      transportMode: transportMode,
    );
    if (result == null) {
      AppLogging.voice(
        'sendVoiceMessage FAILED: sendFile returned null '
        '(${c2Payload.length} bytes, '
        'target=${targetNodeNum?.toRadixString(16) ?? "broadcast"})',
      );
    } else {
      AppLogging.voice(
        'sendVoiceMessage OK: id=${result.fileIdHex}, '
        '${result.totalBytes} bytes, '
        '${result.chunkCount} chunks',
      );
    }
    return result;
  }

  /// Compress an image using native platform encoding (WebP or JPEG).
  ///
  /// Strategy: walk a dimension ladder from large to small. At each
  /// dimension, binary-search quality (1–85) to find the highest quality
  /// that fits in the byte budget. This maximizes perceptual quality for
  /// a given size — a 96×96 at Q72 looks far better than a 160×160 at
  /// Q25 because compression artifacts at low quality are more visually
  /// offensive than smaller dimensions.
  ///
  /// Uses [FlutterImageCompress] for native WebP/JPEG encoding which
  /// produces significantly better output than pure-Dart encoders,
  /// especially at these tiny sizes where WebP's advantage is largest.
  static Future<Uint8List?> _compressImageNative(
    Uint8List sourceBytes, {
    required CompressFormat format,
  }) async {
    final formatName = format == CompressFormat.webp ? 'WebP' : 'JPEG';
    AppLogging.fileTransfer(
      '_compressImageNative($formatName): input ${sourceBytes.length} bytes',
    );

    // Dimension ladder from largest to smallest. We try each dimension
    // and binary-search for the best quality that fits. Larger dimensions
    // are tried first — if we can fit at 160px with acceptable quality,
    // that's preferable to dropping to 96px.
    const dimensions = [160, 128, 96, 80, 64, 48, 32];
    // Quality search bounds. 85 is the ceiling — above that gains are
    // diminishing. Floor of 20 avoids unusable artifact soup.
    const maxQuality = 85;
    const minQuality = 20;

    for (final dim in dimensions) {
      AppLogging.fileTransfer(
        '_compressImageNative($formatName): trying maxDim=$dim, '
        'binary-searching quality $minQuality–$maxQuality',
      );

      // First check: can we fit at minQuality? If not, this dimension
      // is too large and we should drop to the next smaller one.
      Uint8List smallest;
      try {
        smallest = await FlutterImageCompress.compressWithList(
          sourceBytes,
          minWidth: dim,
          minHeight: dim,
          quality: minQuality,
          format: format,
          keepExif: false,
        );
      } catch (e) {
        AppLogging.fileTransfer(
          '_compressImageNative($formatName): native encode failed at '
          'maxDim=$dim: $e',
        );
        return null; // Native encoder can't handle this image — bail out.
      }

      if (smallest.isEmpty) {
        AppLogging.fileTransfer(
          '_compressImageNative($formatName): empty result at maxDim=$dim',
        );
        return null;
      }

      if (smallest.length > SmFileTransferLimits.maxFileSize) {
        AppLogging.fileTransfer(
          '_compressImageNative($formatName): maxDim=$dim too large even at '
          'Q$minQuality (${smallest.length} bytes), stepping down',
        );
        continue; // This dimension can't fit — try a smaller one.
      }

      // Binary search: find the highest quality that still fits.
      var lo = minQuality;
      var hi = maxQuality;
      Uint8List best = smallest;

      while (lo <= hi) {
        final mid = (lo + hi) ~/ 2;
        try {
          final candidate = await FlutterImageCompress.compressWithList(
            sourceBytes,
            minWidth: dim,
            minHeight: dim,
            quality: mid,
            format: format,
            keepExif: false,
          );

          if (candidate.isNotEmpty &&
              candidate.length <= SmFileTransferLimits.maxFileSize) {
            best = candidate;
            lo = mid + 1; // Try higher quality.
          } else {
            hi = mid - 1; // Too large — try lower quality.
          }
        } catch (_) {
          hi = mid - 1; // Encode failed — try lower quality.
        }
      }

      AppLogging.fileTransfer(
        '_compressImageNative($formatName): SUCCESS at maxDim=$dim, '
        'quality=${hi < minQuality ? minQuality : hi}, '
        '${best.length} bytes '
        '(limit=${SmFileTransferLimits.maxFileSize})',
      );
      return best;
    }

    AppLogging.fileTransfer(
      '_compressImageNative($formatName): EXHAUSTED all dimensions',
    );
    return null;
  }

  /// Pure-Dart JPEG fallback when native encoding is unavailable.
  ///
  /// Uses the `image` package with YUV 4:2:0 chroma subsampling for
  /// better compression. Same binary-search strategy as the native path.
  static Future<Uint8List?> _compressImagePureDart(
    Uint8List sourceBytes,
  ) async {
    AppLogging.fileTransfer(
      '_compressImagePureDart: input ${sourceBytes.length} bytes',
    );

    const dimensions = [160, 128, 96, 80, 64, 48, 32];
    const maxQuality = 85;
    const minQuality = 20;

    for (final dim in dimensions) {
      AppLogging.fileTransfer(
        '_compressImagePureDart: trying maxDim=$dim, '
        'binary-searching quality $minQuality–$maxQuality',
      );

      final smallest = await compute(
        _resizeAndEncodeJpeg,
        _CompressArgs(
          imageBytes: sourceBytes,
          maxDim: dim,
          quality: minQuality,
        ),
      );

      if (smallest == null) {
        AppLogging.fileTransfer(
          '_compressImagePureDart: decode failed at maxDim=$dim',
        );
        return null;
      }

      if (smallest.length > SmFileTransferLimits.maxFileSize) {
        AppLogging.fileTransfer(
          '_compressImagePureDart: maxDim=$dim too large even at '
          'Q$minQuality (${smallest.length} bytes), stepping down',
        );
        continue;
      }

      var lo = minQuality;
      var hi = maxQuality;
      Uint8List best = smallest;

      while (lo <= hi) {
        final mid = (lo + hi) ~/ 2;
        final candidate = await compute(
          _resizeAndEncodeJpeg,
          _CompressArgs(imageBytes: sourceBytes, maxDim: dim, quality: mid),
        );

        if (candidate != null &&
            candidate.length <= SmFileTransferLimits.maxFileSize) {
          best = candidate;
          lo = mid + 1;
        } else {
          hi = mid - 1;
        }
      }

      AppLogging.fileTransfer(
        '_compressImagePureDart: SUCCESS at maxDim=$dim, '
        'quality=${hi < minQuality ? minQuality : hi}, '
        '${best.length} bytes '
        '(limit=${SmFileTransferLimits.maxFileSize})',
      );
      return best;
    }

    AppLogging.fileTransfer('_compressImagePureDart: EXHAUSTED all dimensions');
    return null;
  }

  /// Top-level function for isolate: resize and encode as JPEG.
  ///
  /// Uses YUV 4:2:0 chroma subsampling for better compression at small
  /// sizes — standard for photographic content and saves ~15-20% over
  /// 4:4:4 with no perceptible quality difference at these dimensions.
  static Uint8List? _resizeAndEncodeJpeg(_CompressArgs args) {
    try {
      final decoded = img.decodeImage(args.imageBytes);
      if (decoded == null) return null;

      final resized = img.copyResize(
        decoded,
        width: decoded.width > decoded.height ? args.maxDim : null,
        height: decoded.height >= decoded.width ? args.maxDim : null,
        interpolation: img.Interpolation.average,
      );

      return Uint8List.fromList(
        img.encodeJpg(
          resized,
          quality: args.quality,
          chroma: img.JpegChroma.yuv420,
        ),
      );
    } catch (_) {
      // The image package can throw RangeError, FormatException, etc.
      // on malformed input instead of returning null. Treat any decode/
      // encode failure as "this image can't be processed".
      return null;
    }
  }

  /// Cancel an active transfer.
  void cancelTransfer(String fileIdHex) {
    AppLogging.fileTransfer('cancelTransfer: $fileIdHex');
    final engine = ref.read(fileTransferEngineProvider);
    engine.cancelTransfer(fileIdHex);

    // The engine only knows about in-memory transfers. If the transfer was
    // loaded from the database after a restart, the engine won't have it.
    // Update our own state as a fallback so the UI reflects the cancellation.
    final current = state.transfers[fileIdHex];
    if (current != null && current.isActive) {
      state = state.copyWith(
        transfers: {
          ...state.transfers,
          fileIdHex: current.copyWith(
            state: TransferState.cancelled,
            failReason: TransferFailReason.userCancelled,
          ),
        },
      );
    }
  }

  /// Accept a pending inbound transfer.
  ///
  /// For SPP v1 transfers (tracked by the negotiation layer), routes
  /// through [PayloadNegotiation.acceptOffer] which sends the ACCEPT
  /// wire packet and then triggers the engine transition via the
  /// stateChanges listener. For legacy v0 transfers, calls the engine
  /// directly.
  void acceptTransfer(String fileIdHex) {
    final negotiation = ref.read(payloadNegotiationProvider);
    if (negotiation.hasSession(fileIdHex)) {
      AppLogging.spp('user accepted offer (payload=$fileIdHex)');
      negotiation.acceptOffer(fileIdHex);
    } else {
      AppLogging.fileTransfer('Notifier: acceptTransfer $fileIdHex (v0)');
      final engine = ref.read(fileTransferEngineProvider);
      engine.acceptTransfer(fileIdHex);
    }
  }

  /// Reject a pending inbound transfer.
  ///
  /// For SPP v1 transfers, routes through [PayloadNegotiation.declineOffer]
  /// which sends the DECLINE wire packet and cancels the engine transfer
  /// via the stateChanges listener. For legacy v0, calls the engine directly.
  void rejectTransfer(String fileIdHex) {
    final negotiation = ref.read(payloadNegotiationProvider);
    if (negotiation.hasSession(fileIdHex)) {
      AppLogging.spp('user rejected offer (payload=$fileIdHex)');
      negotiation.declineOffer(fileIdHex);
    } else {
      AppLogging.fileTransfer('Notifier: rejectTransfer $fileIdHex (v0)');
      final engine = ref.read(fileTransferEngineProvider);
      engine.rejectTransfer(fileIdHex);
    }
  }

  /// Request retransmission of missing chunks.
  Future<void> requestMissing(String fileIdHex) async {
    AppLogging.fileTransfer('requestMissing: $fileIdHex');
    final engine = ref.read(fileTransferEngineProvider);
    await engine.requestMissingChunks(fileIdHex);
  }

  /// Save a completed file to the documents directory and return its path.
  ///
  /// Works for both outbound (sender) and inbound (receiver) transfers.
  /// Returns the existing [savedFilePath] if already persisted, otherwise
  /// writes the in-memory bytes to disk.
  Future<String?> saveReceivedFile(String fileIdHex) async {
    final transfer = state.transfers[fileIdHex];
    if (transfer == null) {
      AppLogging.fileTransfer('saveFile: $fileIdHex not found');
      return null;
    }
    if (transfer.state != TransferState.complete) {
      AppLogging.fileTransfer(
        'saveFile: $fileIdHex not complete '
        '(${transfer.state.name})',
      );
      return null;
    }

    // Already saved — verify the file still exists on disk.
    if (transfer.savedFilePath != null) {
      if (File(transfer.savedFilePath!).existsSync()) {
        return transfer.savedFilePath;
      }
      // File was deleted externally — fall through to re-save if bytes available.
    }

    if (transfer.fileBytes == null) {
      AppLogging.fileTransfer('saveFile: $fileIdHex no file bytes');
      return null;
    }

    final dir = await getApplicationDocumentsDirectory();
    final rel = _relativePathFor(transfer);
    final transferDir = Directory(
      p.join(dir.path, 'file_transfers', transfer.fileIdHex),
    );
    if (!transferDir.existsSync()) {
      await transferDir.create(recursive: true);
    }

    final absPath = p.join(dir.path, rel);
    await File(absPath).writeAsBytes(transfer.fileBytes!);

    AppLogging.fileTransfer('File saved: ${transfer.filename} → $rel');

    final db = ref.read(fileTransferDatabaseProvider);
    await db.updateSavedPath(fileIdHex, rel);

    final withPath = transfer.copyWith(savedFilePath: absPath);
    final updated = Map<String, FileTransferState>.from(state.transfers)
      ..[fileIdHex] = withPath;
    state = state.copyWith(transfers: updated);

    return absPath;
  }

  /// Purge expired transfers.
  Future<void> purgeExpired() async {
    AppLogging.fileTransfer('purgeExpired: starting');
    final engine = ref.read(fileTransferEngineProvider);
    engine.purgeExpired();

    final db = ref.read(fileTransferDatabaseProvider);
    final count = await db.purgeExpired();
    AppLogging.fileTransfer('purgeExpired: removed $count from database');
  }

  /// Delete a single transfer (from engine memory and database).
  Future<void> deleteTransfer(String fileIdHex) async {
    AppLogging.fileTransfer('deleteTransfer: $fileIdHex');
    final engine = ref.read(fileTransferEngineProvider);
    engine.removeTransfer(fileIdHex);

    final db = ref.read(fileTransferDatabaseProvider);
    await db.deleteTransfer(fileIdHex);

    final updated = Map<String, FileTransferState>.from(state.transfers)
      ..remove(fileIdHex);
    state = state.copyWith(transfers: updated);
  }

  /// Delete all terminal transfers (complete, failed, cancelled).
  Future<int> clearTerminalTransfers() async {
    AppLogging.fileTransfer('clearTerminalTransfers: starting');
    final db = ref.read(fileTransferDatabaseProvider);
    final engine = ref.read(fileTransferEngineProvider);

    final toRemove = state.transfers.values
        .where(
          (t) =>
              t.state == TransferState.complete ||
              t.state == TransferState.failed ||
              t.state == TransferState.cancelled,
        )
        .toList();

    for (final t in toRemove) {
      engine.removeTransfer(t.fileIdHex);
      await db.deleteTransfer(t.fileIdHex);
    }

    final updated = Map<String, FileTransferState>.from(state.transfers)
      ..removeWhere(
        (_, t) =>
            t.state == TransferState.complete ||
            t.state == TransferState.failed ||
            t.state == TransferState.cancelled,
      );
    state = state.copyWith(transfers: updated);

    AppLogging.fileTransfer(
      'clearTerminalTransfers: removed ${toRemove.length}',
    );
    return toRemove.length;
  }

  String _guessMimeType(String filename) {
    final ext = p.extension(filename).toLowerCase();
    return switch (ext) {
      '.txt' => 'text/plain',
      '.json' => 'application/json',
      '.csv' => 'text/csv',
      '.gpx' => 'application/gpx+xml', // lint-allow: hardcoded-string
      '.kml' =>
        'application/vnd.google-earth.kml+xml', // lint-allow: hardcoded-string
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      '.gif' => 'image/gif',
      '.webp' => 'image/webp',
      '.pdf' => 'application/pdf',
      '.zip' => 'application/zip',
      '.gz' => 'application/gzip',
      _ => 'application/octet-stream',
    };
  }
}

final fileTransferStateProvider =
    NotifierProvider<FileTransferStateNotifier, FileTransferListState>(
      FileTransferStateNotifier.new,
    );

// ---------------------------------------------------------------------------
// Convenience providers
// ---------------------------------------------------------------------------

/// Active transfers count.
final activeTransferCountProvider = Provider<int>((ref) {
  final state = ref.watch(fileTransferStateProvider);
  return state.activeTransfers.length;
});

/// Pending inbound offers awaiting user acceptance.
final pendingTransferCountProvider = Provider<int>((ref) {
  final state = ref.watch(fileTransferStateProvider);
  return state.sortedTransfers
      .where((t) => t.state == TransferState.offerPending)
      .length;
});

/// Transfers for a specific node.
final nodeTransfersProvider = Provider.family<List<FileTransferState>, int>((
  ref,
  nodeNum,
) {
  final state = ref.watch(fileTransferStateProvider);
  return state.sortedTransfers
      .where((t) => t.targetNodeNum == nodeNum || t.sourceNodeNum == nodeNum)
      .toList();
});

/// Whether the user has enabled file transfer.
final fileTransferEnabledProvider = Provider<bool>((ref) {
  final settingsAsync = ref.watch(settingsServiceProvider);
  return settingsAsync.maybeWhen(
    data: (settings) => settings.fileTransferEnabled,
    orElse: () => true,
  );
});

// ---------------------------------------------------------------------------
// Image compression arguments (must be top-level for isolate compute)
// ---------------------------------------------------------------------------

class _CompressArgs {
  final Uint8List imageBytes;
  final int maxDim;
  final int quality;

  const _CompressArgs({
    required this.imageBytes,
    required this.maxDim,
    required this.quality,
  });
}
