// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Offline Storage Picker — shared storage-location section (internal vs
// removable SD card) used by the region download sheet and the Settings
// surface, plus the Settings bottom sheet that hosts it.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/chip_selector.dart';
import '../../../core/widgets/info_table.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../services/haptic_service.dart';
import '../../../utils/byte_format.dart';
import '../../../utils/snackbar.dart';
import 'offline_storage_location_notifier.dart';
import 'offline_tile_cache.dart';
import 'offline_tile_storage.dart';

/// Size in bytes of the active offline tile cache root. Recomputes when
/// the storage location changes; invalidate after switches/cleanups that
/// move or delete tiles.
final offlineCacheSizeProvider = FutureProvider<int>((ref) async {
  ref.watch(offlineStorageLocationProvider);
  final cache = OfflineTileCache.instance;
  final root = cache.activeCacheRoot;
  if (root == null) return 0;
  return cache.storage.directorySizeBytes(root);
});

/// Presents the offline map storage sheet (Settings entry point).
Future<void> showOfflineStorageSettingsSheet(BuildContext context) {
  return AppBottomSheet.show<void>(
    context: context,
    child: const _OfflineStorageSettingsSheet(),
  );
}

class _OfflineStorageSettingsSheet extends ConsumerWidget {
  const _OfflineStorageSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sizeAsync = ref.watch(offlineCacheSizeProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.settingsTileOfflineMapStorageTitle,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
        SizedBox(height: AppTheme.spacing4),
        Text(
          context.l10n.offlineStorageSheetDescription,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 13,
            color: context.textTertiary,
          ),
        ),
        SizedBox(height: AppTheme.spacing16),
        InfoTable(
          rows: [
            InfoTableRow(
              label: context.l10n.offlineStorageCacheSizeLabel,
              icon: Icons.storage,
              value: formatByteSize(sizeAsync.value ?? 0),
            ),
          ],
        ),
        const OfflineStorageSection(),
        SizedBox(height: AppTheme.spacing8),
      ],
    );
  }
}

/// Storage-location section: label + internal/SD chip picker + fallback
/// warning. Renders the picker only when a removable SD card is
/// available, and the warning only when boot fell back to internal.
/// Renders nothing at all when neither applies (iOS, no card).
class OfflineStorageSection extends ConsumerStatefulWidget {
  const OfflineStorageSection({super.key});

  @override
  ConsumerState<OfflineStorageSection> createState() =>
      _OfflineStorageSectionState();
}

class _OfflineStorageSectionState extends ConsumerState<OfflineStorageSection>
    with LifecycleSafeMixin<OfflineStorageSection> {
  Future<void> _switchStorage(OfflineTileStorageLocation target) async {
    final current = ref.read(offlineStorageLocationProvider).value;
    if (current == null || (current.location == target && !current.fellBack)) {
      return;
    }
    ref.read(hapticServiceProvider).itemSelect();
    final l10n = context.l10n;
    final notifier = ref.read(offlineStorageLocationProvider.notifier);
    try {
      final abandoned = await notifier.switchTo(target);
      if (!mounted) return;
      ref.invalidate(offlineCacheSizeProvider);
      showSuccessSnackBar(context, l10n.offlineStorageSwitched);
      if (abandoned != null) {
        await _offerAbandonedCacheCleanup(abandoned);
      }
    } on OfflineStorageUnavailableException {
      if (!mounted) return;
      showErrorSnackBar(context, l10n.offlineStorageSwitchFailed);
    }
  }

  Future<void> _offerAbandonedCacheCleanup(AbandonedCache abandoned) async {
    if (!mounted) return;
    final notifier = ref.read(offlineStorageLocationProvider.notifier);
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: context.l10n.offlineStorageOldCacheTitle,
      message: context.l10n.offlineStorageOldCacheMessage(
        formatByteSize(abandoned.bytes),
      ),
      confirmLabel: context.l10n.offlineStorageOldCacheDelete,
      cancelLabel: context.l10n.offlineStorageOldCacheKeep,
      isDestructive: true,
    );
    if (confirmed == true) {
      await notifier.deleteAbandonedCache(abandoned.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(offlineStorageLocationProvider).value;
    if (storage == null || (!storage.sdAvailable && !storage.fellBack)) {
      return const SizedBox.shrink();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (storage.sdAvailable) ...[
          SizedBox(height: AppTheme.spacing16),
          Text(
            context.l10n.offlineStorageLocationLabel,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.textSecondary,
            ),
          ),
          SizedBox(height: AppTheme.spacing12),
          ChipSelector<OfflineTileStorageLocation>(
            value: storage.location,
            options: [
              ChipOption<OfflineTileStorageLocation>(
                value: OfflineTileStorageLocation.internal,
                label: context.l10n.offlineStorageInternal,
                icon: Icons.smartphone,
                color: context.accentColor,
              ),
              ChipOption<OfflineTileStorageLocation>(
                value: OfflineTileStorageLocation.sdCard,
                label: context.l10n.offlineStorageSdCard,
                icon: Icons.sd_card,
                color: context.accentColor,
              ),
            ],
            onChanged: _switchStorage,
          ),
        ],
        if (storage.fellBack) ...[
          SizedBox(height: AppTheme.spacing12),
          StatusBanner.warning(
            title: context.l10n.offlineStorageFallbackTitle,
            subtitle: context.l10n.offlineStorageFallbackSubtitle,
          ),
        ],
      ],
    );
  }
}
