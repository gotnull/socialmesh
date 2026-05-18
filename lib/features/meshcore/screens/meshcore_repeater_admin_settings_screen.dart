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
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/chip_selector.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/primary_gradient_button.dart';
import '../../../core/widgets/settings_primitives.dart';
import '../../../models/meshcore_contact.dart';
import '../../../providers/meshcore_providers.dart';
import '../../../services/haptic_service.dart';
import '../../../services/meshcore/protocol/meshcore_cli_reply_parser.dart';
import '../../../services/meshcore/protocol/meshcore_messages.dart';
import '../../../services/meshcore/protocol/meshcore_session.dart';
import '../../../services/meshcore/storage/meshcore_admin_auto_clock_sync_store.dart';
import '../../../utils/snackbar.dart';

// Range guards mirror upstream's firmware constraints. Out-of-range
// inputs surface inline validation messages and skip the save.
const int _kAdvertIntervalMin = 0;
const int _kAdvertIntervalMax = 1440; // 24 h
const int _kFloodAdvertIntervalMin = 0;
const int _kFloodAdvertIntervalMax = 168; // 1 week
const int _kNameMaxLength = 32;

// D49-D1: radio + tx + location ranges. Frequency / lat / lon are
// decimals; SF / CR / TX power are integers.
const double _kFrequencyMHzMin = 300;
const double _kFrequencyMHzMax = 2500;
const int _kTxPowerMin = 1;
const int _kTxPowerMax = 30;
const double _kLatMin = -90;
const double _kLatMax = 90;
const double _kLonMin = -180;
const double _kLonMax = 180;

// Canonical LoRa bandwidth values in kHz, mirroring the local-radio
// settings sheet so the admin form's ChipSelector renders the same
// chip set.
const List<double> _kSupportedBandwidthsKhz = [
  7.8,
  10.4,
  15.6,
  20.8,
  31.25,
  41.7,
  62.5,
  125.0,
  250.0,
  500.0,
];

String _formatBwLabel(double khz) {
  if (khz == khz.roundToDouble()) return khz.toStringAsFixed(0);
  return khz.toString();
}

class MeshCoreRepeaterAdminSettingsScreen extends ConsumerStatefulWidget {
  final MeshCoreContact contact;

  // D49-D2: admin password forwarded from the hub. Drives the auto
  // re-login fallback when `sendCliCommand` returns `firmwareTimeout`
  // mid-save. Optional so the screen still functions in tests + when
  // the hub was launched without a captured password.
  final String? password;

  const MeshCoreRepeaterAdminSettingsScreen({
    super.key,
    required this.contact,
    this.password,
  });

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
  // D49-D1: radio + location text controllers.
  final TextEditingController _frequencyController = TextEditingController();
  final TextEditingController _txPowerController = TextEditingController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lonController = TextEditingController();
  // D49-D2: password change controllers. Both stay obscured + empty
  // by default (we never fetch passwords from the firmware).
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _guestPasswordController =
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

  // D49-D1: radio + location state. Bandwidth / SF / CR live as
  // separate fields rather than a combined "radio params" struct so
  // each can dirty independently and the dirty check is a simple
  // value comparison. The save loop folds them back into one combined
  // `set radio` command.
  double? _bandwidthKhz;
  double? _initialBandwidthKhz;
  int? _spreadingFactor;
  int? _initialSpreadingFactor;
  int? _codingRate;
  int? _initialCodingRate;
  double? _initialFrequencyMHz;
  int? _initialTxPowerDbm;
  double? _initialLatitude;
  double? _initialLongitude;

  // D49-D2: privacy mode (wire) + auto-clock-sync (storage-only).
  bool _privacyMode = false;
  bool _initialPrivacyMode = false;
  bool _autoClockSync = false;
  bool _initialAutoClockSync = false;
  MeshCoreAdminAutoClockSyncStore? _autoClockSyncStore;

