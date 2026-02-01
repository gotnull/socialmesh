// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../models/presence_confidence.dart';
import '../../../providers/presence_providers.dart';
import '../../../utils/snackbar.dart';

/// Widget for configuring my presence intent and short status.
/// Designed to be embedded in settings screens.
class MyPresenceSettings extends ConsumerStatefulWidget {
  const MyPresenceSettings({super.key});

  @override
  ConsumerState<MyPresenceSettings> createState() => _MyPresenceSettingsState();
}

class _MyPresenceSettingsState extends ConsumerState<MyPresenceSettings> {
  PresenceIntent _intent = PresenceIntent.unknown;
  String? _shortStatus;
  bool _isLoading = true;
  final _statusController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _statusController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final service = ref.read(extendedPresenceServiceProvider);
      await service.init();
      final info = await service.getMyPresenceInfo();
      if (!mounted) return;
      setState(() {
        _intent = info.intent;
        _shortStatus = info.shortStatus;
        _statusController.text = info.shortStatus ?? '';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setIntent(PresenceIntent intent) async {
    HapticFeedback.selectionClick();
    final service = ref.read(extendedPresenceServiceProvider);
    final changed = await service.setMyIntent(intent);
    if (!mounted) return;
    setState(() => _intent = intent);
    if (changed) {
      showSuccessSnackBar(context, 'Presence intent updated');
    }
  }

  Future<void> _setStatus(String? status) async {
    final service = ref.read(extendedPresenceServiceProvider);
    final changed = await service.setMyStatus(status);
    if (!mounted) return;
    setState(() => _shortStatus = status);
    if (changed) {
      showSuccessSnackBar(context, 'Status updated');
    }
  }

  void _showIntentPicker() {
    HapticFeedback.selectionClick();
    AppBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BottomSheetHeader(title: 'Select Intent'),
          const SizedBox(height: 8),
          ...PresenceIntent.values.map((intent) {
            final isSelected = intent == _intent;
            return ListTile(
              leading: Icon(
                IconData(
                  PresenceIntentIcons.codeFor(intent),
                  fontFamily: 'MaterialIcons',
                ),
                color: isSelected ? context.accentColor : context.textSecondary,
              ),
              title: Text(
                intent.label,
                style: TextStyle(
                  color: isSelected ? context.accentColor : context.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              trailing: isSelected
                  ? Icon(Icons.check, color: context.accentColor)
                  : null,
              onTap: () {
                Navigator.of(context).pop();
                _setIntent(intent);
              },
            );
          }),
        ],
      ),
    );
  }

  void _showStatusEditor() {
    HapticFeedback.selectionClick();
    _statusController.text = _shortStatus ?? '';
    AppBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BottomSheetHeader(title: 'Set Status'),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _statusController,
              maxLength: ExtendedPresenceInfo.maxStatusLength,
              maxLines: 1,
              decoration: InputDecoration(
                hintText: 'What are you up to?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: _statusController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _statusController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
              autofocus: true,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (_shortStatus != null && _shortStatus!.isNotEmpty)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _setStatus(null);
                      },
                      child: const Text('Clear'),
                    ),
                  ),
                if (_shortStatus != null && _shortStatus!.isNotEmpty)
                  const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      final text = _statusController.text.trim();
                      _setStatus(text.isEmpty ? null : text);
                    },
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'My Presence',
            style: theme.textTheme.titleSmall?.copyWith(
              color: context.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              // Intent selector
              ListTile(
                leading: Icon(
                  IconData(
                    PresenceIntentIcons.codeFor(_intent),
                    fontFamily: 'MaterialIcons',
                  ),
                  color: context.accentColor,
                ),
                title: const Text('Intent'),
                subtitle: Text(
                  _intent.label,
                  style: TextStyle(color: context.textSecondary),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showIntentPicker,
              ),
              const Divider(height: 1, indent: 56),
              // Status editor
              ListTile(
                leading: Icon(
                  Icons.short_text,
                  color: _shortStatus != null
                      ? context.accentColor
                      : context.textTertiary,
                ),
                title: const Text('Status'),
                subtitle: Text(
                  _shortStatus ?? 'Not set',
                  style: TextStyle(
                    color: _shortStatus != null
                        ? context.textSecondary
                        : context.textTertiary,
                    fontStyle: _shortStatus == null
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showStatusEditor,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Your intent and status are broadcast with your signals.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.textTertiary,
            ),
          ),
        ),
      ],
    );
  }
}
