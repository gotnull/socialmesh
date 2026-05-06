// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// lint-allow: keyboard-dismissal — TextFields are in bottom-sheet sub-widgets, not the main screen
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animated_empty_state.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/primary_gradient_button.dart';
import '../../../core/widgets/qr_share_sheet.dart';
import '../../../core/widgets/search_filter_header.dart';
import '../../../core/widgets/app_bar_overflow_menu.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/status_filter_chip.dart';
import '../../../models/meshcore_channel.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/meshcore_message_providers.dart';
import '../../../providers/meshcore_providers.dart';
import '../../../utils/snackbar.dart';
import '../../navigation/meshcore_shell.dart';
import 'meshcore_chat_screen.dart';
import 'meshcore_qr_scanner_screen.dart';

/// MeshCore Channels screen.
///
/// Displays MeshCore channels/rooms, allows creating and joining channels.
class MeshCoreChannelsScreen extends ConsumerStatefulWidget {
  const MeshCoreChannelsScreen({super.key});

  @override
  ConsumerState<MeshCoreChannelsScreen> createState() =>
      _MeshCoreChannelsScreenState();
}

enum _MeshCoreChannelFilter { all, public, private }

class _MeshCoreChannelsScreenState extends ConsumerState<MeshCoreChannelsScreen>
    with LifecycleSafeMixin<MeshCoreChannelsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  _MeshCoreChannelFilter _activeFilter = _MeshCoreChannelFilter.all;

  @override
  void initState() {
    super.initState();
    AppLogging.meshcore('event=screen.opened name=channels');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final linkStatus = ref.watch(linkStatusProvider);
    final isConnected = linkStatus.isConnected;
    final deviceName = linkStatus.deviceName ?? 'MeshCore';
    final channelsState = ref.watch(meshCoreChannelsProvider);

    final allChannels = channelsState.channels
        .where((c) => c.name.isNotEmpty || !c.isDefaultPsk)
        .toList();
    var channels = _applyFilter(allChannels);
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      channels = channels
          .where(
            (channel) =>
                channel.displayName.toLowerCase().contains(query) ||
                channel.index.toString().contains(query),
          )
          .toList();
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: GlassScaffold.body(
        hasScrollBody: true,
        leading: const MeshCoreHamburgerMenuButton(),
        title:
            '${context.l10n.meshcoreChannelsTitle}${allChannels.isEmpty ? '' : ' (${allChannels.length})'}',
        actions: [
          const MeshCoreDeviceStatusButton(),
          AppBarOverflowMenu<String>(
            onSelected: (value) {
              switch (value) {
                case 'create':
                  _showCreateChannelDialog();
                case 'join':
                  _showJoinChannelDialog();
                case 'import':
                  _importChannelByCode();
                case 'refresh':
                  _refreshChannels();
                case 'disconnect':
                  _disconnect();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'create',
                child: ListTile(
                  leading: const Icon(Icons.add_rounded),
                  title: Text(context.l10n.meshcoreChannelsCreateChannel),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              PopupMenuItem(
                value: 'join',
                child: ListTile(
                  leading: const Icon(Icons.login_rounded),
                  title: Text(context.l10n.meshcoreChannelsJoinChannel),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: const Icon(Icons.qr_code_scanner_rounded),
                  title: Text(context.l10n.meshcoreImportChannel),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              PopupMenuItem(
                value: 'refresh',
                child: ListTile(
                  leading: const Icon(Icons.refresh_rounded),
                  title: Text(context.l10n.meshcoreChannelsRefreshChannels),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'disconnect',
                child: ListTile(
                  leading: const Icon(Icons.link_off_rounded),
                  title: Text(context.l10n.meshcoreDisconnect),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
        body: !isConnected
            ? _buildDisconnectedState()
            : channelsState.isLoading && allChannels.isEmpty
            ? _buildLoadingState()
            : channels.isEmpty
            ? _buildEmptyState(deviceName)
            : _buildChannelsList(
                channels,
                allChannels,
                channelsState.isLoading,
              ),
      ),
    );
  }

  List<MeshCoreChannel> _applyFilter(List<MeshCoreChannel> channels) {
    switch (_activeFilter) {
      case _MeshCoreChannelFilter.all:
        return channels;
      case _MeshCoreChannelFilter.public:
        return channels.where((channel) => channel.isPublic).toList();
      case _MeshCoreChannelFilter.private:
        return channels.where((channel) => !channel.isPublic).toList();
    }
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppTheme.spacing16),
          Text(
            context.l10n.meshcoreLoadingChannels,
            style: TextStyle(color: context.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildDisconnectedState() {
    return AnimatedEmptyState(
      config: AnimatedEmptyStateConfig(
        icons: const [
          Icons.link_off_rounded,
          Icons.router_outlined,
          Icons.forum_outlined,
          Icons.tag_rounded,
          Icons.lock_rounded,
          Icons.public_rounded,
        ],
        taglines: [
          context.l10n.meshcoreDisconnectedChannelsDescription,
          context.l10n.meshcoreChannelsEmptyTagline1,
          context.l10n.meshcoreChannelsEmptyTagline2,
        ],
        titlePrefix: '',
        titleKeyword: context.l10n.meshcoreDisconnectedTitle,
        titleSuffix: '',
      ),
    );
  }

  Widget _buildEmptyState(String deviceName) {
    // [deviceName] is no longer surfaced inline — the connected device is
    // visible via the device-status button in the app bar; a separate
    // "Connected to X" badge inside the empty state would be duplicate UI
    // and clash with the canonical AnimatedEmptyState shape. The "Join
    // Channel" affordance stays accessible via the AppBarOverflowMenu;
    // "Create Channel" is the primary empty-state action.
    return AnimatedEmptyState(
      config: AnimatedEmptyStateConfig(
        icons: const [
          Icons.forum_outlined,
          Icons.tag_rounded,
          Icons.broadcast_on_personal_outlined,
          Icons.lock_rounded,
          Icons.public_rounded,
          Icons.podcasts_rounded,
        ],
        taglines: [
          context.l10n.meshcoreChannelsEmptyTagline1,
          context.l10n.meshcoreChannelsEmptyTagline2,
          context.l10n.meshcoreChannelsEmptyTagline3,
        ],
        titlePrefix: context.l10n.meshcoreChannelsEmptyTitlePrefix,
        titleKeyword: context.l10n.meshcoreChannelsEmptyTitleKeyword,
        titleSuffix: context.l10n.meshcoreChannelsEmptyTitleSuffix,
        actionLabel: context.l10n.meshcoreCreateChannelButton,
        actionIcon: Icons.add_rounded,
        onAction: _showCreateChannelDialog,
        accentColor: AccentColors.purple,
      ),
    );
  }

  Widget _buildChannelsList(
    List<MeshCoreChannel> channels,
    List<MeshCoreChannel> allChannels,
    bool isLoading,
  ) {
    final publicCount = allChannels.where((channel) => channel.isPublic).length;
    final privateCount = allChannels.length - publicCount;
    final textScaler = MediaQuery.textScalerOf(context);

    return RefreshIndicator(
      onRefresh: _refreshChannels,
      child: CustomScrollView(
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: SearchFilterHeaderDelegate(
              searchController: _searchController,
              searchQuery: _searchQuery,
              onSearchChanged: (value) => setState(() => _searchQuery = value),
              hintText: context.l10n.channelsSearchHint,
              textScaler: textScaler,
              rebuildKey: Object.hashAll([
                _activeFilter,
                allChannels.length,
                publicCount,
                privateCount,
              ]),
              filterChips: [
                StatusFilterChip(
                  label: context.l10n.channelsFilterAll,
                  count: allChannels.length,
                  isSelected: _activeFilter == _MeshCoreChannelFilter.all,
                  onTap: () => setState(
                    () => _activeFilter = _MeshCoreChannelFilter.all,
                  ),
                ),
                StatusFilterChip(
                  label: context.l10n.meshcorePublic,
                  count: publicCount,
                  isSelected: _activeFilter == _MeshCoreChannelFilter.public,
                  icon: Icons.public_rounded,
                  color: AccentColors.purple,
                  onTap: () => setState(
                    () => _activeFilter = _MeshCoreChannelFilter.public,
                  ),
                ),
                StatusFilterChip(
                  label: context.l10n.meshcorePrivate,
                  count: privateCount,
                  isSelected: _activeFilter == _MeshCoreChannelFilter.private,
                  icon: Icons.lock_rounded,
                  color: AccentColors.green,
                  onTap: () => setState(
                    () => _activeFilter = _MeshCoreChannelFilter.private,
                  ),
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing16,
              AppTheme.spacing8,
              AppTheme.spacing16,
              AppTheme.spacing16,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final channel = channels[index];
                return _ChannelCard(
                  channel: channel,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          MeshCoreChatScreen.channel(channel: channel),
                    ),
                  ),
                  onLongPress: () => _showChannelOptions(channel),
                );
              }, childCount: channels.length),
            ),
          ),
          if (isLoading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacing8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: AppTheme.spacing16,
                      height: AppTheme.spacing16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: AppTheme.spacing8),
                    Text(
                      context.l10n.meshcoreRefreshing,
                      style: TextStyle(color: context.textTertiary),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _refreshChannels() async {
    final notifier = ref.read(meshCoreChannelsProvider.notifier);
    await notifier.refresh();
  }

  Future<void> _showCreateChannelDialog() async {
    final nameController = TextEditingController();
    var isHashtag = true;

    await AppBottomSheet.show<void>(
      context: context,
      child: StatefulBuilder(
        builder: (ctx, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.meshcoreCreateChannelDialogTitle,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spacing16),
            TextField(
              controller: nameController,
              autofocus: true,
              maxLength: 32,
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              decoration: InputDecoration(
                labelText: context.l10n.meshcoreChannelNameLabel,
                labelStyle: TextStyle(color: context.textSecondary),
                hintText: isHashtag
                    ? context.l10n.meshcoreChannelNameHintHashtag
                    : context.l10n.meshcoreChannelNameHint,
                hintStyle: TextStyle(color: SemanticColors.muted),
                prefixText: isHashtag ? '#' : null,
                prefixStyle: TextStyle(color: AccentColors.purple),
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
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                  borderSide: BorderSide(color: context.accentColor),
                ),
                counterText: '',
              ),
              style: TextStyle(color: context.textPrimary),
            ),
            const SizedBox(height: AppTheme.spacing16),
            ListTile(
              title: Text(
                context.l10n.meshcorePublicHashtagChannel,
                style: TextStyle(color: context.textPrimary, fontSize: 14),
              ),
              subtitle: Text(
                isHashtag
                    ? context.l10n.meshcorePskDerivedFromName
                    : context.l10n.meshcoreRandomPskPrivate,
                style: TextStyle(color: context.textTertiary, fontSize: 12),
              ),
              trailing: ThemedSwitch(
                value: isHashtag,
                onChanged: (v) => setSheetState(() => isHashtag = v),
              ),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: AppTheme.spacing24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: SemanticColors.divider),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                      ),
                    ),
                    child: Text(context.l10n.meshcoreCancel),
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: PrimaryGradientButton(
                    label: context.l10n.meshcoreCreate,
                    icon: Icons.add_rounded,
                    accentColor: AccentColors.purple,
                    onPressed: () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) {
                        showErrorSnackBar(
                          ctx,
                          context.l10n.meshcoreErrorEnterChannelName,
                        );
                        return;
                      }

                      Navigator.pop(ctx);

                      // Create channel with next available index
                      final channelsState = ref.read(meshCoreChannelsProvider);
                      final existingIndices = channelsState.channels
                          .map((c) => c.index)
                          .toSet();
                      var newIndex = 0;
                      for (var i = 0; i < 8; i++) {
                        if (!existingIndices.contains(i)) {
                          newIndex = i;
                          break;
                        }
                      }

                      final channel = isHashtag
                          ? MeshCoreChannel.publicChannel(newIndex, name)
                          : MeshCoreChannel(
                              index: newIndex,
                              name: name,
                              psk: Uint8List.fromList(
                                List.generate(16, (i) => i),
                              ),
                            );

                      await ref
                          .read(meshCoreChannelsProvider.notifier)
                          .setChannel(channel);

                      if (mounted) {
                        showSuccessSnackBar(
                          context,
                          context.l10n.meshcoreChannelCreated(channel.name),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
  }

  void _showJoinChannelDialog() {
    AppBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.meshcoreChannelsJoinChannel,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: context.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          _buildJoinOption(
            icon: Icons.tag_rounded,
            title: context.l10n.meshcoreJoinHashtagChannel,
            subtitle: context.l10n.meshcoreJoinHashtagChannelSubtitle,
            onTap: () {
              Navigator.pop(context);
              _showJoinHashtagDialog();
            },
          ),
          _buildJoinOption(
            icon: Icons.qr_code_scanner_rounded,
            title: context.l10n.meshcoreScanQrCode,
            subtitle: context.l10n.meshcoreScanChannelQrSubtitle,
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const MeshCoreQrScannerScreen(
                    mode: MeshCoreScanMode.channel,
                  ),
                ),
              );
            },
          ),
          _buildJoinOption(
            icon: Icons.keyboard_rounded,
            title: context.l10n.meshcoreEnterChannelCode,
            subtitle: context.l10n.meshcoreEnterChannelCodeSubtitle,
            onTap: () {
              Navigator.pop(context);
              _showEnterCodeDialog();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildJoinOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(AppTheme.spacing10),
        decoration: BoxDecoration(
          color: AccentColors.purple.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppTheme.radius12),
        ),
        child: Icon(icon, color: AccentColors.purple),
      ),
      title: Text(title, style: TextStyle(color: context.textPrimary)),
      subtitle: Text(subtitle, style: TextStyle(color: context.textSecondary)),
      onTap: onTap,
    );
  }

  void _showJoinHashtagDialog() async {
    final controller = TextEditingController();
    final l10n = context.l10n;

    final name = await AppBottomSheet.show<String>(
      context: context,
      child: Builder(
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.meshcoreJoinHashtagChannel,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spacing16),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 32,
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              decoration: InputDecoration(
                labelText: l10n.meshcoreChannelNameLabel,
                labelStyle: TextStyle(color: context.textSecondary),
                prefixText: '#',
                prefixStyle: TextStyle(color: AccentColors.purple),
                hintText: l10n.meshcoreChannelNameHintGeneral,
                hintStyle: TextStyle(color: SemanticColors.muted),
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
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                  borderSide: BorderSide(color: context.accentColor),
                ),
                counterText: '',
              ),
              style: TextStyle(color: context.textPrimary),
            ),
            const SizedBox(height: AppTheme.spacing16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: SemanticColors.divider),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                      ),
                    ),
                    child: Text(context.l10n.meshcoreCancel),
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: PrimaryGradientButton(
                    label: context.l10n.meshcoreJoin,
                    icon: Icons.login_rounded,
                    accentColor: AccentColors.purple,
                    onPressed: () {
                      final text = controller.text.trim();
                      if (text.isEmpty) {
                        showErrorSnackBar(
                          sheetContext,
                          l10n.meshcoreErrorEnterChannelName,
                        );
                        return;
                      }
                      Navigator.pop(sheetContext, text);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;

    // Find next available index
    final channelsState = ref.read(meshCoreChannelsProvider);
    final existingIndices = channelsState.channels.map((c) => c.index).toSet();
    var newIndex = 0;
    for (var i = 0; i < 8; i++) {
      if (!existingIndices.contains(i)) {
        newIndex = i;
        break;
      }
    }

    final channel = MeshCoreChannel.publicChannel(newIndex, name);
    await ref.read(meshCoreChannelsProvider.notifier).setChannel(channel);

    if (mounted) {
      showSuccessSnackBar(
        context,
        context.l10n.meshcoreJoinedHashtagChannel(name),
      );
    }
  }

  /// D29 Part D: paste-code import path for channels.
  ///
  /// Mirrors `_showEnterCodeDialog` shape (single text field + parse +
  /// `setChannel`) but is reachable from the overflow menu's "Import
  /// Channel" entry, awaits the wire ACK, and surfaces explicit
  /// success/failure rather than the fire-and-forget pattern the
  /// pre-existing join-by-code flow uses. Logs do NOT include the
  /// pasted code or PSK — only success/failure outcomes.
  Future<void> _importChannelByCode() async {
    final controller = TextEditingController();
    await AppBottomSheet.show<void>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.meshcoreImportChannelTitle,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            maxLength: 256,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            textAlignVertical: TextAlignVertical.top,
            decoration: InputDecoration(
              hintText: context.l10n.meshcoreImportChannelHint,
              hintStyle: TextStyle(color: SemanticColors.muted),
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
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius8),
                borderSide: BorderSide(color: context.accentColor),
              ),
              prefixIcon: Icon(
                Icons.qr_code_scanner_rounded,
                color: context.textSecondary,
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 48,
                minHeight: 48,
              ),
              counterText: '',
            ),
            style: TextStyle(
              color: context.textPrimary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
          const SizedBox(height: AppTheme.spacing24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: SemanticColors.divider),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                  ),
                  child: Text(context.l10n.meshcoreCancel),
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: PrimaryGradientButton(
                  label: context.l10n.meshcoreImportChannel,
                  icon: Icons.qr_code_scanner_rounded,
                  onPressed: () async {
                    final code = controller.text.trim();
                    if (code.isEmpty) {
                      showErrorSnackBar(
                        context,
                        context.l10n.meshcoreErrorEnterChannelCode,
                      );
                      return;
                    }
                    // Pick the first free channel slot (firmware caps
                    // at 8). If the slot search overflows we still
                    // pass index 0; `setChannel` returns false and
                    // the user sees a clear error.
                    final channelsState = ref.read(meshCoreChannelsProvider);
                    final existingIndices = channelsState.channels
                        .map((c) => c.index)
                        .toSet();
                    var newIndex = 0;
                    for (var i = 0; i < 8; i++) {
                      if (!existingIndices.contains(i)) {
                        newIndex = i;
                        break;
                      }
                    }

                    final parsed = parseChannelCode(code, index: newIndex);
                    if (parsed == null) {
                      showErrorSnackBar(
                        context,
                        context.l10n.meshcoreInvalidChannelCode,
                      );
                      return;
                    }
                    Navigator.pop(context);
                    final ok = await ref
                        .read(meshCoreChannelsProvider.notifier)
                        .setChannel(parsed);
                    if (!mounted) return;
                    if (ok) {
                      showSuccessSnackBar(
                        context,
                        context.l10n.meshcoreChannelImported(
                          parsed.displayName,
                        ),
                      );
                    } else {
                      showErrorSnackBar(
                        context,
                        context.l10n.meshcoreChannelImportFailed(
                          parsed.displayName,
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEnterCodeDialog() {
    final controller = TextEditingController();

    AppBottomSheet.show<void>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.meshcoreEnterChannelCode,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            maxLength: 256,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            textAlignVertical: TextAlignVertical.top,
            decoration: InputDecoration(
              hintText: context.l10n.meshcorePasteChannelCodeHint,
              hintStyle: TextStyle(color: SemanticColors.muted),
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
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius8),
                borderSide: BorderSide(color: context.accentColor),
              ),
              prefixIcon: Icon(Icons.key_rounded, color: context.textSecondary),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 48,
                minHeight: 48,
              ),
              counterText: '',
            ),
            style: TextStyle(
              color: context.textPrimary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
          const SizedBox(height: AppTheme.spacing24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: SemanticColors.divider),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                  ),
                  child: Text(context.l10n.meshcoreCancel),
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: PrimaryGradientButton(
                  label: context.l10n.meshcoreJoin,
                  icon: Icons.login_rounded,
                  onPressed: () {
                    final code = controller.text.trim();
                    if (code.isEmpty) {
                      showErrorSnackBar(
                        context,
                        context.l10n.meshcoreErrorEnterChannelCode,
                      );
                      return;
                    }

                    // Find next available channel index
                    final channelsState = ref.read(meshCoreChannelsProvider);
                    final existingIndices = channelsState.channels
                        .map((c) => c.index)
                        .toSet();
                    var newIndex = 0;
                    for (var i = 0; i < 8; i++) {
                      if (!existingIndices.contains(i)) {
                        newIndex = i;
                        break;
                      }
                    }

                    final channel = parseChannelCode(code, index: newIndex);
                    if (channel != null) {
                      Navigator.pop(context);
                      ref
                          .read(meshCoreChannelsProvider.notifier)
                          .setChannel(channel);
                      showSuccessSnackBar(
                        context,
                        context.l10n.meshcoreJoinedChannel(channel.displayName),
                      );
                    } else {
                      showErrorSnackBar(
                        context,
                        context.l10n.meshcoreInvalidChannelCodeFormat,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  void _showChannelOptions(MeshCoreChannel channel) {
    AppBottomSheet.showActions<void>(
      context: context,
      header: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          channel.displayName,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      actions: [
        BottomSheetAction(
          icon: Icons.chat_rounded,
          iconColor: AccentColors.purple,
          label: context.l10n.meshcoreOpenChannel,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    MeshCoreChatScreen.channel(channel: channel),
              ),
            );
          },
        ),
        BottomSheetAction(
          icon: Icons.qr_code_rounded,
          label: context.l10n.meshcoreShareChannel,
          onTap: () {
            // D29 Part D: surface the channel as a QR + copyable code.
            // The code carries the PSK so this is intentionally an
            // explicit user action (no auto-share). The subtitle
            // surfaces the PSK warning so the user knows what they
            // are about to expose.
            final code = generateChannelCode(channel);
            QrShareSheet.show(
              context: context,
              title: channel.displayName,
              subtitle: context.l10n.meshcoreShareChannelSubtitle,
              qrData: code,
              infoText: context.l10n.meshcoreShareChannelSubtitle,
            );
          },
        ),
        BottomSheetAction(
          icon: Icons.delete_rounded,
          label: context.l10n.meshcoreLeaveChannel,
          isDestructive: true,
          onTap: () {
            _confirmLeaveChannel(channel);
          },
        ),
      ],
    );
  }

  void _confirmLeaveChannel(MeshCoreChannel channel) async {
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: context.l10n.meshcoreLeaveChannelTitle,
      message: context.l10n.meshcoreLeaveChannelMessage(channel.displayName),
      confirmLabel: context.l10n.meshcoreLeave,
      isDestructive: true,
    );

    if (confirmed != true || !mounted) return;

    // Clear channel by setting empty name and default PSK
    await ref
        .read(meshCoreChannelsProvider.notifier)
        .setChannel(MeshCoreChannel.empty(channel.index));
    if (mounted) {
      showSuccessSnackBar(
        context,
        context.l10n.meshcoreLeftChannel(channel.displayName),
      );
    }
  }

  void _disconnect() async {
    final coordinator = ref.read(connectionCoordinatorProvider);
    await coordinator.disconnect();
  }
}

/// Card widget for displaying a single channel.
///
/// D19.C: now a `ConsumerWidget` so the tile reflects the live
/// last-message preview + unread badge from
/// `meshCoreConversationsProvider`. Pre-D19 the tile rendered only
/// static channel metadata, so an inbound message that the
/// conversations notifier had ingested (D17/D18 path) was invisible
/// until the user entered the chat.
class _ChannelCard extends ConsumerWidget {
  final MeshCoreChannel channel;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ChannelCard({
    required this.channel,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPublic = channel.isPublic;
    final conversationsState = ref.watch(meshCoreConversationsProvider);
    final conversationId = 'channel_${channel.index}';
    final conversation = conversationsState.conversations
        .where((c) => c.id == conversationId)
        .cast<MeshCoreConversation?>()
        .firstWhere((_) => true, orElse: () => null);
    final lastMessageText = conversation?.lastMessageText;
    final unreadCount = conversation?.unreadCount ?? 0;

    return BouncyTap(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      onLongPress: onLongPress,
      scaleFactor: 0.98,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border.all(color: context.border, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isPublic ? context.accentColor : context.background,
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
                child: Center(
                  child: Text(
                    '${channel.index}',
                    style: TextStyle(
                      color: isPublic ? Colors.white : context.textSecondary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.displayName,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    if (lastMessageText != null &&
                        lastMessageText.isNotEmpty) ...[
                      const SizedBox(height: AppTheme.spacing2),
                      Text(
                        lastMessageText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: unreadCount > 0
                              ? context.textPrimary
                              : context.textSecondary,
                          fontSize: 13,
                          fontWeight: unreadCount > 0
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppTheme.spacing4),
                    Row(
                      children: [
                        Icon(
                          isPublic ? Icons.lock_open : Icons.lock,
                          size: 14,
                          color: isPublic
                              ? context.textTertiary
                              : context.accentColor,
                        ),
                        const SizedBox(width: AppTheme.spacing6),
                        Text(
                          isPublic
                              ? context.l10n.meshcorePublic
                              : context.l10n.meshcorePrivate,
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacing12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: context.accentColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius4,
                            ),
                          ),
                          child: Text(
                            context.l10n.meshcoreSlotIndex(channel.index),
                            style: TextStyle(
                              color: context.accentColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (unreadCount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.accentColor,
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacing6),
              ],
              Icon(Icons.chevron_right_rounded, color: context.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
