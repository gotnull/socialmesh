// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D49-C: repeater admin settings screen.
//
// Reached from the D49-A admin hub. Five high-frequency admin
// operations rendered as a canonical form (identity / behaviour /
// advertisement sections). Every field talks to the radio over the
// same CLI lane that D49-B exposed -- no new wire surface here. The
// screen orchestrates a sequence of `sendCliCommand` calls on save
// and parses free-text replies via `MeshCoreCliReplyParser` on
// refresh.
//
// Out of scope (deferred to D49-D): radio params (freq / bw / sf /
// cr / tx power), location (lat / lon), password / guest password,
// privacy mode, auto-clock-sync, auto re-login on session timeout.
// Those land alongside the keep-alive + access-list + binary-RPC
// status track.
//
// Async safety: ConsumerStatefulWidget + LifecycleSafeMixin. Every
// `await` is followed by a `mounted` guard. Save and refresh both
// short-circuit if the session is null (the firmware admin session
// dropped, or the user navigated here from an unconnected state).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/primary_gradient_button.dart';
import '../../../core/widgets/settings_primitives.dart';
import '../../../models/meshcore_contact.dart';
import '../../../providers/meshcore_providers.dart';
import '../../../services/haptic_service.dart';
import '../../../services/meshcore/protocol/meshcore_cli_reply_parser.dart';
import '../../../services/meshcore/protocol/meshcore_session.dart';
import '../../../utils/snackbar.dart';

// Range guards mirror upstream's firmware constraints. Out-of-range
// inputs surface inline validation messages and skip the save.
const int _kAdvertIntervalMin = 0;
const int _kAdvertIntervalMax = 1440; // 24 h
const int _kFloodAdvertIntervalMin = 0;
const int _kFloodAdvertIntervalMax = 168; // 1 week
const int _kNameMaxLength = 32;

class MeshCoreRepeaterAdminSettingsScreen extends ConsumerStatefulWidget {
  final MeshCoreContact contact;
  const MeshCoreRepeaterAdminSettingsScreen({super.key, required this.contact});

  @override
  ConsumerState<MeshCoreRepeaterAdminSettingsScreen> createState() =>
      _MeshCoreRepeaterAdminSettingsScreenState();
}

