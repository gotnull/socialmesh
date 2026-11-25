// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Find Topics: listens to the configured broker for a minute and shows the
// root topics in use near the user, so picking one fills in the MQTT Root
// Topic field. Nothing is sent to the radio from here.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/units/distance_format.dart';
import '../../../core/widgets/primary_gradient_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/connectivity_providers.dart';
import '../../../core/utils/utf8_byte_length_formatter.dart';
import 'mqtt_root_topic.dart';
import 'mqtt_topic_discovery.dart';
import 'mqtt_topic_sampler.dart';

/// The state and city names a geocoder gives for a position.
typedef MqttPlaceNames = ({String? state, String? city});

/// The localised message for a root topic [problem].
String mqttRootTopicProblemMessage(
  AppLocalizations l10n,
  MqttRootTopicProblem problem,
) => switch (problem) {
  MqttRootTopicProblem.empty => l10n.mqttRootTopicProblemEmpty,
  MqttRootTopicProblem.whitespace => l10n.mqttRootTopicProblemWhitespace,
  MqttRootTopicProblem.nonAscii => l10n.mqttRootTopicProblemNonAscii,
  MqttRootTopicProblem.wildcard => l10n.mqttRootTopicProblemWildcard,
  MqttRootTopicProblem.leadingSlash => l10n.mqttRootTopicProblemLeadingSlash,
  MqttRootTopicProblem.trailingSlash => l10n.mqttRootTopicProblemTrailingSlash,
  MqttRootTopicProblem.emptySegment => l10n.mqttRootTopicProblemEmptySegment,
  MqttRootTopicProblem.endsWithVersion =>
    l10n.mqttRootTopicProblemEndsWithVersion,
  MqttRootTopicProblem.tooLong => l10n.mqttRootTopicProblemTooLong,
};

/// The Find Topics sheet. Pops with the picked root topic, or null.
class MqttTopicFinderSheet extends ConsumerStatefulWidget {
  /// Most busy regions fill the list well before this many rows.
  static const int maxActiveRows = 30;

  final ScrollController scrollController;
  final MqttBrokerSettings settings;

  /// The region topic, such as `msh/ANZ`, or null when no region is set.
  final String? regionTopic;
  final String regionName;

  /// Where the user is, for the state and city rows and distance ranking.
  final Future<LatLng?> Function() locate;

  /// Place names for a position; null when the lookup failed.
  final Future<MqttPlaceNames?> Function(LatLng position) geocode;
  final MqttTopicSampler Function() samplerFactory;

  const MqttTopicFinderSheet({
    super.key,
    required this.scrollController,
    required this.settings,
    required this.regionTopic,
    required this.regionName,
    required this.locate,
    required this.geocode,
    this.samplerFactory = MqttTopicSampler.new,
  });

  @override
  ConsumerState<MqttTopicFinderSheet> createState() =>
      _MqttTopicFinderSheetState();
}

