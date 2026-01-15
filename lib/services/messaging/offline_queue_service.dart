import '../../core/logging.dart';
import 'dart:async';
import '../../models/mesh_models.dart';

/// A pending message waiting to be sent when connection is restored
class QueuedMessage {
  final String id;
  final String text;
  final int to;
  final int channel;
  final bool wantAck;
  final DateTime queuedAt;
  int retryCount;

  QueuedMessage({
    required this.id,
    required this.text,
    required this.to,
    required this.channel,
    required this.wantAck,
    DateTime? queuedAt,
    this.retryCount = 0,
  }) : queuedAt = queuedAt ?? DateTime.now();
}

/// Callback for sending a message
typedef SendMessageCallback =
    Future<int> Function({
      required String text,
      required int to,
      required int channel,
      required bool wantAck,
      required String messageId,
    });

/// Callback for updating message status
typedef UpdateMessageCallback =
    void Function(
      String messageId,
      MessageStatus status, {
      int? packetId,
      String? errorMessage,
    });

/// Callback to check if ready to send
typedef ReadyToSendCallback = bool Function();

/// Service to manage offline message queue
/// Queues messages when device is disconnected and sends them when reconnected
class OfflineQueueService {
  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal();

  final List<QueuedMessage> _queue = [];
  bool _isProcessing = false;
  bool _isConnected = false;
  SendMessageCallback? _sendCallback;
  UpdateMessageCallback? _updateCallback;
  ReadyToSendCallback? _readyToSendCallback;

  /// Stream controller for queue updates
  final _queueController = StreamController<List<QueuedMessage>>.broadcast();
  Stream<List<QueuedMessage>> get queueStream => _queueController.stream;

  /// Current queue
  List<QueuedMessage> get queue => List.unmodifiable(_queue);

  /// Number of pending messages
  int get pendingCount => _queue.length;

  /// Whether there are pending messages
  bool get hasPending => _queue.isNotEmpty;

  /// Initialize the service with callbacks
  void initialize({
    required SendMessageCallback sendCallback,
    required UpdateMessageCallback updateCallback,
    ReadyToSendCallback? readyToSendCallback,
  }) {
    _sendCallback = sendCallback;
    _updateCallback = updateCallback;
    _readyToSendCallback = readyToSendCallback;
    AppLogging.messages('📤 OfflineQueueService initialized');
  }

  /// Update connection state - triggers queue processing when connected
  void setConnectionState(bool isConnected) {
    final wasConnected = _isConnected;
    _isConnected = isConnected;

    if (!wasConnected && isConnected && _queue.isNotEmpty) {
      AppLogging.messages(
        '📤 Connection restored, processing ${_queue.length} queued messages',
      );
      _processQueue();
    }
  }

  /// Manually trigger queue processing (e.g., after late initialization)
  void processQueueIfNeeded() {
    if (_isConnected && _queue.isNotEmpty && !_isProcessing) {
      AppLogging.messages(
        '📤 Manual trigger: processing ${_queue.length} queued messages',
      );
      _processQueue();
    }
  }

  /// Queue a message for sending
  void enqueue(QueuedMessage message) {
    _queue.add(message);
    _queueController.add(List.unmodifiable(_queue));
    AppLogging.messages(
      '📤 Message queued: ${message.id}, queue size: ${_queue.length}',
    );

    // Try to send immediately if connected
    if (_isConnected && !_isProcessing) {
      _processQueue();
    }
  }

  /// Remove a message from the queue (e.g., user cancelled)
  void remove(String messageId) {
    _queue.removeWhere((m) => m.id == messageId);
    _queueController.add(List.unmodifiable(_queue));
    AppLogging.messages('📤 Message removed from queue: $messageId');
  }

  /// Clear all queued messages
  void clear() {
    _queue.clear();
    _queueController.add(List.unmodifiable(_queue));
    AppLogging.messages('📤 Queue cleared');
  }

  /// Process the queue - send all pending messages
  Future<void> _processQueue() async {
    if (_isProcessing || !_isConnected || _sendCallback == null) return;

    // Wait for protocol to be ready before processing
    if (_readyToSendCallback != null) {
      var attempts = 0;
      while (!_readyToSendCallback!() && attempts < 50) {
        AppLogging.messages(
          '📤 Waiting for protocol to be ready... (${attempts + 1}/50)',
        );
        await Future.delayed(const Duration(milliseconds: 200));
        attempts++;
        if (!_isConnected) {
          AppLogging.messages('📤 Disconnected while waiting, aborting queue');
          return;
        }
      }
      if (!_readyToSendCallback!()) {
        AppLogging.messages('📤 Protocol not ready after 10s, aborting queue');
        return;
      }
    }

    _isProcessing = true;
    AppLogging.messages('📤 Processing queue of ${_queue.length} messages');

    while (_queue.isNotEmpty && _isConnected) {
      final message = _queue.first;

      try {
        AppLogging.messages('📤 Sending queued message: ${message.id}');

        final packetId = await _sendCallback!(
          text: message.text,
          to: message.to,
          channel: message.channel,
          wantAck: message.wantAck,
          messageId: message.id,
        );

        // Update message status to sent
        _updateCallback?.call(
          message.id,
          MessageStatus.sent,
          packetId: packetId,
        );

        // Remove from queue on success
        _queue.removeAt(0);
        _queueController.add(List.unmodifiable(_queue));

        AppLogging.messages(
          '📤 Queued message sent successfully: ${message.id}',
        );

        // Small delay between messages to avoid overwhelming the device
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        AppLogging.messages(
          '📤 Failed to send queued message: ${message.id} - $e',
        );
        message.retryCount++;

        if (message.retryCount >= 3) {
          // Max retries reached, mark as failed and remove
          _updateCallback?.call(
            message.id,
            MessageStatus.failed,
            errorMessage: 'Max retries reached: $e',
          );
          _queue.removeAt(0);
          _queueController.add(List.unmodifiable(_queue));
        } else {
          // Move to end of queue for retry
          _queue.removeAt(0);
          _queue.add(message);
          _queueController.add(List.unmodifiable(_queue));

          // Wait before retrying
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }

    _isProcessing = false;
    AppLogging.messages(
      '📤 Queue processing complete, ${_queue.length} remaining',
    );
  }

  /// Dispose resources
  void dispose() {
    _queueController.close();
  }
}
