import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets/animations.dart';
import '../../core/navigation.dart';
import '../../utils/snackbar.dart';
import 'package:cloud_functions/cloud_functions.dart';

class ReportBugSheet extends StatefulWidget {
  const ReportBugSheet({
    super.key,
    required this.initialScreenshot,
    required this.onSubmit,
    required this.onToggleShake,
    required this.isShakeEnabled,
  });

  final Uint8List? initialScreenshot;
  final Future<Map<String, dynamic>?> Function({
    required String description,
    required bool includeScreenshot,
    Uint8List? screenshotBytes,
  })
  onSubmit;
  final Future<void> Function(bool enabled) onToggleShake;
  final bool isShakeEnabled;

  @override
  State<ReportBugSheet> createState() => _ReportBugSheetState();
}

class ReportBugPromptSheet extends StatefulWidget {
  const ReportBugPromptSheet({
    super.key,
    required this.onToggleShake,
    required this.isShakeEnabled,
  });

  final Future<void> Function(bool enabled) onToggleShake;
  final bool isShakeEnabled;

  @override
  State<ReportBugPromptSheet> createState() => _ReportBugPromptSheetState();
}

class _ReportBugPromptSheetState extends State<ReportBugPromptSheet> {
  late bool _shakeEnabled;

  @override
  void initState() {
    super.initState();
    _shakeEnabled = widget.isShakeEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Report a bug?',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "If something isn't working correctly, you can report it to help improve Socialmesh for everyone.",
                style: TextStyle(color: context.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'Report bug',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Shake device to report a bug'),
                subtitle: const Text('Toggle off to disable'),
                trailing: ThemedSwitch(
                  value: _shakeEnabled,
                  onChanged: (value) async {
                    await widget.onToggleShake(value);
                    if (mounted) {
                      setState(() => _shakeEnabled = value);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportBugSheetState extends State<ReportBugSheet> {
  final _controller = TextEditingController();
  final _descriptionFocusNode = FocusNode();
  bool _includeScreenshot = true;
  bool _isSending = false;
  late bool _shakeEnabled;
  bool _showDescriptionError = false;

  @override
  void initState() {
    super.initState();
    _includeScreenshot = widget.initialScreenshot != null;
    _shakeEnabled = widget.isShakeEnabled;
  }

  @override
  void dispose() {
    _controller.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _showDescriptionError = true);
      _descriptionFocusNode.requestFocus();
      return;
    }
    setState(() => _isSending = true);
    showLoadingSnackBar(context, 'Sending bug report...');
    try {
      final result = await widget.onSubmit(
        description: text,
        includeScreenshot: _includeScreenshot,
        screenshotBytes: widget.initialScreenshot,
      );

      if (!mounted) return;
      // Close the sheet first
      navigatorKey.currentState?.pop();

      final id = result != null ? (result['reportId'] ?? '') : '';
      showGlobalSuccessSnackBar(
        'Bug report submitted${id != '' ? ' (ID: $id)' : ''}.',
      );
    } catch (e) {
      if (!mounted) return;
      String msg;
      if (e is FirebaseFunctionsException) {
        msg = e.message ?? e.toString();
      } else if (e is Exception) {
        msg = e.toString();
      } else {
        msg = '$e';
      }
      showGlobalErrorSnackBar('Failed to send bug report: $msg');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      top: true,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: DraggableScrollableSheet(
          initialChildSize: 0.82,
          minChildSize: 0.55,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Container(
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
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
                      focusNode: _descriptionFocusNode,
                      maxLines: 6,
                      maxLength: 2000,
                      decoration: InputDecoration(
                        hintText: 'Tell us about the issue you encountered',
                        filled: true,
                        fillColor: context.background,
                        errorText:
                            _showDescriptionError
                                ? 'Please describe the issue.'
                                : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: TextStyle(color: context.textPrimary),
                      onTapOutside: (_) => FocusScope.of(context).unfocus(),
                      onChanged: (_) {
                        if (_showDescriptionError) {
                          setState(() => _showDescriptionError = false);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    if (widget.initialScreenshot != null) ...[
                      ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Include screenshot in report'),
                        subtitle: const Text('Helps us debug faster'),
                        trailing: ThemedSwitch(
                          value: _includeScreenshot,
                          onChanged: _isSending
                              ? null
                              : (value) {
                                  setState(() => _includeScreenshot = value);
                                },
                        ),
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
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Shake device to report a bug'),
                      subtitle: const Text('Toggle off to disable'),
                      trailing: ThemedSwitch(
                        value: _shakeEnabled,
                        onChanged: _isSending
                            ? null
                            : (value) async {
                                await widget.onToggleShake(value);
                                if (mounted) {
                                  setState(() => _shakeEnabled = value);
                                }
                              },
                      ),
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Send'),
                      ),
                    ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
