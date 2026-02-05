// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../../services/config/mesh_firestore_config_service.dart';

/// Beautiful PIN dialog with numeric keypad for admin access.
///
/// PIN hash is fetched from Firebase config for security (not in source code).
/// The PIN is stored as a SHA-256 hash in Firebase.
class AdminPinDialog extends StatefulWidget {
  const AdminPinDialog({super.key, required this.adminPinHash});

  /// The admin PIN hash to verify against (SHA-256 hash from Firebase)
  final String adminPinHash;

  /// Hash a PIN using SHA-256
  static String hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  /// Show PIN verification dialog.
  ///
  /// Returns true if PIN was verified successfully.
  static Future<bool> show(BuildContext context) async {
    // Fetch the admin PIN hash from Firebase config
    String adminPinHash = '';
    try {
      await MeshFirestoreConfigService.instance.initialize();
      final config = await MeshFirestoreConfigService.instance
          .getRemoteConfig();
      adminPinHash = config?.adminPin ?? '';
    } catch (e) {
      // If Firebase fails, deny access
      debugPrint('Failed to fetch admin PIN from Firebase: $e');
    }

    // If no PIN is configured, deny access
    if (adminPinHash.isEmpty) {
      return false;
    }

    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AdminPinDialog(adminPinHash: adminPinHash),
    );
    return result ?? false;
  }

  @override
  State<AdminPinDialog> createState() => _AdminPinDialogState();
}

class _AdminPinDialogState extends State<AdminPinDialog> {
  String _enteredPin = '';
  int _attempts = 0;
  static const int _maxAttempts = 3;
  static const int _pinLength = 7; // Fixed PIN length for dot display
  bool _showError = false;

  /// Check if entered PIN matches the stored hash
  bool _verifyPin() {
    final enteredHash = AdminPinDialog.hashPin(_enteredPin);
    return enteredHash == widget.adminPinHash;
  }

  void _onKeyPress(String key) {
    HapticFeedback.lightImpact();

    if (key == 'backspace') {
      if (_enteredPin.isNotEmpty) {
        setState(() {
          _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
          _showError = false;
        });
      }
    } else if (_enteredPin.length < 10) {
      setState(() {
        _enteredPin += key;
        _showError = false;
      });

      // Auto-submit when PIN reaches expected length
      if (_enteredPin.length == _pinLength) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!mounted) return;
          if (_verifyPin()) {
            Navigator.of(context).pop(true);
          } else {
            _attempts++;
            if (_attempts >= _maxAttempts) {
              Navigator.of(context).pop(false);
              // Note: snackbar shown by caller
            } else {
              HapticFeedback.heavyImpact();
              setState(() {
                _enteredPin = '';
                _showError = true;
              });
            }
          }
        });
      }
    }
  }

  Widget _buildPinDot(int index) {
    final isFilled = index < _enteredPin.length;
    final isError = _showError;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 14,
      height: 14,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isFilled
            ? (isError ? AppTheme.errorRed : Colors.white)
            : Colors.transparent,
        border: Border.all(
          color: isError
              ? AppTheme.errorRed
              : (isFilled ? Colors.white : Colors.white.withAlpha(100)),
          width: 2,
        ),
      ),
    );
  }

  Widget _buildNumberKey(String number) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Center(
          child: SizedBox(
            width: 64,
            height: 64,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _onKeyPress(number),
                customBorder: const CircleBorder(),
                splashColor: Colors.white.withAlpha(30),
                highlightColor: Colors.white.withAlpha(15),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha(10),
                    border: Border.all(
                      color: Colors.white.withAlpha(30),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      number,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w300,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionKey({
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Center(
          child: SizedBox(
            width: 64,
            height: 64,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                customBorder: const CircleBorder(),
                splashColor: Colors.white.withAlpha(30),
                highlightColor: Colors.white.withAlpha(15),
                child: Center(
                  child: Icon(
                    icon,
                    size: 28,
                    color: iconColor ?? Colors.white.withAlpha(180),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 300,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lock icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(10),
              ),
              child: Icon(
                Icons.lock_outline_rounded,
                color: Colors.white.withAlpha(200),
                size: 28,
              ),
            ),
            const SizedBox(height: 16),

            // Title
            const Text(
              'Enter PIN',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Admin access required',
              style: TextStyle(
                color: Colors.white.withAlpha(130),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pinLength,
                (index) => _buildPinDot(index),
              ),
            ),

            // Error message
            SizedBox(
              height: 32,
              child: Center(
                child: _showError
                    ? Text(
                        'Wrong PIN · ${_maxAttempts - _attempts} attempts left',
                        style: TextStyle(
                          color: AppTheme.errorRed,
                          fontSize: 13,
                        ),
                      )
                    : null,
              ),
            ),

            // Number pad
            Row(
              children: [
                _buildNumberKey('1'),
                _buildNumberKey('2'),
                _buildNumberKey('3'),
              ],
            ),
            Row(
              children: [
                _buildNumberKey('4'),
                _buildNumberKey('5'),
                _buildNumberKey('6'),
              ],
            ),
            Row(
              children: [
                _buildNumberKey('7'),
                _buildNumberKey('8'),
                _buildNumberKey('9'),
              ],
            ),
            Row(
              children: [
                // Cancel button
                _buildActionKey(
                  icon: Icons.close_rounded,
                  onTap: () => Navigator.of(context).pop(false),
                  iconColor: Colors.white.withAlpha(100),
                ),
                _buildNumberKey('0'),
                // Backspace button
                _buildActionKey(
                  icon: Icons.backspace_outlined,
                  onTap: () => _onKeyPress('backspace'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
