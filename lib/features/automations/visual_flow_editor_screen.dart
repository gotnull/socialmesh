// SPDX-License-Identifier: GPL-3.0-or-later
// Visual Flow Editor Screen — full-screen node canvas for building automations
// visually using the vs_node_view graph editor.
//
// This screen provides:
// - A zoomable/pannable node canvas with dot-grid background
// - A top toolbar with flow name, validation status, and save button
// - A bottom toolbar with node palette for adding nodes
// - Compile-on-save: compiles the graph to Automation objects via the flow
//   compiler and persists them through automationsProvider
// - Round-trip editing: existing Automations can be decompiled into a graph
//   for visual editing, then recompiled and saved back
//
// Entry points:
// - New flow: push this screen with no arguments
// - Edit existing: push with an Automation to decompile into the canvas

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/visual_flow/compiler/flow_compiler.dart';
import '../../core/visual_flow/interfaces/event_signal_interface.dart';
import '../../core/visual_flow/providers/visual_flow_provider.dart';
import '../../core/visual_flow/vs_node_view/data/vs_node_data.dart';
import '../../core/visual_flow/vs_node_view/data/vs_node_data_provider.dart';
import '../../core/visual_flow/vs_node_view/data/vs_history_manager.dart';
import '../../core/visual_flow/vs_node_view/widgets/interactive_vs_node_view.dart';
import '../../core/visual_flow/vs_node_view/widgets/vs_node_view.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/premium_gating.dart';
import '../../models/subscription_models.dart';
import '../../providers/subscription_providers.dart';
import '../../services/haptic_service.dart';
import '../../utils/snackbar.dart';
import 'automation_providers.dart';
import 'models/automation.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// Accent colors for the node palette categories.
const Color _kTriggerAccent = kEventSignalColor;
const Color _kConditionAccent = Color(0xFF22D3EE);
const Color _kLogicAccent = Color(0xFFE0E7FF);
const Color _kActionAccent = Color(0xFF4ADE80);

/// Canvas dimensions for the node editor.
const double _kCanvasWidth = 5000.0;
const double _kCanvasHeight = 4000.0;

/// Initial viewport offset — positions the canvas so nodes placed at
/// (100, 100) are visible without panning.
const double _kInitialViewportX = -50.0;
const double _kInitialViewportY = -30.0;

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Full-screen visual automation flow editor.
///
/// Push with an [automation] to decompile and edit an existing automation.
/// Push without arguments to create a new flow from scratch.
class VisualFlowEditorScreen extends ConsumerStatefulWidget {
  /// The automation to edit, or null for a new flow.
  final Automation? automation;

  const VisualFlowEditorScreen({super.key, this.automation});

  @override
  ConsumerState<VisualFlowEditorScreen> createState() =>
      _VisualFlowEditorScreenState();
}

