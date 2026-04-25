// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/info_table.dart';
import '../../core/widgets/section_header.dart';
import '../../providers/app_providers.dart';
import '../../providers/reticulum_providers.dart';
import '../../services/protocol/reticulum/reticulum_capture_replay.dart';
import '../../services/protocol/reticulum/reticulum_fragment_event.dart';
import '../../utils/snackbar.dart';

class ReticulumReplayScreen extends ConsumerStatefulWidget {
  const ReticulumReplayScreen({super.key});

  @override
  ConsumerState<ReticulumReplayScreen> createState() =>
      _ReticulumReplayScreenState();
}

class _ReticulumReplayScreenState extends ConsumerState<ReticulumReplayScreen>
    with LifecycleSafeMixin {
  List<File> _captureFiles = const [];
  File? _selectedFile;
  ReticulumReplayMode _mode = ReticulumReplayMode.realtime;
  double _speedMultiplier = 10;
  ReticulumCaptureReplay? _engine;
  StreamSubscription<ReticulumFragmentEvent>? _engineSub;
  int _emittedCount = 0;
  bool _isRunning = false;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadFiles);
  }

  @override
  void dispose() {
    _engineSub?.cancel();
    _engine?.stop();
    super.dispose();
  }

  Future<void> _loadFiles() async {
    final writer = ref.read(reticulumCaptureWriterProvider);
    final files = await writer.listCaptureFiles();
    safeSetState(() {
      _captureFiles = files;
    });
  }

  Future<void> _selectFile(File file) async {
    HapticFeedback.selectionClick();
    await _disposeEngine();
    final engine = ReticulumCaptureReplay(
      file: file,
      mode: _mode,
      speedMultiplier: _speedMultiplier,
    );
    try {
      await engine.load();
    } on UnsupportedCaptureVersion {
      if (!mounted) return;
      showErrorSnackBar(context, context.l10n.reticulumReplayInvalidFile);
      return;
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        '${context.l10n.reticulumReplayLoadError}: $e',
      );
      return;
    }
    // Attach the engine→live-stream forwarder up front so both timed
    // playback and step-mode emissions are mirrored into the protocol
    // service's broadcast stream. Without this every replayed event
    // would be visible only to the replay screen's progress UI.
    //
    // The same listener also resets the running/paused flags when the
    // engine reaches the last record so the controls revert from
    // Pause→Start without requiring a manual tap on Stop.
    final protocol = ref.read(protocolServiceProvider);
    final sub = engine.stream.listen((event) {
      protocol.injectReplayedReticulumFragment(event);
      if (!mounted) return;
      safeSetState(() {
        _emittedCount = engine.currentIndex;
        if (engine.isDone) {
          _isRunning = false;
          _isPaused = false;
        }
      });
    });
    safeSetState(() {
      _selectedFile = file;
      _engine = engine;
      _engineSub = sub;
      _emittedCount = 0;
      _isRunning = false;
      _isPaused = false;
    });
  }

  Future<void> _disposeEngine() async {
    await _engineSub?.cancel();
    _engineSub = null;
    await _engine?.stop();
    _engine = null;
  }

  void _setMode(ReticulumReplayMode mode) {
    HapticFeedback.selectionClick();
    safeSetState(() {
      _mode = mode;
    });
    if (_selectedFile != null) {
      // Re-create engine with new mode.
      unawaited(_selectFile(_selectedFile!));
    }
  }

  Future<void> _start() async {
    final engine = _engine;
    if (engine == null) return;
    HapticFeedback.selectionClick();
    // Subscription that forwards engine events into the live broadcast
    // stream is already attached in `_selectFile` so it covers both
    // timed and step modes.
    await engine.start();
    safeSetState(() {
      _isRunning = true;
      _isPaused = false;
    });
  }

  void _pause() {
    final engine = _engine;
    if (engine == null) return;
    HapticFeedback.selectionClick();
    engine.pause();
    safeSetState(() => _isPaused = true);
  }

  void _resume() {
    final engine = _engine;
    if (engine == null) return;
    HapticFeedback.selectionClick();
    engine.resume();
    safeSetState(() => _isPaused = false);
  }

  Future<void> _stop() async {
    HapticFeedback.selectionClick();
    await _disposeEngine();
    safeSetState(() {
      _isRunning = false;
      _isPaused = false;
      _emittedCount = 0;
    });
  }

  void _stepOnce() {
    final engine = _engine;
    if (engine == null) return;
    HapticFeedback.selectionClick();
    engine.stepOne();
    safeSetState(() {
      _emittedCount = engine.currentIndex;
    });
  }

  String _basename(File f) {
    final segs = f.path.split(Platform.pathSeparator);
    return segs.isEmpty ? f.path : segs.last;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: GlassScaffold(
        title: context.l10n.reticulumReplayTitle,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
            sliver: SliverList.list(
              children: [
                _buildFileSection(context),
                const SizedBox(height: AppTheme.spacing16),
                _buildModeSection(context),
                if (_selectedFile != null) ...[
                  const SizedBox(height: AppTheme.spacing16),
                  _buildControlsSection(context),
                  const SizedBox(height: AppTheme.spacing16),
                  _buildStatusSection(context),
                ],
                const SizedBox(height: AppTheme.spacing24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: context.l10n.reticulumReplaySectionFile),
          if (_captureFiles.isEmpty)
            InfoTable(
              rows: [
                InfoTableRow(
                  label: context.l10n.reticulumReplayPickFile,
                  value: context.l10n.reticulumReplayNoFilesAvailable,
                  icon: Icons.folder_off_outlined,
                ),
              ],
            )
          else
            Container(
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                border: Border.all(color: context.border),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < _captureFiles.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: context.border),
                    InkWell(
                      onTap: () => _selectFile(_captureFiles[i]),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacing16,
                          vertical: AppTheme.spacing12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.description_outlined,
                              color:
                                  _selectedFile?.path == _captureFiles[i].path
                                  ? context.accentColor
                                  : context.textSecondary,
                            ),
                            const SizedBox(width: AppTheme.spacing12),
                            Expanded(
                              child: Text(
                                _basename(_captureFiles[i]),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: context.textPrimary,
                                ),
                              ),
                            ),
                            if (_selectedFile?.path == _captureFiles[i].path)
                              Icon(
                                Icons.check_circle,
                                color: context.accentColor,
                                size: 18,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModeSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: context.l10n.reticulumReplaySectionMode),
          Container(
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(AppTheme.radius12),
              border: Border.all(color: context.border),
            ),
            child: Column(
              children: [
                _modeRow(
                  context,
                  ReticulumReplayMode.realtime,
                  context.l10n.reticulumReplayModeRealtime,
                ),
                Divider(height: 1, color: context.border),
                _modeRow(
                  context,
                  ReticulumReplayMode.accelerated,
                  context.l10n.reticulumReplayModeAccelerated,
                ),
                Divider(height: 1, color: context.border),
                _modeRow(
                  context,
                  ReticulumReplayMode.step,
                  context.l10n.reticulumReplayModeStep,
                ),
              ],
            ),
          ),
          if (_mode == ReticulumReplayMode.accelerated) ...[
            const SizedBox(height: AppTheme.spacing12),
            Row(
              children: [
                Text(
                  '${context.l10n.reticulumReplaySpeedLabel}: '
                  '${_speedMultiplier.toStringAsFixed(0)}x',
                  style: TextStyle(fontSize: 13, color: context.textSecondary),
                ),
                Expanded(
                  child: Slider(
                    value: _speedMultiplier,
                    min: 1,
                    max: 1000,
                    onChanged: (v) => safeSetState(
                      () => _speedMultiplier = v.roundToDouble(),
                    ),
                    onChangeEnd: (_) {
                      if (_selectedFile != null) {
                        unawaited(_selectFile(_selectedFile!));
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _modeRow(
    BuildContext context,
    ReticulumReplayMode mode,
    String label,
  ) {
    final selected = _mode == mode;
    return InkWell(
      onTap: _isRunning ? null : () => _setMode(mode),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing16,
          vertical: AppTheme.spacing12,
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? context.accentColor : context.textSecondary,
              size: 20,
            ),
            const SizedBox(width: AppTheme.spacing12),
            Text(
              label,
              style: TextStyle(fontSize: 14, color: context.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsSection(BuildContext context) {
    final engine = _engine;
    if (engine == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: context.l10n.reticulumReplaySectionControls),
          if (_mode == ReticulumReplayMode.step)
            _ControlButton(
              icon: Icons.skip_next,
              label: context.l10n.reticulumReplayStep,
              onPressed: _stepOnce,
            )
          else if (!_isRunning)
            _ControlButton(
              icon: Icons.play_arrow,
              label: context.l10n.reticulumReplayStart,
              onPressed: _start,
            )
          else if (_isPaused)
            _ControlButton(
              icon: Icons.play_arrow,
              label: context.l10n.reticulumReplayResume,
              onPressed: _resume,
            )
          else
            _ControlButton(
              icon: Icons.pause,
              label: context.l10n.reticulumReplayPause,
              onPressed: _pause,
            ),
          if (_isRunning) ...[
            const SizedBox(height: AppTheme.spacing8),
            _ControlButton(
              icon: Icons.stop,
              label: context.l10n.reticulumReplayStop,
              onPressed: _stop,
              isSecondary: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusSection(BuildContext context) {
    final engine = _engine;
    if (engine == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: context.l10n.reticulumReplaySectionStatus),
          InfoTable(
            rows: [
              InfoTableRow(
                label: context.l10n.reticulumReplayFileLabel,
                value: _basename(_selectedFile!),
                icon: Icons.description_outlined,
              ),
              InfoTableRow(
                label: context.l10n.reticulumReplayRecords,
                value: '${engine.totalRecords}',
                icon: Icons.list_outlined,
              ),
              InfoTableRow(
                label: context.l10n.reticulumReplayProgress(
                  _emittedCount,
                  engine.totalRecords,
                ),
                value: engine.totalRecords == 0
                    ? '0%'
                    : '${((_emittedCount / engine.totalRecords) * 100).toStringAsFixed(0)}%',
                icon: Icons.linear_scale,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isSecondary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isSecondary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            vertical: AppTheme.spacing12,
            horizontal: AppTheme.spacing16,
          ),
          decoration: BoxDecoration(
            color: isSecondary ? context.card : null,
            border: isSecondary ? Border.all(color: context.border) : null,
            gradient: isSecondary
                ? null
                : LinearGradient(
                    colors: [
                      context.accentColor,
                      context.accentColor.withValues(alpha: 0.7),
                    ],
                  ),
            borderRadius: BorderRadius.circular(AppTheme.radius12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSecondary ? context.textPrimary : Colors.white,
                size: 20,
              ),
              const SizedBox(width: AppTheme.spacing8),
              Text(
                label,
                style: TextStyle(
                  color: isSecondary ? context.textPrimary : Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
