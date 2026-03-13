// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Widget tests for FileTransferCard — verifies state rendering, animated
// progress presence, voice badge, and action visibility across transfer states.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/file_transfer/widgets/file_transfer_card.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/file_transfer/file_transfer_engine.dart';

// =============================================================================
// Helpers
// =============================================================================

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [nodesProvider.overrideWith(() => _EmptyNodesNotifier())],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

class _EmptyNodesNotifier extends NodesNotifier {
  @override
  Map<int, MeshNode> build() => {};
}

FileTransferState _makeTransfer({
  TransferState state = TransferState.chunking,
  TransferDirection direction = TransferDirection.outbound,
  Set<int>? completedChunks,
  String mimeType = 'application/octet-stream',
  String filename = 'test.bin',
  int chunkCount = 10,
  TransferFailReason? failReason,
}) {
  return FileTransferState(
    fileIdHex: 'aabbccdd',
    fileId: Uint8List(16),
    direction: direction,
    state: state,
    filename: filename,
    mimeType: mimeType,
    totalBytes: 1024,
    chunkSize: 128,
    chunkCount: chunkCount,
    sha256Hash: Uint8List(32),
    completedChunks: completedChunks ?? {0, 1, 2, 3, 4},
    nackRounds: 0,
    failReason: failReason,
    createdAt: DateTime(2026, 3, 1),
    expiresAt: DateTime(2026, 3, 1, 1),
  );
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  group('FileTransferCard — state rendering', () {
    testWidgets('shows filename in full layout', (tester) async {
      final transfer = _makeTransfer(filename: 'mesh_data.json');
      await tester.pumpWidget(_wrap(FileTransferCard(transfer: transfer)));
      await tester.pumpAndSettle();

      expect(find.textContaining('mesh_data.json'), findsWidgets);
    });

    testWidgets('shows animated progress bar for active transfer', (
      tester,
    ) async {
      final transfer = _makeTransfer(state: TransferState.chunking);
      await tester.pumpWidget(_wrap(FileTransferCard(transfer: transfer)));
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('hides progress bar for completed transfer', (tester) async {
      final transfer = _makeTransfer(
        state: TransferState.complete,
        completedChunks: {0, 1, 2, 3, 4, 5, 6, 7, 8, 9},
      );
      await tester.pumpWidget(_wrap(FileTransferCard(transfer: transfer)));
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('shows indeterminate progress for waitingMissing state', (
      tester,
    ) async {
      final transfer = _makeTransfer(state: TransferState.waitingMissing);
      await tester.pumpWidget(_wrap(FileTransferCard(transfer: transfer)));
      // Use pump() — not pumpAndSettle() — because an indeterminate
      // LinearProgressIndicator loops forever and will never settle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // value=null → indeterminate LinearProgressIndicator
      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, isNull);
    });

    testWidgets('shows voice badge chip for codec2 MIME type', (tester) async {
      final transfer = _makeTransfer(
        filename: 'voice_001.c2',
        mimeType: 'audio/x-codec2',
      );
      await tester.pumpWidget(_wrap(FileTransferCard(transfer: transfer)));
      await tester.pumpAndSettle();

      // The Voice badge chip contains the mic icon — presence confirms routing.
      expect(find.byIcon(Icons.mic), findsOneWidget);
    });

    testWidgets('shows voice badge chip for .c2 extension regardless of MIME', (
      tester,
    ) async {
      final transfer = _makeTransfer(
        filename: 'voice_backup.c2',
        mimeType: 'application/octet-stream',
      );
      await tester.pumpWidget(_wrap(FileTransferCard(transfer: transfer)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic), findsOneWidget);
    });

    testWidgets('shows accept/reject buttons for offerPending state', (
      tester,
    ) async {
      final transfer = _makeTransfer(
        state: TransferState.offerPending,
        direction: TransferDirection.inbound,
      );
      await tester.pumpWidget(
        _wrap(
          FileTransferCard(
            transfer: transfer,
            onAccept: () {},
            onReject: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both action labels should be visible.
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets(
      'cancel button visible only for active (non-pending) transfer',
      (tester) async {
        final transfer = _makeTransfer(state: TransferState.chunking);
        await tester.pumpWidget(
          _wrap(FileTransferCard(transfer: transfer, onCancel: () {})),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.close), findsOneWidget);
      },
    );

    testWidgets('compact layout does not show progress bar widget', (
      tester,
    ) async {
      final transfer = _makeTransfer(state: TransferState.chunking);
      await tester.pumpWidget(
        _wrap(FileTransferCard(transfer: transfer, compact: true)),
      );
      await tester.pumpAndSettle();

      // Compact shows a CircularProgressIndicator (ring), not a bar.
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('FileTransferCard — _AnimatedTransferProgress interpolation', () {
    testWidgets('progress bar value starts at initial progress', (
      tester,
    ) async {
      final transfer = _makeTransfer(
        state: TransferState.chunking,
        completedChunks: {0, 1, 2}, // 3/10 = 0.3
        chunkCount: 10,
      );
      await tester.pumpWidget(_wrap(FileTransferCard(transfer: transfer)));
      // Pump one frame — animation not yet complete.
      await tester.pump();

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      // Animated value should be close to 0.3 (starts from 0.3, target 0.3).
      expect(indicator.value, closeTo(0.3, 0.05));
    });
  });
}
