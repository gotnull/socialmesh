// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/mqtt/mqtt_connection_state.dart';

void main() {
  group('GlobalLayerConnectionState display helpers', () {
    test('all states have non-empty display labels', () {
      for (final state in GlobalLayerConnectionState.values) {
        expect(
          state.displayLabel,
          isNotEmpty,
          reason: '${state.name} has empty displayLabel',
        );
      }
    });

    test('all states have non-empty display descriptions', () {
      for (final state in GlobalLayerConnectionState.values) {
        expect(
          state.displayDescription,
          isNotEmpty,
          reason: '${state.name} has empty displayDescription',
        );
      }
    });

    test('all states have a valid icon', () {
      for (final state in GlobalLayerConnectionState.values) {
        expect(
          state.icon,
          isA<IconData>(),
          reason: '${state.name} does not return a valid IconData',
        );
      }
    });

    test('all states have a non-transparent status color', () {
      for (final state in GlobalLayerConnectionState.values) {
        final color = state.statusColor;
        expect(
          color,
          isA<Color>(),
          reason: '${state.name} does not return a valid Color',
        );
        // Colors should have some opacity to be visible
        expect(
          color.alpha,
          greaterThan(0),
          reason: '${state.name} has fully transparent statusColor',
        );
      }
    });

    test('connected state has green status color', () {
      final color = GlobalLayerConnectionState.connected.statusColor;
      // Should be a green-ish color (high green channel)
      expect(color.green, greaterThan(150));
    });

    test('error state has red status color', () {
      final color = GlobalLayerConnectionState.error.statusColor;
      // Should be a red-ish color (high red channel)
      expect(color.red, greaterThan(200));
    });

    test('disabled state display label is Not Set Up', () {
      expect(GlobalLayerConnectionState.disabled.displayLabel, 'Not Set Up');
    });

    test('connected state display label is Connected', () {
      expect(GlobalLayerConnectionState.connected.displayLabel, 'Connected');
    });

    test('disconnected state display label is Disconnected', () {
      expect(
        GlobalLayerConnectionState.disconnected.displayLabel,
        'Disconnected',
      );
    });

    test('degraded state display label is Degraded', () {
      expect(GlobalLayerConnectionState.degraded.displayLabel, 'Degraded');
    });
  });

  group('GlobalLayerConnectionState classification', () {
    test('transitional states are correctly identified', () {
      expect(GlobalLayerConnectionState.connecting.isTransitional, isTrue);
      expect(GlobalLayerConnectionState.reconnecting.isTransitional, isTrue);
      expect(GlobalLayerConnectionState.disconnecting.isTransitional, isTrue);

      expect(GlobalLayerConnectionState.disabled.isTransitional, isFalse);
      expect(GlobalLayerConnectionState.disconnected.isTransitional, isFalse);
      expect(GlobalLayerConnectionState.connected.isTransitional, isFalse);
      expect(GlobalLayerConnectionState.degraded.isTransitional, isFalse);
      expect(GlobalLayerConnectionState.error.isTransitional, isFalse);
    });

    test('active states are correctly identified', () {
      expect(GlobalLayerConnectionState.connected.isActive, isTrue);
      expect(GlobalLayerConnectionState.degraded.isActive, isTrue);

      expect(GlobalLayerConnectionState.disabled.isActive, isFalse);
      expect(GlobalLayerConnectionState.disconnected.isActive, isFalse);
      expect(GlobalLayerConnectionState.connecting.isActive, isFalse);
      expect(GlobalLayerConnectionState.reconnecting.isActive, isFalse);
      expect(GlobalLayerConnectionState.disconnecting.isActive, isFalse);
      expect(GlobalLayerConnectionState.error.isActive, isFalse);
    });

    test('configured states are correctly identified', () {
      expect(GlobalLayerConnectionState.disabled.isConfigured, isFalse);

      for (final state in GlobalLayerConnectionState.values) {
        if (state != GlobalLayerConnectionState.disabled) {
          expect(
            state.isConfigured,
            isTrue,
            reason: '${state.name} should be considered configured',
          );
        }
      }
    });

    test('user actions are allowed in stable and error states', () {
      expect(GlobalLayerConnectionState.connected.allowsUserActions, isTrue);
      expect(GlobalLayerConnectionState.degraded.allowsUserActions, isTrue);
      expect(GlobalLayerConnectionState.disconnected.allowsUserActions, isTrue);
      expect(GlobalLayerConnectionState.error.allowsUserActions, isTrue);

      // User actions should NOT be allowed in transitional states
      expect(GlobalLayerConnectionState.connecting.allowsUserActions, isFalse);
      expect(
        GlobalLayerConnectionState.reconnecting.allowsUserActions,
        isFalse,
      );
      expect(
        GlobalLayerConnectionState.disconnecting.allowsUserActions,
        isFalse,
      );
      expect(GlobalLayerConnectionState.disabled.allowsUserActions, isFalse);
    });

    test('animation should only happen in transitional states', () {
      for (final state in GlobalLayerConnectionState.values) {
        expect(
          state.shouldAnimate,
          state.isTransitional,
          reason: '${state.name}.shouldAnimate should match isTransitional',
        );
      }
    });
  });

  group('GlobalLayerStateMachine.canTransition', () {
    test('self-transitions are never allowed', () {
      for (final state in GlobalLayerConnectionState.values) {
        expect(
          GlobalLayerStateMachine.canTransition(state, state),
          isFalse,
          reason: '${state.name} -> ${state.name} should be invalid',
        );
      }
    });

    group('feature lifecycle transitions', () {
      test('disabled -> disconnected is valid (setup complete)', () {
        expect(
          GlobalLayerStateMachine.canTransition(
            GlobalLayerConnectionState.disabled,
            GlobalLayerConnectionState.disconnected,
          ),
          isTrue,
        );
      });

      test(
        'disabled -> connected is NOT valid (must go through connecting)',
        () {
          expect(
            GlobalLayerStateMachine.canTransition(
              GlobalLayerConnectionState.disabled,
              GlobalLayerConnectionState.connected,
            ),
            isFalse,
          );
        },
      );

      test(
        'disabled -> connecting is NOT valid (must be disconnected first)',
        () {
          expect(
            GlobalLayerStateMachine.canTransition(
              GlobalLayerConnectionState.disabled,
              GlobalLayerConnectionState.connecting,
            ),
            isFalse,
          );
        },
      );
    });

    group('normal connect flow', () {
      test('disconnected -> connecting is valid', () {
        expect(
          GlobalLayerStateMachine.canTransition(
            GlobalLayerConnectionState.disconnected,
            GlobalLayerConnectionState.connecting,
          ),
          isTrue,
        );
      });

      test('connecting -> connected is valid', () {
        expect(
          GlobalLayerStateMachine.canTransition(
            GlobalLayerConnectionState.connecting,
            GlobalLayerConnectionState.connected,
          ),
          isTrue,
        );
      });

      test('connecting -> error is valid', () {
        expect(
          GlobalLayerStateMachine.canTransition(
            GlobalLayerConnectionState.connecting,
            GlobalLayerConnectionState.error,
          ),
          isTrue,
        );
      });

      test('connecting -> disconnected is valid (user cancel)', () {
        expect(
          GlobalLayerStateMachine.canTransition(
            GlobalLayerConnectionState.connecting,
            GlobalLayerConnectionState.disconnected,
          ),
          isTrue,
        );
      });

      test('connecting -> degraded is NOT valid (must connect first)', () {
        expect(
          GlobalLayerStateMachine.canTransition(
            GlobalLayerConnectionState.connecting,
            GlobalLayerConnectionState.degraded,
          ),
          isFalse,
        );
      });
    });

    group('normal disconnect flow', () {
      test('connected -> disconnecting is valid', () {
        expect(
          GlobalLayerStateMachine.canTransition(
            GlobalLayerConnectionState.connected,
            GlobalLayerConnectionState.disconnecting,
          ),
          isTrue,
        );
      });

      test('disconnecting -> disconnected is valid', () {
        expect(
          GlobalLayerStateMachine.canTransition(
            GlobalLayerConnectionState.disconnecting,
            GlobalLayerConnectionState.disconnected,
          ),
          isTrue,
        );
      });

      test('disconnecting -> connected is NOT valid', () {
        expect(
          GlobalLayerStateMachine.canTransition(
            GlobalLayerConnectionState.disconnecting,
            GlobalLayerConnectionState.connected,
          ),
          isFalse,
        );
      });
    });

    group('degradation transitions', () {
      test('connected -> degraded is valid', () {
        expect(
          GlobalLayerStateMachine.canTransition(
            GlobalLayerConnectionState.connected,
            GlobalLayerConnectionState.degraded,
          ),
          isTrue,
        );
      });

      test('degraded -> connected is valid (recovery)', () {
        expect(
          GlobalLayerStateMachine.canTransition(
            GlobalLayerConnectionState.degraded,
            GlobalLayerConnectionState.connected,
          ),
          isTrue,
        );
      });

      test('degraded -> reconnecting is valid', () {
        expect(
          GlobalLayerStateMachine.canTransition(
            GlobalLayerConnectionState.degraded,
            GlobalLayerConnectionState.reconnecting,
          ),
          isTrue,
        );
      });

      test('degraded -> disconnecting is valid', () {
        expect(
          GlobalLayerStateMachine.canTransition(
            GlobalLayerConnectionState.degraded,
            GlobalLayerConnectionState.disconnecting,
          ),
          isTrue,
        );
      });
    });

    group('reconnection transitions', () {
      test('connected -> reconnecting is valid (unexpected disconnect)', () {
        expect(
          GlobalLayerStateMachine.canTransition(
            GlobalLayerConnectionState.connected,
            GlobalLayerConnectionState.reconnecting,
          ),
          isTrue,
        );
      });

      test('reconnecting -> connected is valid (reconnect success)', () {
        expect(
          GlobalLayerStateMachine.canTransition(
            GlobalLayerConnectionState.reconnecting,
            GlobalLayerConnectionState.connected,
          ),
          isTrue,
        );
      });

      test('reconnecting -> error is valid (reconnect failed)', () {
        expect(
          GlobalLayerStateMachine.canTransition(
            GlobalLayerConnectionState.reconnecting,
            GlobalLayerConnectionState.error,
          ),
          isTrue,
        );
      });

      test('reconnecting -> disconnected is valid (give up)', () {
        expect(
          GlobalLayerStateMachine.canTransition(
            GlobalLayerConnectionState.reconnecting,
            GlobalLayerConnectionState.disconnected,
          ),
          isTrue,
        );
      });

      test('reconnecting -> degraded is NOT valid', () {
        expect(
          GlobalLayerStateMachine.canTransition(
            GlobalLayerConnectionState.reconnecting,
            GlobalLayerConnectionState.degraded,
          ),
          isFalse,
        );
      });
    });

    group('error recovery transitions', () {
      test('error -> disconnected is valid', () {
        expect(
          GlobalLayerStateMachine.canTransition(
            GlobalLayerConnectionState.error,
            GlobalLayerConnectionState.disconnected,
          ),
          isTrue,
        );
      });

      test('error -> connecting is valid (retry)', () {
        expect(
          GlobalLayerStateMachine.canTransition(
            GlobalLayerConnectionState.error,
            GlobalLayerConnectionState.connecting,
          ),
          isTrue,
        );
      });

      test('error -> connected is NOT valid (must go through connecting)', () {
        expect(
          GlobalLayerStateMachine.canTransition(
            GlobalLayerConnectionState.error,
            GlobalLayerConnectionState.connected,
          ),
          isFalse,
        );
      });
    });

    group('feature disable transitions', () {
      test('disconnected -> disabled is valid', () {
        expect(
          GlobalLayerStateMachine.canTransition(
            GlobalLayerConnectionState.disconnected,
            GlobalLayerConnectionState.disabled,
          ),
          isTrue,
        );
      });

      test('connected -> disabled is valid', () {
        expect(
          GlobalLayerStateMachine.canTransition(
            GlobalLayerConnectionState.connected,
            GlobalLayerConnectionState.disabled,
          ),
          isTrue,
        );
      });

      test('degraded -> disabled is valid', () {
        expect(
          GlobalLayerStateMachine.canTransition(
            GlobalLayerConnectionState.degraded,
            GlobalLayerConnectionState.disabled,
          ),
          isTrue,
        );
      });

      test('error -> disabled is valid', () {
        expect(
          GlobalLayerStateMachine.canTransition(
            GlobalLayerConnectionState.error,
            GlobalLayerConnectionState.disabled,
          ),
          isTrue,
        );
      });

      test('connecting -> disabled is NOT valid (must cancel first)', () {
        expect(
          GlobalLayerStateMachine.canTransition(
            GlobalLayerConnectionState.connecting,
            GlobalLayerConnectionState.disabled,
          ),
          isFalse,
        );
      });

      test('reconnecting -> disabled is NOT valid (must stop first)', () {
        expect(
          GlobalLayerStateMachine.canTransition(
            GlobalLayerConnectionState.reconnecting,
            GlobalLayerConnectionState.disabled,
          ),
          isFalse,
        );
      });

      test('disconnecting -> disabled is NOT valid (must complete first)', () {
        expect(
          GlobalLayerStateMachine.canTransition(
            GlobalLayerConnectionState.disconnecting,
            GlobalLayerConnectionState.disabled,
          ),
          isFalse,
        );
      });
    });
  });

  group('GlobalLayerStateMachine.reachableFrom', () {
    test('disabled can only reach disconnected', () {
      final reachable = GlobalLayerStateMachine.reachableFrom(
        GlobalLayerConnectionState.disabled,
      );
      expect(reachable, {GlobalLayerConnectionState.disconnected});
    });

    test('disconnected can reach connecting and disabled', () {
      final reachable = GlobalLayerStateMachine.reachableFrom(
        GlobalLayerConnectionState.disconnected,
      );
      expect(reachable, contains(GlobalLayerConnectionState.connecting));
      expect(reachable, contains(GlobalLayerConnectionState.disabled));
      expect(reachable.length, 2);
    });

    test('connecting can reach connected, error, and disconnected', () {
      final reachable = GlobalLayerStateMachine.reachableFrom(
        GlobalLayerConnectionState.connecting,
      );
      expect(reachable, contains(GlobalLayerConnectionState.connected));
      expect(reachable, contains(GlobalLayerConnectionState.error));
      expect(reachable, contains(GlobalLayerConnectionState.disconnected));
      expect(reachable.length, 3);
    });

    test(
      'connected can reach disconnecting, degraded, reconnecting, and disabled',
      () {
        final reachable = GlobalLayerStateMachine.reachableFrom(
          GlobalLayerConnectionState.connected,
        );
        expect(reachable, contains(GlobalLayerConnectionState.disconnecting));
        expect(reachable, contains(GlobalLayerConnectionState.degraded));
        expect(reachable, contains(GlobalLayerConnectionState.reconnecting));
        expect(reachable, contains(GlobalLayerConnectionState.disabled));
        expect(reachable.length, 4);
      },
    );

    test(
      'degraded can reach connected, reconnecting, disconnecting, and disabled',
      () {
        final reachable = GlobalLayerStateMachine.reachableFrom(
          GlobalLayerConnectionState.degraded,
        );
        expect(reachable, contains(GlobalLayerConnectionState.connected));
        expect(reachable, contains(GlobalLayerConnectionState.reconnecting));
        expect(reachable, contains(GlobalLayerConnectionState.disconnecting));
        expect(reachable, contains(GlobalLayerConnectionState.disabled));
        expect(reachable.length, 4);
      },
    );

    test('reconnecting can reach connected, error, and disconnected', () {
      final reachable = GlobalLayerStateMachine.reachableFrom(
        GlobalLayerConnectionState.reconnecting,
      );
      expect(reachable, contains(GlobalLayerConnectionState.connected));
      expect(reachable, contains(GlobalLayerConnectionState.error));
      expect(reachable, contains(GlobalLayerConnectionState.disconnected));
      expect(reachable.length, 3);
    });

    test('disconnecting can only reach disconnected', () {
      final reachable = GlobalLayerStateMachine.reachableFrom(
        GlobalLayerConnectionState.disconnecting,
      );
      expect(reachable, {GlobalLayerConnectionState.disconnected});
    });

    test('error can reach disconnected, connecting, and disabled', () {
      final reachable = GlobalLayerStateMachine.reachableFrom(
        GlobalLayerConnectionState.error,
      );
      expect(reachable, contains(GlobalLayerConnectionState.disconnected));
      expect(reachable, contains(GlobalLayerConnectionState.connecting));
      expect(reachable, contains(GlobalLayerConnectionState.disabled));
      expect(reachable.length, 3);
    });

    test('every state has at least one reachable target', () {
      for (final state in GlobalLayerConnectionState.values) {
        final reachable = GlobalLayerStateMachine.reachableFrom(state);
        expect(
          reachable,
          isNotEmpty,
          reason: '${state.name} has no reachable states (deadlock)',
        );
      }
    });
  });

  group('GlobalLayerStateMachine.transitionError', () {
    test('returns null for valid transitions', () {
      expect(
        GlobalLayerStateMachine.transitionError(
          GlobalLayerConnectionState.disconnected,
          GlobalLayerConnectionState.connecting,
        ),
        isNull,
      );
    });

    test('returns error message for self-transition', () {
      final error = GlobalLayerStateMachine.transitionError(
        GlobalLayerConnectionState.connected,
        GlobalLayerConnectionState.connected,
      );
      expect(error, isNotNull);
      expect(error, contains('itself'));
    });

    test('returns error message for invalid transition', () {
      final error = GlobalLayerStateMachine.transitionError(
        GlobalLayerConnectionState.disabled,
        GlobalLayerConnectionState.connected,
      );
      expect(error, isNotNull);
      expect(error, contains('Invalid transition'));
      expect(error, contains('disabled'));
      expect(error, contains('connected'));
    });

    test('error message lists valid targets for current state', () {
      final error = GlobalLayerStateMachine.transitionError(
        GlobalLayerConnectionState.disabled,
        GlobalLayerConnectionState.connected,
      );
      expect(error, isNotNull);
      // disabled can only reach disconnected
      expect(error, contains('disconnected'));
    });

    test('returns null for every transition that canTransition accepts', () {
      for (final from in GlobalLayerConnectionState.values) {
        for (final to in GlobalLayerConnectionState.values) {
          if (GlobalLayerStateMachine.canTransition(from, to)) {
            expect(
              GlobalLayerStateMachine.transitionError(from, to),
              isNull,
              reason:
                  'transitionError should return null for valid '
                  '${from.name} -> ${to.name}',
            );
          }
        }
      }
    });

    test(
      'returns non-null for every transition that canTransition rejects',
      () {
        for (final from in GlobalLayerConnectionState.values) {
          for (final to in GlobalLayerConnectionState.values) {
            if (from == to) continue;
            if (!GlobalLayerStateMachine.canTransition(from, to)) {
              expect(
                GlobalLayerStateMachine.transitionError(from, to),
                isNotNull,
                reason:
                    'transitionError should return a message for invalid '
                    '${from.name} -> ${to.name}',
              );
            }
          }
        }
      },
    );
  });

  group('GlobalLayerStateTransition', () {
    test('stores all provided values', () {
      final now = DateTime.now();
      final t = GlobalLayerStateTransition(
        from: GlobalLayerConnectionState.disconnected,
        to: GlobalLayerConnectionState.connecting,
        timestamp: now,
        reason: 'User tapped Connect',
        errorMessage: null,
      );
      expect(t.from, GlobalLayerConnectionState.disconnected);
      expect(t.to, GlobalLayerConnectionState.connecting);
      expect(t.timestamp, now);
      expect(t.reason, 'User tapped Connect');
      expect(t.errorMessage, isNull);
    });

    test('stores error message for error transitions', () {
      final t = GlobalLayerStateTransition(
        from: GlobalLayerConnectionState.connecting,
        to: GlobalLayerConnectionState.error,
        timestamp: DateTime.now(),
        reason: 'Connection failed',
        errorMessage: 'ETIMEDOUT',
      );
      expect(t.errorMessage, 'ETIMEDOUT');
    });

    test('age returns a non-negative duration', () {
      final t = GlobalLayerStateTransition(
        from: GlobalLayerConnectionState.connecting,
        to: GlobalLayerConnectionState.connected,
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      expect(t.age.inMinutes, greaterThanOrEqualTo(5));
    });

    test('toRedactedJson includes from and to', () {
      final t = GlobalLayerStateTransition(
        from: GlobalLayerConnectionState.disconnected,
        to: GlobalLayerConnectionState.connecting,
        timestamp: DateTime.now(),
        reason: 'test',
      );
      final json = t.toRedactedJson();
      expect(json['from'], 'disconnected');
      expect(json['to'], 'connecting');
      expect(json['reason'], 'test');
      expect(json.containsKey('timestamp'), isTrue);
    });

    test('toRedactedJson omits null optional fields', () {
      final t = GlobalLayerStateTransition(
        from: GlobalLayerConnectionState.disconnected,
        to: GlobalLayerConnectionState.connecting,
        timestamp: DateTime.now(),
      );
      final json = t.toRedactedJson();
      expect(json.containsKey('reason'), isFalse);
      expect(json.containsKey('error'), isFalse);
    });

    test('toRedactedJson includes error message when present', () {
      final t = GlobalLayerStateTransition(
        from: GlobalLayerConnectionState.connecting,
        to: GlobalLayerConnectionState.error,
        timestamp: DateTime.now(),
        errorMessage: 'Connection refused',
      );
      final json = t.toRedactedJson();
      expect(json['error'], 'Connection refused');
    });

    test('toString contains state names', () {
      final t = GlobalLayerStateTransition(
        from: GlobalLayerConnectionState.disconnected,
        to: GlobalLayerConnectionState.connecting,
        timestamp: DateTime.now(),
      );
      final str = t.toString();
      expect(str, contains('disconnected'));
      expect(str, contains('connecting'));
    });

    test('toString includes reason when present', () {
      final t = GlobalLayerStateTransition(
        from: GlobalLayerConnectionState.disconnected,
        to: GlobalLayerConnectionState.connecting,
        timestamp: DateTime.now(),
        reason: 'User tapped',
      );
      expect(t.toString(), contains('User tapped'));
    });

    test('toString includes error when present', () {
      final t = GlobalLayerStateTransition(
        from: GlobalLayerConnectionState.connecting,
        to: GlobalLayerConnectionState.error,
        timestamp: DateTime.now(),
        errorMessage: 'Timeout',
      );
      expect(t.toString(), contains('Timeout'));
    });
  });

  group('Complete flow validation', () {
    test('happy path: disabled -> disconnected -> connecting -> connected', () {
      expect(
        GlobalLayerStateMachine.canTransition(
          GlobalLayerConnectionState.disabled,
          GlobalLayerConnectionState.disconnected,
        ),
        isTrue,
      );
      expect(
        GlobalLayerStateMachine.canTransition(
          GlobalLayerConnectionState.disconnected,
          GlobalLayerConnectionState.connecting,
        ),
        isTrue,
      );
      expect(
        GlobalLayerStateMachine.canTransition(
          GlobalLayerConnectionState.connecting,
          GlobalLayerConnectionState.connected,
        ),
        isTrue,
      );
    });

    test('disconnect flow: connected -> disconnecting -> disconnected', () {
      expect(
        GlobalLayerStateMachine.canTransition(
          GlobalLayerConnectionState.connected,
          GlobalLayerConnectionState.disconnecting,
        ),
        isTrue,
      );
      expect(
        GlobalLayerStateMachine.canTransition(
          GlobalLayerConnectionState.disconnecting,
          GlobalLayerConnectionState.disconnected,
        ),
        isTrue,
      );
    });

    test(
      'degradation and recovery: connected -> degraded -> reconnecting -> connected',
      () {
        expect(
          GlobalLayerStateMachine.canTransition(
            GlobalLayerConnectionState.connected,
            GlobalLayerConnectionState.degraded,
          ),
          isTrue,
        );
        expect(
          GlobalLayerStateMachine.canTransition(
            GlobalLayerConnectionState.degraded,
            GlobalLayerConnectionState.reconnecting,
          ),
          isTrue,
        );
        expect(
          GlobalLayerStateMachine.canTransition(
            GlobalLayerConnectionState.reconnecting,
            GlobalLayerConnectionState.connected,
          ),
          isTrue,
        );
      },
    );

    test('direct recovery: degraded -> connected (without reconnecting)', () {
      expect(
        GlobalLayerStateMachine.canTransition(
          GlobalLayerConnectionState.degraded,
          GlobalLayerConnectionState.connected,
        ),
        isTrue,
      );
    });

    test('error recovery flow: error -> connecting -> connected', () {
      expect(
        GlobalLayerStateMachine.canTransition(
          GlobalLayerConnectionState.error,
          GlobalLayerConnectionState.connecting,
        ),
        isTrue,
      );
      expect(
        GlobalLayerStateMachine.canTransition(
          GlobalLayerConnectionState.connecting,
          GlobalLayerConnectionState.connected,
        ),
        isTrue,
      );
    });

    test(
      'unexpected disconnect: connected -> reconnecting -> error -> disconnected',
      () {
        expect(
          GlobalLayerStateMachine.canTransition(
            GlobalLayerConnectionState.connected,
            GlobalLayerConnectionState.reconnecting,
          ),
          isTrue,
        );
        expect(
          GlobalLayerStateMachine.canTransition(
            GlobalLayerConnectionState.reconnecting,
            GlobalLayerConnectionState.error,
          ),
          isTrue,
        );
        expect(
          GlobalLayerStateMachine.canTransition(
            GlobalLayerConnectionState.error,
            GlobalLayerConnectionState.disconnected,
          ),
          isTrue,
        );
      },
    );

    test('reconnect give up: reconnecting -> disconnected', () {
      expect(
        GlobalLayerStateMachine.canTransition(
          GlobalLayerConnectionState.reconnecting,
          GlobalLayerConnectionState.disconnected,
        ),
        isTrue,
      );
    });
  });

  group('State machine invariants', () {
    test('no state is completely unreachable', () {
      // Every state except disabled should be reachable from at least
      // one other state
      for (final target in GlobalLayerConnectionState.values) {
        if (target == GlobalLayerConnectionState.disabled) {
          // disabled is the initial state, reachable from several states
        }
        bool reachable = false;
        for (final from in GlobalLayerConnectionState.values) {
          if (GlobalLayerStateMachine.canTransition(from, target)) {
            reachable = true;
            break;
          }
        }
        expect(
          reachable,
          isTrue,
          reason: '${target.name} is unreachable from any other state',
        );
      }
    });

    test('no state is a dead end (all states can transition somewhere)', () {
      for (final state in GlobalLayerConnectionState.values) {
        final reachable = GlobalLayerStateMachine.reachableFrom(state);
        expect(
          reachable,
          isNotEmpty,
          reason: '${state.name} is a dead end with no outgoing transitions',
        );
      }
    });

    test('disabled is reachable from at least one non-disabled state', () {
      bool canReachDisabled = false;
      for (final from in GlobalLayerConnectionState.values) {
        if (from == GlobalLayerConnectionState.disabled) continue;
        if (GlobalLayerStateMachine.canTransition(
          from,
          GlobalLayerConnectionState.disabled,
        )) {
          canReachDisabled = true;
          break;
        }
      }
      expect(canReachDisabled, isTrue);
    });

    test('connected state is reachable from at least two different states', () {
      int count = 0;
      for (final from in GlobalLayerConnectionState.values) {
        if (GlobalLayerStateMachine.canTransition(
          from,
          GlobalLayerConnectionState.connected,
        )) {
          count++;
        }
      }
      expect(
        count,
        greaterThanOrEqualTo(2),
        reason:
            'connected should be reachable from connecting and reconnecting '
            '(at minimum)',
      );
    });
  });
}
