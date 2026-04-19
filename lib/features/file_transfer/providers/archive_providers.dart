// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/archive/archive_inspector_service.dart';
import '../../../services/archive/archive_models.dart';

/// Provides a singleton [ArchiveInspectorService] instance.
final archiveInspectorProvider = Provider<ArchiveInspectorService>((ref) {
  return ArchiveInspectorService();
});

/// State for the archive inspection of a single transfer.
class ArchiveInspectionState {
  /// The inspection manifest (null while loading or if not a ZIP).
  final ArchiveManifest? manifest;

  /// Whether inspection is in progress.
  final bool isLoading;

  /// Error message if inspection failed unexpectedly.
  final String? error;

  /// Map of entry index → extracted bytes (populated on demand).
  final Map<int, Uint8List> extractedEntries;

  const ArchiveInspectionState({
    this.manifest,
    this.isLoading = false,
    this.error,
    this.extractedEntries = const {},
  });

  ArchiveInspectionState copyWith({
    ArchiveManifest? manifest,
    bool? isLoading,
    String? error,
    Map<int, Uint8List>? extractedEntries,
    bool clearError = false,
  }) {
    return ArchiveInspectionState(
      manifest: manifest ?? this.manifest,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      extractedEntries: extractedEntries ?? this.extractedEntries,
    );
  }
}

/// Manages archive inspection state for a specific file transfer.
///
/// Usage:
/// ```dart
/// final state = ref.watch(archiveInspectionProvider);
/// ref.read(archiveInspectionProvider.notifier).inspect(bytes, filename);
/// ```
class ArchiveInspectionNotifier extends Notifier<ArchiveInspectionState> {
  @override
  ArchiveInspectionState build() => const ArchiveInspectionState();

  /// Inspects the given archive bytes and updates state with the manifest.
  void inspect({
    required Uint8List archiveBytes,
    required String archiveFilename,
  }) {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final service = ref.read(archiveInspectorProvider);
      final manifest = service.inspect(
        archiveBytes: archiveBytes,
        archiveFilename: archiveFilename,
      );
      state = ArchiveInspectionState(manifest: manifest);
    } catch (e) {
      state = ArchiveInspectionState(error: e.toString());
    }
  }

  /// Extracts a single entry by index and caches the bytes.
  Uint8List? extractEntry({
    required Uint8List archiveBytes,
    required int entryIndex,
  }) {
    final manifest = state.manifest;
    if (manifest == null || entryIndex >= manifest.entries.length) return null;

    // Return cached extraction.
    final cached = state.extractedEntries[entryIndex];
    if (cached != null) return cached;

    final entry = manifest.entries[entryIndex];
    final service = ref.read(archiveInspectorProvider);
    final bytes = service.extractEntry(
      archiveBytes: archiveBytes,
      entry: entry,
    );

    if (bytes != null) {
      final updated = Map<int, Uint8List>.from(state.extractedEntries);
      updated[entryIndex] = bytes;
      state = state.copyWith(extractedEntries: updated);
    }

    return bytes;
  }
}

/// Provider for archive inspection state.
final archiveInspectionProvider =
    NotifierProvider<ArchiveInspectionNotifier, ArchiveInspectionState>(
      ArchiveInspectionNotifier.new,
    );