class _MeshCoreRepeaterAdminSettingsScreenState
    extends ConsumerState<MeshCoreRepeaterAdminSettingsScreen>
    with LifecycleSafeMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _advertIntervalController =
      TextEditingController();
  final TextEditingController _floodAdvertIntervalController =
      TextEditingController();

  // Initial values are the baseline the radio reports. The save loop
  // only writes the fields whose live value differs from the initial.
  String _initialName = '';
  bool _repeat = true;
  bool _initialRepeat = true;
  bool _allowReadOnly = true;
  bool _initialAllowReadOnly = true;
  int? _initialAdvertInterval;
  int? _initialFloodAdvertInterval;

  bool _busy = false;
  int _prefixCounter = 0;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.contact.name;
    _initialName = widget.contact.name;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _advertIntervalController.dispose();
    _floodAdvertIntervalController.dispose();
    super.dispose();
  }

  String _nextPrefixToken() {
    final v = _prefixCounter++ & 0xFF;
    return '${v.toRadixString(16).padLeft(2, '0').toUpperCase()}|';
  }

  bool get _dirty {
    if (_nameController.text != _initialName) return true;
    if (_repeat != _initialRepeat) return true;
    if (_allowReadOnly != _initialAllowReadOnly) return true;
    final adv = _parseIntOrNull(_advertIntervalController.text);
    if (adv != _initialAdvertInterval) return true;
    final flood = _parseIntOrNull(_floodAdvertIntervalController.text);
    if (flood != _initialFloodAdvertInterval) return true;
    return false;
  }

  int? _parseIntOrNull(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  String? _validateInt(String raw, int min, int max) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final v = int.tryParse(t);
    if (v == null) {
      return context.l10n.meshcoreRepeaterAdminSettingsInvalidNumber;
    }
    if (v < min || v > max) {
      return context.l10n.meshcoreRepeaterAdminSettingsOutOfRange(min, max);
    }
    return null;
  }

  Future<void> _refreshAll() async {
    final session = ref.read(meshCoreSessionProvider);
    if (session == null) {
      showErrorSnackBar(context, context.l10n.meshcoreNotConnectedToDevice);
      return;
    }
    setState(() => _busy = true);
    unawaited(ref.read(hapticServiceProvider).trigger(HapticType.light));

    final refreshers = <_RefreshTask>[
      _RefreshTask(
        command: 'get name',
        apply: (reply) {
          final v = MeshCoreCliReplyParser.extractValue(reply);
          if (v != null) {
            _initialName = v;
            _nameController.text = v;
          }
        },
      ),
      _RefreshTask(
        command: 'get repeat',
        apply: (reply) {
          final v = MeshCoreCliReplyParser.extractBool(reply);
          if (v != null) {
            _initialRepeat = v;
            _repeat = v;
          }
        },
      ),
      _RefreshTask(
        command: 'get allow.read.only',
        apply: (reply) {
          final v = MeshCoreCliReplyParser.extractBool(reply);
          if (v != null) {
            _initialAllowReadOnly = v;
            _allowReadOnly = v;
          }
        },
      ),
      _RefreshTask(
        command: 'get advert.interval',
        apply: (reply) {
          final v = MeshCoreCliReplyParser.extractInt(reply);
          if (v != null) {
            _initialAdvertInterval = v;
            _advertIntervalController.text = v.toString();
          }
        },
      ),
      _RefreshTask(
        command: 'get flood.advert.interval',
        apply: (reply) {
          final v = MeshCoreCliReplyParser.extractInt(reply);
          if (v != null) {
            _initialFloodAdvertInterval = v;
            _floodAdvertIntervalController.text = v.toString();
          }
        },
      ),
    ];

    int refreshed = 0;
    for (final task in refreshers) {
      final ok = await _dispatchGet(session, task);
      if (!mounted) return;
      if (ok) refreshed++;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    if (!mounted) return;
    setState(() => _busy = false);
    showSuccessSnackBar(
      context,
      context.l10n.meshcoreRepeaterAdminSettingsRefreshedSnackbar(refreshed),
    );
  }

  Future<bool> _dispatchGet(MeshCoreSession session, _RefreshTask task) async {
    final result = await session.sendCliCommand(
      pubKey: widget.contact.publicKey,
      command: task.command,
      prefixToken: _nextPrefixToken(),
    );
    if (!mounted) return false;
    if (!result.ok) return false;
    setState(() => task.apply(result.response ?? ''));
    return true;
  }

  Future<void> _save() async {
    final session = ref.read(meshCoreSessionProvider);
    if (session == null) {
      showErrorSnackBar(context, context.l10n.meshcoreNotConnectedToDevice);
      return;
    }

    final advertText = _advertIntervalController.text.trim();
    if (advertText.isNotEmpty &&
        _validateInt(advertText, _kAdvertIntervalMin, _kAdvertIntervalMax) !=
            null) {
      return; // inline validator already surfaces the message
    }
    final floodText = _floodAdvertIntervalController.text.trim();
    if (floodText.isNotEmpty &&
        _validateInt(
              floodText,
              _kFloodAdvertIntervalMin,
              _kFloodAdvertIntervalMax,
            ) !=
            null) {
      return;
    }

    final commands = <_SetCommand>[];
    final liveName = _nameController.text.trim();
    if (liveName != _initialName && liveName.isNotEmpty) {
      commands.add(
        _SetCommand(
          text: 'set name $liveName',
          onSuccess: () => _initialName = liveName,
        ),
      );
    }
    if (_repeat != _initialRepeat) {
      commands.add(
        _SetCommand(
          text: 'set repeat ${_repeat ? 'on' : 'off'}',
          onSuccess: () => _initialRepeat = _repeat,
        ),
      );
    }
    if (_allowReadOnly != _initialAllowReadOnly) {
      commands.add(
        _SetCommand(
          text: 'set allow.read.only ${_allowReadOnly ? 'on' : 'off'}',
          onSuccess: () => _initialAllowReadOnly = _allowReadOnly,
        ),
      );
    }
    final adv = _parseIntOrNull(advertText);
    if (adv != null && adv != _initialAdvertInterval) {
      commands.add(
        _SetCommand(
          text: 'set advert.interval $adv',
          onSuccess: () => _initialAdvertInterval = adv,
        ),
      );
    }
    final flood = _parseIntOrNull(floodText);
    if (flood != null && flood != _initialFloodAdvertInterval) {
      commands.add(
        _SetCommand(
          text: 'set flood.advert.interval $flood',
          onSuccess: () => _initialFloodAdvertInterval = flood,
        ),
      );
    }

    if (commands.isEmpty) return;

    setState(() => _busy = true);
    unawaited(ref.read(hapticServiceProvider).trigger(HapticType.medium));

    int saved = 0;
    try {
      for (final cmd in commands) {
        final result = await session.sendCliCommand(
          pubKey: widget.contact.publicKey,
          command: cmd.text,
          prefixToken: _nextPrefixToken(),
        );
        if (!mounted) return;
        if (result.ok) {
          saved++;
          cmd.onSuccess();
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        context.l10n.meshcoreRepeaterAdminSettingsSaveFailedSnackbar(
          e.toString(),
        ),
      );
      setState(() => _busy = false);
      return;
    }

    if (!mounted) return;
    setState(() => _busy = false);
    showSuccessSnackBar(
      context,
      context.l10n.meshcoreRepeaterAdminSettingsSavedSnackbar(
        saved,
        commands.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GlassScaffold(
      title: l10n.meshcoreRepeaterAdminSettingsTitle(widget.contact.name),
      actions: [
        IconButton(
          key: const ValueKey('meshcore-repeater-admin-settings-refresh-all'),
          tooltip: l10n.meshcoreRepeaterAdminSettingsRefreshAll,
          onPressed: _busy ? null : _refreshAll,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
        ),
      ],
      slivers: [
        SliverFillRemaining(
          hasScrollBody: true,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              HapticFeedback.selectionClick();
              FocusScope.of(context).unfocus();
            },
            child: Column(
              children: [
                Expanded(child: _buildForm(context, l10n)),
                _buildSaveBar(context, l10n),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context, dynamic l10n) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
      children: [
        SettingsSectionHeader(
          title: l10n.meshcoreRepeaterAdminSettingsSectionIdentity as String,
        ),
        FieldGroupCard(
          child: TextField(
            key: const ValueKey('meshcore-repeater-admin-settings-name'),
            controller: _nameController,
            maxLength: _kNameMaxLength,
            enabled: !_busy,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.meshcoreRepeaterAdminSettingsNameLabel as String,
              helperText:
                  l10n.meshcoreRepeaterAdminSettingsNameHelper as String,
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius8),
              ),
              filled: true,
              fillColor: context.background,
              prefixIcon: Icon(
                Icons.badge_outlined,
                color: context.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacing16),
        SettingsSectionHeader(
          title: l10n.meshcoreRepeaterAdminSettingsSectionBehavior as String,
        ),
        SettingsTile(
          key: const ValueKey('meshcore-repeater-admin-settings-repeat-tile'),
          icon: Icons.repeat_rounded,
          iconColor: AccentColors.green,
          title: l10n.meshcoreRepeaterAdminSettingsRepeatTile as String,
          subtitle:
              l10n.meshcoreRepeaterAdminSettingsRepeatTileSubtitle as String,
          trailing: ThemedSwitch(
            key: const ValueKey('meshcore-repeater-admin-settings-repeat'),
            value: _repeat,
            onChanged: _busy ? null : (v) => setState(() => _repeat = v),
          ),
        ),
        SettingsTile(
          key: const ValueKey(
            'meshcore-repeater-admin-settings-allow-read-only-tile',
          ),
          icon: Icons.visibility_outlined,
          iconColor: AccentColors.blue,
          title: l10n.meshcoreRepeaterAdminSettingsAllowReadOnlyTile as String,
          subtitle:
              l10n.meshcoreRepeaterAdminSettingsAllowReadOnlyTileSubtitle
                  as String,
          trailing: ThemedSwitch(
            key: const ValueKey(
              'meshcore-repeater-admin-settings-allow-read-only',
            ),
            value: _allowReadOnly,
            onChanged: _busy ? null : (v) => setState(() => _allowReadOnly = v),
          ),
        ),
        const SizedBox(height: AppTheme.spacing16),
        SettingsSectionHeader(
          title:
              l10n.meshcoreRepeaterAdminSettingsSectionAdvertisement as String,
        ),
        FieldGroupCard(
          child: Column(
            children: [
              TextField(
                key: const ValueKey(
                  'meshcore-repeater-admin-settings-advert-interval',
                ),
                controller: _advertIntervalController,
                enabled: !_busy,
                maxLength: 5,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText:
                      l10n.meshcoreRepeaterAdminSettingsAdvertIntervalLabel
                          as String,
                  helperText:
                      l10n.meshcoreRepeaterAdminSettingsAdvertIntervalHelper
                          as String,
                  errorText: _validateInt(
                    _advertIntervalController.text,
                    _kAdvertIntervalMin,
                    _kAdvertIntervalMax,
                  ),
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                  ),
                  filled: true,
                  fillColor: context.background,
                  prefixIcon: Icon(
                    Icons.timer_outlined,
                    color: context.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacing16),
              TextField(
                key: const ValueKey(
                  'meshcore-repeater-admin-settings-flood-advert-interval',
                ),
                controller: _floodAdvertIntervalController,
                enabled: !_busy,
                maxLength: 4,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText:
                      l10n.meshcoreRepeaterAdminSettingsFloodAdvertIntervalLabel
                          as String,
                  helperText:
                      l10n.meshcoreRepeaterAdminSettingsFloodAdvertIntervalHelper
                          as String,
                  errorText: _validateInt(
                    _floodAdvertIntervalController.text,
                    _kFloodAdvertIntervalMin,
                    _kFloodAdvertIntervalMax,
                  ),
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                  ),
                  filled: true,
                  fillColor: context.background,
                  prefixIcon: Icon(
                    Icons.broadcast_on_personal_outlined,
                    color: context.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacing24),
      ],
    );
  }

  Widget _buildSaveBar(BuildContext context, dynamic l10n) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacing16,
          AppTheme.spacing8,
          AppTheme.spacing16,
          AppTheme.spacing16,
        ),
        child: PrimaryGradientButton(
          key: const ValueKey('meshcore-repeater-admin-settings-save'),
          label: l10n.meshcoreRepeaterAdminSettingsSaveButton as String,
          icon: Icons.save_rounded,
          enabled: _dirty && !_busy,
          isLoading: _busy,
          onPressed: _save,
        ),
      ),
    );
  }
}

class _RefreshTask {
  final String command;
  final void Function(String reply) apply;
  const _RefreshTask({required this.command, required this.apply});
}

class _SetCommand {
  final String text;
  final VoidCallback onSuccess;
  const _SetCommand({required this.text, required this.onSuccess});
}
