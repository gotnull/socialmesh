import 'dart:async';
import 'package:flutter/foundation.dart';
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

/// Callback to check if protocol is ready
typedef ProtocolReadyCallback = bool Function();

/// Service to manage offline message queue
/// Queues messages when device is disconnected and sends them when reconnected
class OfflineQueueService {
  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal();

  final List<QueuedMessage> _queue = [];
  bool _isProcessing = false;
  bool _isWaitingForProtocol = false;
  bool _isConnected = false;
  SendMessageCallback? _sendCallback;
  UpdateMessageCallback? _updateCallback;
  ProtocolReadyCallback? _protocolReadyCallback;

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
    required ProtocolReadyCallback protocolReadyCallback,
  }) {
    _sendCallback = sendCallback;
    _updateCallback = updateCallback;
    _protocolReadyCallback = protocolReadyCallback;
    debugPrint('📤 OfflineQueueService initialized');
  }

  /// Update connection state - triggers queue processing when connected
  void setConnectionState(bool isConnected) {
    final wasConnected = _isConnected;
    _isConnected = isConnected;

    if (!wasConnected && isConnected && _queue.isNotEmpty) {
      debugPrint(
        '📤 Connection restored, will process ${_queue.length} queued messages when protocol ready',
      );
      _waitForProtocolAndProcess();
    }
  }

  /// Wait for protocol to be ready, then process queue
  Future<void> _waitForProtocolAndProcess() async {
    // Prevent multiple concurrent waits
    if (_isWaitingForProtocol || _isProcessing) {
      debugPrint('📤 Already waiting/processing, skipping');
      return;
    }

    if (_protocolReadyCallback == null) {
      debugPrint('📤 No protocol ready callback, processing immediately');
      _processQueue();
      return;
    }

    _isWaitingForProtocol = true;

    // Wait for protocol to be ready (config received) with timeout
    const maxWaitMs = 10000;
    const checkIntervalMs = 100;
    var waited = 0;

    while (waited < maxWaitMs && _isConnected) {
      if (_protocolReadyCallback!()) {
        debugPrint('📤 Protocol ready after ${waited}ms, processing queue');
        _isWaitingForProtocol = false;
        _processQueue();
        return;
      }
      await Future.delayed(const Duration(milliseconds: checkIntervalMs));
      waited += checkIntervalMs;
    }

    _isWaitingForProtocol = false;

    if (!_isConnected) {
      debugPrint('📤 Disconnected while waiting for protocol, aborting');
      return;
    }

    debugPrint('📤 Timeout waiting for protocol, processing queue anyway');
    _processQueue();
  }

  /// Queue a message for sending
  void enqueue(QueuedMessage message) {
    _queue.add(message);
    _queueController.add(List.unmodifiable(_queue));
    debugPrint(
      '📤 Message queued: ${message.id}, queue size: ${_queue.length}',
    );

    // Try to send immediately if connected and protocol ready
    if (_isConnected && !_isProcessing) {
      _waitForProtocolAndProcess();
    }
  }

  /// Remove a message from the queue (e.g., user cancelled)
  void remove(String messageId) {
    _queue.removeWhere((m) => m.id == messageId);
    _queueController.add(List.unmodifiable(_queue));
    debugPrint('📤 Message removed from queue: $messageId');
  }

  /// Clear all queued messages
  void clear() {
    _queue.clear();
    _queueController.add(List.unmodifiable(_queue));
    debugPrint('📤 Queue cleared');
  }

  /// Process the queue - send all pending messages
  Future<void> _processQueue() async {
    if (_isProcessing || !_isConnected || _sendCallback == null) return;

    _isProcessing = true;
    debugPrint('📤 Processing queue of ${_queue.length} messages');

    while (_queue.isNotEmpty && _isConnected) {
      final message = _queue.first;

      try {
        debugPrint(
          '📤 Sending queued message: ${message.id}, wantAck: ${message.wantAck}',
        );

        final packetId = await _sendCallback!(
          text: message.text,
          to: message.to,
          channel: message.channel,
          wantAck: message.wantAck,
          messageId: message.id,
        );

        // Only update status to sent for messages WITHOUT ACK (like channel messages)
        // Messages with ACK will have their status managed by the delivery tracking system
        if (!message.wantAck) {
          _updateCallback?.call(
            message.id,
            MessageStatus.sent,
            packetId: packetId,
          );
        }

        // Remove from queue on success
        _queue.removeAt(0);
        _queueController.add(List.unmodifiable(_queue));

        debugPrint('📤 Queued message sent successfully: ${message.id}');

        // Small delay between messages to avoid overwhelming the device
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        debugPrint('📤 Failed to send queued message: ${message.id} - $e');
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
    debugPrint('📤 Queue processing complete, ${_queue.length} remaining');
  }

  /// Dispose resources
  void dispose() {
    _queueController.close();
  }
}
