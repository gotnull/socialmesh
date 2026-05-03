// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// lint-allow: keyboard-dismissal — TextFields are in bottom-sheet sub-widgets, not the main screen
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animated_empty_state.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/app_bar_overflow_menu.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/qr_share_sheet.dart';
import '../../../models/meshcore_channel.dart';
import '../../../providers/app_providers.dart';
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

class _MeshCoreChannelsScreenState extends ConsumerState<MeshCoreChannelsScreen>
    with LifecycleSafeMixin<MeshCoreChannelsScreen> {
  @override
  Widget build(BuildContext context) {
    final linkStatus = ref.watch(linkStatusProvider);
    final isConnected = linkStatus.isConnected;
    final deviceName = linkStatus.deviceName ?? 'MeshCore';
    final channelsState = ref.watch(meshCoreChannelsProvider);

    // Filter to only show configured channels (non-empty name or PSK)
    final channels = channelsState.channels
        .where((c) => c.name.isNotEmpty || !c.isDefaultPsk)
        .toList();

    return GlassScaffold.body(
      hasScrollBody: true,
      leading: const MeshCoreHamburgerMenuButton(),
      title:
          '${context.l10n.meshcoreChannelsTitle}${channels.isEmpty ? '' : ' (${channels.length})'}',
      actions: [
        const MeshCoreDeviceStatusButton(),
        AppBarOverflowMenu<String>(
          onSelected: (value) {
            switch (value) {
              case 'create':
                _showCreateChannelDialog();
              case 'join':
                _showJoinChannelDialog();
              case 'refresh':
                _refreshChannels();
              case 'disconnect':
                _disconnect();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'create',
              child: Row(
                children: [
                  Icon(
                    Icons.add_rounded,
                    color: context.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Text(
                    context.l10n.meshcoreChannelsCreateChannel,
                    style: TextStyle(color: context.textPrimary),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'join',
              child: Row(
                children: [
                  Icon(
                    Icons.login_rounded,
                    color: context.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Text(
                    context.l10n.meshcoreChannelsJoinChannel,
                    style: TextStyle(color: context.textPrimary),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: [
                  Icon(
                    Icons.refresh_rounded,
                    color: context.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Text(
                    context.l10n.meshcoreChannelsRefreshChannels,
                    style: TextStyle(color: context.textPrimary),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'disconnect',
              child: Row(
                children: [
                  Icon(
                    Icons.link_off_rounded,
                    color: context.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Text(
                    context.l10n.meshcoreDisconnect,
                    style: TextStyle(color: context.textPrimary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
      body: !isConnected
          ? _buildDisconnectedState()
          : channelsState.isLoading && channels.isEmpty
          ? _buildLoadingState()
          : channels.isEmpty
          ? _buildEmptyState(deviceName)
          : _buildChannelsList(channels, channelsState.isLoading),
    );
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.link_off_rounded, size: 64, color: context.textTertiary),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              context.l10n.meshcoreDisconnectedTitle,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: context.textPrimary),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              context.l10n.meshcoreDisconnectedChannelsDescription,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: context.textSecondary),
            ),
          ],
        ),
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

  Widget _buildChannelsList(List<MeshCoreChannel> channels, bool isLoading) {
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshChannels,
            child: ListView.builder(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              itemCount: channels.length,
              itemBuilder: (context, index) {
                final channel = channels[index];
                return _ChannelCard(
                  channel: channel,
                  onTap: () => _showChannelDetails(channel),
                  onLongPress: () => _showChannelOptions(channel),
                );
              },
            ),
          ),
        ),
        if (isLoading)
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
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
      ],
    );
  }

  Future<void> _refreshChannels() async {
    final notifier = ref.read(meshCoreChannelsProvider.notifier);
    await notifier.refresh();
  }

  void _showCreateChannelDialog() {
    final nameController = TextEditingController();
    var isHashtag = true;

    AppBottomSheet.show(
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
                  child: FilledButton(
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
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AccentColors.purple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                      ),
                    ),
                    child: Text(context.l10n.meshcoreCreate),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
              decoration: InputDecoration(
                labelText: l10n.meshcoreChannelNameLabel,
                prefixText: '#',
                prefixStyle: TextStyle(color: AccentColors.purple),
                hintText: l10n.meshcoreChannelNameHintGeneral,
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
                  child: FilledButton(
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
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AccentColors.purple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                      ),
                    ),
                    child: Text(context.l10n.meshcoreJoin),
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

  void _showEnterCodeDialog() {
    final controller = TextEditingController();

    AppBottomSheet.show(
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
                child: FilledButton(
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
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: context.accentColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                  ),
                  child: Text(context.l10n.meshcoreJoin),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showChannelDetails(MeshCoreChannel channel) {
    final channelCode = generateChannelCode(channel);

    QrShareSheet.show(
      context: context,
      title: channel.displayName,
      subtitle: channel.isPublic
          ? context.l10n.meshcorePublicChannel
          : context.l10n.meshcorePrivateChannel,
      qrData: channelCode,
      infoText: context.l10n.meshcoreScanQrToJoinChannel,
    );
  }

  void _showChannelOptions(MeshCoreChannel channel) {
    AppBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            channel.displayName,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: context.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.chat_rounded, color: AccentColors.purple),
            title: Text(
              context.l10n.meshcoreOpenChannel,
              style: TextStyle(color: context.textPrimary),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      MeshCoreChatScreen.channel(channel: channel),
                ),
              );
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.share_rounded, color: context.textSecondary),
            title: Text(
              context.l10n.meshcoreShareChannel,
              style: TextStyle(color: context.textPrimary),
            ),
            onTap: () {
              Navigator.pop(context);
              final code = generateChannelCode(channel);
              Clipboard.setData(ClipboardData(text: code));
              showSuccessSnackBar(
                context,
                context.l10n.meshcoreChannelCodeCopied,
              );
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_rounded, color: AppTheme.errorRed),
            title: Text(
              context.l10n.meshcoreLeaveChannel,
              style: TextStyle(color: AppTheme.errorRed),
            ),
            onTap: () {
              Navigator.pop(context);
              _confirmLeaveChannel(channel);
            },
          ),
        ],
      ),
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
class _ChannelCard extends StatelessWidget {
  final MeshCoreChannel channel;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ChannelCard({
    required this.channel,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isPublic = channel.isPublic;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border.all(color: context.border, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing12),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AccentColors.purple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
                child: Center(
                  child: Icon(
                    isPublic ? Icons.tag_rounded : Icons.lock_rounded,
                    color: AccentColors.purple,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              // Info
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
                    const SizedBox(height: AppTheme.spacing4),
                    Row(
                      children: [
                        Icon(
                          isPublic
                              ? Icons.public_rounded
                              : Icons.vpn_key_rounded,
                          size: 14,
                          color: context.textTertiary,
                        ),
                        const SizedBox(width: AppTheme.spacing4),
                        Text(
                          isPublic
                              ? context.l10n.meshcorePublic
                              : context.l10n.meshcorePrivate,
                          style: TextStyle(
                            color: context.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacing12),
                        Icon(
                          Icons.memory_rounded,
                          size: 14,
                          color: context.textTertiary,
                        ),
                        const SizedBox(width: AppTheme.spacing4),
                        Text(
                          context.l10n.meshcoreSlotIndex(channel.index),
                          style: TextStyle(
                            color: context.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: context.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