class _VisualFlowEditorScreenState extends ConsumerState<VisualFlowEditorScreen>
    with LifecycleSafeMixin<VisualFlowEditorScreen> {
  late final TextEditingController _nameController;
  late final TransformationController _transformController;
  VSNodeDataProvider? _nodeDataProvider;
  VSHistoryManager? _historyManager;
  bool _isSaving = false;
  bool _showNodePalette = false;
  bool _hasInitialized = false;

  /// Tracks the last validation error count for toolbar badge.
  int _errorCount = 0;

  /// Whether we are editing an existing automation (vs creating new).
  bool get _isEditing => widget.automation != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.automation?.name ?? '',
    );
    _transformController = TransformationController();

    // Set initial viewport offset so the starting area is visible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initializeGraph();
    });
  }

  void _initializeGraph() {
    if (_hasInitialized) return;
    _hasInitialized = true;

    final flowNotifier = ref.read(visualFlowProvider.notifier);

    if (widget.automation != null) {
      // Decompile existing automation into visual graph.
      flowNotifier.loadFromAutomation(widget.automation!);
      _nameController.text = widget.automation!.name;
    } else {
      // Create a fresh empty graph.
      flowNotifier.createNew(name: 'New Flow');
    }

    // Build the VSNodeDataProvider from the manager.
    final manager = flowNotifier.nodeManager;
    if (manager != null) {
      _historyManager = VSHistoryManager();
      _nodeDataProvider = VSNodeDataProvider(
        nodeManager: manager,
        historyManager: _historyManager,
      );
    }

    // Run initial validation.
    _runValidation();

    safeSetState(() {});

    // After the frame renders with the new nodes, fit the viewport so all
    // nodes are visible. For new empty graphs, just center the canvas at
    // the default position.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.automation != null &&
          (_nodeDataProvider?.nodes.isNotEmpty ?? false)) {
        _zoomToFit();
      } else {
        _transformController.value = Matrix4.identity()
          ..translate(_kInitialViewportX, _kInitialViewportY);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _transformController.dispose();
    // Close the flow to release resources.
    // We do this in a post-frame callback to avoid modifying provider
    // state during dispose.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Only close if the provider is still alive (widget tree intact).
      try {
        ref.read(visualFlowProvider.notifier).close();
      } catch (_) {
        // Provider may already be disposed.
      }
    });
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Validation
  // -------------------------------------------------------------------------

  void _runValidation() {
    final errors = ref.read(visualFlowProvider.notifier).validate();
    safeSetState(() {
      _errorCount = errors.length;
    });
  }

  // -------------------------------------------------------------------------
  // Compile & Save
  // -------------------------------------------------------------------------

  Future<void> _compileAndSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showWarningSnackBar(context, 'Please enter a name for this automation');
      return;
    }

    // Check premium before saving new automations.
    if (!_isEditing) {
      final hasPremium = ref.read(
        hasFeatureProvider(PremiumFeature.automations),
      );
      if (!hasPremium) {
        showPremiumInfoSheet(
          context: context,
          ref: ref,
          feature: PremiumFeature.automations,
          customDescription:
              'Create powerful visual automations with the node-based '
              'flow editor. Drag, connect, and compile automation logic.',
        );
        return;
      }
    }

    safeSetState(() => _isSaving = true);

    // Update flow name before compiling.
    final flowNotifier = ref.read(visualFlowProvider.notifier);
    flowNotifier.setFlowName(name);

    // Compile the graph.
    final result = flowNotifier.compile();

    if (!result.isSuccess) {
      safeSetState(() => _isSaving = false);
      if (mounted) {
        _showCompilationErrors(result);
      }
      return;
    }

    if (result.automations.isEmpty) {
      safeSetState(() => _isSaving = false);
      if (mounted) {
        showWarningSnackBar(
          context,
          'No automations could be compiled from this graph',
        );
      }
      return;
    }

    // Capture before await.
    final automationsNotifier = ref.read(automationsProvider.notifier);
    final navigator = Navigator.of(context);
    final haptics = ref.read(hapticServiceProvider);

    // Capture messenger before await.
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (_isEditing && widget.automation != null) {
        // Update the existing automation with the first compiled result.
        // If the graph produces multiple automations (OR gates), we update
        // the original and add the rest as new.
        final first = result.automations.first.copyWith(
          id: widget.automation!.id,
          createdAt: widget.automation!.createdAt,
          lastTriggered: widget.automation!.lastTriggered,
          triggerCount: widget.automation!.triggerCount,
        );
        await automationsNotifier.updateAutomation(first);

        // Add any additional automations (from OR gates).
        for (int i = 1; i < result.automations.length; i++) {
          await automationsNotifier.addAutomation(result.automations[i]);
        }
      } else {
        // Add all compiled automations.
        for (final automation in result.automations) {
          await automationsNotifier.addAutomation(automation);
        }
      }

      await haptics.trigger(HapticType.success);

      if (!mounted) return;

      flowNotifier.markClean();
      navigator.pop();

      final count = result.automations.length;
      final suffix = count > 1 ? ' ($count automations)' : '';
      final message = _isEditing
          ? 'Automation updated$suffix'
          : 'Automation created$suffix';
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      safeSetState(() => _isSaving = false);
      if (mounted) {
        showErrorSnackBar(context, 'Failed to save automation');
      }
    }
  }

  void _showCompilationErrors(FlowCompilationResult result) {
    final errors = result.errors;
    final warnings = result.warnings;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppTheme.errorRed,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Compilation Issues',
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (errors.isNotEmpty) ...[
                Text(
                  'Errors',
                  style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(
                    color: AppTheme.errorRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ...errors.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.close,
                          size: 16,
                          color: AppTheme.errorRed,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            e.message,
                            style: TextStyle(color: context.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (warnings.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Warnings',
                  style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(
                    color: AppTheme.warningYellow,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ...warnings.map(
                  (w) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.warning_amber,
                          size: 16,
                          color: AppTheme.warningYellow,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            w.message,
                            style: TextStyle(color: context.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Discard confirmation
  // -------------------------------------------------------------------------

  Future<bool> _onWillPop() async {
    final flowState = ref.read(visualFlowProvider);
    if (!flowState.isDirty) return true;

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.surface,
        title: const Text('Discard Changes?'),
        content: const Text(
          'You have unsaved changes in the flow editor. '
          'Discard them and go back?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Discard', style: TextStyle(color: AppTheme.errorRed)),
          ),
        ],
      ),
    );

    return shouldDiscard ?? false;
  }

  // -------------------------------------------------------------------------
  // Node palette
  // -------------------------------------------------------------------------

  void _toggleNodePalette() {
    final haptics = ref.read(hapticServiceProvider);
    haptics.trigger(HapticType.light);
    safeSetState(() => _showNodePalette = !_showNodePalette);
  }

  void _addNodeFromPalette(String category, int index) {
    final flowNotifier = ref.read(visualFlowProvider.notifier);
    final manager = flowNotifier.nodeManager;
    final provider = _nodeDataProvider;
    if (manager == null || provider == null) return;

    // Calculate position in the center of the current viewport.
    final matrix = _transformController.value;
    final scale = matrix.getMaxScaleOnAxis();
    final tx = matrix.getTranslation().x;
    final ty = matrix.getTranslation().y;

    // Get the visible area center.
    final screenSize = MediaQuery.of(context).size;
    final centerX = (screenSize.width / 2 - tx) / scale;
    final centerY = (screenSize.height / 2 - ty) / scale;

    // Slight random offset to avoid exact overlaps.
    final offset = Offset(
      centerX + (index * 20.0) - 40.0,
      centerY + (index * 15.0) - 30.0,
    );

    // Find the builder from the subgroup.
    final buildersMap = manager.nodeBuildersMap;
    final subgroupMap = buildersMap[category];

    if (subgroupMap is Map<String, dynamic>) {
      final entries = subgroupMap.entries.toList();
      if (index < entries.length) {
        final builder = entries[index].value;
        if (builder is VSNodeData Function(Offset, dynamic)) {
          final node = builder(offset, null);
          provider.updateOrCreateNodes([node]);
          flowNotifier.markDirty();
          _runValidation();

          final haptics = ref.read(hapticServiceProvider);
          haptics.trigger(HapticType.medium);
        }
      }
    }

    safeSetState(() => _showNodePalette = false);
  }

  // -------------------------------------------------------------------------
  // Undo / Redo
  // -------------------------------------------------------------------------

  void _undo() {
    if (_historyManager?.canUndo ?? false) {
      _historyManager!.undo();
      _runValidation();
      ref.read(visualFlowProvider.notifier).markDirty();
    }
  }

  void _redo() {
    if (_historyManager?.canRedo ?? false) {
      _historyManager!.redo();
      _runValidation();
      ref.read(visualFlowProvider.notifier).markDirty();
    }
  }

  // -------------------------------------------------------------------------
  // Delete selected nodes
  // -------------------------------------------------------------------------

  void _deleteSelected() {
    final provider = _nodeDataProvider;
    if (provider == null) return;

    final selected = provider.selectedNodes;
    if (selected.isEmpty) return;

    final nodesToRemove = <VSNodeData>[];
    for (final id in selected) {
      final node = provider.nodes[id];
      if (node != null) {
        nodesToRemove.add(node);
      }
    }

    if (nodesToRemove.isNotEmpty) {
      provider.removeNodes(nodesToRemove);
      provider.selectedNodes = {};
      _runValidation();
      ref.read(visualFlowProvider.notifier).markDirty();

      final haptics = ref.read(hapticServiceProvider);
      haptics.trigger(HapticType.light);
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Watch flow state for reactive updates.
    final flowState = ref.watch(visualFlowProvider);

    return PopScope(
      canPop: !flowState.isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          navigator.pop();
        }
      },
      child: GlassScaffold.body(
        title: _isEditing ? 'Edit Flow' : 'New Flow',
        actions: [
          // Validation badge.
          if (_errorCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: IconButton(
                icon: Badge(
                  label: Text(
                    '$_errorCount',
                    style: const TextStyle(fontSize: 10),
                  ),
                  backgroundColor: AppTheme.errorRed,
                  child: const Icon(Icons.warning_amber_rounded),
                ),
                tooltip: 'Validation issues',
                onPressed: () {
                  final result = ref
                      .read(visualFlowProvider)
                      .lastCompilationResult;
                  if (result != null) {
                    _showCompilationErrors(result);
                  } else {
                    // Run compile to get errors.
                    final compileResult = ref
                        .read(visualFlowProvider.notifier)
                        .compile();
                    _showCompilationErrors(compileResult);
                  }
                },
              ),
            ),
          // Save button.
          _buildSaveAction(),
        ],
        body: _nodeDataProvider == null
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  // Main canvas.
                  _buildCanvas(),

                  // Bottom toolbar.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _buildBottomToolbar(),
                  ),

                  // Node palette overlay.
                  if (_showNodePalette)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 80,
                      child: _buildNodePaletteOverlay(),
                    ),

                  // Flow name input (floating at top).
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 8,
                    child: _buildFlowNameField(),
                  ),
                ],
              ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Canvas
  // -------------------------------------------------------------------------

  Widget _buildCanvas() {
    return InteractiveVSNodeView(
      controller: _transformController,
      nodeDataProvider: _nodeDataProvider!,
      width: _kCanvasWidth,
      height: _kCanvasHeight,
      maxScale: 2.5,
      minScale: 0.15,
      baseNodeView: VSNodeView(
        nodeDataProvider: _nodeDataProvider!,
        showGridBackground: true,
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Flow name field
  // -------------------------------------------------------------------------

  Widget _buildFlowNameField() {
    return Container(
      decoration: BoxDecoration(
        color: context.card.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.account_tree_outlined,
            size: 18,
            color: context.textTertiary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Flow name...',
                hintStyle: TextStyle(color: context.textTertiary),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (_) {
                ref.read(visualFlowProvider.notifier).markDirty();
              },
            ),
          ),
          // Node count badge.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primaryPurple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${ref.read(visualFlowProvider.notifier).nodeCount} nodes',
              style: TextStyle(
                color: AppTheme.primaryPurple,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Bottom toolbar
  // -------------------------------------------------------------------------

  Widget _buildBottomToolbar() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final selectedCount = _nodeDataProvider?.selectedNodes.length ?? 0;

    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: bottomPadding + 8,
      ),
      decoration: BoxDecoration(
        color: context.card.withValues(alpha: 0.95),
        border: Border(top: BorderSide(color: context.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Add node button.
          _ToolbarButton(
            icon: Icons.add_circle_outline,
            label: 'Add',
            color: AppTheme.primaryPurple,
            isActive: _showNodePalette,
            onTap: _toggleNodePalette,
          ),
          const SizedBox(width: 8),

          // Undo.
          _ToolbarButton(
            icon: Icons.undo,
            label: 'Undo',
            color: context.textSecondary,
            onTap: (_historyManager?.canUndo ?? false) ? _undo : null,
          ),
          const SizedBox(width: 8),

          // Redo.
          _ToolbarButton(
            icon: Icons.redo,
            label: 'Redo',
            color: context.textSecondary,
            onTap: (_historyManager?.canRedo ?? false) ? _redo : null,
          ),

          const Spacer(),

          // Delete selected.
          if (selectedCount > 0)
            _ToolbarButton(
              icon: Icons.delete_outline,
              label: 'Delete ($selectedCount)',
              color: AppTheme.errorRed,
              onTap: _deleteSelected,
            ),

          if (selectedCount > 0) const SizedBox(width: 8),

          // Zoom to fit.
          _ToolbarButton(
            icon: Icons.fit_screen_outlined,
            label: 'Fit',
            color: context.textSecondary,
            onTap: _zoomToFit,
          ),
        ],
      ),
    );
  }

  void _zoomToFit() {
    final nodes = _nodeDataProvider?.nodes;
    if (nodes == null || nodes.isEmpty) return;

    // Calculate bounding box of all nodes.
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final node in nodes.values) {
      final x = node.widgetOffset.dx;
      final y = node.widgetOffset.dy;
      final w = node.nodeWidth ?? 200.0;
      const h = 120.0; // Approximate node height.

      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x + w > maxX) maxX = x + w;
      if (y + h > maxY) maxY = y + h;
    }

    // Add padding.
    const padding = 80.0;
    minX -= padding;
    minY -= padding;
    maxX += padding;
    maxY += padding;

    final graphWidth = maxX - minX;
    final graphHeight = maxY - minY;

    final screenSize = MediaQuery.of(context).size;
    // Account for toolbar and name field.
    final availableHeight = screenSize.height - 200;
    final availableWidth = screenSize.width - 32;

    final scaleX = availableWidth / graphWidth;
    final scaleY = availableHeight / graphHeight;
    final scale = (scaleX < scaleY ? scaleX : scaleY).clamp(0.15, 2.0);

    final translateX =
        -minX * scale + (availableWidth - graphWidth * scale) / 2 + 16;
    final translateY =
        -minY * scale + (availableHeight - graphHeight * scale) / 2 + 60;

    _transformController.value = Matrix4.identity()
      ..translate(translateX, translateY)
      ..scale(scale);
  }

  // -------------------------------------------------------------------------
  // Node palette
  // -------------------------------------------------------------------------

  Widget _buildNodePaletteOverlay() {
    final manager = ref.read(visualFlowProvider.notifier).nodeManager;
    if (manager == null) return const SizedBox.shrink();

    final buildersMap = manager.nodeBuildersMap;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: context.card.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Icon(
                  Icons.widgets_outlined,
                  size: 18,
                  color: context.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Add Node',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => safeSetState(() => _showNodePalette = false),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Node categories.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: _buildPaletteCategories(buildersMap),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPaletteCategories(Map<String, dynamic> buildersMap) {
    final categories = <Widget>[];

    for (final entry in buildersMap.entries) {
      final categoryName = entry.key;
      final categoryData = entry.value;

      if (categoryData is Map<String, dynamic>) {
        final color = _categoryColor(categoryName);
        final icon = _categoryIcon(categoryName);

        categories.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 14, color: color),
                    const SizedBox(width: 6),
                    Text(
                      categoryName,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: categoryData.entries.indexed.map((indexed) {
                    final (index, nodeEntry) = indexed;
                    return _PaletteChip(
                      label: nodeEntry.key,
                      color: color,
                      onTap: () => _addNodeFromPalette(categoryName, index),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      }
    }

    return categories;
  }

  Color _categoryColor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('trigger') || lower.contains('when')) {
      return _kTriggerAccent;
    }
    if (lower.contains('condition')) return _kConditionAccent;
    if (lower.contains('logic')) return _kLogicAccent;
    if (lower.contains('action') || lower.contains('then')) {
      return _kActionAccent;
    }
    return context.textSecondary;
  }

  IconData _categoryIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('trigger') || lower.contains('when')) {
      return Icons.bolt;
    }
    if (lower.contains('condition')) return Icons.filter_alt_outlined;
    if (lower.contains('logic')) return Icons.account_tree_outlined;
    if (lower.contains('action') || lower.contains('then')) {
      return Icons.play_arrow;
    }
    return Icons.widgets_outlined;
  }

  // -------------------------------------------------------------------------
  // Save action button
  // -------------------------------------------------------------------------

  Widget _buildSaveAction() {
    if (_isSaving) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return BouncyTap(
      onTap: _compileAndSave,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.primaryMagenta, AppTheme.primaryPurple],
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.save_outlined, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              _isEditing ? 'Save' : 'Create',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Toolbar button widget
// ---------------------------------------------------------------------------

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool isActive;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;
    final effectiveColor = isDisabled
        ? color.withValues(alpha: 0.3)
        : isActive
        ? AppTheme.primaryPurple
        : color;

    return BouncyTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primaryPurple.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: effectiveColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: effectiveColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Palette chip widget
// ---------------------------------------------------------------------------

class _PaletteChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PaletteChip({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BouncyTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
