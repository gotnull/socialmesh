import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/navigation.dart';
import '../../utils/snackbar.dart';

class ReportBugSheet extends StatefulWidget {
  const ReportBugSheet({
    super.key,
    required this.initialScreenshot,
    required this.onSubmit,
    required this.onToggleShake,
    required this.isShakeEnabled,
  });

  final Uint8List? initialScreenshot;
  final Future<void> Function({
    required String description,
    required bool includeScreenshot,
    Uint8List? screenshotBytes,
  }) onSubmit;
  final Future<void> Function(bool enabled) onToggleShake;
  final bool isShakeEnabled;

  @override
  State<ReportBugSheet> createState() => _ReportBugSheetState();
}

class _ReportBugSheetState extends State<ReportBugSheet> {
  final _controller = TextEditingController();
  bool _includeScreenshot = true;
  bool _isSending = false;
  late bool _shakeEnabled;

  @override
  void initState() {
    super.initState();
    _includeScreenshot = widget.initialScreenshot != null;
    _shakeEnabled = widget.isShakeEnabled;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      showErrorSnackBar(context, 'Please describe the issue.');
      return;
    }
    setState(() => _isSending = true);
    try {
      await widget.onSubmit(
        description: text,
        includeScreenshot: _includeScreenshot,
        screenshotBytes: widget.initialScreenshot,
      );
      if (!mounted) return;
      navigatorKey.currentState?.pop();
      showGlobalSuccessSnackBar('Bug report sent. תודה!');
    } catch (e) {
      if (!mounted) return;
      showGlobalErrorSnackBar('Failed to send bug report.');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Container(
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Report bug',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: context.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'What happened?',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  maxLines: 6,
                  maxLength: 2000,
                  decoration: InputDecoration(
                    hintText: 'Tell us about the issue you encountered',
                    filled: true,
                    fillColor: context.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: TextStyle(color: context.textPrimary),
                ),
                const SizedBox(height: 8),
                if (widget.initialScreenshot != null) ...[
                  SwitchListTile(
                    value: _includeScreenshot,
                    onChanged:
                        _isSending ? null : (value) {
                          setState(() => _includeScreenshot = value);
                        },
                    title: const Text('Include screenshot in report'),
                    subtitle: const Text('Helps us debug faster'),
                    activeColor: context.accentColor,
                  ),
                  if (_includeScreenshot)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: context.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: context.border.withValues(alpha: 0.3),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          widget.initialScreenshot!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                SwitchListTile(
                  value: _shakeEnabled,
                  onChanged: _isSending
                      ? null
                      : (value) async {
                          await widget.onToggleShake(value);
                          if (mounted) {
                            setState(() => _shakeEnabled = value);
                          }
                        },
                  title: const Text('Shake device to report a bug'),
                  subtitle: const Text('Toggle off to disable'),
                  activeColor: context.accentColor,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSending ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Send'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
