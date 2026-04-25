// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Riverpod 3.x providers for the rns_companion HTTP client.
//
// Three layers:
//   * `rnsCompanionBaseUrlProvider` — overridable URL string
//   * `rnsCompanionClientProvider`  — singleton client built off the URL
//   * data providers — `services`, `pages(destination)`, `page(d, p)`
//
// All data providers are `FutureProvider` (read-only, no caching
// beyond Riverpod's per-arg memoisation). No state mutation, no
// background fetch — refresh by invalidating the provider from a UI
// retry button.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/rns_companion/rns_companion_client.dart';
import '../services/rns_companion/rns_companion_models.dart';

const String _kPrefHost = 'rnsCompanion.host';
const String _kPrefPort = 'rnsCompanion.port';

/// Persisted host + port for the companion endpoint. Defaults to
/// loopback (per the companion's README); user-editable from the
/// settings screen.
typedef RnsCompanionEndpoint = ({String host, int port});

class RnsCompanionEndpointNotifier extends Notifier<RnsCompanionEndpoint> {
  @override
  RnsCompanionEndpoint build() {
    Future.microtask(_loadFromPrefs);
    return (host: kRnsCompanionDefaultHost, port: kRnsCompanionDefaultPort);
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = (
        host: prefs.getString(_kPrefHost) ?? kRnsCompanionDefaultHost,
        port: prefs.getInt(_kPrefPort) ?? kRnsCompanionDefaultPort,
      );
    } catch (_) {
      // Defaults already in state — silent recovery is fine.
    }
  }

  Future<void> setHost(String host) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefHost, host);
    state = (host: host, port: state.port);
  }

  Future<void> setPort(int port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPrefPort, port);
    state = (host: state.host, port: port);
  }

  Future<void> setEndpoint(String host, int port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefHost, host);
    await prefs.setInt(_kPrefPort, port);
    state = (host: host, port: port);
  }
}

final rnsCompanionEndpointProvider =
    NotifierProvider<RnsCompanionEndpointNotifier, RnsCompanionEndpoint>(
      RnsCompanionEndpointNotifier.new,
    );

/// Derived base URL for the companion service. Watches the
/// persisted endpoint; tests can still override this directly with
/// `rnsCompanionBaseUrlProvider.overrideWithValue(...)` to skip the
/// notifier entirely.
final rnsCompanionBaseUrlProvider = Provider<String>((ref) {
  final ep = ref.watch(rnsCompanionEndpointProvider);
  return 'http://${ep.host}:${ep.port}';
});

/// Singleton client. Closes its underlying HTTP client on dispose.
final rnsCompanionClientProvider = Provider<RnsCompanionClient>((ref) {
  final baseUrl = ref.watch(rnsCompanionBaseUrlProvider);
  final client = RnsCompanionClient(baseUri: Uri.parse(baseUrl));
  ref.onDispose(client.close);
  return client;
});

/// Async list of services visible to the companion.
final rnsCompanionServicesProvider =
    FutureProvider<List<RnsCompanionServiceSummary>>((ref) {
      return ref.watch(rnsCompanionClientProvider).listServices();
    });

/// Lightweight reachability probe — calls `/health` with a short
/// timeout so the UI can render a "connected / unreachable" pill
/// without waiting on the heavier `listServices()` call. Refreshes
/// when the user taps the pill or invalidates the provider.
final rnsCompanionHealthProvider = FutureProvider<RnsCompanionHealth>((
  ref,
) async {
  // Build a one-off client with a tighter timeout. We can't use
  // the shared client because its 5 s timeout is a property at
  // construction time — too long for a status pill.
  final baseUrl = ref.watch(rnsCompanionBaseUrlProvider);
  final client = RnsCompanionClient(
    baseUri: Uri.parse(baseUrl),
    timeout: const Duration(seconds: 2),
  );
  ref.onDispose(client.close);
  return client.getHealth();
});

/// Async list of pages for a given service destination.
final rnsCompanionPagesProvider =
    FutureProvider.family<List<RnsCompanionPageSummary>, String>((
      ref,
      destination,
    ) {
      return ref.watch(rnsCompanionClientProvider).listPages(destination);
    });

/// Page-body lookup keyed by `(destination, pageId)`.
final rnsCompanionPageProvider =
    FutureProvider.family<
      RnsCompanionPageBody,
      ({String destination, String pageId})
    >((ref, args) {
      return ref
          .watch(rnsCompanionClientProvider)
          .getPage(args.destination, args.pageId);
    });
