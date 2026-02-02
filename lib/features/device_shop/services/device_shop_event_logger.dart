// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logging.dart';

/// Event data for device shop analytics
class DeviceShopEvent {
  final String event;
  final DateTime timestamp;
  final Map<String, dynamic> payload;

  const DeviceShopEvent({
    required this.event,
    required this.timestamp,
    required this.payload,
  });

  Map<String, dynamic> toJson() {
    return {
      'event': event,
      'ts': timestamp.toIso8601String(),
      'payload': payload,
    };
  }

  factory DeviceShopEvent.fromJson(Map<String, dynamic> json) {
    return DeviceShopEvent(
      event: json['event'] as String,
      timestamp: DateTime.parse(json['ts'] as String),
      payload: json['payload'] as Map<String, dynamic>,
    );
  }
}

/// Interface for device shop event logging
abstract class DeviceShopEventLogger {
  /// Log a buy now tap with full product and seller context
  Future<void> logBuyNowTap({
    required String sellerId,
    required String sellerName,
    required String productId,
    required String productName,
    required String category,
    required double price,
    required String currency,
    required String destinationUrl,
    required String screen, // 'list' or 'detail'
  });

  /// Log a partner contact tap (website or email)
  Future<void> logPartnerContactTap({
    required String sellerId,
    required String sellerName,
    required String actionType, // 'website' or 'email'
    String? destinationUrl,
  });

  /// Log discount code reveal
  Future<void> logDiscountReveal({
    required String sellerId,
    required String sellerName,
    required String code,
  });

  /// Log discount code copy
  Future<void> logDiscountCopy({
    required String sellerId,
    required String sellerName,
    required String code,
  });

  /// Get all logged events (for inspection)
  Future<List<DeviceShopEvent>> getEvents();

  /// Clear all logged events
  Future<void> clearEvents();
}

/// Local implementation using SharedPreferences
class LocalDeviceShopEventLogger implements DeviceShopEventLogger {
  static const String _storageKey = 'device_shop_events';
  static const int _maxEvents = 1000; // Prevent unbounded growth

  @override
  Future<void> logBuyNowTap({
    required String sellerId,
    required String sellerName,
    required String productId,
    required String productName,
    required String category,
    required double price,
    required String currency,
    required String destinationUrl,
    required String screen,
  }) async {
    await _logEvent('device_shop_buy_now_tap', {
      'seller_id': sellerId,
      'seller_name': sellerName,
      'product_id': productId,
      'product_name': productName,
      'category': category,
      'price': price,
      'currency': currency,
      'destination_url': destinationUrl,
      'screen': screen,
    });
  }

  @override
  Future<void> logPartnerContactTap({
    required String sellerId,
    required String sellerName,
    required String actionType,
    String? destinationUrl,
  }) async {
    await _logEvent('device_shop_partner_contact_tap', {
      'seller_id': sellerId,
      'seller_name': sellerName,
      'action_type': actionType,
      if (destinationUrl != null) 'destination_url': destinationUrl,
    });
  }

  @override
  Future<void> logDiscountReveal({
    required String sellerId,
    required String sellerName,
    required String code,
  }) async {
    await _logEvent('device_shop_discount_reveal', {
      'seller_id': sellerId,
      'seller_name': sellerName,
      'code': code,
    });
  }

  @override
  Future<void> logDiscountCopy({
    required String sellerId,
    required String sellerName,
    required String code,
  }) async {
    await _logEvent('device_shop_discount_copy', {
      'seller_id': sellerId,
      'seller_name': sellerName,
      'code': code,
    });
  }

  @override
  Future<List<DeviceShopEvent>> getEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final eventsJson = prefs.getStringList(_storageKey) ?? [];
      return eventsJson.map((json) {
        final decoded = jsonDecode(json) as Map<String, dynamic>;
        return DeviceShopEvent.fromJson(decoded);
      }).toList();
    } catch (e) {
      AppLogging.app('[DeviceShopEventLogger] Error reading events: $e');
      return [];
    }
  }

  @override
  Future<void> clearEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e) {
      AppLogging.app('[DeviceShopEventLogger] Error clearing events: $e');
    }
  }

  Future<void> _logEvent(String eventName, Map<String, dynamic> payload) async {
    try {
      final event = DeviceShopEvent(
        event: eventName,
        timestamp: DateTime.now(),
        payload: payload,
      );

      final prefs = await SharedPreferences.getInstance();
      final existingEvents = prefs.getStringList(_storageKey) ?? [];

      // Add new event
      existingEvents.add(jsonEncode(event.toJson()));

      // Trim to max size if needed
      if (existingEvents.length > _maxEvents) {
        existingEvents.removeRange(0, existingEvents.length - _maxEvents);
      }

      await prefs.setStringList(_storageKey, existingEvents);

      AppLogging.app(
        '[DeviceShopEventLogger] Logged: $eventName with ${payload.length} fields',
      );
    } catch (e) {
      AppLogging.app('[DeviceShopEventLogger] Error logging event: $e');
    }
  }
}

/// No-op implementation for testing or when logging is disabled
class NoOpDeviceShopEventLogger implements DeviceShopEventLogger {
  @override
  Future<void> logBuyNowTap({
    required String sellerId,
    required String sellerName,
    required String productId,
    required String productName,
    required String category,
    required double price,
    required String currency,
    required String destinationUrl,
    required String screen,
  }) async {}

  @override
  Future<void> logPartnerContactTap({
    required String sellerId,
    required String sellerName,
    required String actionType,
    String? destinationUrl,
  }) async {}

  @override
  Future<void> logDiscountReveal({
    required String sellerId,
    required String sellerName,
    required String code,
  }) async {}

  @override
  Future<void> logDiscountCopy({
    required String sellerId,
    required String sellerName,
    required String code,
  }) async {}

  @override
  Future<List<DeviceShopEvent>> getEvents() async => [];

  @override
  Future<void> clearEvents() async {}
}