class _MqttTopicFinderSheetState extends ConsumerState<MqttTopicFinderSheet>
    with LifecycleSafeMixin {
  late final MqttTopicSampler _sampler = widget.samplerFactory();
  StreamSubscription<MqttSamplerSnapshot>? _snapshotSub;
  MqttSamplerSnapshot _snapshot = const MqttSamplerSnapshot(
    phase: MqttSamplerPhase.idle,
  );
  final TextEditingController _customController = TextEditingController();
  LatLng? _position;
  List<MqttLadderRung> _ladder = const [];
  bool _locating = true;
  bool _geocodeFailed = false;

  @override
  void initState() {
    super.initState();
    _snapshotSub = _sampler.snapshots.listen((s) {
      safeSetState(() => _snapshot = s);
    });
    _customController.addListener(() => safeSetState(() {}));
    final regionTopic = widget.regionTopic;
    if (regionTopic != null) {
      _ladder = mqttTopicLadder(
        regionTopic: regionTopic,
        regionName: widget.regionName,
      );
      unawaited(_buildLadder(regionTopic));
      WidgetsBinding.instance.addPostFrameCallback((_) => _startSampling());
    } else {
      _locating = false;
    }
  }

  @override
  void dispose() {
    _snapshotSub?.cancel();
    _sampler.dispose();
    _customController.dispose();
    super.dispose();
  }

  void _startSampling() {
    final regionTopic = widget.regionTopic;
    if (!mounted || regionTopic == null) return;
    if (!ref.read(isOnlineProvider)) return;
    unawaited(_sampler.start(widget.settings, regionTopic));
  }

  Future<void> _buildLadder(String regionTopic) async {
    final position = await widget.locate();
    if (!mounted) return;
    if (position == null) {
      safeSetState(() => _locating = false);
      return;
    }
    final names = await widget.geocode(position);
    if (!mounted) return;
    safeSetState(() {
      _position = position;
      _locating = false;
      _geocodeFailed = names == null;
      _ladder = mqttTopicLadder(
        regionTopic: regionTopic,
        regionName: widget.regionName,
        state: names?.state,
        city: names?.city,
      );
    });
  }

  void _pick(String topic) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(topic);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final online = ref.watch(isOnlineProvider);
    final regionTopic = widget.regionTopic;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing16,
              AppTheme.spacing12,
              AppTheme.spacing16,
              AppTheme.spacing8,
            ),
            child: Row(
              children: [
                Icon(Icons.travel_explore, color: context.accentColor),
                const SizedBox(width: AppTheme.spacing8),
                Expanded(
                  child: Text(
                    l10n.mqttTopicFinderTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.border),
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.all(AppTheme.spacing16),
              children: [
                if (regionTopic == null)
                  StatusBanner.warning(title: l10n.mqttTopicFinderNoRegion)
                else if (!online)
                  StatusBanner.warning(title: l10n.mqttTopicFinderOffline)
                else
                  _buildStatus(context),
                const SizedBox(height: AppTheme.spacing8),
                _footnote(
                  context,
                  l10n.mqttTopicFinderPrivacy(widget.settings.host),
                ),
                if (regionTopic != null) ...[
                  const SizedBox(height: AppTheme.spacing16),
                  SectionTitle(title: l10n.mqttTopicFinderNearYou),
                  for (final rung in _ladder) _buildRungRow(context, rung),
                  _footnote(context, _ladderNote(l10n)),
                  const SizedBox(height: AppTheme.spacing16),
                  SectionTitle(title: l10n.mqttTopicFinderActiveTopics),
                  ..._buildActiveRows(context),
                ],
                const SizedBox(height: AppTheme.spacing16),
                SectionTitle(title: l10n.mqttTopicFinderCustomTopic),
                _buildCustom(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _ladderNote(AppLocalizations l10n) {
    if (_locating) return l10n.mqttTopicFinderCountsNote;
    if (_position == null) return l10n.mqttTopicFinderNoLocation;
    if (_geocodeFailed) return l10n.mqttTopicFinderGeocodeFailed;
    return l10n.mqttTopicFinderCountsNote;
  }

  Widget _buildStatus(BuildContext context) {
    final l10n = context.l10n;
    final snapshot = _snapshot;
    switch (snapshot.phase) {
      case MqttSamplerPhase.idle:
      case MqttSamplerPhase.connecting:
        return StatusBanner.accent(
          title: l10n.mqttTopicFinderConnecting(widget.settings.host),
          isLoading: true,
        );
      case MqttSamplerPhase.subscribing:
        return StatusBanner.accent(
          title: l10n.mqttTopicFinderSubscribing,
          isLoading: true,
        );
      case MqttSamplerPhase.sampling:
        return StatusBanner.accent(
          title: l10n.mqttTopicFinderListening(snapshot.secondsRemaining),
          isLoading: true,
          trailing: TextButton(
            style: _compactAction,
            onPressed: () {
              HapticFeedback.selectionClick();
              _sampler.stop();
            },
            child: Text(l10n.mqttTopicFinderStop),
          ),
        );
      case MqttSamplerPhase.finished:
        return StatusBanner.success(
          title: l10n.mqttTopicFinderFinished(snapshot.messageCount),
          trailing: _retryButton(l10n),
        );
      case MqttSamplerPhase.failed:
        return StatusBanner.error(
          title: switch (snapshot.failure) {
            MqttSamplerFailure.filtersRefused =>
              l10n.mqttTopicFinderFailedFilters,
            MqttSamplerFailure.closed => l10n.mqttTopicFinderFailedClosed,
            _ => l10n.mqttTopicFinderFailedConnect(widget.settings.host),
          },
          trailing: _retryButton(l10n),
        );
    }
  }

  // A single-line banner: a full-height button would sit below the title.
  static final ButtonStyle _compactAction = TextButton.styleFrom(
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing8),
  );

  Widget _retryButton(AppLocalizations l10n) => TextButton(
    style: _compactAction,
    onPressed: () {
      HapticFeedback.selectionClick();
      _startSampling();
    },
    child: Text(l10n.commonRetry),
  );

  Widget _footnote(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: AppTheme.spacing8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: context.textSecondary),
    ),
  );

  Widget _buildRungRow(BuildContext context, MqttLadderRung rung) {
    final l10n = context.l10n;
    final live = mqttActivityForRung(rung, _snapshot.activity);
    final level = switch (rung.level) {
      MqttLadderLevel.region => l10n.mqttTopicFinderLevelRegion,
      MqttLadderLevel.state => l10n.mqttTopicFinderLevelState,
      MqttLadderLevel.city => l10n.mqttTopicFinderLevelCity,
    };
    return _TopicRow(
      title: l10n.mqttTopicFinderRungTitle(level, rung.placeName),
      topic: live?.topic ?? rung.topic,
      details: live == null ? null : _details(context, live.activity),
      count: _countLabel(l10n, live?.activity),
      onTap: () => _pick(live?.topic ?? rung.topic),
    );
  }

  List<Widget> _buildActiveRows(BuildContext context) {
    final l10n = context.l10n;
    final ranked = rankMqttRoots(
      _snapshot.activity,
      ladder: _ladder,
      from: _position,
    );
    if (ranked.isEmpty) {
      final text = switch (_snapshot.phase) {
        MqttSamplerPhase.finished || MqttSamplerPhase.failed =>
          _snapshot.activity.isEmpty
              ? l10n.mqttTopicFinderNothingHeard
              : l10n.mqttTopicFinderOnlyLadder,
        _ => l10n.mqttTopicFinderNothingYet,
      };
      return [_footnote(context, text)];
    }
    return [
      for (final root in ranked.take(MqttTopicFinderSheet.maxActiveRows))
        _TopicRow(
          topic: root.root,
          details: _details(context, root.activity, distance: root.distance),
          count: _countLabel(l10n, root.activity),
          onTap: () => _pick(root.root),
        ),
    ];
  }

  String? _details(
    BuildContext context,
    MqttRootActivity activity, {
    double? distance,
  }) {
    final parts = <String>[];
    if (activity.channels.isNotEmpty) {
      final channels = activity.channels.toList()..sort();
      parts.add(channels.take(3).join(', '));
    }
    if (distance != null) {
      parts.add(
        context.l10n.mqttTopicFinderNearest(
          formatDistanceMeters(
            distance,
            ref.read(measurementUnitsProvider),
            context.l10n,
          ),
        ),
      );
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  String _countLabel(AppLocalizations l10n, MqttRootActivity? activity) {
    final count = activity?.nodeCount ?? 0;
    return activity?.truncated ?? false
        ? l10n.mqttTopicFinderNodeCountAtLeast(count)
        : l10n.mqttTopicFinderNodeCount(count);
  }

  Widget _buildCustom(BuildContext context) {
    final l10n = context.l10n;
    final sanitized = sanitizeMqttRootTopic(_customController.text);
    final problem = _customController.text.isEmpty
        ? null
        : mqttRootTopicProblem(sanitized);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _customController,
          maxLength: 256,
          inputFormatters: const [Utf8ByteLengthFormatter(64)],
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
          style: TextStyle(color: context.textPrimary),
          decoration: InputDecoration(
            labelText: l10n.mqttTopicFinderCustomTopic,
            labelStyle: TextStyle(color: context.textSecondary),
            prefixIcon: Icon(Icons.tag, color: context.textSecondary),
            errorText: problem == null
                ? null
                : mqttRootTopicProblemMessage(l10n, problem),
            errorMaxLines: 3,
            counterText: '',
            filled: true,
            fillColor: context.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius8),
              borderSide: BorderSide(color: context.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius8),
              borderSide: BorderSide(color: context.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius8),
              borderSide: BorderSide(color: context.accentColor),
            ),
          ),
        ),
        _footnote(context, l10n.mqttTopicFinderCustomRules),
        const SizedBox(height: AppTheme.spacing12),
        PrimaryGradientButton(
          label: l10n.mqttTopicFinderUseTopic,
          enabled: _customController.text.isNotEmpty && problem == null,
          onPressed: () => _pick(sanitized),
        ),
      ],
    );
  }
}

/// One tappable topic: an optional place line, the topic itself, the
/// channels and distance, and the node count.
class _TopicRow extends StatelessWidget {
  final String? title;
  final String topic;
  final String? details;
  final String count;
  final VoidCallback onTap;

  const _TopicRow({
    this.title,
    required this.topic,
    required this.details,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
      child: Material(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null)
                        Text(
                          title!,
                          style: textTheme.bodySmall?.copyWith(
                            color: context.textSecondary,
                          ),
                        ),
                      Text(
                        topic,
                        style: textTheme.titleSmall?.copyWith(
                          color: context.textPrimary,
                        ),
                      ),
                      if (details != null)
                        Text(
                          details!,
                          style: textTheme.bodySmall?.copyWith(
                            color: context.textTertiary,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.spacing8),
                Text(
                  count,
                  style: textTheme.bodySmall?.copyWith(
                    color: context.accentColor,
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
