import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/connection_providers.dart';
import '../../providers/app_providers.dart';
import '../../core/logging.dart';
import 'command.dart';

export 'command.dart';

/// Central command dispatcher that validates requirements before execution.
/// This is the authoritative enforcement layer - all device operations MUST
/// flow through this dispatcher.
class CommandDispatcher {
  final Ref _ref;

  CommandDispatcher(this._ref);

  /// Dispatch a command with requirement validation.
  /// Returns CommandFailure if requirements are not met.
  Future<CommandResult<T>> dispatch<T>(DeviceCommand<T> command) async {
    // Check all requirements
    final unmetRequirement = _checkRequirements(command.requirements);

    if (unmetRequirement != null) {
      AppLogging.debug(
        'CommandDispatcher: Blocking ${command.runtimeType} - '
        'unmet requirement: $unmetRequirement',
      );
      return CommandFailure(_errorForRequirement(unmetRequirement));
    }

    // Requirements met, execute command
    try {
      AppLogging.debug('CommandDispatcher: Executing ${command.runtimeType}');
      final result = await command.execute(_ref);
      return CommandSuccess(result);
    } catch (e) {
      AppLogging.debug('CommandDispatcher: ${command.runtimeType} failed: $e');
      return CommandFailure(CommandError.executionFailed(e.toString()));
    }
  }

  /// Check requirements and return first unmet requirement, or null if all met
  FeatureRequirement? _checkRequirements(Set<FeatureRequirement> requirements) {
    for (final requirement in requirements) {
      if (!_isRequirementMet(requirement)) {
        return requirement;
      }
    }
    return null;
  }

  /// Check if a single requirement is met
  bool _isRequirementMet(FeatureRequirement requirement) {
    switch (requirement) {
      case FeatureRequirement.none:
        return true;

      case FeatureRequirement.cached:
        // Cached data is always available if we've ever connected
        return true;

      case FeatureRequirement.network:
        // For now, assume network is available
        // Could add connectivity check here
        return true;

      case FeatureRequirement.deviceConnection:
        final deviceState = _ref.read(deviceConnectionProvider);
        if (!deviceState.isConnected) return false;

        // Also verify protocol is ready
        final protocol = _ref.read(protocolServiceProvider);
        return protocol.myNodeNum != null;
    }
  }

  /// Create appropriate error for unmet requirement
  CommandError _errorForRequirement(FeatureRequirement requirement) {
    switch (requirement) {
      case FeatureRequirement.none:
        return CommandError.executionFailed('Unknown error');
      case FeatureRequirement.cached:
        return CommandError.executionFailed('No cached data available');
      case FeatureRequirement.network:
        return CommandError.networkUnavailable();
      case FeatureRequirement.deviceConnection:
        final deviceState = _ref.read(deviceConnectionProvider);
        if (!deviceState.isConnected) {
          return CommandError.deviceNotConnected();
        }
        return CommandError.protocolNotReady();
    }
  }
}

/// Provider for the command dispatcher
final commandDispatcherProvider = Provider<CommandDispatcher>((ref) {
  return CommandDispatcher(ref);
});

/// Convenience method to dispatch a command from any ref
extension CommandDispatcherExtension on Ref {
  Future<CommandResult<T>> dispatch<T>(DeviceCommand<T> command) {
    return read(commandDispatcherProvider).dispatch(command);
  }
}

/// Convenience method to dispatch a command from WidgetRef
extension WidgetRefCommandDispatcher on WidgetRef {
  Future<CommandResult<T>> dispatch<T>(DeviceCommand<T> command) {
    return read(commandDispatcherProvider).dispatch(command);
  }
}
