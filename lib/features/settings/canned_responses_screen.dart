import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../models/canned_response.dart';
import '../../models/user_profile.dart';
import '../../providers/profile_providers.dart';
import '../../services/storage/storage_service.dart';
import '../../providers/app_providers.dart';
import '../../core/widgets/loading_indicator.dart';

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

  /// Sync canned responses to cloud profile
  void _syncToCloud() {
    final jsonList = _responses.map((r) => r.toJson()).toList();
    final jsonStr = jsonEncode(jsonList);
    ref
        .read(userProfileProvider.notifier)
        .updatePreferences(UserPreferences(cannedResponsesJson: jsonStr));
  }

  Future<void> _addResponse() async {
    if (_settingsService == null) return;
    final result = await _showEditSheet(null);
    if (result != null) {
      await _settingsService!.addCannedResponse(result);
      setState(_loadResponses);
      _syncToCloud();
    }
  }

  Future<void> _editResponse(CannedResponse response) async {
    if (_settingsService == null) return;
    final result = await _showEditSheet(response);
    if (result != null) {
      await _settingsService!.updateCannedResponse(result);
      setState(_loadResponses);
      _syncToCloud();
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
      _syncToCloud();
    }
  }

  Future<void> _resetToDefaults() async {
    if (_settingsService == null) return;
    final confirmed = await _showConfirmSheet(
      title: 'Reset to Defaults',
      message:
          'This will remove all custom responses and restore the default set.',
      confirmLabel: 'Reset',
      isDestructive: true,
    );
    if (confirmed == true) {
      await _settingsService!.resetCannedResponsesToDefaults();
      setState(_loadResponses);
      _syncToCloud();
    }
  }

  Future<bool?> _showConfirmSheet({
    required String title,
    required String message,
    required String confirmLabel,
    bool isDestructive = false,
  }) {
    return AppBottomSheet.showConfirm(
      context: context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      isDestructive: isDestructive,
    );
  }

  Future<CannedResponse?> _showEditSheet(CannedResponse? existing) async {
    return AppBottomSheet.show<CannedResponse>(
      context: context,
      child: _EditResponseContent(existing: existing),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Quick Responses',
      actions: [
        IconButton(
          icon: Icon(
            _isReordering ? Icons.check : Icons.reorder,
            color: _isReordering ? context.accentColor : null,
          ),
          tooltip: _isReordering ? 'Done' : 'Reorder',
          onPressed: () {
            HapticFeedback.selectionClick();
            setState(() => _isReordering = !_isReordering);
          },
        ),
        AppBarOverflowMenu<String>(
          onSelected: (value) {
            if (value == 'reset') {
              _resetToDefaults();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'reset',
              child: Row(
                children: [
                  Icon(Icons.restore, color: context.textSecondary),
                  SizedBox(width: 12),
                  Text('Reset to defaults'),
                ],
              ),
            ),
          ],
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: _addResponse,
        backgroundColor: context.accentColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _isReordering
                  ? 'Drag to reorder responses'
                  : 'Tap to edit, swipe to delete',
              style: TextStyle(color: context.textSecondary, fontSize: 14),
            ),
          ),
        ),
        if (_isLoading)
          SliverFillRemaining(child: Center(child: LoadingIndicator(size: 48)))
        else if (_isReordering)
          SliverFillRemaining(
            child: ReorderableListView.builder(
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
                _syncToCloud();
              },
              itemBuilder: (context, index) => _ResponseTile(
                key: ValueKey(_responses[index].id),
                response: _responses[index],
                isReordering: true,
                onTap: () {},
                onDelete: () {},
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
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
                    child: const Icon(Icons.delete, color: AppTheme.errorRed),
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
              }, childCount: _responses.length),
            ),
          ),
      ],
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
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: isReordering ? null : onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: context.accentColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Icon(Icons.bolt, size: 20, color: context.accentColor),
          ),
        ),
        title: Text(
          response.text,
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: response.isDefault
            ? Text(
                'Default',
                style: TextStyle(color: context.textSecondary, fontSize: 12),
              )
            : null,
        trailing: isReordering
            ? Icon(Icons.drag_handle, color: context.textSecondary)
            : Icon(Icons.chevron_right, color: context.textSecondary),
      ),
    );
  }
}

class _EditResponseContent extends StatefulWidget {
  final CannedResponse? existing;

  const _EditResponseContent({this.existing});

  @override
  State<_EditResponseContent> createState() => _EditResponseContentState();
}

class _EditResponseContentState extends State<_EditResponseContent> {
  late final TextEditingController _textController;
  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.existing?.text ?? '');
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final response =
        widget.existing?.copyWith(text: text) ?? CannedResponse(text: text);
    Navigator.pop(context, response);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BottomSheetHeader(
          title: _isEditing ? 'Edit Response' : 'Add Response',
          subtitle: 'Create a quick message for fast sending',
        ),
        const SizedBox(height: 24),
        BottomSheetTextField(
          controller: _textController,
          label: 'Message',
          hint: 'e.g., On my way',
          maxLength: 100,
          autofocus: true,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 24),
        BottomSheetButtons(
          onCancel: () => Navigator.pop(context),
          onConfirm: _submit,
          confirmLabel: _isEditing ? 'Save' : 'Add',
        ),
      ],
    );
  }
}
