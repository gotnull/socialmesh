// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

library;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../l10n/app_localizations.dart';
import '../models/mesh_service_instance.dart';
import '../models/mesh_service_localization.dart';
import '../models/mesh_service_signal_kind.dart';
import '../models/mesh_service_template.dart';

class MeshServiceComposeDraft {
  final String title;
  final String description;
  final int ttlMinutes;
  final List<String> options;
  final List<String> items;
  final MeshServiceSignalKind signalKind;
  final String sensorValue;
  final String sensorUnit;
  final String sensorSource;

  const MeshServiceComposeDraft({
    required this.title,
    required this.description,
    required this.ttlMinutes,
    this.options = const [],
    this.items = const [],
    this.signalKind = MeshServiceSignalKind.checkIn,
    this.sensorValue = '',
    this.sensorUnit = '',
    this.sensorSource = '',
  });
}

class MeshServiceComposeController {
  final bool isPublishing;
  final List<TextEditingController>? optionControllers;
  final VoidCallback? onAddOption;
  final void Function(int index)? onRemoveOption;
  final List<TextEditingController>? itemControllers;
  final VoidCallback? onAddItem;
  final void Function(int index)? onRemoveItem;
  final MeshServiceSignalKind signalKind;
  final ValueChanged<MeshServiceSignalKind>? onSignalKindChanged;
  final TextEditingController? sensorValueController;
  final TextEditingController? sensorUnitController;
  final TextEditingController? sensorSourceController;
  final VoidCallback? onChanged;
  final int maxPollOptions;
  final int maxListItems;

  const MeshServiceComposeController({
    required this.isPublishing,
    this.optionControllers,
    this.onAddOption,
    this.onRemoveOption,
    this.itemControllers,
    this.onAddItem,
    this.onRemoveItem,
    this.signalKind = MeshServiceSignalKind.checkIn,
    this.onSignalKindChanged,
    this.sensorValueController,
    this.sensorUnitController,
    this.sensorSourceController,
    this.onChanged,
    this.maxPollOptions = 0,
    this.maxListItems = 0,
  });
}

class MeshServiceRemoteDetailViewData {
  final String title;
  final String description;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final List<String> pollOptions;
  final List<int> pollVoteCounts;
  final int pollTotalOptions;
  final int? selectedPollOption;
  final List<String> listItems;
  final List<bool> listItemStates;
  final int listTotalItems;
  final MeshServiceSignalKind? signalKind;
  final String? sensorValue;
  final String? sensorUnit;
  final String? sensorSource;
  final DateTime? sensorCapturedAt;
  final bool isInteractionBusy;
  final int? pendingListItemIndex;
  final Future<void> Function(int optionIndex)? onVote;
  final Future<void> Function(int itemIndex, bool checked)? onToggleItem;

  const MeshServiceRemoteDetailViewData({
    required this.title,
    required this.description,
    required this.expiresAt,
    required this.createdAt,
    this.pollOptions = const [],
    this.pollVoteCounts = const [],
    this.pollTotalOptions = 0,
    this.selectedPollOption,
    this.listItems = const [],
    this.listItemStates = const [],
    this.listTotalItems = 0,
    this.signalKind,
    this.sensorValue,
    this.sensorUnit,
    this.sensorSource,
    this.sensorCapturedAt,
    this.isInteractionBusy = false,
    this.pendingListItemIndex,
    this.onVote,
    this.onToggleItem,
  });
}

abstract class MeshServicePresentationSpec {
  const MeshServicePresentationSpec();

  MeshServiceType get type;

  String discoveryEyebrow(AppLocalizations l10n);

  String discoveryCta(AppLocalizations l10n);

  String composeLead(AppLocalizations l10n) {
    return meshServiceIntentDescription(l10n, type);
  }

  String composeTitleLabel(AppLocalizations l10n) {
    return type == MeshServiceType.poll
        ? l10n.meshServicesFieldQuestion
        : l10n.meshServicesFieldTitle;
  }

  String composeDescriptionLabel(AppLocalizations l10n) {
    return l10n.meshServicesFieldDescription;
  }

  String composeDescriptionHint(AppLocalizations l10n) {
    return l10n.meshServicesDescriptionHint;
  }

