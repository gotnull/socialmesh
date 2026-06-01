// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/bottom_action_bar.dart';
import '../../core/widgets/datetime_picker_sheet.dart';
import '../../core/widgets/emoji_glyph.dart';
import '../../core/widgets/emoji_picker_sheet.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/primary_gradient_button.dart';
import '../../providers/app_providers.dart';
import '../../utils/snackbar.dart';
import 'models/mesh_waypoint.dart';
import 'providers/waypoint_providers.dart';

/// Create or edit a shared Meshtastic waypoint (POI). A null [existing]
/// creates a new waypoint at [location] with a fresh random id; a non-null
/// [existing] edits in place, reusing its id.
class WaypointFormScreen extends ConsumerStatefulWidget {
  final LatLng location;
  final MeshWaypoint? existing;

  const WaypointFormScreen({super.key, required this.location, this.existing});

  @override
  ConsumerState<WaypointFormScreen> createState() => _WaypointFormScreenState();
}

class _WaypointFormScreenState extends ConsumerState<WaypointFormScreen>
    with LifecycleSafeMixin {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  int _icon = 0;
  bool _expires = false;
  DateTime? _expiryDate;
  bool _locked = false;
  bool _isSaving = false;

  late final int _waypointId;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _waypointId = existing.id;
      _nameController.text = existing.name;
      _descriptionController.text = existing.description;
      _icon = existing.icon;
      if (existing.hasExpiry) {
        _expires = true;
        _expiryDate = DateTime.fromMillisecondsSinceEpoch(
          existing.expire * 1000,
        );
      }
      _locked = existing.isLocked;
    } else {
      // Fresh random 32-bit id, matching the official Meshtastic clients.
      _waypointId = Random().nextInt(0xFFFFFFFF);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
  }

  Future<void> _pickEmoji() async {
    final emoji = await showEmojiPickerSheet(context);
    if (emoji == null || emoji.isEmpty || !mounted) return;
    // Store the first rune to match the single-scalar wire format. ZWJ
    // sequences collapse to their base glyph (a wire-format limitation shared
    // with the official clients).
    safeSetState(() => _icon = emoji.runes.first);
  }

  Future<void> _toggleExpires(bool value) async {
    if (!value) {
      safeSetState(() {
        _expires = false;
        _expiryDate = null;
      });
      return;
    }
    safeSetState(() {
      _expires = true;
      _expiryDate ??= DateTime.now().add(const Duration(hours: 8));
    });
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final date = await DatePickerSheet.show(
      context,
      initialDate: _expiryDate ?? now.add(const Duration(hours: 8)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      title: context.l10n.waypointExpireDateLabel,
    );
    if (date == null || !mounted) return;
    // Default the time wheel to the existing expiry time when editing a
    // waypoint that already has one; otherwise to the current time (HIG: a
    // time picker opens at "now", not an arbitrary derived value).
    final initialTime = (_isEditing && widget.existing!.hasExpiry)
        ? TimeOfDay.fromDateTime(_expiryDate!)
        : TimeOfDay.now();
    final time = await TimePickerSheet.show(
      context,
      initialTime: initialTime,
      title: context.l10n.waypointExpireTimeLabel,
    );
    if (!mounted) return;
    final t = time ?? TimeOfDay.fromDateTime(date);
    safeSetState(() {
      _expiryDate = DateTime(date.year, date.month, date.day, t.hour, t.minute);
    });
  }

  Future<void> _save() async {
    safeSetState(() => _isSaving = true);
    final notifier = ref.read(waypointsNotifierProvider.notifier);
    final myNodeNum = ref.read(myNodeNumProvider);

    final expire = _expires && _expiryDate != null
        ? _expiryDate!.millisecondsSinceEpoch ~/ 1000
        : 0;

    final waypoint = MeshWaypoint(
      id: _waypointId,
      latitude: widget.location.latitude,
      longitude: widget.location.longitude,
      expire: expire,
      lockedTo: _locked && myNodeNum != null ? myNodeNum : 0,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      icon: _icon,
      sourceNodeNum: myNodeNum ?? 0,
      receivedAt: DateTime.now(),
      isMine: true,
    );

    try {
      await notifier.createOrUpdate(waypoint);
      if (!mounted) return;
      showSuccessSnackBar(
        context,
        _isEditing
            ? context.l10n.waypointUpdated
            : context.l10n.waypointCreated,
      );
      safeNavigatorPop();
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, context.l10n.waypointSendError);
      safeSetState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myNodeNum = ref.watch(myNodeNumProvider);
    return GestureDetector(
      onTap: _dismissKeyboard,
      child: GlassScaffold(
        title: _isEditing
            ? context.l10n.waypointEditTitle
            : context.l10n.waypointCreateTitle,
        bottomNavigationBar: BottomActionBar(
          child: PrimaryGradientButton(
            label: context.l10n.waypointSave,
            icon: Icons.place,
            isLoading: _isSaving,
            onPressed: _isSaving ? null : _save,
          ),
        ),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _sectionTitle(context.l10n.waypointNameLabel),
                _detailsCard(),
                const SizedBox(height: AppTheme.spacing16),
                _sectionTitle(context.l10n.waypointEmojiLabel),
                _iconCard(),
                const SizedBox(height: AppTheme.spacing16),
                _sectionTitle(context.l10n.waypointExpireLabel),
                _expiryCard(),
                const SizedBox(height: AppTheme.spacing16),
                _sectionTitle(context.l10n.waypointLockedLabel),
                _lockedCard(myNodeNum != null),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: context.textTertiary,
          letterSpacing: 1,
        ),
      ),
    );
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
    color: context.card,
    borderRadius: BorderRadius.circular(AppTheme.radius12),
  );

  InputDecoration _fieldDecoration({
    required String label,
    required String hint,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: context.textSecondary),
      hintText: hint,
      hintStyle: TextStyle(color: context.textTertiary.withValues(alpha: 0.5)),
      filled: true,
      fillColor: context.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius10),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      counterText: '',
    );
  }

  Widget _detailsCard() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: _cardDecoration,
      child: Column(
        children: [
          TextField(
            controller: _nameController,
            maxLength: 30,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            style: TextStyle(color: context.textPrimary),
            decoration: _fieldDecoration(
              label: context.l10n.waypointNameLabel,
              hint: context.l10n.waypointNameHint,
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          TextField(
            controller: _descriptionController,
            maxLength: 100,
            maxLines: 3,
            minLines: 1,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            style: TextStyle(color: context.textPrimary),
            decoration: _fieldDecoration(
              label: context.l10n.waypointDescriptionLabel,
              hint: context.l10n.waypointDescriptionHint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconCard() {
    final hasIcon = _icon != 0;
    return Container(
      decoration: _cardDecoration,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AccentColors.orange.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: hasIcon
              ? EmojiGlyph(codePoint: _icon, size: 20)
              : Icon(Icons.place, color: AccentColors.orange, size: 20),
        ),
        title: Text(
          context.l10n.waypointEmojiLabel,
          style: TextStyle(color: context.textPrimary),
        ),
        subtitle: Text(
          context.l10n.waypointPickEmoji,
          style: TextStyle(color: context.textTertiary, fontSize: 12),
        ),
        trailing: Icon(Icons.chevron_right, color: context.textSecondary),
        onTap: _pickEmoji,
      ),
    );
  }

  Widget _expiryCard() {
    return Container(
      decoration: _cardDecoration,
      child: Column(
        children: [
          ListTile(
            title: Text(
              context.l10n.waypointExpireLabel,
              style: TextStyle(color: context.textPrimary),
            ),
            subtitle: Text(
              context.l10n.waypointExpireSubtitle,
              style: TextStyle(color: context.textTertiary, fontSize: 12),
            ),
            trailing: ThemedSwitch(value: _expires, onChanged: _toggleExpires),
          ),
          if (_expires) ...[
            Divider(height: 1, color: context.border),
            ListTile(
              title: Text(
                context.l10n.waypointExpireDateLabel,
                style: TextStyle(color: context.textPrimary),
              ),
              subtitle: Text(
                _expiryDate != null
                    ? _formatExpiry(_expiryDate!)
                    : context.l10n.waypointNoExpiry,
                style: TextStyle(color: context.textTertiary, fontSize: 12),
              ),
              trailing: Icon(
                Icons.calendar_today,
                color: context.textSecondary,
                size: 18,
              ),
              onTap: _pickExpiry,
            ),
          ],
        ],
      ),
    );
  }

  Widget _lockedCard(bool nodeKnown) {
    return Container(
      decoration: _cardDecoration,
      child: ListTile(
        leading: Icon(
          _locked ? Icons.lock : Icons.lock_open,
          color: _locked ? context.accentColor : context.textSecondary,
        ),
        title: Text(
          context.l10n.waypointLockedLabel,
          style: TextStyle(color: context.textPrimary),
        ),
        subtitle: Text(
          context.l10n.waypointLockedSubtitle,
          style: TextStyle(color: context.textTertiary, fontSize: 12),
        ),
        trailing: ThemedSwitch(
          value: _locked,
          // Locking binds to our node number; disable until the node identity
          // is known (i.e. we are connected).
          onChanged: nodeKnown ? (v) => safeSetState(() => _locked = v) : null,
        ),
      ),
    );
  }

  String _formatExpiry(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }
}
