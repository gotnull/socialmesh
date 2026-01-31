// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/command/commands.dart';
import '../core/logging.dart';
import 'connection_providers.dart';

/// Manages lifecycle-aware command execution.
/// Prevents device commands from executing during invalid app states.
class LifecycleCommandManager {
  final Ref _ref;
  bool _isAppActive = true;
  final List<_DeferredCommand> _deferredCommands = [];

  LifecycleCommandManager(this._ref);

  /// Update app lifecycle state
  void setAppActive(bool active) {
    _isAppActive = active;

    if (active) {
      _processDeferredCommands();
    }
  }

  /// Execute a command with lifecycle awareness.
  /// If app is backgrounded, command may be deferred or rejected.
  Future<CommandResult<T>> execute<T>(
    DeviceCommand<T> command, {
    bool deferIfInactive = false,
    Duration? maxDeferDuration,
  }) async {
    // If app is active, execute normally
    if (_isAppActive) {
      return _ref.read(commandDispatcherProvider).dispatch(command);
    }

    // App is inactive
    if (deferIfInactive) {
      // Queue for later execution
      final completer = Completer<CommandResult<T>>();
      _deferredCommands.add(
        _DeferredCommand(
          command: command,
          completer: completer,
          enqueuedAt: DateTime.now(),
          maxAge: maxDeferDuration ?? const Duration(minutes: 5),
        ),
      );

      AppLogging.debug(
        'LifecycleCommandManager: Deferred ${command.runtimeType} (app inactive)',
      );

      return completer.future;
    }

    // Reject command while inactive
    AppLogging.debug(
      'LifecycleCommandManager: Rejected ${command.runtimeType} (app inactive)',
    );
    return CommandFailure(
      CommandError(
        type: CommandErrorType.executionFailed,
        message: 'App is not active',
        userMessage: 'Action cancelled - app is in background',
      ),
    );
  }

  /// Process any deferred commands
  void _processDeferredCommands() {
    if (_deferredCommands.isEmpty) return;

    final now = DateTime.now();
    final expiredCommands = <_DeferredCommand>[];
    final validCommands = <_DeferredCommand>[];

    for (final deferred in _deferredCommands) {
      if (now.difference(deferred.enqueuedAt) > deferred.maxAge) {
        expiredCommands.add(deferred);
      } else {
        validCommands.add(deferred);
      }
    }

    _deferredCommands.clear();

    // Reject expired commands
    for (final expired in expiredCommands) {
      expired.completer.complete(
        CommandFailure(
          CommandError(
            type: CommandErrorType.executionFailed,
            message: 'Command expired',
            userMessage: 'Action expired while app was in background',
          ),
        ),
      );
    }

    // Execute valid commands
    for (final valid in validCommands) {
      _ref
          .read(commandDispatcherProvider)
          .dispatch(valid.command)
          .then(
            (result) =>
                valid.completer.complete(result as CommandResult<Never>),
          );
    }

    if (validCommands.isNotEmpty) {
      AppLogging.debug(
        'LifecycleCommandManager: Processed ${validCommands.length} deferred commands',
      );
    }
  }

  /// Cancel all deferred commands
  void cancelAllDeferred() {
    for (final deferred in _deferredCommands) {
      deferred.completer.complete(
        CommandFailure(
          CommandError(
            type: CommandErrorType.executionFailed,
            message: 'Cancelled',
            userMessage: 'Action cancelled',
          ),
        ),
      );
    }
    _deferredCommands.clear();
  }
}

class _DeferredCommand {
  final DeviceCommand<dynamic> command;
  final Completer<CommandResult<dynamic>> completer;
  final DateTime enqueuedAt;
  final Duration maxAge;

  _DeferredCommand({
    required this.command,
    required this.completer,
    required this.enqueuedAt,
    required this.maxAge,
  });
}

/// Provider for lifecycle command manager
final lifecycleCommandManagerProvider = Provider<LifecycleCommandManager>((
  ref,
) {
  return LifecycleCommandManager(ref);
});

/// Mixin for widgets that need to manage command lifecycle
mixin CommandLifecycleMixin {
  /// Execute a command that should only run when app is active
  Future<CommandResult<T>> executeActiveOnly<T>(
    WidgetRef ref,
    DeviceCommand<T> command,
  ) {
    return ref.read(lifecycleCommandManagerProvider).execute(command);
  }

  /// Execute a command that can be deferred if app is inactive
  Future<CommandResult<T>> executeDeferrable<T>(
    WidgetRef ref,
    DeviceCommand<T> command, {
    Duration? maxDeferDuration,
  }) {
    return ref
        .read(lifecycleCommandManagerProvider)
        .execute(
          command,
          deferIfInactive: true,
          maxDeferDuration: maxDeferDuration,
        );
  }
}

/// Guard that prevents timer/callback execution when device is disconnected
class DeviceConnectionGuard {
  final Ref _ref;

  DeviceConnectionGuard(this._ref);

  /// Execute callback only if device is connected
  Future<T?> executeIfConnected<T>(Future<T> Function() callback) async {
    final isConnected = _ref.read(isDeviceConnectedProvider);
    if (!isConnected) {
      AppLogging.debug(
        'DeviceConnectionGuard: Blocked callback - not connected',
      );
      return null;
    }
    return callback();
  }

  /// Execute callback only if device is connected, otherwise return default
  Future<T> executeOrDefault<T>(
    Future<T> Function() callback,
    T defaultValue,
  ) async {
    final isConnected = _ref.read(isDeviceConnectedProvider);
    if (!isConnected) {
      return defaultValue;
    }
    return callback();
  }

  /// Check connection state synchronously
  bool get isConnected => _ref.read(isDeviceConnectedProvider);
}

/// Provider for device connection guard
final deviceConnectionGuardProvider = Provider<DeviceConnectionGuard>((ref) {
  return DeviceConnectionGuard(ref);
});

/// Extension for easy guard access
extension DeviceConnectionGuardExtension on Ref {
  DeviceConnectionGuard get connectionGuard =>
      read(deviceConnectionGuardProvider);
}

extension WidgetRefConnectionGuard on WidgetRef {
  DeviceConnectionGuard get connectionGuard =>
      read(deviceConnectionGuardProvider);
}