  Widget buildComposeFields(
    BuildContext context,
    AppLocalizations l10n,
    MeshServiceComposeController controller,
    Color accentColor,
  ) {
    return const SizedBox.shrink();
  }

  Widget buildComposePreviewContent(
    BuildContext context,
    AppLocalizations l10n,
    MeshServiceComposeDraft draft,
  );

  Widget buildRemoteDetailContent(
    BuildContext context,
    AppLocalizations l10n,
    MeshServiceRemoteDetailViewData detail,
  );

  Widget buildLocalSummary(
    BuildContext context,
    AppLocalizations l10n,
    MeshServiceInstance instance,
  );

  String formattedVisibleFor(AppLocalizations l10n, int ttlMinutes) {
    final duration = ttlMinutes >= 60
        ? l10n.meshServicesDurationHours(ttlMinutes ~/ 60)
        : l10n.meshServicesDurationMinutes(ttlMinutes);
    return l10n.meshServicesVisibleFor(duration);
  }
}

abstract final class MeshServicePresentationRegistry {
  static const MeshServicePresentationSpec _feed = _FeedPresentationSpec();
  static const MeshServicePresentationSpec _list = _ListPresentationSpec();
  static const MeshServicePresentationSpec _poll = _PollPresentationSpec();
  static const MeshServicePresentationSpec _signal = _SignalPresentationSpec();
  static const MeshServicePresentationSpec _sensor = _SensorPresentationSpec();
  static const MeshServicePresentationSpec _game = _GamePresentationSpec();

  static MeshServicePresentationSpec forType(MeshServiceType type) {
    return switch (type) {
      MeshServiceType.feed => _feed,
      MeshServiceType.list => _list,
      MeshServiceType.poll => _poll,
      MeshServiceType.signal => _signal,
      MeshServiceType.sensor => _sensor,
      MeshServiceType.game => _game,
    };
  }
}

class _FeedPresentationSpec extends MeshServicePresentationSpec {
  const _FeedPresentationSpec();

  @override
  MeshServiceType get type => MeshServiceType.feed;

  @override
  String discoveryEyebrow(AppLocalizations l10n) =>
      l10n.meshServicesEyebrowFeed;

  @override
  String discoveryCta(AppLocalizations l10n) => l10n.meshServicesOpenFeedAction;

  @override
  Widget buildComposePreviewContent(
    BuildContext context,
    AppLocalizations l10n,
    MeshServiceComposeDraft draft,
  ) {
    return _PreviewNarrative(description: draft.description);
  }

  @override
  Widget buildRemoteDetailContent(
    BuildContext context,
    AppLocalizations l10n,
    MeshServiceRemoteDetailViewData detail,
  ) {
    return _NarrativeDetail(
      description: detail.description,
      secondary: _relativeTime(l10n, detail.createdAt),
    );
  }

  @override
  Widget buildLocalSummary(
    BuildContext context,
    AppLocalizations l10n,
    MeshServiceInstance instance,
  ) {
    return _NarrativeDetail(description: instance.description);
  }
}

class _ListPresentationSpec extends MeshServicePresentationSpec {
  const _ListPresentationSpec();

  @override
  MeshServiceType get type => MeshServiceType.list;

  @override
  String discoveryEyebrow(AppLocalizations l10n) =>
      l10n.meshServicesEyebrowList;

  @override
  String discoveryCta(AppLocalizations l10n) => l10n.meshServicesOpenListAction;

  @override
  Widget buildComposeFields(
    BuildContext context,
    AppLocalizations l10n,
    MeshServiceComposeController controller,
    Color accentColor,
  ) {
    final items = controller.itemControllers ?? const [];
    return _CompactItemsEditor(
      items: items,
      isChecklist: true,
      isPublishing: controller.isPublishing,
      accentColor: accentColor,
      maxItems: controller.maxListItems,
      onAddItem: controller.onAddItem,
      onRemoveItem: controller.onRemoveItem,
      onChanged: controller.onChanged,
      itemLabelBuilder: l10n.meshServicesFieldItem,
      addLabel: l10n.meshServicesFieldAddItem,
    );
  }

