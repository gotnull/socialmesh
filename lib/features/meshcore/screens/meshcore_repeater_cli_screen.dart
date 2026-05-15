// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D49-B: repeater CLI screen.
//
// Reached from the D49-A repeater admin hub. Sends arbitrary text
// commands to the repeater via `MeshCoreSession.sendCliCommand`
// (`CMD_SEND_TXT_MSG 0x02` + `TXT_TYPE_CLI_DATA 0x01`) and renders
// the routed text reply in a monospace scrollback.
//
// State model: in-memory only, mirrors the reference behaviour.
// Closing the screen drops the history; reopening starts fresh.
//
// Async safety: ConsumerStatefulWidget + LifecycleSafeMixin; every
// `await` is followed by a `mounted` guard. The send button is
// debounced via `_inFlightTokens` so two rapid taps cannot collide on
// the same `XX|` correlation token.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animated_empty_state.dart';
import '../../../core/widgets/app_bar_overflow_menu.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../models/meshcore_contact.dart';
import '../../../providers/meshcore_providers.dart';
import '../../../services/haptic_service.dart';
import '../../../services/meshcore/protocol/meshcore_messages.dart';
import '../../../utils/snackbar.dart';
import '../widgets/meshcore_repeater_cli_help_sheet.dart';

class MeshCoreRepeaterCliScreen extends ConsumerStatefulWidget {
  final MeshCoreContact contact;
  const MeshCoreRepeaterCliScreen({super.key, required this.contact});

  @override
  ConsumerState<MeshCoreRepeaterCliScreen> createState() =>
      _MeshCoreRepeaterCliScreenState();
}

