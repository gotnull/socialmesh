// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../core/logging.dart';
import '../services/file_transfer/file_transfer_database.dart';
import '../services/file_transfer/file_transfer_engine.dart';
import '../services/protocol/protocol_service.dart';
import '../services/protocol/socialmesh/sm_codec.dart';
import '../services/protocol/socialmesh/sm_constants.dart';
import '../services/protocol/socialmesh/sm_file_transfer.dart';
import 'app_providers.dart';

// ---------------------------------------------------------------------------
// Database provider
// ---------------------------------------------------------------------------

final fileTransferDatabaseProvider = Provider<FileTransferDatabase>((ref) {
  AppLogging.fileTransfer('Provider: creating FileTransferDatabase');
  final db = FileTransferDatabase();
  ref.onDispose(() {
    AppLogging.fileTransfer('Provider: disposing FileTransferDatabase');
    db.close();
  });
  return db;
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
          final settingsAsync = ref.read(settingsServiceProvider);
          final autoAccept = settingsAsync.maybeWhen(
            data: (s) => s.fileTransferAutoAccept,
            orElse: () => true,
          );
          engine.handleIncomingOffer(
            event.packet as SmFileOffer,
            sourceNodeNum: event.senderNodeNum,
            autoAccept: autoAccept,
          );
        case SmPacketType.fileChunk:
          engine.handleIncomingChunk(
            event.packet as SmFileChunk,
            sourceNodeNum: event.senderNodeNum,
          );
        case SmPacketType.fileNack:
          engine.handleIncomingNack(event.packet as SmFileNack);
        case SmPacketType.fileAck:
          engine.handleIncomingAck(event.packet as SmFileAck);
        default:
          break;
      }
    });
  }

  engine = FileTransferEngine(
    sendPacket: (payload, portnum, {destinationNode, hopLimit = 3}) async {
      // Always read the CURRENT protocol service for sending so that
      // reconnect-created instances are used transparently.
      final protocol = ref.read(protocolServiceProvider);
      return protocol.sendSmFileTransferPacket(
        payload,
        destinationNode: destinationNode,
        hopLimit: hopLimit,
      );
    },
    onStateChanged: (state) {
      // Persist state changes to database.
      final db = ref.read(fileTransferDatabaseProvider);
      db.saveTransfer(state);

      // Notify the state notifier.
      ref.read(fileTransferStateProvider.notifier).updateTransfer(state);
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

  ref.onDispose(() {
    AppLogging.fileTransfer('Provider: disposing FileTransferEngine');
    subscription?.cancel();
    engine.dispose();
  });

  return engine;
});

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
  }

  /// Update a single transfer state (called by engine callback).
  void updateTransfer(FileTransferState transfer) {
    final prev = state.transfers[transfer.fileIdHex];
    final updated = Map<String, FileTransferState>.from(state.transfers)
      ..[transfer.fileIdHex] = transfer;
    state = state.copyWith(transfers: updated);

    // Auto-save bytes to disk when a transfer completes.
    // Covers both outbound (sender) and inbound (receiver).
    final justCompleted =
        transfer.state == TransferState.complete &&
        transfer.fileBytes != null &&
        transfer.savedFilePath == null &&
        (prev == null || prev.state != TransferState.complete);
    if (justCompleted) {
      Future.microtask(() => _autoSaveFile(transfer));
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

      // Update in-memory state with absolute path.
      final withPath = transfer.copyWith(savedFilePath: absPath);
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
    final transfer = engine.initiateTransfer(
      filename: filename,
      mimeType: mimeType,
      fileBytes: fileBytes,
      targetNodeNum: targetNodeNum,
      transportMode: transportMode,
    );

    if (transfer == null) return null;

    AppLogging.protocol(
      'File transfer initiated: ${transfer.fileIdHex} '
      '(${transfer.filename}, ${transfer.totalBytes} bytes, '
      '${transfer.chunkCount} chunks)',
    );

    // Start sending.
    await engine.startTransfer(transfer.fileIdHex);
    return transfer;
  }

  /// Pick a file and initiate transfer.
  Future<FileTransferState?> pickAndSendFile({
    int? targetNodeNum,
    FileTransportMode transportMode = FileTransportMode.auto,
  }) async {
    final result = await FilePicker.platform.pickFiles(
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
  /// Uses [ImagePicker] for initial selection with aggressive initial
  /// compression, then iteratively re-encodes with the `image` package
  /// until the result fits within [SmFileTransferLimits.maxFileSize].
  Future<FileTransferState?> pickAndSendImage({
    int? targetNodeNum,
    FileTransportMode transportMode = FileTransportMode.auto,
  }) async {
    AppLogging.fileTransfer(
      'pickAndSendImage: initiated '
      '(target=${targetNodeNum != null ? "!${targetNodeNum.toRadixString(16)}" : "none"})',
    );
    final imagePicker = ImagePicker();
    final pickedFile = await imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 160,
      maxHeight: 160,
      imageQuality: 50,
    );

    if (pickedFile == null) {
      AppLogging.fileTransfer('pickAndSendImage: user cancelled selection');
      return null;
    }

    AppLogging.fileTransfer(
      'pickAndSendImage: picked "${pickedFile.name}" '
      'path=${pickedFile.path}',
    );

    Uint8List bytes = await File(pickedFile.path).readAsBytes();
    final initialSize = bytes.length;
    AppLogging.fileTransfer(
      'pickAndSendImage: initial size $initialSize bytes '
      '(limit=${SmFileTransferLimits.maxFileSize})',
    );

    // Iteratively compress if still too large.
    if (bytes.length > SmFileTransferLimits.maxFileSize) {
      AppLogging.fileTransfer(
        'pickAndSendImage: $initialSize > max, starting iterative '
        'compression',
      );
      final compressed = await _compressImageToFit(bytes);
      if (compressed != null) {
        bytes = compressed;
        AppLogging.fileTransfer(
          'pickAndSendImage: compressed $initialSize -> ${bytes.length} bytes',
        );
      } else {
        AppLogging.fileTransfer(
          'pickAndSendImage: compression returned null — all attempts failed',
        );
      }
    }

    if (bytes.isEmpty || bytes.length > SmFileTransferLimits.maxFileSize) {
      AppLogging.fileTransfer(
        'pickAndSendImage REJECTED: final size ${bytes.length} exceeds '
        'max ${SmFileTransferLimits.maxFileSize}',
      );
      return null;
    }

    // Generate a short filename — ImagePicker temp names can exceed
    // SmFileTransferLimits.maxFilenameBytes (64 bytes).
    final filename = 'img_${DateTime.now().millisecondsSinceEpoch}.jpg';

    AppLogging.fileTransfer(
      'pickAndSendImage: sending "$filename" (${bytes.length} bytes) '
      'to target=${targetNodeNum != null ? "!${targetNodeNum.toRadixString(16)}" : "none"}',
    );

    return sendFile(
      filename: filename,
      mimeType: 'image/jpeg',
      fileBytes: bytes,
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
    return sendFile(
      filename: 'voice_${DateTime.now().millisecondsSinceEpoch}.c2',
      mimeType: 'audio/x-codec2',
      fileBytes: c2Payload,
      targetNodeNum: targetNodeNum,
      transportMode: transportMode,
    );
  }

  /// Iteratively resize and re-encode as JPEG to fit mesh transfer limits.
  static Future<Uint8List?> _compressImageToFit(Uint8List sourceBytes) async {
    AppLogging.fileTransfer(
      '_compressImageToFit: input ${sourceBytes.length} bytes',
    );
    const attempts = [
      (maxDim: 128, quality: 40),
      (maxDim: 96, quality: 35),
      (maxDim: 80, quality: 30),
      (maxDim: 64, quality: 25),
      (maxDim: 48, quality: 20),
      (maxDim: 32, quality: 15),
    ];

    for (final attempt in attempts) {
      AppLogging.fileTransfer(
        '_compressImageToFit: trying maxDim=${attempt.maxDim}, '
        'quality=${attempt.quality}',
      );
      final compressed = await compute(
        _resizeAndEncodeJpeg,
        _CompressArgs(
          imageBytes: sourceBytes,
          maxDim: attempt.maxDim,
          quality: attempt.quality,
        ),
      );
      if (compressed != null) {
        AppLogging.fileTransfer(
          '_compressImageToFit: result ${compressed.length} bytes '
          '(limit=${SmFileTransferLimits.maxFileSize})',
        );
        if (compressed.length <= SmFileTransferLimits.maxFileSize) {
          AppLogging.fileTransfer(
            '_compressImageToFit: SUCCESS at maxDim=${attempt.maxDim}, '
            'quality=${attempt.quality}',
          );
          return compressed;
        }
      } else {
        AppLogging.fileTransfer(
          '_compressImageToFit: encode returned null at '
          'maxDim=${attempt.maxDim}',
        );
      }
    }

    AppLogging.fileTransfer('_compressImageToFit: EXHAUSTED all attempts');
    return null;
  }

  /// Top-level function for isolate: resize and encode as JPEG.
  static Uint8List? _resizeAndEncodeJpeg(_CompressArgs args) {
    final decoded = img.decodeImage(args.imageBytes);
    if (decoded == null) return null;

    final resized = img.copyResize(
      decoded,
      width: decoded.width > decoded.height ? args.maxDim : null,
      height: decoded.height >= decoded.width ? args.maxDim : null,
      interpolation: img.Interpolation.average,
    );

    return Uint8List.fromList(img.encodeJpg(resized, quality: args.quality));
  }

  /// Cancel an active transfer.
  void cancelTransfer(String fileIdHex) {
    AppLogging.fileTransfer('cancelTransfer: $fileIdHex');
    final engine = ref.read(fileTransferEngineProvider);
    engine.cancelTransfer(fileIdHex);
  }

  /// Accept a pending inbound transfer.
  void acceptTransfer(String fileIdHex) {
    AppLogging.fileTransfer('Notifier: acceptTransfer $fileIdHex');
    final engine = ref.read(fileTransferEngineProvider);
    engine.acceptTransfer(fileIdHex);
  }

  /// Reject a pending inbound transfer.
  void rejectTransfer(String fileIdHex) {
    AppLogging.fileTransfer('Notifier: rejectTransfer $fileIdHex');
    final engine = ref.read(fileTransferEngineProvider);
    engine.rejectTransfer(fileIdHex);
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
