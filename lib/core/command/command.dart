// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/connection_providers.dart';
import 'package:socialmesh/l10n/l10n_utils.dart';

/// Result type for command execution
sealed class CommandResult<T> {
  const CommandResult();
}

class CommandSuccess<T> extends CommandResult<T> {
  final T value;
  const CommandSuccess(this.value);
}

class CommandFailure<T> extends CommandResult<T> {
  final CommandError error;
  const CommandFailure(this.error);
}

/// Error returned when a command cannot execute
class CommandError {
  final CommandErrorType type;
  final String message;
  final String? userMessage;
  final FeatureRequirement? unmetRequirement;

  const CommandError({
    required this.type,
    required this.message,
    this.userMessage,
    this.unmetRequirement,
  });

  factory CommandError.deviceNotConnected() {
    final l10n = safeL10n();
    return CommandError(
      type: CommandErrorType.deviceNotConnected,
      message: 'Device not connected', // lint-allow: hardcoded-string
      userMessage: l10n.commandErrorConnectDevice,
      unmetRequirement: FeatureRequirement.deviceConnection,
    );
  }

  factory CommandError.protocolNotReady() {
    final l10n = safeL10n();
    return CommandError(
      type: CommandErrorType.protocolNotReady,
      message: 'Protocol not configured', // lint-allow: hardcoded-string
      userMessage: l10n.commandErrorWaitingConfig,
      unmetRequirement: FeatureRequirement.deviceConnection,
    );
  }

  factory CommandError.networkUnavailable() {
    final l10n = safeL10n();
    return CommandError(
      type: CommandErrorType.networkUnavailable,
      message: 'Network unavailable', // lint-allow: hardcoded-string
      userMessage: l10n.commandErrorCheckInternet,
      unmetRequirement: FeatureRequirement.network,
    );
  }

  factory CommandError.executionFailed(String message) => CommandError(
    type: CommandErrorType.executionFailed,
    message: message,
    userMessage: message,
  );
}

enum CommandErrorType {
  deviceNotConnected,
  protocolNotReady,
  networkUnavailable,
  authenticationRequired,
  executionFailed,
}

/// Base class for all device-dependent commands.
/// Commands declare their requirements and are validated before execution.
abstract class DeviceCommand<T> {
  /// Requirements that must be met for this command to execute
  Set<FeatureRequirement> get requirements;

  /// Execute the command. Called only after requirements are validated.
  Future<T> execute(Ref ref);
}

/// Extension methods for CommandResult
extension CommandResultExtension<T> on CommandResult<T> {
  bool get isSuccess => this is CommandSuccess<T>;
  bool get isFailure => this is CommandFailure<T>;

  T? get valueOrNull => switch (this) {
    CommandSuccess<T>(:final value) => value,
    CommandFailure<T>() => null,
  };

  CommandError? get errorOrNull => switch (this) {
    CommandSuccess<T>() => null,
    CommandFailure<T>(:final error) => error,
  };

  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(CommandError error) onFailure,
  }) {
    return switch (this) {
      CommandSuccess<T>(:final value) => onSuccess(value),
      CommandFailure<T>(:final error) => onFailure(error),
    };
  }
}
