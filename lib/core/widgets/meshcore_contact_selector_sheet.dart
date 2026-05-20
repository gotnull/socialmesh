// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCore-side equivalent of `NodeSelectorSheet`. Returns a
// `MeshCoreContactSelection` whose `nodeNumPrefix` is the first 4
// pubkey bytes as big-endian uint32 - the same int Slice A used to
// tag inbound MeshCore `AutomationMessage.from`, so a target picked
// here round-trips cleanly through Slice D's action dispatch helper
// (`_sendMeshCoreContactMessage` in `automation_providers.dart`).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/meshcore_contact.dart';
import '../../providers/meshcore_message_providers.dart';
import '../../providers/meshcore_providers.dart';
import '../l10n/l10n_extension.dart';
import '../theme.dart';
import 'app_bottom_sheet.dart';

class MeshCoreContactSelection {
  // First 4 pubkey bytes as big-endian uint32. Matches the value
  // `AutomationMessage.from` carries for inbound MeshCore messages.
  final int nodeNumPrefix;
  // The contact's display name at selection time; the action editor
  // shows this label without re-resolving.
  final String displayName;

  const MeshCoreContactSelection({
    required this.nodeNumPrefix,
    required this.displayName,
  });
}

class MeshCoreContactSelectorSheet extends ConsumerStatefulWidget {
  final String title;
  final int? initialSelection;

  const MeshCoreContactSelectorSheet({
    super.key,
    required this.title,
    this.initialSelection,
  });

  static Future<MeshCoreContactSelection?> show(
    BuildContext context, {
    required String title,
    int? initialSelection,
  }) {
    return AppBottomSheet.show<MeshCoreContactSelection>(
      context: context,
      padding: EdgeInsets.zero,
      child: MeshCoreContactSelectorSheet(
        title: title,
        initialSelection: initialSelection,
      ),
    );
  }

  @override
  ConsumerState<MeshCoreContactSelectorSheet> createState() =>
      _MeshCoreContactSelectorSheetState();
}

class _MeshCoreContactSelectorSheetState
    extends ConsumerState<MeshCoreContactSelectorSheet> {
  late int? _selectedPrefix;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedPrefix = widget.initialSelection;
  }

  List<MeshCoreContact> _filteredContacts(List<MeshCoreContact> all) {
    if (_searchQuery.trim().isEmpty) return all;
    final q = _searchQuery.toLowerCase();
    return all
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.publicKeyHex.toLowerCase().startsWith(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(meshCoreContactsProvider).contacts;
    final filtered = _filteredContacts(contacts);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing24,
              0,
              AppTheme.spacing16,
              0,
            ),
            child: Row(
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    context.l10n.automationActionDone,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.border),
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: TextField(
              maxLength: 64,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: context.l10n.meshcoreContactSelectorSearchHint,
                prefixIcon: Icon(Icons.search, color: context.textSecondary),
                isDense: true,
                counterText: '',
                filled: true,
                fillColor: context.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                  borderSide: BorderSide(color: context.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                  borderSide: BorderSide(color: context.border),
                ),
              ),
            ),
          ),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing16,
                vertical: AppTheme.spacing24,
              ),
              child: Text(
                contacts.isEmpty
                    ? context.l10n.meshcoreContactSelectorEmpty
                    : context.l10n.meshcoreContactSelectorNoMatches,
                style: TextStyle(color: context.textTertiary),
                textAlign: TextAlign.center,
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final contact = filtered[index];
                  final prefix = meshCoreSenderIdFromKey(contact.publicKey);
                  final isSelected = _selectedPrefix == prefix;
                  return _ContactTile(
                    name: contact.name,
                    pubKeyHexPrefix: contact.publicKeyHex.substring(0, 8),
                    isSelected: isSelected,
                    onTap: () {
                      Navigator.pop(
                        context,
                        MeshCoreContactSelection(
                          nodeNumPrefix: prefix,
                          displayName: contact.name,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final String name;
  final String pubKeyHexPrefix;
  final bool isSelected;
  final VoidCallback onTap;

  const _ContactTile({
    required this.name,
    required this.pubKeyHexPrefix,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing12,
          ),
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                ),
                child: Icon(
                  Icons.contact_page_outlined,
                  size: 18,
                  color: context.accentColor,
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                    Text(
                      pubKeyHexPrefix,
                      style: TextStyle(
                        color: context.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check, color: Theme.of(context).colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
