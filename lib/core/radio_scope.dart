// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Per-radio storage scoping.
//
// Everything the app observes through a radio - mesh nodes, messages,
// telemetry, routes, waypoints, traceroutes - belongs to that radio, not to
// the install. Without a scope the stores are single-tenant: connecting a
// second radio unions its mesh with the first one's leftovers, and the
// device-switch handler can only fix that by deleting the first radio's
// history outright.
//
// Scoping gives every radio its own directory under `<documents>/radios/`
// and its own preference keyspace. Switching radios closes the open stores,
// points the scope at the target radio, and lets the stores reopen against
// that radio's files. Switching back restores what was there.
//
// A scope is identified by the radio's own node number, which survives BLE
// UUID rotation and reaching the same radio over a different transport. The
// node number is not known until the radio reports it, so a first-ever
// connect opens a provisional device-id scope that is promoted (directory
// renamed, preference keys moved) the moment the identity arrives.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logging.dart';

/// A database file that holds radio-observed data and therefore moves with
/// the scope. [legacySubdirectory] is where the file lived before scoping
/// existed, relative to the documents directory, and is only consulted by
/// the one-time migration.
class ScopedDatabaseFile {
  const ScopedDatabaseFile(this.fileName, {this.legacySubdirectory});

  final String fileName;
  final String? legacySubdirectory;
}

/// Databases that hold data observed through one radio.
///
/// Deliberately excluded, because they belong to the user rather than to a
/// radio: `widgets.db`, `automations.db`, `translation_cache.db`,
/// `nodeboard_cache.db`, `operations.db`, `incidents.db`, `tasks.db`.
const List<ScopedDatabaseFile> kRadioScopedDatabases = [
  ScopedDatabaseFile('messages.db'),
  ScopedDatabaseFile('telemetry.db'),
  ScopedDatabaseFile('routes.db'),
  ScopedDatabaseFile('traceroute_history.db'),
  ScopedDatabaseFile('nodedex.db'),
  ScopedDatabaseFile('waypoints.db'),
  ScopedDatabaseFile('tak_events.db'),
  ScopedDatabaseFile('file_transfers.db'),
  ScopedDatabaseFile('mesh_services.db'),
  ScopedDatabaseFile('peer_safety.db'),
  ScopedDatabaseFile('canvas.db'),
  ScopedDatabaseFile('mesh_feed.db', legacySubdirectory: 'databases'),
  ScopedDatabaseFile('mesh_seen_packets.db', legacySubdirectory: 'cache'),
  // Overlay link records are keyed by peer node number, which only means
  // anything inside one mesh. Overlay endpoint identity (`endpoints.db`) and
  // resource transfers (`overlay_transfers.db`) are bound to the peer's
  // persona instead, so they stay unscoped.
  ScopedDatabaseFile('links.db'),
];

/// Preference keys that hold radio-observed data. Values are moved into the
/// scoped keyspace by the one-time migration and follow the scope after it.
const List<String> kRadioScopedPreferenceKeys = [
  'nodes',
  'node_identities',
  'device_favorites',
  'device_ignored',
  'device_unfavorite_tombstones',
];

/// SQLite sidecar suffixes that must travel with a database file.
const List<String> _sidecarSuffixes = ['-journal', '-wal', '-shm'];

/// Scope key used before any radio identity is known, and as the migration
/// target when the install has never recorded a node number.
const String kLegacyRadioScopeKey = 'legacy';

const String _deviceScopePrefix = 'dev-';
const String _nodeScopePrefix = 'node-';

/// Scope key for a radio that has reported its node number.
String radioScopeKeyForNodeNum(int nodeNum) =>
    '$_nodeScopePrefix${(nodeNum & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0')}';

/// Provisional scope key for a radio we have not identified yet. Derived
/// from a hash so BLE UUIDs, USB paths and TCP endpoints all produce a
/// filesystem-safe name of fixed length.
String radioScopeKeyForDeviceId(String deviceId) =>
    '$_deviceScopePrefix${_fnv1a32(deviceId).toRadixString(16).padLeft(8, '0')}';