  @override
  Widget buildComposePreviewContent(
    BuildContext context,
    AppLocalizations l10n,
    MeshServiceComposeDraft draft,
  ) {
    final items = draft.items.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InlineMeta(label: l10n.meshServicesItemsCount(draft.items.length)),
        const SizedBox(height: AppTheme.spacing12),
        for (final item in items)
          _ChecklistLine(label: item, checked: false, enabled: false),
      ],
    );
  }

  @override
  Widget buildRemoteDetailContent(
    BuildContext context,
    AppLocalizations l10n,
    MeshServiceRemoteDetailViewData detail,
  ) {
    final doneCount = detail.listItemStates.where((value) => value).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (detail.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
            child: Text(
              detail.description,
              style: context.bodySecondaryStyle?.copyWith(
                color: context.textSecondary,
                height: 1.35,
              ),
            ),
          ),
        _InlineMeta(
          label: l10n.meshServicesListProgress(
            doneCount,
            detail.listTotalItems,
          ),
        ),
        const SizedBox(height: AppTheme.spacing12),
        for (var index = 0; index < detail.listItems.length; index++)
          _ChecklistLine(
            label: detail.listItems[index],
            checked: index < detail.listItemStates.length
                ? detail.listItemStates[index]
                : false,
            isPending: detail.pendingListItemIndex == index,
            enabled: !detail.isInteractionBusy && detail.onToggleItem != null,
            onTap: detail.onToggleItem == null
                ? null
                : () => detail.onToggleItem!(
                    index,
                    !(index < detail.listItemStates.length &&
                        detail.listItemStates[index]),
                  ),
          ),
        if (detail.listTotalItems > detail.listItems.length)
          Padding(
            padding: const EdgeInsets.only(top: AppTheme.spacing8),
            child: _InlineMeta(
              label: l10n.meshServicesMoreItemsCount(
                detail.listTotalItems - detail.listItems.length,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget buildLocalSummary(
    BuildContext context,
    AppLocalizations l10n,
    MeshServiceInstance instance,
  ) {
    final items =
        (instance.config['items'] as List<dynamic>?)?.cast<String>() ??
        const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InlineMeta(label: l10n.meshServicesItemsCount(items.length)),
        if (items.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacing8),
          for (final item in items.take(3))
            _ChecklistLine(label: item, checked: false, enabled: false),
        ],
      ],
    );
  }
}

class _PollPresentationSpec extends MeshServicePresentationSpec {
  const _PollPresentationSpec();

  @override
  MeshServiceType get type => MeshServiceType.poll;

  @override
  String discoveryEyebrow(AppLocalizations l10n) =>
      l10n.meshServicesEyebrowPoll;

  @override
  String discoveryCta(AppLocalizations l10n) => l10n.meshServicesOpenPollAction;

  @override
  Widget buildComposeFields(
    BuildContext context,
    AppLocalizations l10n,
    MeshServiceComposeController controller,
    Color accentColor,
  ) {
    return _CompactItemsEditor(
      items: controller.optionControllers ?? const [],
      isChecklist: false,
      isPublishing: controller.isPublishing,
      accentColor: accentColor,
      maxItems: controller.maxPollOptions,
      onAddItem: controller.onAddOption,
      onRemoveItem: controller.onRemoveOption,
      onChanged: controller.onChanged,
      itemLabelBuilder: l10n.meshServicesFieldOption,
      addLabel: l10n.meshServicesFieldAddOption,
    );
  }

  @override
  Widget buildComposePreviewContent(
    BuildContext context,
    AppLocalizations l10n,
    MeshServiceComposeDraft draft,
  ) {
    return Wrap(
      spacing: AppTheme.spacing8,
      runSpacing: AppTheme.spacing8,
      children: [
        for (final option in draft.options.take(4)) _OptionChip(label: option),
      ],
    );
  }

