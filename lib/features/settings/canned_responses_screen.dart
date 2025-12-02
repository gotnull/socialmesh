import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../models/canned_response.dart';
import '../../services/storage/storage_service.dart';
import '../../providers/app_providers.dart';

class CannedResponsesScreen extends ConsumerStatefulWidget {
  const CannedResponsesScreen({super.key});

  @override
  ConsumerState<CannedResponsesScreen> createState() =>
      _CannedResponsesScreenState();
}

class _CannedResponsesScreenState extends ConsumerState<CannedResponsesScreen> {
  List<CannedResponse> _responses = [];
  SettingsService? _settingsService;
  bool _isReordering = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initSettings();
  }

  Future<void> _initSettings() async {
    _settingsService = await ref.read(settingsServiceProvider.future);
    _loadResponses();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _loadResponses() {
    if (_settingsService != null) {
      _responses = _settingsService!.cannedResponses;
    }
  }

  Future<void> _addResponse() async {
    if (_settingsService == null) return;
    final result = await _showEditDialog(null);
    if (result != null) {
      await _settingsService!.addCannedResponse(result);
      setState(_loadResponses);
    }
  }

  Future<void> _editResponse(CannedResponse response) async {
    if (_settingsService == null) return;
    final result = await _showEditDialog(response);
    if (result != null) {
      await _settingsService!.updateCannedResponse(result);
      setState(_loadResponses);
    }
  }

  Future<void> _deleteResponse(CannedResponse response) async {
    if (_settingsService == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Response'),
        content: Text('Delete "${response.text}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _settingsService!.deleteCannedResponse(response.id);
      setState(_loadResponses);
    }
  }

  Future<void> _resetToDefaults() async {
    if (_settingsService == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset to Defaults'),
        content: const Text(
          'This will remove all custom responses and restore the default set.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _settingsService!.resetCannedResponsesToDefaults();
      setState(_loadResponses);
    }
  }

  Future<CannedResponse?> _showEditDialog(CannedResponse? existing) async {
    final textController = TextEditingController(text: existing?.text ?? '');
    String? selectedEmoji = existing?.emoji;

    final commonEmojis = [
      '👍',
      '✅',
      '❌',
      '🚶',
      '🆘',
      '✨',
      '⏳',
      '🙏',
      '👋',
      '🔥',
      '💪',
      '🎯',
      '📍',
      '🏠',
      '⚠️',
      '🔔',
    ];

    return showDialog<CannedResponse>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.darkCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(existing == null ? 'Add Response' : 'Edit Response'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: textController,
                  autofocus: true,
                  maxLength: 100,
                  decoration: InputDecoration(
                    labelText: 'Response text',
                    hintText: 'e.g., On my way',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: AppTheme.darkBackground,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select emoji (optional)',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // No emoji option
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setDialogState(() => selectedEmoji = null);
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: selectedEmoji == null
                              ? AppTheme.primaryGreen.withValues(alpha: 0.3)
                              : AppTheme.darkBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selectedEmoji == null
                                ? AppTheme.primaryGreen
                                : Colors.grey.shade700,
                            width: selectedEmoji == null ? 2 : 1,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.block,
                            size: 20,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    ...commonEmojis.map(
                      (emoji) => GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setDialogState(() => selectedEmoji = emoji);
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: selectedEmoji == emoji
                                ? AppTheme.primaryGreen.withValues(alpha: 0.3)
                                : AppTheme.darkBackground,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selectedEmoji == emoji
                                  ? AppTheme.primaryGreen
                                  : Colors.grey.shade700,
                              width: selectedEmoji == emoji ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final text = textController.text.trim();
                if (text.isEmpty) return;
                final response =
                    existing?.copyWith(text: text, emoji: selectedEmoji) ??
                    CannedResponse(text: text, emoji: selectedEmoji);
                Navigator.pop(context, response);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
              ),
              child: Text(existing == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: const Text('Quick Responses'),
        actions: [
          IconButton(
            icon: Icon(
              _isReordering ? Icons.check : Icons.reorder,
              color: _isReordering ? AppTheme.primaryGreen : null,
            ),
            tooltip: _isReordering ? 'Done' : 'Reorder',
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _isReordering = !_isReordering);
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            color: AppTheme.darkCard,
            onSelected: (value) {
              if (value == 'reset') {
                _resetToDefaults();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.restore, color: AppTheme.textSecondary),
                    SizedBox(width: 12),
                    Text('Reset to defaults'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _isReordering
                  ? 'Drag to reorder responses'
                  : 'Tap to edit, swipe to delete',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryGreen,
                    ),
                  )
                : _isReordering
                ? ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _responses.length,
                    onReorder: (oldIndex, newIndex) async {
                      if (_settingsService == null) return;
                      HapticFeedback.mediumImpact();
                      await _settingsService!.reorderCannedResponses(
                        oldIndex,
                        newIndex,
                      );
                      setState(_loadResponses);
                    },
                    itemBuilder: (context, index) => _ResponseTile(
                      key: ValueKey(_responses[index].id),
                      response: _responses[index],
                      isReordering: true,
                      onTap: () {},
                      onDelete: () {},
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _responses.length,
                    itemBuilder: (context, index) {
                      final response = _responses[index];
                      return Dismissible(
                        key: ValueKey(response.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: AppTheme.errorRed.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.delete,
                            color: AppTheme.errorRed,
                          ),
                        ),
                        confirmDismiss: (_) async {
                          HapticFeedback.mediumImpact();
                          return true;
                        },
                        onDismissed: (_) {
                          _settingsService?.deleteCannedResponse(response.id);
                          setState(_loadResponses);
                        },
                        child: _ResponseTile(
                          response: response,
                          isReordering: false,
                          onTap: () => _editResponse(response),
                          onDelete: () => _deleteResponse(response),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addResponse,
        backgroundColor: AppTheme.primaryGreen,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _ResponseTile extends StatelessWidget {
  final CannedResponse response;
  final bool isReordering;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ResponseTile({
    super.key,
    required this.response,
    required this.isReordering,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: isReordering ? null : onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: response.emoji != null
            ? Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    response.emoji!,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              )
            : Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.darkBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(
                    Icons.chat_bubble_outline,
                    size: 20,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
        title: Text(
          response.text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: response.isDefault
            ? const Text(
                'Default',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              )
            : null,
        trailing: isReordering
            ? const Icon(Icons.drag_handle, color: AppTheme.textSecondary)
            : const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
      ),
    );
  }
}