/// True when [key] is a provisional scope awaiting a node number.
bool isProvisionalRadioScopeKey(String key) =>
    key == kLegacyRadioScopeKey || key.startsWith(_deviceScopePrefix);

int _fnv1a32(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit & 0xFF;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

/// One stored radio profile: its scope key, the label last advertised by
/// the device, and how much disk it occupies.
class RadioScopeInfo {
  const RadioScopeInfo({
    required this.key,
    required this.label,
    required this.sizeBytes,
    required this.isCurrent,
    this.sharesWith,
  });

  final String key;
  final String? label;
  final int sizeBytes;
  final bool isCurrent;

  /// Scope whose data this radio reads and writes instead of its own, or
  /// null when it uses its own. See [RadioScope.shareScope].
  final String? sharesWith;

  /// Node number this scope belongs to, or null for a provisional scope.
  int? get nodeNum => nodeNumForRadioScopeKey(key);
}

/// Node number encoded in a node scope [key], or null for any other key.
int? nodeNumForRadioScopeKey(String key) => key.startsWith(_nodeScopePrefix)
    ? int.tryParse(key.substring(_nodeScopePrefix.length), radix: 16)
    : null;

/// Closes an open store so its files can be moved or reopened elsewhere.
typedef RadioScopedCloser = Future<void> Function();

/// Resolves storage locations for the radio currently in use.
///
/// Process-wide singleton because database paths are resolved deep inside
/// store constructors that have no access to the provider container. The
/// provider layer owns every mutation ([useDevice], [useNodeNum]); stores
/// only ever read [databasePath] and [prefsKey].
class RadioScope {
  RadioScope._();

  static final RadioScope instance = RadioScope._();

  static const String _scopeRootDirName = 'radios';
  static const String _prefsCurrentKey = 'radio_scope_current';
  static const String _prefsDeviceMapKey = 'radio_scope_devices';
  static const String _prefsLabelsKey = 'radio_scope_labels';
  // Radio's own public key (hex) per node scope. Firmware 2.8 derives the
  // node number from the public key, so a radio upgraded to it comes back
  // with a new number and the same key; the key is what proves the two
  // scopes are one radio.
  static const String _prefsPublicKeysKey = 'radio_scope_pubkeys';
  // Scopes that share another scope's data: identity scope -> the scope it
  // reads and writes instead. A radio grouped this way keeps its own
  // identity (label, key, device ids) while its traffic lands in the shared
  // dataset, so the grouping can be undone without moving anything.
  static const String _prefsAliasesKey = 'radio_scope_aliases';
  static const String _prefsMigratedKey = 'radio_scope_migrated';
  static const String _tcpDeviceIdPrefix = 'tcp:';
  // Separates key from value in the flat StringList-backed maps below.
  // A space is safe because keys are device ids and scope keys, neither of
  // which contains one, and it keeps the stored value readable in a plist
  // dump. [_legacyMapSeparator] is the NUL an earlier build wrote; reads
  // accept either so an install written by that build keeps its mappings.
  static const String _mapSeparator = ' ';
  static const String _legacyMapSeparator = '\u0000';

  /// A provisional scope holding nothing but empty schemas can be discarded
  /// when promotion finds an existing scope for the same radio. SQLite pages
  /// are 4 KiB and an empty schema runs to a handful of them.
  static const int _emptyDatabaseBytes = 64 * 1024;

  String _current = kLegacyRadioScopeKey;
  // Identity scope of the radio last bound through [useNodeNum]. Differs
  // from [_current] only while that radio shares another scope's data.
  String? _lastIdentity;
  bool _initialised = false;
  Directory? _rootOverride;
  final Map<Object, RadioScopedCloser> _closers = {};
  final StreamController<String> _changes =
      StreamController<String>.broadcast();

  /// Scope key currently in effect.
  String get currentKey => _current;

  /// Emits the new key every time the scope changes. The provider layer
  /// listens so it can rebuild the stores.
  Stream<String> get changes => _changes.stream;

  /// Loads the persisted scope and, on first run, moves pre-scoping files
  /// into it. Safe to call more than once.
  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;
    final prefs = await SharedPreferences.getInstance();
    _current = prefs.getString(_prefsCurrentKey) ?? kLegacyRadioScopeKey;
    await _migrateUnscopedData(prefs);
    AppLogging.storage('RADIO SCOPE: active scope=$_current');
  }

  /// Absolute path for [fileName] inside the current scope, creating the
  /// scope directory if this is the first write to it.
  Future<String> databasePath(String fileName) async {
    final dir = await _directoryFor(_current, create: true);
    return p.join(dir.path, fileName);
  }

  /// Preference key [base] rewritten into the current scope's keyspace.
  String prefsKey(String base) => _scopedPrefsKey(_current, base);

  /// Reads a scoped preference through [read], falling back to the unscoped
  /// key while the install has not identified a radio yet.
  ///
  /// The fallback covers pre-scoping data that [init]'s migration has not
  /// moved (an early read, or a test that seeds raw keys). It is confined to
  /// the legacy scope on purpose: once a radio has been identified, absent
  /// scoped data means that radio has none, and reading the shared key would
  /// hand it the previous radio's.
  T? readScoped<T>(String base, T? Function(String key) read) {
    final scoped = read(prefsKey(base));
    if (scoped != null) return scoped;
    if (_current != kLegacyRadioScopeKey) return null;
    return read(base);
  }

  /// Registers a store so [_closeOpenStores] can close it before the files
  /// move. [owner] is the store instance itself.
  void registerCloser(Object owner, RadioScopedCloser closer) {
    _closers[owner] = closer;
  }

  void unregisterCloser(Object owner) {
    _closers.remove(owner);
  }

  /// Points the scope at [deviceId]'s radio ahead of connecting to it.
  ///
  /// Uses the node number recorded the last time this device was seen, so a
  /// known radio lands directly in its own scope; a device we have never
  /// connected to gets a provisional scope until it reports its identity.
  ///
  /// [knownNodeNum] is the caller's own answer to "which radio is this?",
  /// used when the device id itself is new but the radio is not - a rotated
  /// BLE UUID, or the same radio reached over another transport. Without it
  /// such a connect would open a provisional scope and show an empty mesh
  /// until the radio reported its identity a second or two later.
  ///
  /// Returns true when the scope changed.
  Future<bool> useDevice({
    required String deviceId,
    String? label,
    int? knownNodeNum,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final known = _readMap(prefs, _prefsDeviceMapKey)[deviceId];
    final identity =
        known ??
        (knownNodeNum != null
            ? radioScopeKeyForNodeNum(knownNodeNum)
            : radioScopeKeyForDeviceId(deviceId));
    if (known == null && knownNodeNum != null) {
      await _rememberMapping(prefs, _prefsDeviceMapKey, deviceId, identity);
    }
    if (label != null) {
      await _rememberLabel(
        prefs,
        identity,
        label,
        synthetic: label == deviceId,
      );
    }
    // Bookkeeping stays with the radio's own identity; storage follows any
    // sharing arrangement it is part of.
    final target = _resolveAlias(prefs, identity);
    if (target == _current) return false;
    AppLogging.storage(
      'RADIO SCOPE: device $deviceId -> scope $target (was $_current)',
    );
    await _applyScope(prefs, target);
    return true;
  }

  /// Binds the running session to the radio's own node number.
  ///
  /// When the session is still on a provisional scope the directory and
  /// preference values recorded so far are promoted into the node scope, so
  /// nothing observed between connect and identity is stranded.
  ///
  /// [ownPublicKey] is the radio's own public key when known. It is
  /// recorded against the node scope and is what identifies a radio whose
  /// node number changed (firmware 2.8 derives the number from the key):
  /// the old scope is folded into the new one so its history follows the
  /// radio. Callers should pass it whenever they have it, including on a
  /// repeat call for the same node number once the key has arrived.
  ///
  /// Returns true when the scope changed.
  Future<bool> useNodeNum(
    int nodeNum, {
    String? deviceId,
    String? label,
    List<int>? ownPublicKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final identity = radioScopeKeyForNodeNum(nodeNum);
    final publicKeyHex = _publicKeyHex(ownPublicKey);
    final previousScopeForDevice = deviceId != null
        ? _readMap(prefs, _prefsDeviceMapKey)[deviceId]
        : null;
    if (deviceId != null) {
      await _rememberMapping(prefs, _prefsDeviceMapKey, deviceId, identity);
    }
    if (label != null) {
      await _rememberLabel(
        prefs,
        identity,
        label,
        synthetic: label == deviceId,
      );
    }
    if (publicKeyHex != null) {
      await _rememberMapping(
        prefs,
        _prefsPublicKeysKey,
        identity,
        publicKeyHex,
      );
    }
    _lastIdentity = identity;

    final target = _resolveAlias(prefs, identity);
    if (target != identity) {
      // This radio shares another radio's data. The arrangement is explicit,
      // so none of the renumbering inference below applies: land on the
      // shared scope, folding in only the provisional directory a fresh
      // connect may have opened in the meantime.
      if (target == _current) return false;
      AppLogging.storage(
        'RADIO SCOPE: $identity shares data with $target - switching',
      );
      await _closeOpenStores();
      if (isProvisionalRadioScopeKey(_current)) {
        await _promoteDirectory(from: _current, to: target);
        await _promotePreferences(prefs, from: _current, to: target);
      }
      await _setCurrent(prefs, target);
      _changes.add(target);
      return true;
    }

    if (target == _current) {
      // Same identity as the active scope. If another node scope carries
      // this radio's key, the radio was renumbered and the connect path
      // already landed on the new number: fold the old scope in now that
      // the key proves they are one radio.
      final donor = _renumberedDonor(prefs, target: target, key: publicKeyHex);
      if (donor == null) return false;
      AppLogging.storage(
        'RADIO SCOPE: $target carries the key recorded for $donor - '
        'renumbered radio, folding $donor into $target',
      );
      await _closeOpenStores();
      await _foldScope(prefs, from: donor, into: target);
      _changes.add(target);
      return true;
    }

    if (isProvisionalRadioScopeKey(_current)) {
      AppLogging.storage(
        'RADIO SCOPE: promoting provisional scope $_current -> $target',
      );
      await _closeOpenStores();
      await _promoteDirectory(from: _current, to: target);
      await _promotePreferences(prefs, from: _current, to: target);
      await _promoteLabel(prefs, from: _current, to: target);
      await _setCurrent(prefs, target);
      _changes.add(target);
      return true;
    }

    // A node scope that disagrees with the reported number is either a
    // device switch that slipped past the connect path, or the same radio
    // under a new number. The key decides when it is known; failing that,
    // a per-radio device id (BLE, not a reusable TCP endpoint) that was
    // mapped to the active scope, with nothing yet filed under the new
    // number, is taken as the same radio.
    if (await _isRenumberedRadio(
      prefs,
      from: _current,
      to: target,
      key: publicKeyHex,
      deviceId: deviceId,
      previousScopeForDevice: previousScopeForDevice,
    )) {
      AppLogging.storage(
        'RADIO SCOPE: radio renumbered $_current -> $target, moving its data',
      );
      await _closeOpenStores();
      await _foldScope(prefs, from: _current, into: target);
      await _setCurrent(prefs, target);
      _changes.add(target);
      return true;
    }

    // Follow the radio rather than keep writing its data into the previous
    // radio's scope.
    AppLogging.storage(
      'RADIO SCOPE: identity $target does not match active scope $_current '
      '— switching without promotion',
    );
    await _applyScope(prefs, target);
    return true;
  }

  /// Every stored radio profile, largest first.
  Future<List<RadioScopeInfo>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final labels = _readMap(prefs, _prefsLabelsKey);
    final aliases = _readMap(prefs, _prefsAliasesKey);
    final root = await _scopeRoot(create: false);
    if (!await root.exists()) return const [];
    final scopes = <RadioScopeInfo>[];
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final key = p.basename(entity.path);
      scopes.add(
        RadioScopeInfo(
          key: key,
          label: labels[key],
          sizeBytes: await _directorySize(entity),
          isCurrent: key == _current,
          sharesWith: aliases[key],
        ),
      );
    }
    scopes.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
    return scopes;
  }

  /// Deletes one stored radio profile: its directory, its preference values
  /// and its label. Refuses to delete the scope currently in use, since its
  /// stores are open.
  Future<bool> deleteScope(String key) async {
    if (key == _current) {
      AppLogging.storage('RADIO SCOPE: refusing to delete active scope $key');
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    final dir = await _directoryFor(key, create: false);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    for (final base in kRadioScopedPreferenceKeys) {
      await prefs.remove(_scopedPrefsKey(key, base));
    }
    final labels = _readMap(prefs, _prefsLabelsKey)..remove(key);
    await _writeMap(prefs, _prefsLabelsKey, labels);
    final devices = _readMap(prefs, _prefsDeviceMapKey)
      ..removeWhere((_, scope) => scope == key);
    await _writeMap(prefs, _prefsDeviceMapKey, devices);
    final keys = _readMap(prefs, _prefsPublicKeysKey)..remove(key);
    await _writeMap(prefs, _prefsPublicKeysKey, keys);
    // A deleted dataset can no longer be shared into; radios that shared it
    // go back to their own. A radio whose own leftover data is deleted keeps
    // its sharing arrangement.
    final aliases = _readMap(prefs, _prefsAliasesKey)
      ..removeWhere((_, into) => into == key);
    await _writeMap(prefs, _prefsAliasesKey, aliases);
    AppLogging.storage('RADIO SCOPE: deleted scope $key');
    return true;
  }

  // ---------------------------------------------------------------------------
  // Shared datasets
  // ---------------------------------------------------------------------------

  /// Makes the radio behind [key] read and write [into]'s data from now on.
  ///
  /// Nothing is moved or merged: [key]'s own dataset stays on disk as a
  /// stored profile until the user deletes it, and [stopSharing] returns
  /// the radio to it. Both scopes must be node scopes. Sharing into a scope
  /// that itself shares another follows the chain, so every arrangement
  /// ends on a scope that owns its data. Returns false when the request is
  /// not applicable.
  Future<bool> shareScope({required String key, required String into}) async {
    if (isProvisionalRadioScopeKey(key) || isProvisionalRadioScopeKey(into)) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    final canonical = _resolveAlias(prefs, into);
    if (canonical == key) return false;

    final aliases = _readMap(prefs, _prefsAliasesKey);
    aliases[key] = canonical;
    // Anyone who shared [key] now shares what [key] shares.
    for (final entry in aliases.entries.toList()) {
      if (entry.value == key) aliases[entry.key] = canonical;
    }
    await _writeMap(prefs, _prefsAliasesKey, aliases);
    AppLogging.storage('RADIO SCOPE: $key now shares data with $canonical');

    // The active session moves when it belongs to a radio now sharing.
    final activeIdentity = _lastIdentity ?? _current;
    final activeTarget = _resolveAlias(prefs, activeIdentity);
    if (activeTarget != _current) {
      await _applyScope(prefs, activeTarget);
    }
    return true;
  }

  /// Ends [key]'s sharing arrangement; the radio uses its own data again.
  /// Returns false when [key] was not sharing.
  Future<bool> stopSharing(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final aliases = _readMap(prefs, _prefsAliasesKey);
    if (aliases.remove(key) == null) return false;
    await _writeMap(prefs, _prefsAliasesKey, aliases);
    AppLogging.storage('RADIO SCOPE: $key uses its own data again');
    if (_lastIdentity == key && _current != key) {
      await _applyScope(prefs, key);
    }
    return true;
  }

  /// Scope [key] stores into: itself, or the scope it shares.
  String _resolveAlias(SharedPreferences prefs, String key) {
    final aliases = _readMap(prefs, _prefsAliasesKey);
    var resolved = key;
    // Arrangements are flattened on write, so one hop is the norm; the loop
    // bound only guards against a hand-edited preference forming a cycle.
    for (var hop = 0; hop < 8; hop++) {
      final next = aliases[resolved];
      if (next == null || next == resolved) break;
      resolved = next;
    }
    return resolved;
  }

  // ---------------------------------------------------------------------------
  // Renumbered radios
  // ---------------------------------------------------------------------------

  String? _publicKeyHex(List<int>? key) {
    if (key == null || key.isEmpty) return null;
    final buffer = StringBuffer();
    for (final byte in key) {
      buffer.write((byte & 0xFF).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  /// Another node scope recorded with the same public key as [target].
  String? _renumberedDonor(
    SharedPreferences prefs, {
    required String target,
    required String? key,
  }) {
    if (key == null) return null;
    for (final entry in _readMap(prefs, _prefsPublicKeysKey).entries) {
      if (entry.key == target) continue;
      if (entry.value == key && !isProvisionalRadioScopeKey(entry.key)) {
        return entry.key;
      }
    }
    return null;
  }

  /// Whether the radio active under [from] is the same radio now reporting
  /// the node number behind [to].
  Future<bool> _isRenumberedRadio(
    SharedPreferences prefs, {
    required String from,
    required String to,
    required String? key,
    required String? deviceId,
    required String? previousScopeForDevice,
  }) async {
    if (isProvisionalRadioScopeKey(from)) return false;
    final recordedKey = _readMap(prefs, _prefsPublicKeysKey)[from];
    if (key != null && recordedKey != null) {
      // Both keys known: they decide, in either direction.
      return key == recordedKey;
    }
    // No key to compare. A TCP endpoint is reused freely across radios, so
    // it says nothing; a BLE or USB identity belongs to one radio. If that
    // identity was filed under [from] and nothing has been filed under
    // [to] yet, the radio kept its identity and changed its number.
    if (deviceId == null || deviceId.startsWith(_tcpDeviceIdPrefix)) {
      return false;
    }
    if (previousScopeForDevice != from) return false;
    return !await _scopeHasData(to);
  }

  Future<bool> _scopeHasData(String key) async {
    final dir = await _directoryFor(key, create: false);
    if (!await dir.exists()) return false;
    return await _directorySize(dir) > _emptyDatabaseBytes;
  }

  /// Moves everything filed under [from] into [into] and forgets [from]:
  /// directory (when [into] holds nothing yet), preference values (where
  /// [into] has none), label, device mappings and recorded key. Stores must
  /// already be closed.
  Future<void> _foldScope(
    SharedPreferences prefs, {
    required String from,
    required String into,
  }) async {
    final target = await _directoryFor(into, create: false);
    if (await target.exists() && !await _scopeHasData(into)) {
      // Only empty schemas from the moments before the identity resolved.
      await target.delete(recursive: true);
    }
    await _promoteDirectory(from: from, to: into);
    await _promotePreferences(prefs, from: from, to: into);
    await _promoteLabel(prefs, from: from, to: into);

    final devices = _readMap(prefs, _prefsDeviceMapKey);
    var devicesChanged = false;
    for (final entry in devices.entries.toList()) {
      if (entry.value == from) {
        devices[entry.key] = into;
        devicesChanged = true;
      }
    }
    if (devicesChanged) {
      await _writeMap(prefs, _prefsDeviceMapKey, devices);
    }

    final keys = _readMap(prefs, _prefsPublicKeysKey);
    final carriedKey = keys.remove(from);
    if (carriedKey != null) {
      keys.putIfAbsent(into, () => carriedKey);
    }
    await _writeMap(prefs, _prefsPublicKeysKey, keys);
  }

  /// Root of the scope tree, for the account-deletion wipe.
  Future<Directory> scopeRootDirectory() => _scopeRoot(create: false);

  /// Test seam: redirects the scope tree at [root] and resets in-memory
  /// state so each test starts from a known scope.
  @visibleForTesting
  void debugSetRoot(Directory? root, {String? currentKey}) {
    _rootOverride = root;
    _current = currentKey ?? kLegacyRadioScopeKey;
    _lastIdentity = null;
    _initialised = false;
    _closers.clear();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<void> _applyScope(SharedPreferences prefs, String target) async {
    await _closeOpenStores();
    await _setCurrent(prefs, target);
    _changes.add(target);
  }

  Future<void> _setCurrent(SharedPreferences prefs, String target) async {
    _current = target;
    await prefs.setString(_prefsCurrentKey, target);
  }

  /// Closes every open scoped store so no SQLite handle survives a directory
  /// move or points at the previous radio's files.
  Future<void> _closeOpenStores() async {
    if (_closers.isEmpty) return;
    final closers = List<RadioScopedCloser>.from(_closers.values);
    _closers.clear();
    for (final close in closers) {
      try {
        await close();
      } catch (e) {
        AppLogging.storage('RADIO SCOPE: store close failed (continuing): $e');
      }
    }
    AppLogging.storage('RADIO SCOPE: closed ${closers.length} open stores');
  }

  Future<Directory> _scopeRoot({required bool create}) async {
    final base = _rootOverride ?? await getApplicationDocumentsDirectory();
    final root = Directory(p.join(base.path, _scopeRootDirName));
    if (create && !await root.exists()) {
      await root.create(recursive: true);
    }
    return root;
  }

  Future<Directory> _directoryFor(String key, {required bool create}) async {
    final root = await _scopeRoot(create: create);
    final dir = Directory(p.join(root.path, key));
    if (create && !await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _scopedPrefsKey(String scope, String base) => 'rs/$scope/$base';

  Future<void> _promoteDirectory({
    required String from,
    required String to,
  }) async {
    final source = await _directoryFor(from, create: false);
    if (!await source.exists()) return;
    final target = await _directoryFor(to, create: false);

    if (!await target.exists()) {
      await source.rename(target.path);
      AppLogging.storage('RADIO SCOPE: moved scope directory $from -> $to');
      return;
    }

    // The radio already has a scope, reached under a different device id.
    // Its files are the ones with history; the provisional directory only
    // covers the window before the identity arrived.
    final size = await _directorySize(source);
    if (size <= _emptyDatabaseBytes) {
      await source.delete(recursive: true);
      AppLogging.storage(
        'RADIO SCOPE: discarded empty provisional directory $from '
        '(scope $to already exists)',
      );
      return;
    }
    AppLogging.storage(
      'RADIO SCOPE: kept provisional directory $from ($size bytes) — scope '
      '$to already exists and its data takes precedence',
    );
  }

  Future<void> _promotePreferences(
    SharedPreferences prefs, {
    required String from,
    required String to,
  }) async {
    for (final base in kRadioScopedPreferenceKeys) {
      final sourceKey = _scopedPrefsKey(from, base);
      final value = prefs.get(sourceKey);
      if (value == null) continue;
      final targetKey = _scopedPrefsKey(to, base);
      if (prefs.get(targetKey) == null) {
        await _writeValue(prefs, targetKey, value);
      }
      await prefs.remove(sourceKey);
    }
  }

  /// Carries the device label recorded against a provisional scope over to
  /// the node scope, so the radio keeps the name it advertised at connect
  /// time once its identity resolves.
  Future<void> _promoteLabel(
    SharedPreferences prefs, {
    required String from,
    required String to,
  }) async {
    final labels = _readMap(prefs, _prefsLabelsKey);
    final carried = labels.remove(from);
    if (carried == null) return;
    labels.putIfAbsent(to, () => carried);
    await _writeMap(prefs, _prefsLabelsKey, labels);
  }

  /// One-time move of pre-scoping files and preference values into a scope.
  ///
  /// The install's own node number picks the target when it is known, so an
  /// upgrade lands its existing history under the radio it came from rather
  /// than in a scope no future connect would ever select.
  Future<void> _migrateUnscopedData(SharedPreferences prefs) async {
    if (prefs.getBool(_prefsMigratedKey) ?? false) return;

    final lastNodeNum = prefs.getInt('last_my_node_num');
    final target = lastNodeNum != null
        ? radioScopeKeyForNodeNum(lastNodeNum)
        : kLegacyRadioScopeKey;

    final base = _rootOverride ?? await getApplicationDocumentsDirectory();

    // Created on the first file that actually moves. A fresh install has
    // nothing to migrate, and an empty directory here would surface as a
    // radio with no data on the Radio Data screen.
    Directory? destination;

    var moved = 0;
    for (final db in kRadioScopedDatabases) {
      final sourceDir = db.legacySubdirectory == null
          ? base.path
          : p.join(base.path, db.legacySubdirectory!);
      for (final suffix in ['', ..._sidecarSuffixes]) {
        final source = File(p.join(sourceDir, '${db.fileName}$suffix'));
        if (!await source.exists()) continue;
        destination ??= await _directoryFor(target, create: true);
        final targetPath = p.join(destination.path, '${db.fileName}$suffix');
        try {
          await source.rename(targetPath);
          moved++;
        } catch (e) {
          // Renaming across filesystems fails; copy instead so the data is
          // never left behind in a location nothing reads any more.
          try {
            await source.copy(targetPath);
            await source.delete();
            moved++;
          } catch (e2) {
            AppLogging.storage(
              'RADIO SCOPE: could not migrate ${db.fileName}$suffix: $e2',
            );
          }
        }
      }
    }

    var movedPrefs = 0;
    for (final key in kRadioScopedPreferenceKeys) {
      final value = prefs.get(key);
      if (value == null) continue;
      await _writeValue(prefs, _scopedPrefsKey(target, key), value);
      await prefs.remove(key);
      movedPrefs++;
    }

    if (lastNodeNum != null) {
      final deviceId = prefs.getString('last_device_id');
      if (deviceId != null) {
        await _rememberMapping(prefs, _prefsDeviceMapKey, deviceId, target);
      }
      final deviceName = prefs.getString('last_device_name');
      if (deviceName != null) {
        await _rememberLabel(prefs, target, deviceName);
      }
    }

    await _setCurrent(prefs, target);
    await prefs.setBool(_prefsMigratedKey, true);
    AppLogging.storage(
      'RADIO SCOPE: migrated $moved database files and $movedPrefs preference '
      'values into scope $target',
    );
  }

  Future<void> _writeValue(
    SharedPreferences prefs,
    String key,
    Object value,
  ) async {
    if (value is String) {
      await prefs.setString(key, value);
    } else if (value is List<String>) {
      await prefs.setStringList(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is List) {
      await prefs.setStringList(key, value.map((e) => '$e').toList());
    }
  }

  Future<int> _directorySize(Directory dir) async {
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {
          // File vanished mid-walk; it contributes nothing.
        }
      }
    }
    return total;
  }

  Map<String, String> _readMap(SharedPreferences prefs, String key) {
    final entries = prefs.getStringList(key) ?? const [];
    final map = <String, String>{};
    for (final entry in entries) {
      var index = entry.indexOf(_mapSeparator);
      if (index <= 0) index = entry.indexOf(_legacyMapSeparator);
      if (index <= 0) continue;
      map[entry.substring(0, index)] = entry.substring(index + 1);
    }
    return map;
  }

  Future<void> _writeMap(
    SharedPreferences prefs,
    String key,
    Map<String, String> map,
  ) async {
    await prefs.setStringList(
      key,
      map.entries.map((e) => '${e.key}$_mapSeparator${e.value}').toList(),
    );
  }

  Future<void> _rememberMapping(
    SharedPreferences prefs,
    String mapKey,
    String key,
    String value,
  ) async {
    final map = _readMap(prefs, mapKey);
    if (map[key] == value) return;
    map[key] = value;
    await _writeMap(prefs, mapKey, map);
  }

  /// Records the name to show for [scope].
  ///
  /// A [synthetic] label is one the connect path derived from the device id
  /// rather than from anything the radio advertised - a saved TCP endpoint
  /// reconnects under `tcp:host:port` as its "name". It seeds an empty slot
  /// but never overwrites a real advertised name, otherwise every
  /// auto-reconnect would downgrade `0864_0864` back to its endpoint.
  Future<void> _rememberLabel(
    SharedPreferences prefs,
    String scope,
    String label, {
    bool synthetic = false,
  }) async {
    if (label.isEmpty) return;
    if (synthetic && _readMap(prefs, _prefsLabelsKey).containsKey(scope)) {
      return;
    }
    await _rememberMapping(prefs, _prefsLabelsKey, scope, label);
  }
}