  @override
  Widget buildRemoteDetailContent(
    BuildContext context,
    AppLocalizations l10n,
    MeshServiceRemoteDetailViewData detail,
  ) {
    final totalVotes = detail.pollVoteCounts.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (detail.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
            child: Text(
              detail.description,
              style: context.bodySecondaryStyle?.copyWith(
                color: context.textSecondary,
                height: 1.35,
              ),
            ),
          ),
        _InlineMeta(
          label: totalVotes == 0
              ? l10n.meshServicesPollNoVotes
              : l10n.meshServicesPollVotesCount(totalVotes),
        ),
        const SizedBox(height: AppTheme.spacing12),
        for (var index = 0; index < detail.pollOptions.length; index++)
          _PollOptionButton(
            label: detail.pollOptions[index],
            votes: index < detail.pollVoteCounts.length
                ? detail.pollVoteCounts[index]
                : 0,
            selected: detail.selectedPollOption == index,
            enabled: !detail.isInteractionBusy && detail.onVote != null,
            onTap: detail.onVote == null ? null : () => detail.onVote!(index),
          ),
      ],
    );
  }

  @override
  Widget buildLocalSummary(
    BuildContext context,
    AppLocalizations l10n,
    MeshServiceInstance instance,
  ) {
    final options =
        (instance.config['options'] as List<dynamic>?)?.cast<String>() ??
        const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InlineMeta(label: l10n.meshServicesChoicesCount(options.length)),
        if (options.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacing8),
          Wrap(
            spacing: AppTheme.spacing8,
            runSpacing: AppTheme.spacing8,
            children: [
              for (final option in options.take(3)) _OptionChip(label: option),
            ],
          ),
        ],
      ],
    );
  }
}

class _SignalPresentationSpec extends MeshServicePresentationSpec {
  const _SignalPresentationSpec();

  @override
  MeshServiceType get type => MeshServiceType.signal;

  @override
  String discoveryEyebrow(AppLocalizations l10n) =>
      l10n.meshServicesEyebrowSignal;

  @override
  String discoveryCta(AppLocalizations l10n) =>
      l10n.meshServicesOpenSignalAction;

  @override
  Widget buildComposeFields(
    BuildContext context,
    AppLocalizations l10n,
    MeshServiceComposeController controller,
    Color accentColor,
  ) {
    return Wrap(
      spacing: AppTheme.spacing8,
      runSpacing: AppTheme.spacing8,
      children: [
        for (final kind in MeshServiceSignalKind.values)
          ChoiceChip(
            label: Text(meshServiceSignalKindName(l10n, kind)),
            selected: controller.signalKind == kind,
            onSelected:
                controller.isPublishing ||
                    controller.onSignalKindChanged == null
                ? null
                : (_) => controller.onSignalKindChanged!(kind),
          ),
      ],
    );
  }

  @override
  Widget buildComposePreviewContent(
    BuildContext context,
    AppLocalizations l10n,
    MeshServiceComposeDraft draft,
  ) {
    return Wrap(
      spacing: AppTheme.spacing8,
      runSpacing: AppTheme.spacing8,
      children: [
        _StatusPill(
          label: meshServiceSignalKindName(l10n, draft.signalKind),
          color: SemanticColors.warning,
        ),
        _StatusPill(
          label: l10n.meshServicesSignalActiveLabel,
          color: SemanticColors.success,
        ),
      ],
    );
  }

