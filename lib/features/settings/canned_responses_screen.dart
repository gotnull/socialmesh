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
    final result = await _showEditSheet(null);
    if (result != null) {
      await _settingsService!.addCannedResponse(result);
      setState(_loadResponses);
    }
  }

  Future<void> _editResponse(CannedResponse response) async {
    if (_settingsService == null) return;
    final result = await _showEditSheet(response);
    if (result != null) {
      await _settingsService!.updateCannedResponse(result);
      setState(_loadResponses);
    }
  }

  Future<void> _deleteResponse(CannedResponse response) async {
    if (_settingsService == null) return;
    final confirmed = await _showConfirmSheet(
      title: 'Delete Response',
      message: 'Delete "${response.text}"?',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (confirmed == true) {
      await _settingsService!.deleteCannedResponse(response.id);
      setState(_loadResponses);
    }
  }

  Future<void> _resetToDefaults() async {
    if (_settingsService == null) return;
    final confirmed = await _showConfirmSheet(
      title: 'Reset to Defaults',
      message: 'This will remove all custom responses and restore the default set.',
      confirmLabel: 'Reset',
      isDestructive: true,
    );
    if (confirmed == true) {
      await _settingsService!.resetCannedResponsesToDefaults();
      setState(_loadResponses);
    }
  }

  Future<bool?> _showConfirmSheet({
    required String title,
    required String message,
    required String confirmLabel,
    bool isDestructive = false,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: AppTheme.textTertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.grey.shade700),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: isDestructive
                              ? AppTheme.errorRed
                              : AppTheme.primaryGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(confirmLabel),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<CannedResponse?> _showEditSheet(CannedResponse? existing) async {
    final textController = TextEditingController(text: existing?.text ?? '');
    final isEditing = existing != null;

    return showModalBottomSheet<CannedResponse>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: AppTheme.textTertiary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    isEditing ? 'Edit Response' : 'Add Response',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create a quick message for fast sending',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Message',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.darkBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.darkBorder),
                    ),
                    child: TextField(
                      controller: textController,
                      autofocus: true,
                      maxLength: 100,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'e.g., On my way',
                        hintStyle: TextStyle(color: AppTheme.textTertiary),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                        counterStyle: TextStyle(color: AppTheme.textTertiary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: Colors.grey.shade700),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            final text = textController.text.trim();
                            if (text.isEmpty) return;
                            final response = existing?.copyWith(text: text) ??
                                CannedResponse(text: text);
                            Navigator.pop(context, response);
                          },
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: AppTheme.primaryGreen,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(isEditing ? 'Save' : 'Add'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
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
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Icon(
              Icons.bolt,
              size: 20,
              color: AppTheme.primaryGreen,
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
