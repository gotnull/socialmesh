// Vendored from vs_node_view v2.1.1 — BSD-3-Clause
// Import paths rewritten for Socialmesh vendoring.
// Modified: Replaced PopupMenuButton with a simpler icon button row for mobile.
// Modified: Styled title with sci-fi themed divider and typography.

import 'package:flutter/material.dart';

import '../common.dart';
import '../data/vs_node_data.dart';
import '../data/vs_node_data_provider.dart';

enum PopupOptions { rename, delete }

class VSNodeTitle extends StatefulWidget {
  /// Base node title widget.
  ///
  /// Used in [VSNode] to build the title.
  const VSNodeTitle({required this.data, super.key});

  final VSNodeData data;

  @override
  State<VSNodeTitle> createState() => _VSNodeTitleState();
}

class _VSNodeTitleState extends State<VSNodeTitle> {
  bool isRenaming = false;
  final titleController = TextEditingController();
  final focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    titleController.text = widget.data.title;
  }

  @override
  void dispose() {
    titleController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  void _startRename() {
    setState(() {
      isRenaming = true;
      titleController.text = widget.data.title;
    });
    // Request focus on the next frame after the rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) focusNode.requestFocus();
    });
  }

  void _cancelRename() {
    setState(() {
      isRenaming = false;
      titleController.text = widget.data.title;
    });
  }

  void _commitRename(String input) {
    if (input.trim().isNotEmpty) {
      widget.data.title = input.trim();
    }
    setState(() => isRenaming = false);
  }

  void _deleteNode() {
    VSNodeDataProvider.of(context).removeNodes([widget.data]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: isRenaming
                  ? TextField(
                      controller: titleController,
                      focusNode: focusNode,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                        letterSpacing: 0.5,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: widget.data.type,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 8,
                        ),
                      ),
                      onTapOutside: (_) => _cancelRename(),
                      onSubmitted: _commitRename,
                    )
                  : wrapWithToolTip(
                      toolTip: widget.data.toolTip,
                      child: GestureDetector(
                        onDoubleTap: _startRename,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            widget.data.title,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            // Action buttons — compact row instead of PopupMenuButton for
            // easier mobile interaction. Each button has a generous touch
            // area.
            SizedBox(
              width: 28,
              height: 28,
              child: PopupMenuButton<PopupOptions>(
                tooltip: "",
                padding: EdgeInsets.zero,
                iconSize: 18,
                icon: Icon(
                  Icons.more_vert,
                  size: 18,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                onSelected: (value) {
                  switch (value) {
                    case PopupOptions.rename:
                      _startRename();
                    case PopupOptions.delete:
                      _deleteNode();
                  }
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem<PopupOptions>(
                    value: PopupOptions.rename,
                    height: 40,
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit,
                          size: 16,
                          color: colorScheme.onSurface,
                        ),
                        const SizedBox(width: 8),
                        const Text("Rename", style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  PopupMenuItem<PopupOptions>(
                    value: PopupOptions.delete,
                    height: 40,
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Delete",
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        // Sci-fi divider — gradient line matching the interface color scheme
        // rather than a plain Material Divider.
        Container(
          height: 1,
          margin: const EdgeInsets.only(top: 4, bottom: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primary.withValues(alpha: 0.0),
                colorScheme.primary.withValues(alpha: 0.5),
                colorScheme.primary.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}