  @override
  Widget buildRemoteDetailContent(
    BuildContext context,
    AppLocalizations l10n,
    MeshServiceRemoteDetailViewData detail,
  ) {
    final kind = detail.signalKind ?? MeshServiceSignalKind.checkIn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppTheme.spacing8,
          runSpacing: AppTheme.spacing8,
          children: [
            _StatusPill(
              label: meshServiceSignalKindName(l10n, kind),
              color: SemanticColors.warning,
            ),
            _StatusPill(
              label: l10n.meshServicesSignalActiveLabel,
              color: SemanticColors.success,
            ),
          ],
        ),
        if (detail.description.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacing12),
          Text(
            detail.description,
            style: context.bodySecondaryStyle?.copyWith(
              color: context.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget buildLocalSummary(
    BuildContext context,
    AppLocalizations l10n,
    MeshServiceInstance instance,
  ) {
    final kind = MeshServiceSignalKind.fromStorage(
      instance.config['signalKind'],
    );
    return _StatusPill(
      label: meshServiceSignalKindName(l10n, kind),
      color: SemanticColors.warning,
    );
  }
}

class _GamePresentationSpec extends MeshServicePresentationSpec {
  const _GamePresentationSpec();

  @override
  MeshServiceType get type => MeshServiceType.game;

  @override
  String discoveryEyebrow(AppLocalizations l10n) =>
      l10n.meshServicesEyebrowGame;

  @override
  String discoveryCta(AppLocalizations l10n) => l10n.meshServicesOpenGameAction;

  @override
  Widget buildComposePreviewContent(
    BuildContext context,
    AppLocalizations l10n,
    MeshServiceComposeDraft draft,
  ) {
    return _PreviewNarrative(
      description: draft.description.isEmpty
          ? l10n.meshServicesGameComposeLead
          : draft.description,
    );
  }

  @override
  Widget buildRemoteDetailContent(
    BuildContext context,
    AppLocalizations l10n,
    MeshServiceRemoteDetailViewData detail,
  ) {
    // Graphical rendering lives in GameDetailScreen. This is only shown
    // when a remote game is viewed via the generic service detail surface.
    return _NarrativeDetail(
      description: detail.description.isEmpty
          ? l10n.meshServicesGameRemoteHint
          : detail.description,
    );
  }

  @override
  Widget buildLocalSummary(
    BuildContext context,
    AppLocalizations l10n,
    MeshServiceInstance instance,
  ) {
    final gameTypeCode = (instance.config['gameTypeCode'] as int?) ?? 0;
    final statusCode = (instance.config['gameStatusCode'] as int?) ?? 1;
    final label = switch (statusCode) {
      2 => l10n.meshGamesStatusCompleted,
      3 => l10n.meshGamesStatusAbandoned,
      4 => l10n.meshGamesStatusStale,
      _ => _gameTypeLabel(l10n, gameTypeCode),
    };
    return _StatusPill(label: label, color: context.accentColor);
  }

  String _gameTypeLabel(AppLocalizations l10n, int code) {
    return switch (code) {
      0x01 => l10n.meshGamesTypeRps,
      0x02 => l10n.meshGamesTypeTicTacToe,
      _ => l10n.meshGamesTypeUnknown,
    };
  }
}

class _SensorPresentationSpec extends MeshServicePresentationSpec {
  const _SensorPresentationSpec();

  @override
  MeshServiceType get type => MeshServiceType.sensor;

  @override
  String discoveryEyebrow(AppLocalizations l10n) =>
      l10n.meshServicesEyebrowSensor;

  @override
  String discoveryCta(AppLocalizations l10n) =>
      l10n.meshServicesOpenSensorAction;

  @override
  String composeTitleLabel(AppLocalizations l10n) =>
      l10n.meshServicesFieldSensorName;

  @override
  Widget buildComposeFields(
    BuildContext context,
    AppLocalizations l10n,
    MeshServiceComposeController controller,
    Color accentColor,
  ) {
    return Column(
      children: [
        TextFormField(
          controller: controller.sensorValueController,
          enabled: !controller.isPublishing,
          maxLength: 16,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: l10n.meshServicesFieldSensorValue,
            hintText: l10n.meshServicesSensorValueHint,
            counterText: '',
          ),
          onChanged: (_) => controller.onChanged?.call(),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return l10n.meshServicesMinSensorValue;
            }
            return null;
          },
        ),
        const SizedBox(height: AppTheme.spacing12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller.sensorUnitController,
                enabled: !controller.isPublishing,
                maxLength: 8,
                decoration: InputDecoration(
                  labelText: l10n.meshServicesFieldSensorUnit,
                  hintText: l10n.meshServicesSensorUnitHint,
                  counterText: '',
                ),
                onChanged: (_) => controller.onChanged?.call(),
              ),
            ),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: TextFormField(
                controller: controller.sensorSourceController,
                enabled: !controller.isPublishing,
                maxLength: 24,
                decoration: InputDecoration(
                  labelText: l10n.meshServicesFieldSensorSource,
                  hintText: l10n.meshServicesSensorSourceHint,
                  counterText: '',
                ),
                onChanged: (_) => controller.onChanged?.call(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget buildComposePreviewContent(
    BuildContext context,
    AppLocalizations l10n,
    MeshServiceComposeDraft draft,
  ) {
    return _SensorReading(
      value: draft.sensorValue.isEmpty
          ? l10n.meshServicesSensorUnknownValue
          : draft.sensorValue,
      unit: draft.sensorUnit,
      source: draft.sensorSource,
    );
  }

  @override
  Widget buildRemoteDetailContent(
    BuildContext context,
    AppLocalizations l10n,
    MeshServiceRemoteDetailViewData detail,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SensorReading(
          value: (detail.sensorValue == null || detail.sensorValue!.isEmpty)
              ? l10n.meshServicesSensorUnknownValue
              : detail.sensorValue!,
          unit: detail.sensorUnit,
          source: detail.sensorSource,
        ),
        if (detail.sensorCapturedAt != null) ...[
          const SizedBox(height: AppTheme.spacing12),
          _InlineMeta(
            label: l10n.meshServicesSensorUpdatedLabel(
              _relativeTime(l10n, detail.sensorCapturedAt),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget buildLocalSummary(
    BuildContext context,
    AppLocalizations l10n,
    MeshServiceInstance instance,
  ) {
    return _SensorReading(
      value:
          (instance.config['sensorValue'] as String?) ??
          l10n.meshServicesSensorUnknownValue,
      unit: instance.config['sensorUnit'] as String?,
      source: instance.config['sensorSource'] as String?,
    );
  }
}

class _PreviewNarrative extends StatelessWidget {
  final String description;

  const _PreviewNarrative({required this.description});

  @override
  Widget build(BuildContext context) {
    return Text(
      description,
      style: context.bodySecondaryStyle?.copyWith(
        color: context.textSecondary,
        height: 1.35,
      ),
    );
  }
}

class _NarrativeDetail extends StatelessWidget {
  final String description;
  final String? secondary;

  const _NarrativeDetail({required this.description, this.secondary});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (description.isNotEmpty)
          Text(
            description,
            style: context.bodySecondaryStyle?.copyWith(
              color: context.textSecondary,
              height: 1.35,
            ),
          ),
        if (secondary != null && secondary!.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacing10),
          _InlineMeta(label: secondary!),
        ],
      ],
    );
  }
}

class _InlineMeta extends StatelessWidget {
  final String label;

  const _InlineMeta({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: context.bodySmallStyle?.copyWith(color: context.textTertiary),
    );
  }
}

class _ChecklistLine extends StatelessWidget {
  final String label;
  final bool checked;
  final bool enabled;
  final bool isPending;
  final VoidCallback? onTap;

  const _ChecklistLine({
    required this.label,
    required this.checked,
    required this.enabled,
    this.isPending = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isPending
        ? context.accentColor.withValues(alpha: 0.34)
        : checked
        ? SemanticColors.success.withValues(alpha: 0.28)
        : context.border.withValues(alpha: enabled ? 0.18 : 0.12);
    final backgroundColor = isPending
        ? context.accentColor.withValues(alpha: 0.08)
        : checked
        ? SemanticColors.success.withValues(alpha: 0.1)
        : context.surface.withValues(alpha: enabled ? 0.9 : 0.6);
    final controlBorderColor = isPending
        ? context.accentColor.withValues(alpha: 0.38)
        : checked
        ? SemanticColors.success.withValues(alpha: 0.28)
        : context.border.withValues(alpha: 0.22);
    final controlFillColor = isPending
        ? context.accentColor.withValues(alpha: 0.08)
        : checked
        ? SemanticColors.success.withValues(alpha: 0.12)
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
      child: Opacity(
        opacity: enabled || isPending ? 1 : 0.8,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing12,
              vertical: AppTheme.spacing12,
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(AppTheme.radius12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Container(
                  width: AppTheme.spacing24,
                  height: AppTheme.spacing24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: controlFillColor,
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                    border: Border.all(color: controlBorderColor),
                  ),
                  child: isPending
                      ? LoadingIndicator(
                          size: AppTheme.spacing16,
                          strokeWidth: 2.2,
                          color: context.accentColor,
                        )
                      : Icon(
                          checked
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          size: AppTheme.spacing20,
                          color: checked
                              ? SemanticColors.success
                              : context.textTertiary,
                        ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Text(
                    label,
                    style: context.bodySecondaryStyle?.copyWith(
                      color: context.textPrimary,
                      fontWeight: checked || isPending
                          ? FontWeight.w600
                          : FontWeight.w500,
                      decoration: checked && !isPending
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: SemanticColors.success.withValues(
                        alpha: 0.72,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  final String label;

  const _OptionChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing10,
        vertical: AppTheme.spacing6,
      ),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius10),
        border: Border.all(color: context.border.withValues(alpha: 0.14)),
      ),
      child: Text(
        label,
        style: context.bodySmallStyle?.copyWith(color: context.textPrimary),
      ),
    );
  }
}

class _PollOptionButton extends StatelessWidget {
  final String label;
  final int votes;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  const _PollOptionButton({
    required this.label,
    required this.votes,
    required this.selected,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = selected ? context.accentColor : context.textTertiary;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacing12),
          decoration: BoxDecoration(
            color: selected
                ? context.accentColor.withValues(alpha: 0.08)
                : context.surface,
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            border: Border.all(
              color: selected
                  ? context.accentColor.withValues(alpha: 0.3)
                  : context.border.withValues(alpha: 0.14),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: context.bodySecondaryStyle?.copyWith(
                    color: context.textPrimary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Text(
                '$votes',
                style: context.bodySmallStyle?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing10,
        vertical: AppTheme.spacing6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius10),
      ),
      child: Text(
        label,
        style: context.bodySmallStyle?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SensorReading extends StatelessWidget {
  final String value;
  final String? unit;
  final String? source;

  const _SensorReading({required this.value, this.unit, this.source});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: value,
            style: context.headingStyle?.copyWith(
              color: context.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            children: [
              if (unit != null && unit!.isNotEmpty)
                TextSpan(
                  text: ' $unit',
                  style: context.titleSmallStyle?.copyWith(
                    color: context.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        if (source != null && source!.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacing6),
          Text(
            source!,
            style: context.bodySmallStyle?.copyWith(
              color: context.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _CompactItemsEditor extends StatelessWidget {
  final List<TextEditingController> items;
  final bool isChecklist;
  final bool isPublishing;
  final Color accentColor;
  final int maxItems;
  final VoidCallback? onAddItem;
  final void Function(int index)? onRemoveItem;
  final void Function()? onChanged;
  final String Function(int) itemLabelBuilder;
  final String addLabel;

  const _CompactItemsEditor({
    required this.items,
    required this.isChecklist,
    required this.isPublishing,
    required this.accentColor,
    required this.maxItems,
    required this.onAddItem,
    required this.onRemoveItem,
    required this.onChanged,
    required this.itemLabelBuilder,
    required this.addLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < items.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
            child: Row(
              children: [
                Icon(
                  isChecklist
                      ? Icons.check_box_outline_blank
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: accentColor.withValues(alpha: 0.5),
                ),
                const SizedBox(width: AppTheme.spacing10),
                Expanded(
                  child: TextField(
                    controller: items[index],
                    enabled: !isPublishing,
                    maxLength: 60,
                    decoration: InputDecoration(
                      hintText: itemLabelBuilder(index + 1),
                      counterText: '',
                    ),
                    onChanged: (_) => onChanged?.call(),
                  ),
                ),
                if (items.length > 1 && onRemoveItem != null)
                  IconButton(
                    onPressed: isPublishing ? null : () => onRemoveItem!(index),
                    icon: Icon(
                      Icons.remove_circle_outline,
                      color: SemanticColors.error.withValues(alpha: 0.8),
                    ),
                  ),
              ],
            ),
          ),
        if (items.length < maxItems && onAddItem != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: isPublishing ? null : onAddItem,
              icon: const Icon(Icons.add),
              label: Text(addLabel),
            ),
          ),
      ],
    );
  }
}

String _relativeTime(AppLocalizations l10n, DateTime? dateTime) {
  if (dateTime == null) return '';
  final diff = DateTime.now().difference(dateTime);
  if (diff.inMinutes < 1) return l10n.meshExplorerFreshnessJustNow;
  if (diff.inHours < 1) {
    return l10n.meshExplorerFreshnessMinutes(diff.inMinutes);
  }
  return l10n.meshExplorerFreshnessHours(diff.inHours);
}