  bool _busy = false;
  int _prefixCounter = 0;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.contact.name;
    _initialName = widget.contact.name;
    // D49-D2: hydrate the auto-clock-sync toggle from local storage.
    // Fire-and-forget; the screen renders the default (false) until
    // the SharedPreferences instance lands.
    _loadAutoClockSync();
  }

  Future<void> _loadAutoClockSync() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final store = MeshCoreAdminAutoClockSyncStore(prefs);
    final enabled = store.isEnabled(widget.contact.publicKeyHex);
    setState(() {
      _autoClockSyncStore = store;
      _initialAutoClockSync = enabled;
      _autoClockSync = enabled;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _advertIntervalController.dispose();
    _floodAdvertIntervalController.dispose();
    _frequencyController.dispose();
    _txPowerController.dispose();
    _latController.dispose();
    _lonController.dispose();
    _passwordController.dispose();
    _guestPasswordController.dispose();
    super.dispose();
  }

  double? _parseDoubleOrNull(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  String? _validateDouble(String raw, double min, double max) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final v = double.tryParse(t);
    if (v == null) {
      return context.l10n.meshcoreRepeaterAdminSettingsInvalidNumber;
    }
    if (v < min || v > max) {
      return context.l10n.meshcoreRepeaterAdminSettingsOutOfRangeDecimal(
        min,
        max,
      );
    }
    return null;
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
    if (_radioDirty) return true;
    final tx = _parseIntOrNull(_txPowerController.text);
    if (tx != _initialTxPowerDbm) return true;
    final lat = _parseDoubleOrNull(_latController.text);
    if (lat != _initialLatitude) return true;
    final lon = _parseDoubleOrNull(_lonController.text);
    if (lon != _initialLongitude) return true;
    // D49-D2: any non-empty password field is a dirty signal; we
    // never read passwords back from the firmware so there is no
    // "initial value" to compare against.
    if (_passwordController.text.isNotEmpty) return true;
    if (_guestPasswordController.text.isNotEmpty) return true;
    if (_privacyMode != _initialPrivacyMode) return true;
    if (_autoClockSync != _initialAutoClockSync) return true;
    return false;
  }

  // D49-D1: returns true when ANY of the four radio fields differs
  // from its baseline. Save dispatches one combined `set radio`
  // command for the whole tuple, so dirty must be all-or-nothing
  // (we don't half-write radio params).
  bool get _radioDirty {
    final freq = _parseDoubleOrNull(_frequencyController.text);
    if (freq != _initialFrequencyMHz) return true;
    if (_bandwidthKhz != _initialBandwidthKhz) return true;
    if (_spreadingFactor != _initialSpreadingFactor) return true;
    if (_codingRate != _initialCodingRate) return true;
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
        command: 'get name', // lint-allow: hardcoded-string
        apply: (reply) {
          final v = MeshCoreCliReplyParser.extractValue(reply);
          if (v != null) {
            _initialName = v;
            _nameController.text = v;
          }
        },
      ),
      _RefreshTask(
        command: 'get repeat', // lint-allow: hardcoded-string
        apply: (reply) {
          final v = MeshCoreCliReplyParser.extractBool(reply);
          if (v != null) {
            _initialRepeat = v;
            _repeat = v;
          }
        },
      ),
      _RefreshTask(
        command: 'get allow.read.only', // lint-allow: hardcoded-string
        apply: (reply) {
          final v = MeshCoreCliReplyParser.extractBool(reply);
          if (v != null) {
            _initialAllowReadOnly = v;
            _allowReadOnly = v;
          }
        },
      ),
      _RefreshTask(
        command: 'get advert.interval', // lint-allow: hardcoded-string
        apply: (reply) {
          final v = MeshCoreCliReplyParser.extractInt(reply);
          if (v != null) {
            _initialAdvertInterval = v;
            _advertIntervalController.text = v.toString();
          }
        },
      ),
      _RefreshTask(
        command: 'get flood.advert.interval', // lint-allow: hardcoded-string
        apply: (reply) {
          final v = MeshCoreCliReplyParser.extractInt(reply);
          if (v != null) {
            _initialFloodAdvertInterval = v;
            _floodAdvertIntervalController.text = v.toString();
          }
        },
      ),
      // D49-D1: radio params come back as a single CSV reply.
      _RefreshTask(
        command: 'get radio', // lint-allow: hardcoded-string
        apply: (reply) {
          final r = MeshCoreCliReplyParser.parseRadioReply(reply);
          if (r != null) {
            _initialFrequencyMHz = r.freqMHz;
            _frequencyController.text = r.freqMHz.toString();
            _initialBandwidthKhz = r.bandwidthKhz;
            _bandwidthKhz = r.bandwidthKhz;
            _initialSpreadingFactor = r.spreadingFactor;
            _spreadingFactor = r.spreadingFactor;
            _initialCodingRate = r.codingRate;
            _codingRate = r.codingRate;
          }
        },
      ),
      _RefreshTask(
        command: 'get tx', // lint-allow: hardcoded-string
        apply: (reply) {
          final v = MeshCoreCliReplyParser.extractInt(reply);
          if (v != null) {
            _initialTxPowerDbm = v;
            _txPowerController.text = v.toString();
          }
        },
      ),
      _RefreshTask(
        command: 'get lat', // lint-allow: hardcoded-string
        apply: (reply) {
          final v = MeshCoreCliReplyParser.extractDouble(reply);
          if (v != null) {
            _initialLatitude = v;
            _latController.text = v.toString();
          }
        },
      ),
      _RefreshTask(
        command: 'get lon', // lint-allow: hardcoded-string
        apply: (reply) {
          final v = MeshCoreCliReplyParser.extractDouble(reply);
          if (v != null) {
            _initialLongitude = v;
            _lonController.text = v.toString();
          }
        },
      ),
      // D49-D2: privacy mode is the only D49-D2 wire-side field that
      // has a getter; the password / guest-password fields are
      // write-only by design, and auto-clock-sync is storage-only.
      _RefreshTask(
        command: 'get privacy', // lint-allow: hardcoded-string
        apply: (reply) {
          final v = MeshCoreCliReplyParser.extractBool(reply);
          if (v != null) {
            _initialPrivacyMode = v;
            _privacyMode = v;
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
    final result = await _runCliCommand(session, task.command);
    if (!mounted) return false;
    if (!result.ok) return false;
    setState(() => task.apply(result.response ?? ''));
    return true;
  }

  /// D49-D2: route a single CLI call through the re-login-aware
  /// wrapper when a password is available; fall back to the bare
  /// `sendCliCommand` otherwise (tests + future deep-link flows).
  Future<MeshCoreCliResult> _runCliCommand(
    MeshCoreSession session,
    String command,
  ) async {
    final password = widget.password;
    if (password == null || password.isEmpty) {
      return session.sendCliCommand(
        pubKey: widget.contact.publicKey,
        command: command,
        prefixToken: _nextPrefixToken(),
      );
    }
    return session.sendCliCommandWithReLogin(
      pubKey: widget.contact.publicKey,
      password: password,
      command: command,
      prefixToken: _nextPrefixToken(),
      retryPrefixTokenBuilder: _nextPrefixToken,
    );
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
    // D49-D1: inline range checks for the new fields. Bail without
    // sending when any field carries a value outside the firmware's
    // accepted range -- the inline validator already shows the user
    // the specific message; we just refuse the save.
    final freqText = _frequencyController.text.trim();
    if (freqText.isNotEmpty &&
        _validateDouble(freqText, _kFrequencyMHzMin, _kFrequencyMHzMax) !=
            null) {
      return;
    }
    final txText = _txPowerController.text.trim();
    if (txText.isNotEmpty &&
        _validateInt(txText, _kTxPowerMin, _kTxPowerMax) != null) {
      return;
    }
    final latText = _latController.text.trim();
    if (latText.isNotEmpty &&
        _validateDouble(latText, _kLatMin, _kLatMax) != null) {
      return;
    }
    final lonText = _lonController.text.trim();
    if (lonText.isNotEmpty &&
        _validateDouble(lonText, _kLonMin, _kLonMax) != null) {
      return;
    }

    final commands = <_SetCommand>[];
    final liveName = _nameController.text.trim();
    if (liveName != _initialName && liveName.isNotEmpty) {
      commands.add(
        _SetCommand(
          text: 'set name $liveName', // lint-allow: hardcoded-string
          onSuccess: () => _initialName = liveName,
        ),
      );
    }
    if (_repeat != _initialRepeat) {
      commands.add(
        _SetCommand(
          text:
              'set repeat ${_repeat ? 'on' : 'off'}', // lint-allow: hardcoded-string
          onSuccess: () => _initialRepeat = _repeat,
        ),
      );
    }
    if (_allowReadOnly != _initialAllowReadOnly) {
      commands.add(
        _SetCommand(
          text:
              'set allow.read.only ${_allowReadOnly ? 'on' : 'off'}', // lint-allow: hardcoded-string
          onSuccess: () => _initialAllowReadOnly = _allowReadOnly,
        ),
      );
    }
    final adv = _parseIntOrNull(advertText);
    if (adv != null && adv != _initialAdvertInterval) {
      commands.add(
        _SetCommand(
          text: 'set advert.interval $adv', // lint-allow: hardcoded-string
          onSuccess: () => _initialAdvertInterval = adv,
        ),
      );
    }
    final flood = _parseIntOrNull(floodText);
    if (flood != null && flood != _initialFloodAdvertInterval) {
      commands.add(
        _SetCommand(
          text:
              'set flood.advert.interval $flood', // lint-allow: hardcoded-string
          onSuccess: () => _initialFloodAdvertInterval = flood,
        ),
      );
    }
    // D49-D1: radio params save as a single combined command when
    // ANY of the four fields is dirty AND every field carries a
    // value. The firmware applies the set atomically -- there is no
    // partial-update path.
    if (_radioDirty) {
      final freq = _parseDoubleOrNull(freqText);
      final bw = _bandwidthKhz;
      final sf = _spreadingFactor;
      final cr = _codingRate;
      if (freq != null && bw != null && sf != null && cr != null) {
        final bwText = _formatBwLabel(bw);
        commands.add(
          _SetCommand(
            text:
                'set radio $freq $bwText $sf $cr', // lint-allow: hardcoded-string
            onSuccess: () {
              _initialFrequencyMHz = freq;
              _initialBandwidthKhz = bw;
              _initialSpreadingFactor = sf;
              _initialCodingRate = cr;
            },
          ),
        );
      }
    }
    final tx = _parseIntOrNull(txText);
    if (tx != null && tx != _initialTxPowerDbm) {
      commands.add(
        _SetCommand(
          text: 'set tx $tx', // lint-allow: hardcoded-string
          onSuccess: () => _initialTxPowerDbm = tx,
        ),
      );
    }
    final lat = _parseDoubleOrNull(latText);
    if (lat != null && lat != _initialLatitude) {
      commands.add(
        _SetCommand(
          text: 'set lat $lat', // lint-allow: hardcoded-string
          onSuccess: () => _initialLatitude = lat,
        ),
      );
    }
    final lon = _parseDoubleOrNull(lonText);
    if (lon != null && lon != _initialLongitude) {
      commands.add(
        _SetCommand(
          text: 'set lon $lon', // lint-allow: hardcoded-string
          onSuccess: () => _initialLongitude = lon,
        ),
      );
    }
    // D49-D2: password / guest password / privacy mode wire-side
    // setters. Password fields are write-only -- on success we
    // clear the input but DO NOT mirror the value into any state.
    final pwd = _passwordController.text;
    if (pwd.isNotEmpty) {
      commands.add(
        _SetCommand(
          text: 'password $pwd', // lint-allow: hardcoded-string
          onSuccess: () => _passwordController.clear(),
        ),
      );
    }
    final guestPwd = _guestPasswordController.text;
    if (guestPwd.isNotEmpty) {
      commands.add(
        _SetCommand(
          text: 'set guest.password $guestPwd', // lint-allow: hardcoded-string
          onSuccess: () => _guestPasswordController.clear(),
        ),
      );
    }
    if (_privacyMode != _initialPrivacyMode) {
      commands.add(
        _SetCommand(
          text:
              'set privacy ${_privacyMode ? 'on' : 'off'}', // lint-allow: hardcoded-string
          onSuccess: () => _initialPrivacyMode = _privacyMode,
        ),
      );
    }

    // D49-D2: auto-clock-sync is storage-only -- no wire command.
    // Persist the dirty toggle alongside the wire-side commands;
    // counts toward the saved total only if the storage write
    // succeeds, so the user sees an accurate "Saved N of M".
    final autoClockSyncDirty = _autoClockSync != _initialAutoClockSync;

    if (commands.isEmpty && !autoClockSyncDirty) return;

    setState(() => _busy = true);
    unawaited(ref.read(hapticServiceProvider).trigger(HapticType.medium));

    int saved = 0;
    int timedOut = 0;
    int total = commands.length + (autoClockSyncDirty ? 1 : 0);
    try {
      for (final cmd in commands) {
        final result = await _runCliCommand(session, cmd.text);
        if (!mounted) return;
        if (result.ok) {
          saved++;
          cmd.onSuccess();
        } else if (result.firmwareTimeout) {
          timedOut++;
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      // D49-D2: persist the auto-clock-sync toggle (storage-only;
      // no wire side). Counts toward the saved/total tally so the
      // summary snackbar matches what the user expects.
      if (autoClockSyncDirty) {
        final store = _autoClockSyncStore;
        if (store != null) {
          await store.setEnabled(widget.contact.publicKeyHex, _autoClockSync);
          if (!mounted) return;
          saved++;
          _initialAutoClockSync = _autoClockSync;
        }
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
    // D49-D1: if any commands timed out, the admin session may have
    // expired. Surface that explicitly so the user knows to re-login
    // (auto re-login lands in D49-D2 alongside password persistence).
    if (timedOut > 0) {
      showErrorSnackBar(
        context,
        context.l10n.meshcoreRepeaterAdminSettingsSavedWithTimeoutsSnackbar(
          saved,
          total,
        ),
      );
    } else {
      showSuccessSnackBar(
        context,
        context.l10n.meshcoreRepeaterAdminSettingsSavedSnackbar(saved, total),
      );
    }
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
        const SizedBox(height: AppTheme.spacing16),
        SettingsSectionHeader(
          title: l10n.meshcoreRepeaterAdminSettingsSectionRadio as String,
        ),
        FieldGroupCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const ValueKey(
                  'meshcore-repeater-admin-settings-frequency',
                ),
                controller: _frequencyController,
                enabled: !_busy,
                maxLength: 10,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\-0-9.]')),
                ],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText:
                      l10n.meshcoreRepeaterAdminSettingsFrequencyLabel
                          as String,
                  helperText:
                      l10n.meshcoreRepeaterAdminSettingsFrequencyHelper
                          as String,
                  errorText: _validateDouble(
                    _frequencyController.text,
                    _kFrequencyMHzMin,
                    _kFrequencyMHzMax,
                  ),
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                  ),
                  filled: true,
                  fillColor: context.background,
                  prefixIcon: Icon(
                    Icons.podcasts_rounded,
                    color: context.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacing16),
              Text(
                l10n.meshcoreRepeaterAdminSettingsBandwidthLabel as String,
                style: TextStyle(color: context.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: AppTheme.spacing8),
              ChipSelector<double?>(
                key: const ValueKey(
                  'meshcore-repeater-admin-settings-bandwidth',
                ),
                value: _bandwidthKhz,
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _bandwidthKhz = v),
                options: [
                  for (final khz in _kSupportedBandwidthsKhz)
                    ChipOption<double?>(
                      value: khz,
                      // Technical kHz value, not translatable.
                      label: _formatBwLabel(
                        khz,
                      ), // lint-allow: hardcoded-string
                      icon: Icons.tune_rounded,
                      color: context.accentColor,
                    ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing16),
              Text(
                l10n.meshcoreRepeaterAdminSettingsSpreadingFactorLabel
                    as String,
                style: TextStyle(color: context.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: AppTheme.spacing8),
              ChipSelector<int?>(
                key: const ValueKey(
                  'meshcore-repeater-admin-settings-spreading-factor',
                ),
                value: _spreadingFactor,
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _spreadingFactor = v),
                options: [
                  for (var sf = 5; sf <= 12; sf++)
                    ChipOption<int?>(
                      value: sf,
                      // Numeric SF index, not translatable.
                      label: '$sf', // lint-allow: hardcoded-string
                      icon: Icons.signal_cellular_alt_rounded,
                      color: context.accentColor,
                    ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing16),
              Text(
                l10n.meshcoreRepeaterAdminSettingsCodingRateLabel as String,
                style: TextStyle(color: context.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: AppTheme.spacing8),
              ChipSelector<int?>(
                key: const ValueKey(
                  'meshcore-repeater-admin-settings-coding-rate',
                ),
                value: _codingRate,
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _codingRate = v),
                options: [
                  for (var cr = 5; cr <= 8; cr++)
                    ChipOption<int?>(
                      value: cr,
                      // Protocol-level fraction, not translatable.
                      label: '4/$cr', // lint-allow: hardcoded-string
                      icon: Icons.alt_route_rounded,
                      color: context.accentColor,
                    ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing16),
              TextField(
                key: const ValueKey(
                  'meshcore-repeater-admin-settings-tx-power',
                ),
                controller: _txPowerController,
                enabled: !_busy,
                maxLength: 3,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText:
                      l10n.meshcoreRepeaterAdminSettingsTxPowerLabel as String,
                  helperText:
                      l10n.meshcoreRepeaterAdminSettingsTxPowerHelper as String,
                  errorText: _validateInt(
                    _txPowerController.text,
                    _kTxPowerMin,
                    _kTxPowerMax,
                  ),
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                  ),
                  filled: true,
                  fillColor: context.background,
                  prefixIcon: Icon(
                    Icons.flash_on_rounded,
                    color: context.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacing16),
        SettingsSectionHeader(
          title: l10n.meshcoreRepeaterAdminSettingsSectionLocation as String,
        ),
        FieldGroupCard(
          child: Column(
            children: [
              TextField(
                key: const ValueKey(
                  'meshcore-repeater-admin-settings-latitude',
                ),
                controller: _latController,
                enabled: !_busy,
                maxLength: 12,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\-0-9.]')),
                ],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText:
                      l10n.meshcoreRepeaterAdminSettingsLatLabel as String,
                  helperText:
                      l10n.meshcoreRepeaterAdminSettingsLatHelper as String,
                  errorText: _validateDouble(
                    _latController.text,
                    _kLatMin,
                    _kLatMax,
                  ),
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                  ),
                  filled: true,
                  fillColor: context.background,
                  prefixIcon: Icon(
                    Icons.place_outlined,
                    color: context.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacing16),
              TextField(
                key: const ValueKey(
                  'meshcore-repeater-admin-settings-longitude',
                ),
                controller: _lonController,
                enabled: !_busy,
                maxLength: 12,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\-0-9.]')),
                ],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText:
                      l10n.meshcoreRepeaterAdminSettingsLonLabel as String,
                  helperText:
                      l10n.meshcoreRepeaterAdminSettingsLonHelper as String,
                  errorText: _validateDouble(
                    _lonController.text,
                    _kLonMin,
                    _kLonMax,
                  ),
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                  ),
                  filled: true,
                  fillColor: context.background,
                  prefixIcon: Icon(
                    Icons.explore_outlined,
                    color: context.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacing16),
        SettingsSectionHeader(
          title: l10n.meshcoreRepeaterAdminSettingsSectionSecurity as String,
        ),
        FieldGroupCard(
          child: Column(
            children: [
              TextField(
                key: const ValueKey(
                  'meshcore-repeater-admin-settings-password',
                ),
                controller: _passwordController,
                enabled: !_busy,
                obscureText: true,
                maxLength: 64,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText:
                      l10n.meshcoreRepeaterAdminSettingsPasswordLabel as String,
                  helperText:
                      l10n.meshcoreRepeaterAdminSettingsPasswordHelper
                          as String,
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                  ),
                  filled: true,
                  fillColor: context.background,
                  prefixIcon: Icon(
                    Icons.lock_outline_rounded,
                    color: context.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacing16),
              TextField(
                key: const ValueKey(
                  'meshcore-repeater-admin-settings-guest-password',
                ),
                controller: _guestPasswordController,
                enabled: !_busy,
                obscureText: true,
                maxLength: 64,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText:
                      l10n.meshcoreRepeaterAdminSettingsGuestPasswordLabel
                          as String,
                  helperText:
                      l10n.meshcoreRepeaterAdminSettingsGuestPasswordHelper
                          as String,
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                  ),
                  filled: true,
                  fillColor: context.background,
                  prefixIcon: Icon(
                    Icons.lock_person_outlined,
                    color: context.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        SettingsTile(
          key: const ValueKey('meshcore-repeater-admin-settings-privacy-tile'),
          icon: Icons.shield_outlined,
          iconColor: AccentColors.purple,
          title: l10n.meshcoreRepeaterAdminSettingsPrivacyTile as String,
          subtitle:
              l10n.meshcoreRepeaterAdminSettingsPrivacyTileSubtitle as String,
          trailing: ThemedSwitch(
            key: const ValueKey('meshcore-repeater-admin-settings-privacy'),
            value: _privacyMode,
            onChanged: _busy ? null : (v) => setState(() => _privacyMode = v),
          ),
        ),
        SettingsTile(
          key: const ValueKey(
            'meshcore-repeater-admin-settings-auto-clock-sync-tile',
          ),
          icon: Icons.schedule_rounded,
          iconColor: AccentColors.cyan,
          title: l10n.meshcoreRepeaterAdminSettingsAutoClockSyncTile as String,
          subtitle:
              l10n.meshcoreRepeaterAdminSettingsAutoClockSyncTileSubtitle
                  as String,
          trailing: ThemedSwitch(
            key: const ValueKey(
              'meshcore-repeater-admin-settings-auto-clock-sync',
            ),
            value: _autoClockSync,
            onChanged: _busy ? null : (v) => setState(() => _autoClockSync = v),
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