class _MeshCoreRepeaterCliScreenState
    extends ConsumerState<MeshCoreRepeaterCliScreen>
    with LifecycleSafeMixin {
  static const int _maxCommandLength = 200;

  final TextEditingController _commandController = TextEditingController();
  final FocusNode _commandFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final List<_CliEntry> _history = [];
  final Set<String> _inFlightTokens = <String>{};
  int _prefixCounter = 0;
  int _commandHistoryIndex = -1;

  @override
  void dispose() {
    _commandController.dispose();
    _commandFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _nextPrefixToken() {
    for (var i = 0; i < 256; i++) {
      final v = _prefixCounter++ & 0xFF;
      final token = '${v.toRadixString(16).padLeft(2, '0').toUpperCase()}|';
      if (!_inFlightTokens.contains(token)) return token;
    }
    return '00|';
  }

  Future<void> _send({String? overrideText}) async {
    final raw = (overrideText ?? _commandController.text).trim();
    if (raw.isEmpty) return;

    final session = ref.read(meshCoreSessionProvider);
    if (session == null) {
      showErrorSnackBar(context, context.l10n.meshcoreNotConnectedToDevice);
      return;
    }

    final token = _nextPrefixToken();
    _inFlightTokens.add(token);

    setState(() {
      _history.add(_CliEntry.command(raw));
      _commandController.clear();
      _commandHistoryIndex = -1;
    });

    unawaited(ref.read(hapticServiceProvider).trigger(HapticType.medium));
    _scheduleScrollToBottom();

    try {
      final result = await session.sendCliCommand(
        pubKey: widget.contact.publicKey,
        command: raw,
        prefixToken: token,
      );
      if (!mounted) return;

      switch (result.outcome) {
        case MeshCoreCliOutcome.ok:
          setState(() {
            _history.add(_CliEntry.response(result.response ?? ''));
          });
          _scheduleScrollToBottom();
        case MeshCoreCliOutcome.firmwareTimeout:
          final seconds = 20;
          showErrorSnackBar(
            context,
            context.l10n.meshcoreRepeaterCliTimeoutSnackbar(seconds),
          );
        case MeshCoreCliOutcome.rateLimited:
          final waitSeconds = ((result.nextSendIn?.inMilliseconds ?? 0) / 1000)
              .ceil();
          showErrorSnackBar(
            context,
            context.l10n.meshcoreRepeaterCliRateLimitedSnackbar(waitSeconds),
          );
      }
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        context.l10n.meshcoreRepeaterCliErrorSnackbar(e.toString()),
      );
    } finally {
      _inFlightTokens.remove(token);
    }
  }

  void _scheduleScrollToBottom() {
    safePostFrame(() {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _navigateHistory({required bool back}) {
    final commands = _history
        .where((e) => e.isCommand)
        .map((e) => e.text)
        .toList(growable: false);
    if (commands.isEmpty) return;
    int next = _commandHistoryIndex;
    if (back) {
      if (next < commands.length - 1) next++;
    } else {
      if (next > 0) {
        next--;
      } else {
        setState(() {
          _commandHistoryIndex = -1;
          _commandController.clear();
        });
        return;
      }
    }
    setState(() {
      _commandHistoryIndex = next;
      _commandController.text = commands[commands.length - 1 - next];
      _commandController.selection = TextSelection.fromPosition(
        TextPosition(offset: _commandController.text.length),
      );
    });
  }

  void _clearHistory() {
    setState(() {
      _history.clear();
      _commandHistoryIndex = -1;
    });
    unawaited(ref.read(hapticServiceProvider).trigger(HapticType.light));
  }

  void _useQuickCommand(String command) {
    unawaited(ref.read(hapticServiceProvider).trigger(HapticType.selection));
    _send(overrideText: command);
  }

  Future<void> _openHelp() async {
    final picked = await showMeshCoreRepeaterCliHelpSheet(context);
    if (!mounted || picked == null) return;
    setState(() {
      _commandController.text = picked;
      _commandController.selection = TextSelection.fromPosition(
        TextPosition(offset: picked.length),
      );
    });
    _commandFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GlassScaffold(
      title: l10n.meshcoreRepeaterCliTitle(widget.contact.name),
      actions: [
        IconButton(
          key: const ValueKey('meshcore-repeater-cli-help'),
          tooltip: l10n.meshcoreRepeaterCliHelpTitle,
          icon: const Icon(Icons.help_outline_rounded),
          onPressed: _openHelp,
        ),
        AppBarOverflowMenu<String>(
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              key: const ValueKey('meshcore-repeater-cli-clear'),
              value: 'clear',
              enabled: _history.isNotEmpty,
              child: Row(
                children: [
                  Icon(
                    Icons.clear_all_rounded,
                    size: 20,
                    color: _history.isEmpty
                        ? context.textTertiary
                        : context.textPrimary,
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Text(l10n.meshcoreRepeaterCliClearHistory),
                ],
              ),
            ),
          ],
          onSelected: (v) {
            if (v == 'clear') _clearHistory();
          },
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
                _QuickCommandsStrip(onPick: _useQuickCommand),
                const Divider(height: 1),
                Expanded(
                  child: _history.isEmpty
                      ? const _CliEmptyState()
                      : _CliScrollback(
                          controller: _scrollController,
                          entries: _history,
                        ),
                ),
                const Divider(height: 1),
                _CommandInput(
                  controller: _commandController,
                  focusNode: _commandFocusNode,
                  maxLength: _maxCommandLength,
                  onSubmit: _send,
                  onHistoryBack: () => _navigateHistory(back: true),
                  onHistoryForward: () => _navigateHistory(back: false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CliEntry {
  final String text;
  final bool isCommand;
  const _CliEntry._(this.text, this.isCommand);
  factory _CliEntry.command(String t) => _CliEntry._(t, true);
  factory _CliEntry.response(String t) => _CliEntry._(t, false);
}

class _CliEmptyState extends StatelessWidget {
  const _CliEmptyState();
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AnimatedEmptyState(
      config: AnimatedEmptyStateConfig(
        icons: const [
          Icons.terminal_rounded,
          Icons.code_rounded,
          Icons.bolt_rounded,
        ],
        taglines: [l10n.meshcoreRepeaterCliEmptyDescription],
        titlePrefix: '',
        titleKeyword: l10n.meshcoreRepeaterCliEmptyTitle,
        titleSuffix: '',
      ),
    );
  }
}

class _QuickCommandsStrip extends StatelessWidget {
  final ValueChanged<String> onPick;
  const _QuickCommandsStrip({required this.onPick});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entries = <_QuickCommand>[
      _QuickCommand('advert', l10n.meshcoreRepeaterCliQuickAdvertise),
      _QuickCommand('get name', l10n.meshcoreRepeaterCliQuickGetName),
      _QuickCommand('get radio', l10n.meshcoreRepeaterCliQuickGetRadio),
      _QuickCommand('get tx', l10n.meshcoreRepeaterCliQuickGetTx),
      _QuickCommand(
        'discover.neighbors',
        l10n.meshcoreRepeaterCliQuickDiscovery,
      ),
      _QuickCommand('neighbors', l10n.meshcoreRepeaterCliQuickNeighbors),
      _QuickCommand('ver', l10n.meshcoreRepeaterCliQuickVersion),
      _QuickCommand('clock', l10n.meshcoreRepeaterCliQuickClock),
      _QuickCommand('clock sync', l10n.meshcoreRepeaterCliQuickClockSync),
    ];

    return SizedBox(
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing16,
          vertical: AppTheme.spacing8,
        ),
        child: Row(
          children: [
            for (var i = 0; i < entries.length; i++) ...[
              if (i > 0) const SizedBox(width: AppTheme.spacing8),
              _QuickCommandChip(
                key: ValueKey(
                  'meshcore-repeater-cli-quick-${entries[i].command}',
                ),
                label: entries[i].label,
                onTap: () => onPick(entries[i].command),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickCommand {
  final String command;
  final String label;
  const _QuickCommand(this.command, this.label);
}

class _QuickCommandChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickCommandChip({
    super.key,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.card,
      borderRadius: BorderRadius.circular(AppTheme.radius8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing12,
            vertical: AppTheme.spacing4,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.play_arrow_rounded,
                size: 16,
                color: context.textSecondary,
              ),
              const SizedBox(width: AppTheme.spacing4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CliScrollback extends StatelessWidget {
  final ScrollController controller;
  final List<_CliEntry> entries;
  const _CliScrollback({required this.controller, required this.entries});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.all(AppTheme.spacing16),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppTheme.spacing12),
      itemBuilder: (_, i) {
        final entry = entries[i];
        final isCmd = entry.isCommand;
        final accent = isCmd ? context.accentColor : context.textSecondary;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing4),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(AppTheme.radius4),
              ),
              child: Icon(
                isCmd ? Icons.chevron_right_rounded : Icons.arrow_back_rounded,
                size: 16,
                color: accent,
              ),
            ),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: SelectableText(
                entry.text,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  color: isCmd ? context.accentColor : context.textPrimary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CommandInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final int maxLength;
  final Future<void> Function() onSubmit;
  final VoidCallback onHistoryBack;
  final VoidCallback onHistoryForward;
  const _CommandInput({
    required this.controller,
    required this.focusNode,
    required this.maxLength,
    required this.onSubmit,
    required this.onHistoryBack,
    required this.onHistoryForward,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing12),
        child: Row(
          children: [
            IconButton(
              key: const ValueKey('meshcore-repeater-cli-history-back'),
              icon: const Icon(Icons.arrow_upward_rounded, size: 20),
              tooltip: l10n.meshcoreRepeaterCliPreviousCommand,
              onPressed: onHistoryBack,
            ),
            IconButton(
              key: const ValueKey('meshcore-repeater-cli-history-forward'),
              icon: const Icon(Icons.arrow_downward_rounded, size: 20),
              tooltip: l10n.meshcoreRepeaterCliNextCommand,
              onPressed: onHistoryForward,
            ),
            const SizedBox(width: AppTheme.spacing8),
            Expanded(
              child: TextField(
                key: const ValueKey('meshcore-repeater-cli-input'),
                controller: controller,
                focusNode: focusNode,
                maxLength: maxLength,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  color: context.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: l10n.meshcoreRepeaterCliPlaceholder,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                  ),
                  filled: true,
                  fillColor: context.background,
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing16,
                    vertical: AppTheme.spacing12,
                  ),
                  prefixIcon: Icon(
                    Icons.chevron_right_rounded,
                    color: context.textSecondary,
                  ),
                ),
                textInputAction: TextInputAction.send,
                inputFormatters: [LengthLimitingTextInputFormatter(maxLength)],
                onSubmitted: (_) {
                  unawaited(onSubmit());
                },
              ),
            ),
            const SizedBox(width: AppTheme.spacing8),
            IconButton.filled(
              key: const ValueKey('meshcore-repeater-cli-send'),
              icon: const Icon(Icons.send_rounded),
              onPressed: () {
                unawaited(onSubmit());
              },
            ),
          ],
        ),
      ),
    );
  }
}
