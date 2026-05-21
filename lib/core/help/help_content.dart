// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:socialmesh/features/onboarding/widgets/mesh_node_brain.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

/// Direction for coach mark arrows
enum ArrowDirection {
  topLeft,
  topCenter,
  topRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
  leftTop,
  leftCenter,
  leftBottom,
  rightTop,
  rightCenter,
  rightBottom,
}

/// A single step in a help tour
class HelpStep {
  final String id;
  final String bubbleText;
  final MeshBrainMood icoMood;
  final GlobalKey? targetKey; // Widget to spotlight
  final ArrowDirection? arrowDirection;
  final bool canGoBack;
  final bool canSkip;
  final Duration? autoAdvanceDelay;

  const HelpStep({
    required this.id,
    required this.bubbleText,
    this.icoMood = MeshBrainMood.speaking,
    this.targetKey,
    this.arrowDirection,
    this.canGoBack = true,
    this.canSkip = true,
    this.autoAdvanceDelay,
  });
}

/// A complete help topic/tour
class HelpTopic {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final List<HelpStep> steps;
  final String category;
  final int priority; // Lower = higher priority

  const HelpTopic({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.steps,
    required this.category,
    this.priority = 100,
  });
}

/// Help content database
class HelpContent {
  HelpContent._();

  // Categories
  static const String catChannels = 'Channels';
  static const String catMessaging = 'Messaging';
  static const String catNodes = 'Nodes';
  static const String catDevice = 'Device';
  static const String catNetwork = 'Network';
  static const String catAutomations = 'Automations';
  static const String catSettings = 'Settings';
  static const String catLegal = 'Legal & Safety';
  // ============================================================================
  // CHANNEL CREATION HELP
  // ============================================================================

  static final HelpTopic channelCreation = HelpTopic(
    id: 'channel_creation',
    title: 'Creating a Channel',
    description: 'Learn how to create and configure mesh channels',
    icon: Icons.group_add,
    category: catChannels,
    priority: 1,
    steps: [
      HelpStep(
        id: 'channel_intro',
        bubbleText:
            "Let's make a **channel**! It's like a walkie-talkie. Only your friends who know the secret can listen in.",
        icoMood: MeshBrainMood.excited,
        canGoBack: false,
      ),
      HelpStep(
        id: 'channel_name',
        bubbleText:
            "First, pick a **name** for your channel. Something easy to remember, like 'Family' or 'Hiking Buddies'.",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'privacy_level',
        bubbleText:
            "How secret should your channel be?\n\n**OPEN**: Anyone can listen in.\n**SHARED**: Like a password everyone knows.\n**PRIVATE**: Only friends you invite.\n**MAXIMUM**: Super duper secret!",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'encryption_key',
        bubbleText:
            "I made a **secret key** for you! It scrambles your messages so only your friends can read them. Like a secret code!",
        icoMood: MeshBrainMood.playful,
      ),
      HelpStep(
        id: 'channel_complete',
        bubbleText:
            "All done! Show your friends the **QR code** and they can join your channel. Easy peasy!",
        icoMood: MeshBrainMood.celebrating,
        canSkip: false,
      ),
    ],
  );

  // ============================================================================
  // ENCRYPTION LEVELS HELP
  // ============================================================================

  static final HelpTopic encryptionLevels = HelpTopic(
    id: 'encryption_levels',
    title: 'Channel Encryption',
    description: 'Understanding privacy and encryption options',
    icon: Icons.lock,
    category: catChannels,
    priority: 2,
    steps: [
      HelpStep(
        id: 'encryption_intro',
        bubbleText:
            "Let me explain **encryption levels**. It's like choosing how secret your messages are!",
        icoMood: MeshBrainMood.curious,
        canGoBack: false,
      ),
      HelpStep(
        id: 'default_key',
        bubbleText:
            "**DEFAULT KEY** means everyone in the mesh can read your messages. It's public! Use this for general announcements or testing.",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'psk_encryption',
        bubbleText:
            "**PSK** (Pre-Shared Key) means you generate a random secret key. Only people with this exact key can decode your messages. Much more private!",
        icoMood: MeshBrainMood.approving,
      ),
      HelpStep(
        id: 'psk_sharing',
        bubbleText:
            "Share your PSK via **QR code**! When someone scans it, they get the key and channel settings. Easy peasy!",
        icoMood: MeshBrainMood.playful,
      ),
    ],
  );

  // ============================================================================
  // MESSAGE ROUTING HELP
  // ============================================================================

  static final HelpTopic messageRouting = HelpTopic(
    id: 'message_routing',
    title: 'How Messages Travel',
    description: 'Understanding mesh routing and message hops',
    icon: Icons.alt_route,
    category: catMessaging,
    priority: 5,
    steps: [
      HelpStep(
        id: 'routing_intro',
        bubbleText:
            "Want to see how I work? When you send a message, I **bounce it from node to node** like a game of hot potato!",
        icoMood: MeshBrainMood.excited,
        canGoBack: false,
      ),
      HelpStep(
        id: 'routing_hops',
        bubbleText:
            "Each **hop** is when a node receives your message and forwards it. Most messages need **1-3 hops** to reach their destination!",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'routing_router_role',
        bubbleText:
            "**ROUTER** nodes are the mesh superheroes - they relay messages for everyone! **CLIENT** nodes only send/receive their own messages.",
        icoMood: MeshBrainMood.proud,
      ),
      HelpStep(
        id: 'routing_store_forward',
        bubbleText:
            "**Store & Forward** is awesome! If the recipient hasn't been heard recently, I'll hold onto the message and deliver it when a packet arrives.",
        icoMood: MeshBrainMood.playful,
      ),
    ],
  );

  // ============================================================================
  // NODES LIST HELP
  // ============================================================================

  static final HelpTopic nodesOverview = HelpTopic(
    id: 'nodes_overview',
    title: 'Your Mesh Network',
    description: 'Understanding the nodes in your mesh',
    icon: Icons.hub,
    category: catNodes,
    priority: 3,
    steps: [
      HelpStep(
        id: 'nodes_intro',
        bubbleText:
            "This is your **mesh network**! Every device you see here is a node that can talk to you.",
        icoMood: MeshBrainMood.excited,
        canGoBack: false,
      ),
      HelpStep(
        id: 'nodes_status',
        bubbleText:
            "**Green dot** means **Online** (heard recently). **Yellow** means **Seen recently**. **Gray** means **Offline**. LoRa has no offline signal—status is inferred.",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'nodes_info',
        bubbleText:
            "Each card shows the node's **name**, **battery level**, and **signal strength**. Tap any node to see more details!",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'nodes_filters',
        bubbleText:
            "Use the **filters** at the top to find specific nodes. You can show only **Online** nodes, favorites, or nodes with GPS.",
        icoMood: MeshBrainMood.approving,
      ),
      HelpStep(
        id: 'nodes_actions',
        bubbleText:
            "Tap a node to **send a message**, see their **location on the map**, or check their **telemetry data**!",
        icoMood: MeshBrainMood.playful,
      ),
    ],
  );

  // ============================================================================
  // NODE ROLES HELP
  // ============================================================================

  static final HelpTopic nodeRoles = HelpTopic(
    id: 'node_roles',
    title: 'Node Roles',
    description: 'CLIENT vs ROUTER vs REPEATER explained',
    icon: Icons.settings_input_antenna,
    category: catNodes,
    priority: 4,
    steps: [
      HelpStep(
        id: 'roles_intro',
        bubbleText:
            "**Node roles** determine how your device helps the mesh. Let me break it down for you!",
        icoMood: MeshBrainMood.curious,
        canGoBack: false,
      ),
      HelpStep(
        id: 'role_client',
        bubbleText:
            "**CLIENT**: Your device sends and receives messages but doesn't relay for others. Great for **battery life**!",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'role_router',
        bubbleText:
            "**ROUTER**: You're a mesh superhero! You relay messages for everyone. Uses more battery but makes the mesh stronger!",
        icoMood: MeshBrainMood.proud,
      ),
      HelpStep(
        id: 'role_router_late',
        bubbleText:
            "**ROUTER LATE**: Rebroadcasts after other routers. Extends coverage without taking priority hops. Great for backup relays!",
        icoMood: MeshBrainMood.approving,
      ),
      HelpStep(
        id: 'role_client_base',
        bubbleText:
            "**CLIENT BASE**: Base station for your favorited nodes. Routes their packets like a router, handles everything else like a client!",
        icoMood: MeshBrainMood.energized,
      ),
    ],
  );

  // ============================================================================
  // REGION SELECTION HELP
  // ============================================================================

  static final HelpTopic regionSelection = HelpTopic(
    id: 'region_selection',
    title: 'Selecting Your Region',
    description: 'Frequency bands and legal compliance',
    icon: Icons.public,
    category: catDevice,
    priority: 3,
    steps: [
      HelpStep(
        id: 'region_intro',
        bubbleText:
            "This is important! Your **region** determines which radio frequencies you can legally use.",
        icoMood: MeshBrainMood.alert,
        canGoBack: false,
      ),
      HelpStep(
        id: 'region_legal',
        bubbleText:
            "Each country has different rules. Using the **wrong frequency** can be illegal! Always match your physical location.",
        icoMood: MeshBrainMood.nervous,
      ),
      HelpStep(
        id: 'region_bands',
        bubbleText:
            "Most regions use **915MHz** (Americas) or **868MHz** (Europe). Some use **433MHz**. Your device's hardware must support the frequency!",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'region_warning',
        bubbleText:
            "Wrong region = **can't communicate** with others! Make sure everyone in your mesh uses the same region setting.",
        icoMood: MeshBrainMood.nervous,
      ),
    ],
  );

  // ============================================================================
  // DEVICE CONNECTION HELP
  // ============================================================================

  static final HelpTopic deviceConnection = HelpTopic(
    id: 'device_connection',
    title: 'Connecting Your Device',
    description: 'BLE vs USB and pairing process',
    icon: Icons.bluetooth,
    category: catDevice,
    priority: 2,
    steps: [
      HelpStep(
        id: 'connection_intro',
        bubbleText:
            "Let's connect your Meshtastic device! There are two ways: **Bluetooth** or **USB**.",
        icoMood: MeshBrainMood.excited,
        canGoBack: false,
      ),
      HelpStep(
        id: 'connection_ble',
        bubbleText:
            "**BLUETOOTH** (BLE): Wireless! Your device shows up as **Meshtastic_XXXX**. Just tap to connect. Works while device is in your pocket!",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'connection_usb',
        bubbleText:
            "**USB**: Plug in with a cable. More reliable, charges your device, slightly faster. Great for configuration!",
        icoMood: MeshBrainMood.approving,
      ),
      HelpStep(
        id: 'connection_pairing',
        bubbleText:
            "First time? Your device needs to be in **pairing mode**. Check for a Bluetooth icon on the screen or press the button!",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'connection_troubleshoot',
        bubbleText:
            "Can't find your device? Check:\n- **Bluetooth is on**\n- Device has power\n- Device isn't connected elsewhere\n- You're close enough (under 10m)",
        icoMood: MeshBrainMood.thinking,
      ),
      HelpStep(
        id: 'connection_disconnect',
        bubbleText:
            "Keep getting **disconnected**? Common causes:\n- **Another app** (e.g. Meshtastic app) is already connected to this node\n- On **TCP/IP (ESP devices)**, only one client can connect at a time\n- Try closing other apps or disconnecting other devices first",
        icoMood: MeshBrainMood.thinking,
      ),
    ],
  );

  // ============================================================================
  // GPS SETTINGS HELP
  // ============================================================================

  static final HelpTopic gpsSettings = HelpTopic(
    id: 'gps_settings',
    title: 'GPS & Position Sharing',
    description: 'Location updates and privacy',
    icon: Icons.gps_fixed,
    category: catSettings,
    priority: 7,
    steps: [
      HelpStep(
        id: 'gps_intro',
        bubbleText:
            "**GPS** lets others see where you are on the map! Let me explain how it works.",
        icoMood: MeshBrainMood.curious,
        canGoBack: false,
      ),
      HelpStep(
        id: 'gps_broadcast',
        bubbleText:
            "Your device broadcasts **position updates** every few minutes. Other nodes see you appear on their map!",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'gps_privacy',
        bubbleText:
            "Privacy matters! You can **disable GPS** or set update intervals. Turn it off when you want to stay hidden!",
        icoMood: MeshBrainMood.inviting,
      ),
      HelpStep(
        id: 'gps_battery',
        bubbleText:
            "GPS uses **battery**! Longer update intervals = better battery life. Balance privacy and utility!",
        icoMood: MeshBrainMood.thinking,
      ),
    ],
  );

  // ============================================================================
  // SIGNAL METRICS HELP
  // ============================================================================

  static final HelpTopic signalMetrics = HelpTopic(
    id: 'signal_metrics',
    title: 'Understanding Signal Strength',
    description: 'SNR, RSSI, and what they mean',
    icon: Icons.signal_cellular_alt,
    category: catNetwork,
    priority: 6,
    steps: [
      HelpStep(
        id: 'metrics_intro',
        bubbleText:
            "Let's decode those signal numbers! They tell you how good your connection is.",
        icoMood: MeshBrainMood.curious,
        canGoBack: false,
      ),
      HelpStep(
        id: 'metrics_rssi',
        bubbleText:
            "**RSSI** (Received Signal Strength): How loud the signal is. Higher is better! **-50 dBm** = excellent, **-120 dBm** = barely hanging on.",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'metrics_snr',
        bubbleText:
            "**SNR** (Signal-to-Noise Ratio): How clear the signal is. Positive = good, negative = noisy! **+10 dB** = great, **-10 dB** = struggling.",
        icoMood: MeshBrainMood.thinking,
      ),
      HelpStep(
        id: 'metrics_practical',
        bubbleText:
            "In practice: **Green** = excellent, **yellow** = okay, **red** = poor. Move closer or find higher ground to improve!",
        icoMood: MeshBrainMood.approving,
      ),
    ],
  );

  // ============================================================================
  // MAP SCREEN HELP
  // ============================================================================

  static final HelpTopic mapOverview = HelpTopic(
    id: 'map_overview',
    title: 'Mesh Map',
    description: 'See your mesh network on a map',
    icon: Icons.map,
    category: catNodes,
    priority: 5,
    steps: [
      HelpStep(
        id: 'map_intro',
        bubbleText:
            "Welcome to the **Mesh Map**! Every dot you see is a node with GPS. They're all part of your network!",
        icoMood: MeshBrainMood.excited,
        canGoBack: false,
      ),
      HelpStep(
        id: 'map_markers',
        bubbleText:
            "**Tap any marker** to see who it is. You can send them a message, check their battery, or see when they were last heard!",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'map_features',
        bubbleText:
            "Try the **heatmap** to see where nodes cluster, or **connection lines** to see who can talk to who!",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'map_measure',
        bubbleText:
            "Use **measure mode** to check distances between points. Great for planning where to put a new node!",
        icoMood: MeshBrainMood.approving,
      ),
      HelpStep(
        id: 'map_filters',
        bubbleText:
            "Use **filters** to show only **Online** nodes, or nodes with GPS. Helps when your map gets crowded!",
        icoMood: MeshBrainMood.playful,
      ),
    ],
  );

  // ============================================================================
  // CHANNELS LIST HELP
  // ============================================================================

  static final HelpTopic channelsOverview = HelpTopic(
    id: 'channels_overview',
    title: 'Your Channels',
    description: 'Managing mesh communication channels',
    icon: Icons.forum,
    category: catChannels,
    priority: 2,
    steps: [
      HelpStep(
        id: 'channels_intro',
        bubbleText:
            "These are your **channels**! Think of them like different radio frequencies. Each one is a separate conversation.",
        icoMood: MeshBrainMood.excited,
        canGoBack: false,
      ),
      HelpStep(
        id: 'channels_primary',
        bubbleText:
            "The **Primary** channel is special. It's always slot 0 and can't be deleted. Most mesh traffic goes here!",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'channels_secondary',
        bubbleText:
            "**Secondary channels** are for private groups. Create one for your family, hiking club, or emergency team!",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'channels_encryption',
        bubbleText:
            "See the **lock icon**? That means the channel is encrypted. Only people with the key can read messages!",
        icoMood: MeshBrainMood.approving,
      ),
      HelpStep(
        id: 'channels_share',
        bubbleText:
            "Tap a channel to see its **QR code**. Friends can scan it to join instantly with the right settings!",
        icoMood: MeshBrainMood.playful,
      ),
    ],
  );

  // ============================================================================
  // AUTOMATIONS HELP
  // ============================================================================

  static final HelpTopic automationsOverview = HelpTopic(
    id: 'automations_overview',
    title: 'Automations',
    description: 'Automatic actions for your mesh',
    icon: Icons.auto_awesome,
    category: catAutomations,
    priority: 8,
    steps: [
      HelpStep(
        id: 'automations_intro',
        bubbleText:
            "**Automations** make your mesh smarter! Set up rules and I'll do things automatically for you.",
        icoMood: MeshBrainMood.excited,
        canGoBack: false,
      ),
      HelpStep(
        id: 'automations_triggers',
        bubbleText:
            "Every automation starts with a **trigger**. Like when a node becomes inactive, battery gets low, or you enter an area!",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'automations_actions',
        bubbleText:
            "Then pick an **action**! Send a message, play a sound, show a notification, or even trigger IFTTT!",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'automations_examples',
        bubbleText:
            "Example: **Alert me when Dad's battery drops below 20%**. Or **Send 'I'm home!' when I enter my geofence**!",
        icoMood: MeshBrainMood.approving,
      ),
      HelpStep(
        id: 'automations_toggle',
        bubbleText:
            "Use the **toggle switch** to enable or disable automations. Test them out before going live!",
        icoMood: MeshBrainMood.playful,
      ),
    ],
  );

  // ============================================================================
  // WIDGET DASHBOARD HELP
  // ============================================================================

  static final HelpTopic dashboardOverview = HelpTopic(
    id: 'dashboard_overview',
    title: 'Your Dashboard',
    description: 'Your customizable mesh command center',
    icon: Icons.dashboard,
    category: catSettings,
    priority: 1,
    steps: [
      HelpStep(
        id: 'dashboard_intro',
        bubbleText:
            "Welcome to your **Dashboard**! This is your personalized command center. Everything you need, at a glance!",
        icoMood: MeshBrainMood.excited,
        canGoBack: false,
      ),
      HelpStep(
        id: 'dashboard_widgets',
        bubbleText:
            "Each card is a **widget**. They show live data from your mesh - battery levels, messages, weather, and more!",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'dashboard_reorder',
        bubbleText:
            "**Long-press and drag** to rearrange widgets. Put your favorites at the top! Tap **Edit** to add or remove them.",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'dashboard_tap',
        bubbleText:
            "**Tap any widget** to see more details or take action. Try tapping a node widget to see all their info!",
        icoMood: MeshBrainMood.approving,
      ),
    ],
  );

  // ============================================================================
  // WIDGET BUILDER HELP
  // ============================================================================

  static final HelpTopic widgetBuilderOverview = HelpTopic(
    id: 'widget_builder_overview',
    title: 'Widget Builder',
    description: 'Create your own custom widgets',
    icon: Icons.widgets,
    category: catSettings,
    priority: 10,
    steps: [
      HelpStep(
        id: 'builder_intro',
        bubbleText:
            "Welcome to the **Widget Builder**! Here you can create your own custom widgets from scratch!",
        icoMood: MeshBrainMood.excited,
        canGoBack: false,
      ),
      HelpStep(
        id: 'builder_templates',
        bubbleText:
            "Start with a **template** or build from blank. Templates give you gauges, charts, and status cards ready to customize!",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'builder_bindings',
        bubbleText:
            "The magic is in **data bindings**! Connect any element to live mesh data - battery, GPS, temperature, signal strength!",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'builder_preview',
        bubbleText:
            "Use **Preview** to see how your widget looks with real data before saving. Tweak until it's perfect!",
        icoMood: MeshBrainMood.approving,
      ),
    ],
  );

  // ============================================================================
  // WIDGET MARKETPLACE HELP
  // ============================================================================

  static final HelpTopic marketplaceOverview = HelpTopic(
    id: 'marketplace_overview',
    title: 'Widget Marketplace',
    description: 'Discover widgets made by the community',
    icon: Icons.store,
    category: catSettings,
    priority: 11,
    steps: [
      HelpStep(
        id: 'marketplace_intro',
        bubbleText:
            "Welcome to the **Marketplace**! Browse widgets created by other mesh enthusiasts around the world!",
        icoMood: MeshBrainMood.excited,
        canGoBack: false,
      ),
      HelpStep(
        id: 'marketplace_browse',
        bubbleText:
            "Browse by **category** - find status displays, charts, gauges, or creative designs. Tap any widget to preview it!",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'marketplace_install',
        bubbleText:
            "Found one you like? **Tap install** and it's added to your collection. Use it on your dashboard right away!",
        icoMood: MeshBrainMood.approving,
      ),
      HelpStep(
        id: 'marketplace_share',
        bubbleText:
            "Made something cool? **Share your widgets** to the marketplace and help the community!",
        icoMood: MeshBrainMood.playful,
      ),
    ],
  );

  // ============================================================================
  // SIGNALS HELP
  // ============================================================================

  static final HelpTopic signalsOverview = HelpTopic(
    id: 'signals_overview',
    title: 'Signals',
    description: 'Broadcast ephemeral signals to your mesh',
    icon: Icons.sensors,
    category: catMessaging,
    priority: 6,
    steps: [
      HelpStep(
        id: 'signals_intro',
        bubbleText:
            "Welcome to **Signals**! Broadcast moments to your mesh. Signals are **ephemeral** - you choose how long they last, from **15 minutes** up to **24 hours**.",
        icoMood: MeshBrainMood.excited,
        canGoBack: false,
      ),
      HelpStep(
        id: 'signals_create',
        bubbleText:
            "Tap the **sensor icon** to go active! Add text, a photo, or your location. Choose your TTL - shorter times work great for quick check-ins.",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'signals_proximity',
        bubbleText:
            "Signals show **proximity badges** - how many hops away the sender is. **Nearby** signals (0-1 hops) appear first!",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'signals_filters',
        bubbleText:
            "Use **filters** to focus on what matters: nearby signals, mesh-only, or content with media. Toggle between **list** and **grid** views!",
        icoMood: MeshBrainMood.approving,
      ),
      HelpStep(
        id: 'signals_privacy',
        bubbleText:
            "Signals are **mesh-first** - they travel through the radio network. When they fade, they're gone. True ephemeral, off-grid content!",
        icoMood: MeshBrainMood.playful,
      ),
    ],
  );

  // ============================================================================
  // SIGNAL CREATION HELP
  // ============================================================================

  static final HelpTopic signalCreation = HelpTopic(
    id: 'signal_creation',
    title: 'Creating a Signal',
    description: 'How to compose and broadcast a signal',
    icon: Icons.edit_note,
    category: catMessaging,
    priority: 7,
    steps: [
      HelpStep(
        id: 'create_intro',
        bubbleText:
            "Time to **Go Active**! A signal is an ephemeral broadcast — "
            "it lives on the mesh for a set time, then fades away. Let me "
            "walk you through it.",
        icoMood: MeshBrainMood.excited,
        canGoBack: false,
      ),
      HelpStep(
        id: 'create_text',
        bubbleText:
            "Type your message in the main field — up to **280 characters**. "
            "The circular counter in the corner shows how many you have left.",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'create_image',
        bubbleText:
            "Tap the **image icon** to attach a photo. Images are uploaded "
            "via cloud when you are online — they are not available in "
            "mesh-only mode.",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'create_location',
        bubbleText:
            "Tap the **location pin** to attach your device's GPS position. "
            "Your location is fuzzed to a configurable radius for privacy. "
            "Tap again to remove it.",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'create_ttl',
        bubbleText:
            "The **timer icon** sets your TTL — how long the signal stays "
            "alive. Choose from **15 minutes** up to **24 hours**. Shorter "
            "times work great for quick check-ins.",
        icoMood: MeshBrainMood.approving,
      ),
      HelpStep(
        id: 'create_intent',
        bubbleText:
            "Pick a **Presence Intent** to tell the mesh what you are up to — "
            "exploring, monitoring, helping, or just listening. It adds "
            "context without extra words.",
        icoMood: MeshBrainMood.playful,
      ),
      HelpStep(
        id: 'create_status',
        bubbleText:
            "The **short status** field is a one-liner that appears as a "
            "subtitle on your signal card. Think of it as a mood or caption.",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'create_submit',
        bubbleText:
            "When you are ready, hit **Broadcast**! Your signal travels "
            "through the mesh radio first. If cloud is available, it syncs "
            "there too for wider reach.",
        icoMood: MeshBrainMood.excited,
      ),
    ],
  );

  // ============================================================================
  // SIGNAL DETAIL HELP
  // ============================================================================

  static final HelpTopic signalDetail = HelpTopic(
    id: 'signal_detail',
    title: 'Signal Details',
    description: 'Interacting with a signal and its responses',
    icon: Icons.forum_outlined,
    category: catMessaging,
    priority: 8,
    steps: [
      HelpStep(
        id: 'detail_intro',
        bubbleText:
            "This is the **signal detail** screen. You can read the full "
            "content, see where it was posted, and browse all responses.",
        icoMood: MeshBrainMood.speaking,
        canGoBack: false,
      ),
      HelpStep(
        id: 'detail_ttl',
        bubbleText:
            "The **TTL bar** shows how much time the signal has left. When "
            "it reaches zero the signal expires and this screen closes "
            "automatically.",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'detail_responses',
        bubbleText:
            "Responses are **threaded**. You can reply directly to the "
            "signal or to another person's response. Nested replies indent "
            "so you can follow the conversation.",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'detail_voting',
        bubbleText:
            "Tap the **up or down arrow** on any response to vote. Votes "
            "surface the most useful replies. You can change your vote at "
            "any time.",
        icoMood: MeshBrainMood.approving,
      ),
      HelpStep(
        id: 'detail_reply',
        bubbleText:
            "Use the **reply bar** at the bottom to respond. Tap the reply "
            "icon on any response to start a threaded conversation with "
            "that person.",
        icoMood: MeshBrainMood.playful,
      ),
      HelpStep(
        id: 'detail_actions',
        bubbleText:
            "The **overflow menu** (three dots) lets you **delete** your "
            "own signal or **report** someone else's. Only one of those "
            "options appears depending on whether you authored the signal.",
        icoMood: MeshBrainMood.speaking,
      ),
    ],
  );

  // ============================================================================
  // WORLD MESH HELP
  // ============================================================================

  static final HelpTopic worldMeshOverview = HelpTopic(
    id: 'world_mesh_overview',
    title: 'World Mesh',
    description: 'Global mesh network visualization',
    icon: Icons.public,
    category: catNetwork,
    priority: 7,
    steps: [
      HelpStep(
        id: 'world_intro',
        bubbleText:
            "Welcome to **World Mesh**! See the entire global Meshtastic network. Every dot is a node sharing its location!",
        icoMood: MeshBrainMood.excited,
        canGoBack: false,
      ),
      HelpStep(
        id: 'world_scope',
        bubbleText:
            "Zoom out to see the **worldwide mesh**, or zoom in to explore local clusters. It's amazing how many nodes exist!",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'world_data',
        bubbleText:
            "Data comes from **MQTT** - nodes that opted to share their position publicly. Your local nodes appear too!",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'world_filters',
        bubbleText:
            "Use **filters** to show specific regions or time ranges. Find active meshes near places you're visiting!",
        icoMood: MeshBrainMood.approving,
      ),
    ],
  );

  // ============================================================================
  // ROUTES HELP
  // ============================================================================

  static final HelpTopic routesOverview = HelpTopic(
    id: 'routes_overview',
    title: 'Routes',
    description: 'Record and share GPS routes',
    icon: Icons.route,
    category: catDevice,
    priority: 9,
    steps: [
      HelpStep(
        id: 'routes_intro',
        bubbleText:
            "**Routes** lets you record your journeys! Perfect for hikes, bike rides, or any adventure off the grid.",
        icoMood: MeshBrainMood.excited,
        canGoBack: false,
      ),
      HelpStep(
        id: 'routes_record',
        bubbleText:
            "Tap **Record** to start tracking. I'll save your GPS points as you move. Works even without cell signal!",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'routes_gpx',
        bubbleText:
            "**Import GPX files** to follow existing trails. Export your routes to share with others or use in other apps!",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'routes_share',
        bubbleText:
            "Share routes with your mesh buddies! Great for coordinating meet-up points or showing others your favorite trails.",
        icoMood: MeshBrainMood.approving,
      ),
    ],
  );

  // ============================================================================
  // POSITION HISTORY HELP
  // ============================================================================

  static final HelpTopic positionOverview = HelpTopic(
    id: 'position_overview',
    title: 'Position History',
    description: 'GPS position logs for all nodes on your mesh',
    icon: Icons.location_on,
    category: catNetwork,
    priority: 9,
    steps: [
      HelpStep(
        id: 'position_intro',
        bubbleText:
            "**Position History** records every GPS position broadcast by nodes on your mesh. Think of it as a flight recorder for location data!",
        icoMood: MeshBrainMood.speaking,
        canGoBack: false,
      ),
      HelpStep(
        id: 'position_list_map',
        bubbleText:
            "Switch between **list view** and **map view** using the overflow menu. The map draws colour-coded trails per node so you can visualise movement over time.",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'position_filters',
        bubbleText:
            "Use **filter chips** to narrow results: today, this week, good GPS fix, or just your own node. Combine with a **custom date range** for precise slicing.",
        icoMood: MeshBrainMood.thinking,
      ),
      HelpStep(
        id: 'position_search',
        bubbleText:
            "The **search bar** filters by node name. Handy when you have dozens of nodes and want to track a specific one.",
        icoMood: MeshBrainMood.approving,
      ),
      HelpStep(
        id: 'position_map_nodes',
        bubbleText:
            "In map view, tap the **node list** button to pick a single node. Each node gets its own colour trail with distance calculations between points.",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'position_export',
        bubbleText:
            "**Export as CSV** from the overflow menu for analysis in spreadsheets or GIS tools. Great for documenting coverage tests!",
        icoMood: MeshBrainMood.excited,
      ),
      HelpStep(
        id: 'position_good_fix',
        bubbleText:
            "The **Good Fix** filter shows only positions with 6+ satellites. This helps you ignore noisy indoor fixes and focus on reliable outdoor data.",
        icoMood: MeshBrainMood.approving,
      ),
    ],
  );

  // ============================================================================
  // SETTINGS HELP
  // ============================================================================

  static final HelpTopic settingsOverview = HelpTopic(
    id: 'settings_overview',
    title: 'Settings',
    description: 'Configure your app and device',
    icon: Icons.settings,
    category: catSettings,
    priority: 15,
    steps: [
      HelpStep(
        id: 'settings_intro',
        bubbleText:
            "Welcome to **Settings**! Here you can customize everything about your app and connected device.",
        icoMood: MeshBrainMood.speaking,
        canGoBack: false,
      ),
      HelpStep(
        id: 'settings_device',
        bubbleText:
            "**Device settings** let you configure your Meshtastic radio - name, region, power levels, and modules!",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'settings_app',
        bubbleText:
            "**App settings** control themes, notifications, privacy options, and how the app behaves.",
        icoMood: MeshBrainMood.approving,
      ),
      HelpStep(
        id: 'settings_cloud',
        bubbleText:
            "**Cloud Sync** is a premium subscription that syncs your **NodeDex**, **automations**, **widgets**, and **profile** across all your devices. It also serves as your **backup** — if you ever delete the app or switch phones, Cloud Sync restores everything. Without it, all data lives only on this device and is lost if the app is removed.",
        icoMood: MeshBrainMood.playful,
      ),
    ],
  );

  // ============================================================================
  // PROFILE HELP
  // ============================================================================

  static final HelpTopic profileOverview = HelpTopic(
    id: 'profile_overview',
    title: 'Your Profile',
    description: 'Manage your mesh identity',
    icon: Icons.person,
    category: catSettings,
    priority: 12,
    steps: [
      HelpStep(
        id: 'profile_intro',
        bubbleText:
            "This is **your profile**! Customize your mesh identity with a display name, callsign, and avatar.",
        icoMood: MeshBrainMood.speaking,
        canGoBack: false,
      ),
      HelpStep(
        id: 'profile_customize',
        bubbleText:
            "Your profile is **optional and private by default**. Customize it to stand out on the mesh!",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'profile_share',
        bubbleText:
            "Add a **callsign**, **avatar**, and **links** to make your profile yours.",
        icoMood: MeshBrainMood.approving,
      ),
      HelpStep(
        id: 'profile_cloud',
        bubbleText:
            "**Cloud Sync** is a premium feature that backs up your profile, NodeDex, automations, and widgets to the cloud. It protects your data — if you delete the app or get a new phone, everything **restores automatically** when you sign back in. Without it, your data exists only on this device.",
        icoMood: MeshBrainMood.playful,
      ),
    ],
  );

  // ============================================================================
  // MESH 3D HELP
  // ============================================================================

  static final HelpTopic mesh3dOverview = HelpTopic(
    id: 'mesh_3d_overview',
    title: 'Mesh 3D',
    description: '3D network topology visualization',
    icon: Icons.view_in_ar,
    category: catNetwork,
    priority: 13,
    steps: [
      HelpStep(
        id: 'mesh3d_intro',
        bubbleText:
            "Welcome to **Mesh 3D**! See your entire network in three dimensions. Drag to rotate, pinch to zoom!",
        icoMood: MeshBrainMood.excited,
        canGoBack: false,
      ),
      HelpStep(
        id: 'mesh3d_nodes',
        bubbleText:
            "Each sphere is a **node**. Lines show connections based on signal strength. Closer = stronger signal!",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'mesh3d_colors',
        bubbleText:
            "Colors show **node health**. Green = active, yellow = fading, gray = inactive. Status is inferred from last heard.",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'mesh3d_tap',
        bubbleText:
            "**Tap any node** to select it and see details. Great for understanding your network topology!",
        icoMood: MeshBrainMood.approving,
      ),
    ],
  );

  // ============================================================================
  // GLOBE HELP
  // ============================================================================

  static final HelpTopic globeOverview = HelpTopic(
    id: 'globe_overview',
    title: 'Globe View',
    description: '3D globe with your mesh',
    icon: Icons.language,
    category: catNetwork,
    priority: 14,
    steps: [
      HelpStep(
        id: 'globe_intro',
        bubbleText:
            "Spin the **Globe** to see your mesh from space! Every glowing point is a node with GPS coordinates.",
        icoMood: MeshBrainMood.excited,
        canGoBack: false,
      ),
      HelpStep(
        id: 'globe_interact',
        bubbleText:
            "**Drag to spin**, pinch to zoom. Tap a node to fly to its location and see details!",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'globe_arcs',
        bubbleText:
            "Watch the **connection arcs** - they show message paths traveling across your mesh in real-time!",
        icoMood: MeshBrainMood.curious,
      ),
    ],
  );

  // ============================================================================
  // TIMELINE HELP
  // ============================================================================

  static final HelpTopic timelineOverview = HelpTopic(
    id: 'timeline_overview',
    title: 'Timeline',
    description: 'Your mesh activity history',
    icon: Icons.timeline,
    category: catMessaging,
    priority: 16,
    steps: [
      HelpStep(
        id: 'timeline_intro',
        bubbleText:
            "The **Timeline** shows everything happening on your mesh. Messages, node changes, telemetry - all in order!",
        icoMood: MeshBrainMood.speaking,
        canGoBack: false,
      ),
      HelpStep(
        id: 'timeline_filter',
        bubbleText:
            "Use **filters** to focus on specific event types. Just messages? Only node joins? You control the view!",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'timeline_tap',
        bubbleText:
            "**Tap any event** to see full details. Great for debugging or understanding what's happening on your network!",
        icoMood: MeshBrainMood.approving,
      ),
    ],
  );

  // ============================================================================
  // DEVICE SHOP HELP
  // ============================================================================

  static final HelpTopic deviceShopOverview = HelpTopic(
    id: 'device_shop_overview',
    title: 'Device Shop',
    description: 'Browse Meshtastic hardware',
    icon: Icons.shopping_bag,
    category: catDevice,
    priority: 17,
    steps: [
      HelpStep(
        id: 'shop_intro',
        bubbleText:
            "Welcome to the **Device Shop**! Browse Meshtastic-compatible radios and accessories.",
        icoMood: MeshBrainMood.speaking,
        canGoBack: false,
      ),
      HelpStep(
        id: 'shop_compare',
        bubbleText:
            "**Compare devices** by range, battery, and features. I've rated each one to help you choose!",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'shop_links',
        bubbleText:
            "Tap **Buy** to visit trusted vendors. Prices and availability shown are from real stores!",
        icoMood: MeshBrainMood.approving,
      ),
    ],
  );

  // ============================================================================
  // OFFLINE MAPS HELP
  // ============================================================================

  static final HelpTopic offlineMapsOverview = HelpTopic(
    id: 'offline_maps_overview',
    title: 'Offline Maps',
    description: 'Map display settings and controls',
    icon: Icons.download,
    category: catDevice,
    priority: 18,
    steps: [
      HelpStep(
        id: 'offline_intro',
        bubbleText:
            "**Offline Maps** let you use the map without internet! Essential for adventures off the grid.",
        icoMood: MeshBrainMood.speaking,
        canGoBack: false,
      ),
      HelpStep(
        id: 'offline_download',
        bubbleText:
            "**Select a region** and zoom level, then tap download. I'll save all the map tiles to your device!",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'offline_manage',
        bubbleText:
            "Manage your downloads here - see storage used and **delete** old regions you don't need anymore.",
        icoMood: MeshBrainMood.approving,
      ),
    ],
  );

  // ============================================================================
  // RADIO CONFIG HELP
  // ============================================================================

  static final HelpTopic radioConfigOverview = HelpTopic(
    id: 'radio_config_overview',
    title: 'Radio Settings',
    description: 'Configure your LoRa radio',
    icon: Icons.radio,
    category: catDevice,
    priority: 20,
    steps: [
      HelpStep(
        id: 'radio_intro',
        bubbleText:
            "**Radio settings** control how your device transmits. Region, power, and modem preset are key!",
        icoMood: MeshBrainMood.speaking,
        canGoBack: false,
      ),
      HelpStep(
        id: 'radio_region',
        bubbleText:
            "Your **region** determines legal frequencies. Set this wrong and you could interfere with other services!",
        icoMood: MeshBrainMood.alert,
      ),
      HelpStep(
        id: 'radio_modem',
        bubbleText:
            "**Modem preset** balances range vs speed. Long-range = slower but further. Short-fast = quick but closer.",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'radio_power',
        bubbleText:
            "Higher **TX power** means more range but uses more battery. Find the sweet spot for your needs!",
        icoMood: MeshBrainMood.approving,
      ),
    ],
  );

  // ============================================================================
  // PRESENCE HELP
  // ============================================================================

  static final HelpTopic presenceOverview = HelpTopic(
    id: 'presence_overview',
    title: 'Node Presence',
    description: 'Track which nodes are active on your mesh',
    icon: Icons.people,
    category: catNodes,
    priority: 25,
    steps: [
      HelpStep(
        id: 'presence_intro',
        bubbleText:
            "**Presence** shows which nodes are active, recently seen, or inactive on your mesh network.",
        icoMood: MeshBrainMood.speaking,
        canGoBack: false,
      ),
      HelpStep(
        id: 'presence_active',
        bubbleText:
            "**Online** nodes (green) were heard within the last 2 hours — matching the Meshtastic firmware definition of online.",
        icoMood: MeshBrainMood.approving,
      ),
      HelpStep(
        id: 'presence_recent',
        bubbleText:
            "**Recently seen** nodes (yellow) were heard a few minutes ago. Probably still around.",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'presence_inactive',
        bubbleText:
            "**Offline** nodes (gray) haven't been heard from in over 2 hours. They might be out of range or powered off.",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'presence_chart',
        bubbleText:
            "The **activity chart** shows recent node activity over time. Watch the mesh come alive!",
        icoMood: MeshBrainMood.excited,
      ),
    ],
  );

  // ============================================================================
  // REACHABILITY HELP
  // ============================================================================

  static final HelpTopic reachabilityOverview = HelpTopic(
    id: 'reachability_overview',
    title: 'Mesh Reachability',
    description: 'Understand which nodes you can reach',
    icon: Icons.hub,
    category: catNetwork,
    priority: 30,
    steps: [
      HelpStep(
        id: 'reachability_intro',
        bubbleText:
            "**Reachability** estimates how likely you are to reach each node. This is based on passively observed mesh data.",
        icoMood: MeshBrainMood.speaking,
        canGoBack: false,
      ),
      HelpStep(
        id: 'reachability_beta',
        bubbleText:
            "This is **BETA** - we don't send test packets! Everything is estimated from messages we see flowing through the mesh.",
        icoMood: MeshBrainMood.alert,
      ),
      HelpStep(
        id: 'reachability_high',
        bubbleText:
            "**High** reachability (bright) means we've seen lots of communication with that node. Messages will probably get through!",
        icoMood: MeshBrainMood.approving,
      ),
      HelpStep(
        id: 'reachability_medium',
        bubbleText:
            "**Medium** reachability (dimmer) means some communication but not consistent. Messages might make it.",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'reachability_low',
        bubbleText:
            "**Low** reachability (very dim) means we rarely see communication. The node might be too far or behind obstacles.",
        icoMood: MeshBrainMood.speaking,
      ),
    ],
  );

  // ============================================================================
  // MESH HEALTH HELP
  // ============================================================================

  static final HelpTopic meshHealthOverview = HelpTopic(
    id: 'mesh_health_overview',
    title: 'Mesh Health',
    description: 'Monitor your mesh network health',
    icon: Icons.monitor_heart,
    category: catNetwork,
    priority: 35,
    steps: [
      HelpStep(
        id: 'health_intro',
        bubbleText:
            "**Mesh Health** monitors your network for issues like congestion, packet loss, and problematic nodes.",
        icoMood: MeshBrainMood.speaking,
        canGoBack: false,
      ),
      HelpStep(
        id: 'health_status',
        bubbleText:
            "The **status indicator** shows overall mesh health. Green = healthy, yellow = issues detected, red = critical problems.",
        icoMood: MeshBrainMood.approving,
      ),
      HelpStep(
        id: 'health_metrics',
        bubbleText:
            "**Metrics** show packet counts, retransmissions, and hop counts. Watch for high retransmit rates!",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'health_utilization',
        bubbleText:
            "The **utilization chart** shows how busy your mesh is over time. Spikes might indicate problems.",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'health_issues',
        bubbleText:
            "**Issues** section highlights specific problems and suggests fixes. Check here if things seem slow!",
        icoMood: MeshBrainMood.alert,
      ),
      HelpStep(
        id: 'health_monitoring',
        bubbleText:
            "Use the **pause** button to stop monitoring if you want to save battery. Hit **reset** to clear the data and start fresh!",
        icoMood: MeshBrainMood.excited,
      ),
    ],
  );

  // ============================================================================
  // TRACEROUTE HELP
  // ============================================================================

  static final HelpTopic tracerouteOverview = HelpTopic(
    id: 'traceroute_overview',
    title: 'Traceroute',
    description: 'Discover the route packets take across your mesh',
    icon: Icons.route,
    category: catNetwork,
    priority: 8,
    steps: [
      HelpStep(
        id: 'traceroute_intro',
        bubbleText:
            "**Traceroute** discovers the actual path your packets take to reach another node. It reveals which relays are forwarding your data.",
        icoMood: MeshBrainMood.speaking,
        canGoBack: false,
      ),
      HelpStep(
        id: 'traceroute_how',
        bubbleText:
            "When you send a traceroute, each relay along the route adds itself to the packet. The destination sends it back so you can see **both directions**.",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'traceroute_send',
        bubbleText:
            "Send a traceroute from a **node's detail sheet** (tap the route icon) or from **Dashboard Quick Actions** where you can pick any known node.",
        icoMood: MeshBrainMood.approving,
      ),
      HelpStep(
        id: 'traceroute_cooldown',
        bubbleText:
            "There is a **30-second cooldown** between traceroutes to respect airtime fairness. A visible countdown shows the remaining time.",
        icoMood: MeshBrainMood.alert,
      ),
      HelpStep(
        id: 'traceroute_results',
        bubbleText:
            "Results show **forward** and **return** hop paths. Each row reads \"heard at X dB\" — the **SNR** that node measured on its inbound packet. The final row in each section is the endpoint (the target on the forward path, you on the return path), so even a direct connection shows both reception SNRs.",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'traceroute_history',
        bubbleText:
            "All traceroutes are saved to **Traceroute History** (Settings > Telemetry Logs). Filter by response status, search by node name, and compare runs over time.",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'traceroute_export',
        bubbleText:
            "Export your traceroute history as **CSV** for trend analysis or documentation. Use the overflow menu on the history screen.",
        icoMood: MeshBrainMood.approving,
      ),
      HelpStep(
        id: 'traceroute_tips',
        bubbleText:
            "**Pro tip:** Run traceroutes after repositioning nodes, changing antennas, or adjusting channels to validate your changes with real route data!",
        icoMood: MeshBrainMood.excited,
      ),
    ],
  );

  // ============================================================================
  // NODEDEX OVERVIEW
  // ============================================================================

  static final HelpTopic nodeDexOverview = HelpTopic(
    id: 'nodedex_overview',
    title: 'NodeDex Field Journal',
    description: 'Your personal record of every node discovered on the mesh',
    icon: Icons.hexagon_outlined,
    category: catNodes,
    priority: 3,
    steps: [
      HelpStep(
        id: 'nodedex_intro',
        bubbleText:
            "Welcome to the **NodeDex** — your personal mesh field journal! Every node you discover is recorded here with a unique **Sigil** and personality **Trait**.",
        icoMood: MeshBrainMood.excited,
        canGoBack: false,
      ),
      HelpStep(
        id: 'nodedex_sigils',
        bubbleText:
            "Each node gets a **procedural Sigil** — a geometric glyph generated from its identity. No two nodes share the same sigil. Think of it as a visual fingerprint for the mesh!",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'nodedex_traits',
        bubbleText:
            "Nodes earn **Traits** based on real behavior — **Wanderer** moves between regions, **Beacon** is always online, **Ghost** is rarely seen, **Sentinel** holds a fixed position, **Relay** forwards traffic.",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'nodedex_filters',
        bubbleText:
            "Use the **filter chips** to show only specific traits, recently discovered nodes, or nodes you have tagged. The **search bar** finds nodes by name or hex ID.",
        icoMood: MeshBrainMood.approving,
      ),
      HelpStep(
        id: 'nodedex_field_journal',
        bubbleText:
            "As you observe more nodes, your **field journal** fills in — each node earns a **Patina score** and **identity overlay** based on real encounters. The more you observe, the richer the detail!",
        icoMood: MeshBrainMood.playful,
      ),
      HelpStep(
        id: 'nodedex_album_mode',
        bubbleText:
            "Tap the **view toggle** in the app bar to switch to **Album mode** — a collector-style card grid grouped by trait, rarity, or region. Each card shows the node's sigil with a holographic shimmer based on rarity!",
        icoMood: MeshBrainMood.excited,
      ),
      HelpStep(
        id: 'nodedex_atmosphere',
        bubbleText:
            "Notice the subtle **ambient particles** behind the screen? That is the **Elemental Atmosphere** — rain, embers, mist, and starlight driven by your real mesh data. More nodes and activity means more atmosphere!",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'nodedex_cloud_sync',
        bubbleText:
            "Your NodeDex is stored locally in SQLite and survives app restarts — but **not** app deletion. If you uninstall the app or switch phones, your local NodeDex is gone. With a **Cloud Sync** subscription, your entire journal — sigils, encounters, social tags, notes, and co-seen links — backs up to the cloud and **restores automatically** on any device you sign into.",
        icoMood: MeshBrainMood.approving,
      ),
      HelpStep(
        id: 'nodedex_export',
        bubbleText:
            "Use the **menu** to **export** your NodeDex as a JSON file for backup, or **import** one from another device. Your field journal travels with you — even without Cloud Sync!",
        icoMood: MeshBrainMood.approving,
      ),
    ],
  );

  // ============================================================================
  // NODEDEX DETAIL
  // ============================================================================

  static final HelpTopic nodeDexDetail = HelpTopic(
    id: 'nodedex_detail',
    title: 'Node Profile',
    description: 'Understanding a node\'s full identity and history',
    icon: Icons.hexagon_outlined,
    category: catNodes,
    priority: 4,
    steps: [
      HelpStep(
        id: 'nodedex_sigil',
        bubbleText:
            "This is the node's **Sigil** — a unique procedural glyph generated from its identity. No two nodes share the same sigil. It's like a visual fingerprint!",
        icoMood: MeshBrainMood.excited,
        canGoBack: false,
      ),
      HelpStep(
        id: 'nodedex_trait',
        bubbleText:
            "The **Trait** is an inferred personality based on how this node behaves — movement patterns, signal consistency, encounter frequency. Confidence grows with more data.",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'nodedex_auto_summary',
        bubbleText:
            "**Auto-Summary** computes insights from encounter history — time-of-day distribution, observation streaks, and busiest-day patterns. Everything updates automatically as new encounters arrive.",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'nodedex_observation_timeline',
        bubbleText:
            "The **Observation Timeline** visualizes this node's encounter density over time, with relative labels showing how recently each observation was recorded.",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'nodedex_discovery',
        bubbleText:
            "**Discovery Stats** show when you first and last saw this node, how many encounters you've had, and the closest range recorded. These update automatically.",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'nodedex_signal',
        bubbleText:
            "**Signal Records** track the best and most recent SNR and RSSI values. These help you understand link quality — higher SNR and less negative RSSI mean stronger signals.",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'nodedex_social_tag',
        bubbleText:
            "The **Social Tag** is a label you assign to categorize this node — friend, relay, base station, or anything else. It's your personal metadata, never shared over the mesh.",
        icoMood: MeshBrainMood.approving,
      ),
      HelpStep(
        id: 'nodedex_note',
        bubbleText:
            "**Your Note** is a free-text field for anything you want to remember about this node. Location hints, operator name, antenna type — whatever helps you.",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'nodedex_regions',
        bubbleText:
            "**Region History** records every regulatory region where this node has been observed. Useful for tracking mobile nodes across different areas.",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'nodedex_encounters',
        bubbleText:
            "**Recent Encounters** is a timeline of when this node appeared on your mesh. Each entry shows the timestamp, signal quality, and range if GPS was available.",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'nodedex_activity_timeline',
        bubbleText:
            "The **Activity Timeline** is a unified chronological feed of everything observed about this node — encounters, messages, presence changes, signals, and milestones.",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'nodedex_coseen',
        bubbleText:
            "**Co-Seen Links** show nodes frequently observed in the same session as this one. Tap any link to see the full relationship — shared encounters, message counts, and connection strength.",
        icoMood: MeshBrainMood.playful,
      ),
      HelpStep(
        id: 'nodedex_device',
        bubbleText:
            "**Device Info** shows live telemetry — battery level, hardware model, firmware version, and uptime. This data comes from the node directly and updates in real time.",
        icoMood: MeshBrainMood.approving,
      ),
      HelpStep(
        id: 'nodedex_trait_evidence',
        bubbleText:
            "**Trait Evidence** surfaces the concrete observations behind the primary trait — co-seen count, tenure, mobility, signal consistency, timing. These are the signals that drove the confidence score.",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'nodedex_additional_traits',
        bubbleText:
            "**Additional Traits** show other archetypes that also scored for this node. Nodes rarely fit a single archetype perfectly — secondary traits reveal nuance.",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'nodedex_pet_companion',
        bubbleText:
            "**Pet Companion** — your own NodePet lives locally with your node. Other nodes can appear here when they share a small companion summary.",
        icoMood: MeshBrainMood.playful,
      ),
      HelpStep(
        id: 'nodedex_mrrp_services',
        bubbleText:
            "**MRRP Services** are the capabilities this node advertises over the mesh — boards, profiles, meetups, and more. Each ID is a specific service the peer exposes.",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'nodedex_field_note',
        bubbleText:
            "The **Field Note** is a short, deterministic journal entry generated from the node's identity and primary trait. The same node always produces the same note — and it never travels over the mesh.",
        icoMood: MeshBrainMood.playful,
      ),
      HelpStep(
        id: 'nodedex_radio_compatibility',
        bubbleText:
            "**Radio Compatibility** compares your local radio's current preset and frequency against the values stamped on this node's last observation. Use it to spot mismatches that prevent direct RF reachability.",
        icoMood: MeshBrainMood.curious,
      ),
    ],
  );

  /// Inline help text for individual NodeDex detail sections.
  ///
  /// Used by the section info buttons to show contextual help
  /// without starting a full guided tour.
  static const Map<String, String> nodeDexSectionHelp = {
    'sigil':
        'A unique procedural glyph generated from this node\'s identity. '
        'The shape, symmetry, and color palette are deterministic — the same '
        'node always produces the same sigil. Think of it as a visual fingerprint.',
    'trait':
        'An inferred personality archetype derived from behavioral signals: '
        'movement patterns, encounter frequency, signal consistency, and session '
        'duration. Confidence increases as more data is collected over time.',
    'auto_summary':
        'Computed insights from this node\'s encounter history. The time-of-day '
        'distribution shows when encounters most often occur, the streak tracks '
        'consecutive observation days, and the busiest day highlights weekly '
        'patterns. All stats update automatically as new encounters arrive.',
    'observation_timeline':
        'A visual timeline of this node\'s observation history. The bar shows '
        'encounter density over time, with relative labels ("3w ago", "2h ago") '
        'showing how recently each endpoint was recorded. The sighting count '
        'reflects total distinct encounters.',
    'discovery':
        'Tracks when this node was first and last seen on your mesh, the total '
        'number of encounters, and the closest recorded range. All values update '
        'automatically as new packets arrive.',
    'signal':
        'Best and most recent SNR (Signal-to-Noise Ratio) and RSSI '
        '(Received Signal Strength Indicator) values. Higher SNR and less '
        'negative RSSI indicate a stronger, more reliable link.',
    'social_tag':
        'A personal label you assign to categorize this node. Social tags are '
        'stored locally and included in NodeDex exports, but never transmitted '
        'over the mesh. Use them to mark friends, relays, base stations, or '
        'any category that helps you organize your network.',
    'note':
        'A free-text note for anything you want to remember about this node. '
        'Notes are private, stored locally, and included in NodeDex exports.',
    'regions':
        'Every regulatory region where this node has been observed. Region '
        'data is recorded from the node\'s configuration packets and helps '
        'track mobile nodes across different geographic areas.',
    'encounters':
        'A chronological timeline of when this node appeared on your mesh. '
        'Each encounter records the timestamp, signal quality (SNR/RSSI), '
        'and distance if GPS coordinates were available on both sides. '
        'The most recent 10 encounters are shown.',
    'activity_timeline':
        'A unified chronological feed of everything observed about this node: '
        'encounters, messages, presence state changes, signals, and milestones. '
        'Scroll through the full narrative of your interaction history with '
        'this node. The timeline loads the most recent 50 events and can '
        'expand to show the complete history.',
    'coseen':
        'Nodes that are frequently observed in the same session as this node. '
        'A higher count means these nodes tend to appear together — they may '
        'be co-located, part of the same deployment, or carried by the same '
        'person. Tap any link to see the full edge detail including shared '
        'encounter history and message activity.',
    'device':
        'Live telemetry from the node: battery percentage, hardware model, '
        'firmware version, channel utilization, and uptime. This data is only '
        'available when the node is actively heard on the mesh.',
    'trait_evidence':
        'The observations that most strongly support the primary trait '
        'assigned above. Each bullet is a concrete signal drawn from encounter '
        'history — co-seen connections, tenure, mobility, signal consistency, '
        'and timing. These are the inputs that drove the confidence score.',
    'additional_traits':
        'Other behavioral archetypes that also scored for this node, ranked '
        'by confidence. A node rarely fits a single archetype perfectly — '
        'secondary traits reveal nuance, like an Anchor that also acts as a '
        'Beacon, or a Drifter with Sentinel-like stretches.',
    // Fallback copies for the [SectionInfoButton] existence check. The
    // user-visible text comes from the ARB-backed resolver below; these
    // strings are never displayed. Two keys — one per self-vs-remote
    // branch — so [SectionInfoButton] opens the sheet in either case.
    'pet_companion_self':
        'Your NodePet lives with your node and evolves locally from your '
        'care and mesh activity.',
    'pet_companion_remote':
        'If this node shares a companion summary, it can appear here. '
        'Full companion state stays local to its owner.',
    'mrrp_services':
        'MRRP (Mesh Request-Response Protocol) services this node advertises. '
        'Each service ID represents a capability the node exposes over the '
        'mesh, such as a message board, profile exchange, or meetup '
        'coordination. Tap any ID to learn more about that specific service.',
    'field_note':
        'A short, deterministic journal entry generated from this node\'s '
        'identity and primary trait — like a naturalist\'s field observation. '
        'The same node always produces the same note; it never changes, and '
        'it never travels over the mesh.',
    'radio_compatibility':
        'Compares your local radio\'s current preset and frequency against '
        'the values stamped on this node\'s last observation. Use this to '
        'spot mismatches that prevent direct RF reachability.',
    // Album-specific section help
    'album_rarity':
        'Rarity tiers are computed from encounter count and inferred trait. '
        'Common nodes have few encounters, while Legendary nodes combine rare '
        'traits with deep observation history. Rarity determines the card '
        'border color and holographic shimmer intensity.',
    'album_grouping':
        'Cards can be grouped by Trait (behavioral archetype), Rarity '
        '(encounter-based tier), or Region (geographic area where first seen). '
        'Tap the group chips below the cover to switch between views.',
    'album_explorer_title':
        'Your Explorer Title reflects your overall collection progress. '
        'Newcomer, Scout, Cartographer, Pathfinder, and Chronicler are earned '
        'by discovering more nodes, encountering them repeatedly, and exploring '
        'multiple regions.',
    'album_holographic':
        'The holographic shimmer on cards is a visual indicator of rarity. '
        'Common cards have no shimmer. Uncommon cards shimmer faintly. Rare, '
        'Epic, and Legendary cards glow with increasing intensity. The effect '
        'respects your reduce-motion preference.',
    'album_patina':
        'Patina is a composite score reflecting how deeply you have observed '
        'a node — encounter frequency, signal quality, co-seen connections, '
        'and time since first discovery all contribute. Higher patina means '
        'richer visual detail on the card.',
    'album_cloud_sync':
        'With a Cloud Sync subscription, your entire NodeDex album backs up '
        'to the cloud and syncs across devices — sigils, encounters, social '
        'tags, notes, co-seen links, and collection progress. If you delete '
        'the app or get a new phone, everything restores when you sign back '
        'in. Without Cloud Sync, your collection exists only on this device '
        'and is lost if the app is removed. You can still export/import as '
        'JSON for manual backups.',
  };

  // ============================================================================
  // NODEDEX COLLECTOR ALBUM
  // ============================================================================

  static final HelpTopic nodeDexAlbum = HelpTopic(
    id: 'nodedex_album',
    title: 'Collector Album',
    description: 'A collectible card view of your discovered nodes',
    icon: Icons.style_outlined,
    category: catNodes,
    priority: 5,
    steps: [
      HelpStep(
        id: 'album_intro',
        bubbleText:
            "Welcome to the **Collector Album** — a card-collector view of your NodeDex! Every discovered node becomes a collectible card with its sigil, trait, and rarity tier.",
        icoMood: MeshBrainMood.excited,
        canGoBack: false,
      ),
      HelpStep(
        id: 'album_cover',
        bubbleText:
            "The **Album Cover** is your dashboard — it shows your **Explorer Title**, total nodes, encounters, regions explored, and a rarity breakdown bar. Watch your collection grow!",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'album_grouping',
        bubbleText:
            "Use the **group chips** to organize cards by **Trait** (Beacon, Relay, Ghost...), **Rarity** (Common through Legendary), or **Region** (geographic area). Each group gets its own album page.",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'album_rarity',
        bubbleText:
            "Cards earn **rarity tiers** based on encounter count and trait. **Common** nodes are newly seen, while **Legendary** cards combine rare traits with deep observation history. Rarity drives the border glow and holographic shimmer!",
        icoMood: MeshBrainMood.playful,
      ),
      HelpStep(
        id: 'album_interactions',
        bubbleText:
            "**Tap** a card to open the node's full profile. **Long-press** to open the **Card Gallery** — a full-screen carousel where you can swipe through cards and tap to flip them over for stats!",
        icoMood: MeshBrainMood.approving,
      ),
      HelpStep(
        id: 'album_gallery',
        bubbleText:
            "In the **Card Gallery**, swipe left and right to browse cards. **Tap** a card to flip it — the back shows discovery stats, signal records, encounter count, and patina score. Swipe down to dismiss.",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'album_holographic',
        bubbleText:
            "Higher-rarity cards shimmer with a **holographic effect** — the rarer the card, the brighter the glow. This effect respects your **reduce-motion** setting and uses an optimized painter for grid thumbnails.",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'album_persistence',
        bubbleText:
            "Your album view preference and grouping choice are **saved automatically**. With **Cloud Sync**, your entire collection — sigils, encounters, tags, notes — backs up and syncs across all your devices. Delete the app, get a new phone — your collection is safe and restores on sign-in.",
        icoMood: MeshBrainMood.approving,
      ),
    ],
  );

  // ============================================================================
  // NODEDEX CONSTELLATION
  // ============================================================================

  static final HelpTopic nodeDexConstellation = HelpTopic(
    id: 'nodedex_constellation',
    title: 'Constellation View',
    description: 'A star-map visualization of co-seen node relationships',
    icon: Icons.auto_awesome,
    category: catNodes,
    priority: 6,
    steps: [
      HelpStep(
        id: 'constellation_intro',
        bubbleText:
            "Welcome to the **Constellation** — a star-map of your mesh network! Nodes appear as stars, and lines between them show **co-seen relationships** — nodes observed in the same session.",
        icoMood: MeshBrainMood.excited,
        canGoBack: false,
      ),
      HelpStep(
        id: 'constellation_layout',
        bubbleText:
            "The layout is **force-directed** — nodes that are frequently co-seen cluster together, while isolated nodes drift to the edges. The graph stabilizes after a moment so nothing shifts while you explore.",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'constellation_interactions',
        bubbleText:
            "**Tap** a node to highlight its connections. **Double-tap** to zoom into a cluster. **Long-press** to open the node's full profile. **Pinch** to zoom in and out of the star map.",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'constellation_edges',
        bubbleText:
            "Use the **edge density** button in the app bar to control how many connections are shown. **Sparse** shows only the strongest links, **All** shows everything. The right density depends on your network size.",
        icoMood: MeshBrainMood.approving,
      ),
      HelpStep(
        id: 'constellation_search',
        bubbleText:
            "The **search** icon lets you find a specific node by name or hex ID. The view automatically zooms and pans to center the matching node with a pulse highlight.",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'constellation_atmosphere',
        bubbleText:
            "The constellation has its own **Elemental Atmosphere** — subtle starlight and mist particles behind the graph, driven by your real mesh data. It never obstructs the visualization.",
        icoMood: MeshBrainMood.playful,
      ),
      HelpStep(
        id: 'constellation_data',
        bubbleText:
            "Co-seen data is built **automatically** from your encounters. The more sessions you observe, the richer the constellation becomes. All relationship data is stored locally — but is **lost if you delete the app**. With **Cloud Sync**, your entire constellation backs up and restores on any device you sign into.",
        icoMood: MeshBrainMood.approving,
      ),
    ],
  );

  // ============================================================================
  // CLOUD SYNC
  // ============================================================================

  static final HelpTopic cloudSyncOverview = HelpTopic(
    id: 'cloud_sync_overview',
    title: 'Cloud Sync',
    description: 'Premium cross-device sync for your mesh data',
    icon: Icons.cloud_sync,
    category: catSettings,
    priority: 16,
    steps: [
      HelpStep(
        id: 'cloud_sync_intro',
        bubbleText:
            "**Cloud Sync** is a premium subscription that keeps your mesh data synchronized across all your devices — and serves as your **backup**. Without it, all data lives only on-device and is permanently lost if you delete the app or lose your phone.",
        icoMood: MeshBrainMood.speaking,
        canGoBack: false,
      ),
      HelpStep(
        id: 'cloud_sync_what_syncs',
        bubbleText:
            "Cloud Sync backs up your **NodeDex** (sigils, encounters, social tags, notes, co-seen links), **automations**, **custom widgets**, and **profile**. Reinstall the app, switch phones, or sign in on a second device — your entire mesh identity restores automatically.",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'cloud_sync_offline_first',
        bubbleText:
            "The app is **offline-first**. Changes are saved locally to SQLite immediately and queued in an **outbox**. When you are online, the outbox drains to the cloud automatically — no manual sync needed.",
        icoMood: MeshBrainMood.approving,
      ),
      HelpStep(
        id: 'cloud_sync_conflict',
        bubbleText:
            "If you edit the same node on two devices, Cloud Sync uses **last-write-wins** conflict resolution with per-field timestamps. Social tags and notes resolve independently so you never lose both edits.",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'cloud_sync_subscription',
        bubbleText:
            "Cloud Sync is available as a **monthly** or **yearly** subscription. You can subscribe from **Settings > Account & Subscription**. Cancelled subscriptions keep working until the billing period ends.",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'cloud_sync_without',
        bubbleText:
            "Without Cloud Sync, all your data stays on-device only. It survives app restarts, but **not** app deletion or a phone reset. You can **export** your NodeDex as JSON for manual backup. Cloud Sync automates this and adds cross-device restore — but the app works fully offline without it.",
        icoMood: MeshBrainMood.approving,
      ),
    ],
  );

  // ============================================================================
  // AETHER
  // ============================================================================

  static final HelpTopic aetherOverview = HelpTopic(
    id: 'aether_overview',
    title: 'Aether',
    description: 'Track Meshtastic nodes at altitude',
    icon: Icons.radar,
    category: catNodes,
    priority: 4,
    steps: [
      HelpStep(
        id: 'aether_intro',
        bubbleText:
            "**Aether** lets you track Meshtastic nodes at altitude! At 35,000 ft, LoRa signals can reach **400+ km** — far beyond typical ground-level range.",
        icoMood: MeshBrainMood.speaking,
        canGoBack: false,
      ),
      HelpStep(
        id: 'aether_schedule',
        bubbleText:
            "**Schedule a flight** before you fly. Enter your flight number, airports, departure time, and your node's ID. Other mesh enthusiasts can then track your journey and try to receive your signal.",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'aether_active',
        bubbleText:
            "**Active flights** show live position data from the OpenSky Network API. You'll see altitude, speed, heading, and estimated coverage radius based on radio horizon calculations.",
        icoMood: MeshBrainMood.approving,
      ),
      HelpStep(
        id: 'aether_reports',
        bubbleText:
            "**Reception reports** let ground stations report when they receive your signal. Reports include distance, RSSI, and SNR. All reports are saved to the **global leaderboard**.",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'aether_leaderboard',
        bubbleText:
            "The **leaderboard is global and persistent** — stored in the cloud, not on your device. Rankings survive app reinstalls and are visible to the entire SocialMesh community. Top 3 get gold, silver, and bronze!",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'aether_tips',
        bubbleText:
            "**Tips**: Window seats help. Turn off airplane mode briefly during cruise altitude (where permitted). Ground stations with elevated antennas have better odds. Good luck!",
        icoMood: MeshBrainMood.approving,
      ),
    ],
  );

  // ============================================================================
  // TAK GATEWAY
  // ============================================================================

  static final HelpTopic takGatewayOverview = HelpTopic(
    id: 'tak_gateway_overview',
    title: 'TAK Gateway',
    description: 'Bridge your mesh into the TAK ecosystem',
    icon: Icons.shield_outlined,
    category: catNetwork,
    priority: 12,
    steps: [
      HelpStep(
        id: 'tak_intro',
        bubbleText:
            "**TAK Gateway** bridges your mesh into the Team Awareness "
            "Kit (TAK) ecosystem. It streams live **Cursor-on-Target** "
            "entities from a TAK server straight onto your map.",
        icoMood: MeshBrainMood.speaking,
        canGoBack: false,
      ),
      HelpStep(
        id: 'tak_connect',
        bubbleText:
            "Tap the **link icon** in the app bar to connect or disconnect. "
            "The status card shows your gateway URL, connection uptime, "
            "and total events received.",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'tak_affiliations',
        bubbleText:
            "Every entity is colored by **standard affiliation** — "
            "blue for friendly, red for hostile, green for neutral, "
            "yellow for unknown. The icon changes by dimension too: "
            "ground, air, sea, or space.",
        icoMood: MeshBrainMood.approving,
      ),
      HelpStep(
        id: 'tak_filter',
        bubbleText:
            "Use the **filter chips** to narrow the list by affiliation, "
            "or type a callsign in the **search bar**. The stale-mode "
            "chip cycles between all, active-only, and stale-only.",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'tak_detail',
        bubbleText:
            "Tap any entity to open its **detail screen** — full CoT "
            "fields, coordinates, speed, course, and raw XML. Use the "
            "map icon to jump straight to its position on the map.",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'tak_tracking',
        bubbleText:
            "**Long-press** an entity tile to toggle tracking. Tracked "
            "entities are highlighted on the map and stay visible even "
            "when the TAK screen is closed.",
        icoMood: MeshBrainMood.approving,
      ),
      HelpStep(
        id: 'tak_settings',
        bubbleText:
            "Open **TAK Settings** from the overflow menu to change the "
            "gateway URL, toggle auto-connect, and adjust the stale "
            "timeout. All settings persist between sessions.",
        icoMood: MeshBrainMood.speaking,
      ),
    ],
  );

  /// Section-level help text for TAK detail screens.
  ///
  /// Used by the section info buttons to show contextual help
  /// without starting a full guided tour.
  static const Map<String, String> takSectionHelp = {
    'status':
        'The status card shows whether the WebSocket connection to the TAK '
        'Gateway is active, the gateway URL, how long the connection has been '
        'up, and how many CoT events have been received since connecting.',
    'affiliation':
        'Affiliation describes the relationship of an entity to '
        'the observer: Friendly (blue), Hostile (red), Neutral (green), or '
        'Unknown (yellow). Affiliation is parsed from the second character '
        'of the CoT type string (e.g. a-f-G = friendly ground).',
    'cot_type':
        'The CoT type string encodes an entity\'s affiliation, dimension, '
        'and function using standard atoms separated by hyphens. For '
        'example, "a-f-G-U-C-I" is an atom (a), friendly (f), ground (G), '
        'unit (U-C), sub-type (I). The icon and color are derived '
        'from this string.',
    'identity':
        'The UID uniquely identifies this entity across all CoT messages. '
        'The callsign is a human-readable label assigned by the TAK server. '
        'The type string determines the entity\'s icon, color, and '
        'classification.',
    'position':
        'Latitude and longitude in WGS-84 decimal degrees as reported in '
        'the CoT event. Tap the "Show on Map" icon in the app bar to center '
        'the map on this position.',
    'motion':
        'Speed, course, and altitude parsed from the CoT event\'s track and '
        'point elements. Speed is shown in km/h and knots. Course is the '
        'heading in degrees from true north with a compass direction. '
        'Altitude is height above ellipsoid in meters and feet. '
        'This section is hidden when the gateway does not provide motion data.',
    'timestamps':
        'Event Time is when the CoT event was generated. Stale Time is when '
        'the entity should be considered outdated if no update arrives. '
        'Received is when SocialMesh received the event from the gateway. '
        'An entity is marked STALE when the current time exceeds Stale Time.',
    'tracking':
        'Tracked entities are pinned and highlighted on the map with a '
        'distinct marker ring. They remain visible even when you navigate '
        'away from the TAK screen. Long-press a tile to toggle tracking, '
        'or use the pin icon in the detail screen.',
    'raw_payload':
        'The raw JSON payload as received from the TAK Gateway WebSocket. '
        'This includes all CoT fields, XML attributes, and any extension '
        'data attached to the event. Useful for debugging or verifying '
        'what the gateway is sending.',
    'filters':
        'Filter chips let you narrow the entity list by affiliation. The '
        'stale-mode chip cycles through All (show everything), Active Only '
        '(hide stale entities), and Stale Only (show only expired entities). '
        'The search bar matches against callsign and UID.',
    'settings':
        'TAK Settings let you configure the gateway URL, toggle auto-connect '
        'on screen open, and set the stale timeout duration. All settings '
        'persist locally between app sessions.',
  };

  // ============================================================================
  // LEGAL & COMPLIANCE
  // ============================================================================

  /// Radio compliance help — linked from Channel Wizard screen.
  static final HelpTopic radioCompliance = HelpTopic(
    id: 'radio_compliance',
    title: 'Radio Rules & Your Responsibilities',
    description: 'Understand your legal obligations when using radio devices',
    icon: Icons.cell_tower,
    category: catLegal,
    priority: 1,
    steps: [
      HelpStep(
        id: 'radio_intro',
        bubbleText:
            "Mesh radios operate on **regulated frequencies**. That means there are rules about where, when, and how you can transmit.",
        icoMood: MeshBrainMood.focused,
        canGoBack: false,
      ),
      HelpStep(
        id: 'radio_responsibility',
        bubbleText:
            "**You** are responsible for making sure your radio equipment is legal in your country and that you operate within permitted frequency bands and power limits.",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'radio_licence',
        bubbleText:
            "Some regions require an **amateur radio licence** before you can transmit. Check with your local regulatory authority — for example, ACMA in Australia or FCC in the US.",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'radio_interference',
        bubbleText:
            "Never interfere with **emergency communications** or licensed services. Violations can result in fines or criminal penalties.",
        icoMood: MeshBrainMood.alert,
      ),
      HelpStep(
        id: 'radio_terms_link',
        bubbleText:
            "For full details, check the **Radio and Legal Compliance** section in our Terms of Service. You can find it in Settings under Terms of Service.",
        icoMood: MeshBrainMood.approving,
      ),
    ],
  );

  /// Acceptable use help — linked from Automations screen.
  static final HelpTopic acceptableUse = HelpTopic(
    id: 'acceptable_use',
    title: 'Acceptable Use & Prohibited Activities',
    description: 'What you can and cannot do with SocialMesh',
    icon: Icons.gavel_rounded,
    category: catLegal,
    priority: 2,
    steps: [
      HelpStep(
        id: 'use_intro',
        bubbleText:
            "SocialMesh is a powerful tool — automations, signals, and mesh messaging give you a lot of capability. With that comes responsibility!",
        icoMood: MeshBrainMood.focused,
        canGoBack: false,
      ),
      HelpStep(
        id: 'use_lawful',
        bubbleText:
            "Use the App only for **lawful purposes**. Do not transmit harmful, threatening, or abusive content over the mesh network.",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'use_automations',
        bubbleText:
            "Automations are great for alerts and notifications, but do not use them to **spam the mesh** or flood other users with unwanted messages.",
        icoMood: MeshBrainMood.alert,
      ),
      HelpStep(
        id: 'use_impersonation',
        bubbleText:
            "Do not **impersonate** other people or entities on the mesh network. Be yourself!",
        icoMood: MeshBrainMood.playful,
      ),
      HelpStep(
        id: 'use_terms_link',
        bubbleText:
            "The full list of prohibited activities is in the **Use of the Service** section of our Terms. You can review it anytime in Settings.",
        icoMood: MeshBrainMood.approving,
      ),
    ],
  );

  /// User responsibility help — linked from Signals / Create Signal screen.
  static final HelpTopic userResponsibility = HelpTopic(
    id: 'user_responsibility',
    title: 'Your Data, Your Responsibility',
    description: 'How SocialMesh handles data and what you are responsible for',
    icon: Icons.security_rounded,
    category: catLegal,
    priority: 3,
    steps: [
      HelpStep(
        id: 'responsibility_intro',
        bubbleText:
            "SocialMesh is designed to be **privacy-first**. Your messages and data stay on your device — we do not store them on any server.",
        icoMood: MeshBrainMood.focused,
        canGoBack: false,
      ),
      HelpStep(
        id: 'responsibility_signals',
        bubbleText:
            "When you create a **Signal**, it is broadcast over the mesh network. Anyone within range can receive it. Think of it like a public radio broadcast.",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'responsibility_content',
        bubbleText:
            "You are responsible for **everything you transmit**. Do not share personal information, sensitive data, or content that could harm others.",
        icoMood: MeshBrainMood.alert,
      ),
      HelpStep(
        id: 'responsibility_third_party',
        bubbleText:
            "Some features use **third-party services** like RevenueCat for purchases and Firebase for crash reports. These have their own privacy policies.",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'responsibility_terms_link',
        bubbleText:
            "For complete details, review our **Terms of Service** and **Privacy Policy** in Settings. They explain exactly what data stays local and what is shared.",
        icoMood: MeshBrainMood.approving,
      ),
    ],
  );

  // ============================================================================
  // FILE TRANSFER HELP
  // ============================================================================

  static final HelpTopic fileTransferOverview = HelpTopic(
    id: 'file_transfer_overview',
    title: 'File Transfers',
    description: 'Send files over the mesh radio without internet',
    icon: Icons.attach_file,
    category: catNetwork,
    priority: 28,
    steps: [
      HelpStep(
        id: 'ft_intro',
        bubbleText:
            "**File Transfers** let you send small files — text, configs, coordinates — directly over LoRa radio. No internet, no servers.",
        icoMood: MeshBrainMood.excited,
        canGoBack: false,
      ),
      HelpStep(
        id: 'ft_how',
        bubbleText:
            "Files are split into **~200-byte chunks** and sent one at a time over the mesh. The receiver reassembles them automatically.",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'ft_nack',
        bubbleText:
            "Missed a chunk? No problem. The receiver sends a **NACK** (negative acknowledgement) to request retransmission of exactly the missing pieces.",
        icoMood: MeshBrainMood.approving,
      ),
      HelpStep(
        id: 'ft_limit',
        bubbleText:
            "Files are capped at **8 KB**. LoRa is a slow, shared, low-power radio — a single transfer can occupy the channel for up to a minute at long-range settings.",
        icoMood: MeshBrainMood.alert,
      ),
      HelpStep(
        id: 'ft_beta',
        bubbleText:
            "This feature is **BETA**. Both nodes must be running SocialMesh on the same mesh channel. Standard Meshtastic nodes cannot receive these transfers.",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'ft_contacts',
        bubbleText:
            "Use the **Contacts** tab to choose a node, then tap **Send File**. The Contacts tab shows every node your device has seen on the mesh.",
        icoMood: MeshBrainMood.speaking,
      ),
    ],
  );

  static final HelpTopic fileTransferLimits = HelpTopic(
    id: 'file_transfer_limits',
    title: 'Why Only 8 KB?',
    description: 'Airtime budget and LoRa duty cycle explained',
    icon: Icons.timer_outlined,
    category: catNetwork,
    priority: 29,
    steps: [
      HelpStep(
        id: 'ftl_shared',
        bubbleText:
            "LoRa channels are **shared and slow**. Every byte you send is airtime stolen from every other node in range. Treat it like a walkie-talkie frequency, not Wi-Fi.",
        icoMood: MeshBrainMood.alert,
        canGoBack: false,
      ),
      HelpStep(
        id: 'ftl_toa',
        bubbleText:
            "**Time on Air** per chunk depends on Spreading Factor (SF). SF7 (fast, short range): ~30 ms/chunk. SF12 (slow, long range): ~1,500 ms/chunk.",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'ftl_math',
        bubbleText:
            "8 KB ÷ 200 bytes/chunk = **41 chunks**. At SF7: ~1.2 seconds total. At SF12: **~62 seconds** of continuous radio transmission.",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'ftl_duty',
        bubbleText:
            "EU868 and similar bands impose a **1% duty cycle** — your radio can only transmit for 36 seconds per hour. At SF12, one 8 KB transfer nearly exhausts that entire budget.",
        icoMood: MeshBrainMood.alert,
      ),
      HelpStep(
        id: 'ftl_cap',
        bubbleText:
            "8 KB is the **safest ceiling** that keeps transfers survivable at worst-case spreading factors without violating duty cycle regulations or blocking the mesh for minutes.",
        icoMood: MeshBrainMood.approving,
      ),
      HelpStep(
        id: 'ftl_usb',
        bubbleText:
            "BLE and USB-connected transfers carry no radio duty-cycle risk. In a future release, higher limits will be unlocked for direct wired connections.",
        icoMood: MeshBrainMood.speaking,
      ),
    ],
  );

  // ============================================================================
  // SIP HUB HELP
  // ============================================================================

  static final HelpTopic sipHubOverview = HelpTopic(
    id: 'sip_hub_overview',
    title: 'SocialMesh',
    description: 'Discover and chat with nearby SocialMesh peers',
    icon: Icons.sensors,
    category: catNetwork,
    priority: 7,
    steps: [
      HelpStep(
        id: 'sip_hub_intro',
        bubbleText:
            "Welcome to **SocialMesh**! This is your peer discovery hub. Nearby devices running SocialMesh appear here once they beacon or respond to a rollcall.",
        icoMood: MeshBrainMood.excited,
        canGoBack: false,
      ),
      HelpStep(
        id: 'sip_hub_scan',
        bubbleText:
            "Tap the **scan icon** to send a rollcall request. Nearby peers will respond within seconds. Auto-scan fires every 60 seconds in the background.",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'sip_hub_handshake',
        bubbleText:
            "Once you see a peer, tap **Handshake** to exchange identity. After the handshake you can open an **end-to-end encrypted** ephemeral DM — no servers, no accounts.",
        icoMood: MeshBrainMood.approving,
      ),
      HelpStep(
        id: 'sip_hub_privacy',
        bubbleText:
            "All discovery is **anonymous by default**. Peers only reveal a rotating 4-byte ambient ID until you mutually agree to a handshake.",
        icoMood: MeshBrainMood.playful,
      ),
    ],
  );

  // ============================================================================
  // MESH EXPLORER HELP
  // ============================================================================

  static final HelpTopic meshExplorerOverview = HelpTopic(
    id: 'mesh_explorer_overview',
    title: 'Mesh Explorer',
    description: 'Explore nearby peers and mesh services',
    icon: Icons.explore_outlined,
    category: catNetwork,
    priority: 8,
    steps: [
      HelpStep(
        id: 'mesh_explorer_intro',
        bubbleText:
            "Welcome to **Mesh Explorer**! This shows all SocialMesh-capable peers currently in radio range. Anonymous peers appear instantly — no handshake needed.",
        icoMood: MeshBrainMood.excited,
        canGoBack: false,
      ),
      HelpStep(
        id: 'mesh_explorer_peers',
        bubbleText:
            "Each tile shows a **peer's ambient sigil** and capabilities. Tap a peer to view details or initiate a **SIP handshake** for identity exchange.",
        icoMood: MeshBrainMood.speaking,
      ),
      HelpStep(
        id: 'mesh_explorer_services',
        bubbleText:
            "The **Services** section shows what nearby peers are offering — Bulletin Boards, Profiles, and more. Tap a service tile to interact with it.",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'mesh_explorer_scan',
        bubbleText:
            "Tap the **sensor icon** to broadcast a rollcall to the mesh. Peers respond within seconds. The explorer refreshes automatically when new peers are heard.",
        icoMood: MeshBrainMood.approving,
      ),
    ],
  );

  // ============================================================================
  // ALL TOPICS
  // ============================================================================

  static final List<HelpTopic> allTopics = [
    channelCreation,
    channelsOverview,
    encryptionLevels,
    deviceConnection,
    radioCompliance,
    acceptableUse,
    userResponsibility,
    regionSelection,
    nodesOverview,
    nodeRoles,
    mapOverview,
    messageRouting,
    automationsOverview,
    presenceOverview,
    reachabilityOverview,
    meshHealthOverview,
    gpsSettings,
    signalMetrics,
    dashboardOverview,
    widgetBuilderOverview,
    marketplaceOverview,
    signalsOverview,
    signalCreation,
    signalDetail,
    worldMeshOverview,
    routesOverview,
    positionOverview,
    settingsOverview,
    profileOverview,
    mesh3dOverview,
    globeOverview,
    timelineOverview,
    deviceShopOverview,
    offlineMapsOverview,
    radioConfigOverview,
    nodeDexOverview,
    nodeDexDetail,
    nodeDexAlbum,
    nodeDexConstellation,
    cloudSyncOverview,
    tracerouteOverview,
    aetherOverview,
    takGatewayOverview,
    fileTransferOverview,
    fileTransferLimits,
    sipHubOverview,
    meshExplorerOverview,
  ];

  /// Get a topic by ID
  static HelpTopic? getTopic(String id) {
    try {
      return allTopics.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get topics by category
  static List<HelpTopic> getTopicsByCategory(String category) {
    return allTopics.where((t) => t.category == category).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }

  /// Get all categories
  static List<String> get allCategories => [
    catChannels,
    catMessaging,
    catNodes,
    catDevice,
    catNetwork,
    catAutomations,
    catSettings,
    catLegal,
  ];

  // ---------------------------------------------------------------------------
  // Localization lookup methods
  // ---------------------------------------------------------------------------
  // These map English-default const data to localized strings at runtime.
  // Callers (help screens, tours) pass AppLocalizations to get the translated
  // version; the English fallback is the topic/step id itself.

  /// Returns the localized title for a help topic.
  static String localizedTitle(String topicId, AppLocalizations l10n) =>
      switch (topicId) {
        'channel_creation' => l10n.helpChannelCreationTitle,
        'encryption_levels' => l10n.helpEncryptionLevelsTitle,
        'message_routing' => l10n.helpMessageRoutingTitle,
        'nodes_overview' => l10n.helpNodesOverviewTitle,
        'node_roles' => l10n.helpNodeRolesTitle,
        'region_selection' => l10n.helpRegionSelectionTitle,
        'device_connection' => l10n.helpDeviceConnectionTitle,
        'gps_settings' => l10n.helpGpsSettingsTitle,
        'signal_metrics' => l10n.helpSignalMetricsTitle,
        'map_overview' => l10n.helpMapOverviewTitle,
        'channels_overview' => l10n.helpChannelsOverviewTitle,
        'automations_overview' => l10n.helpAutomationsOverviewTitle,
        'dashboard_overview' => l10n.helpDashboardOverviewTitle,
        'widget_builder_overview' => l10n.helpWidgetBuilderOverviewTitle,
        'marketplace_overview' => l10n.helpMarketplaceOverviewTitle,
        'signals_overview' => l10n.helpSignalsOverviewTitle,
        'signal_creation' => l10n.helpSignalCreationTitle,
        'signal_detail' => l10n.helpSignalDetailTitle,
        'world_mesh_overview' => l10n.helpWorldMeshOverviewTitle,
        'routes_overview' => l10n.helpRoutesOverviewTitle,
        'position_overview' => l10n.helpPositionOverviewTitle,
        'settings_overview' => l10n.helpSettingsOverviewTitle,
        'profile_overview' => l10n.helpProfileOverviewTitle,
        'mesh_3d_overview' => l10n.helpMesh3dOverviewTitle,
        'globe_overview' => l10n.helpGlobeOverviewTitle,
        'timeline_overview' => l10n.helpTimelineOverviewTitle,
        'device_shop_overview' => l10n.helpDeviceShopOverviewTitle,
        'offline_maps_overview' => l10n.helpOfflineMapsOverviewTitle,
        'radio_config_overview' => l10n.helpRadioConfigOverviewTitle,
        'presence_overview' => l10n.helpPresenceOverviewTitle,
        'reachability_overview' => l10n.helpReachabilityOverviewTitle,
        'mesh_health_overview' => l10n.helpMeshHealthOverviewTitle,
        'traceroute_overview' => l10n.helpTracerouteOverviewTitle,
        'nodedex_overview' => l10n.helpNodedexOverviewTitle,
        'nodedex_detail' => l10n.helpNodedexDetailTitle,
        'nodedex_album' => l10n.helpNodedexAlbumTitle,
        'nodedex_constellation' => l10n.helpNodedexConstellationTitle,
        'cloud_sync_overview' => l10n.helpCloudSyncOverviewTitle,
        'aether_overview' => l10n.helpAetherOverviewTitle,
        'tak_gateway_overview' => l10n.helpTakGatewayOverviewTitle,
        'radio_compliance' => l10n.helpRadioComplianceTitle,
        'acceptable_use' => l10n.helpAcceptableUseTitle,
        'user_responsibility' => l10n.helpUserResponsibilityTitle,
        'file_transfer_overview' => l10n.helpFileTransferOverviewTitle,
        'file_transfer_limits' => l10n.helpFileTransferLimitsTitle,
        'sip_hub_overview' => l10n.helpSipHubOverviewTitle,
        'mesh_explorer_overview' => l10n.helpMeshExplorerOverviewTitle,
        _ => topicId,
      };

  /// Returns the localized description for a help topic.
  static String localizedDescription(String topicId, AppLocalizations l10n) =>
      switch (topicId) {
        'channel_creation' => l10n.helpChannelCreationDescription,
        'encryption_levels' => l10n.helpEncryptionLevelsDescription,
        'message_routing' => l10n.helpMessageRoutingDescription,
        'nodes_overview' => l10n.helpNodesOverviewDescription,
        'node_roles' => l10n.helpNodeRolesDescription,
        'region_selection' => l10n.helpRegionSelectionDescription,
        'device_connection' => l10n.helpDeviceConnectionDescription,
        'gps_settings' => l10n.helpGpsSettingsDescription,
        'signal_metrics' => l10n.helpSignalMetricsDescription,
        'map_overview' => l10n.helpMapOverviewDescription,
        'channels_overview' => l10n.helpChannelsOverviewDescription,
        'automations_overview' => l10n.helpAutomationsOverviewDescription,
        'dashboard_overview' => l10n.helpDashboardOverviewDescription,
        'widget_builder_overview' => l10n.helpWidgetBuilderOverviewDescription,
        'marketplace_overview' => l10n.helpMarketplaceOverviewDescription,
        'signals_overview' => l10n.helpSignalsOverviewDescription,
        'signal_creation' => l10n.helpSignalCreationDescription,
        'signal_detail' => l10n.helpSignalDetailDescription,
        'world_mesh_overview' => l10n.helpWorldMeshOverviewDescription,
        'routes_overview' => l10n.helpRoutesOverviewDescription,
        'position_overview' => l10n.helpPositionOverviewDescription,
        'settings_overview' => l10n.helpSettingsOverviewDescription,
        'profile_overview' => l10n.helpProfileOverviewDescription,
        'mesh_3d_overview' => l10n.helpMesh3dOverviewDescription,
        'globe_overview' => l10n.helpGlobeOverviewDescription,
        'timeline_overview' => l10n.helpTimelineOverviewDescription,
        'device_shop_overview' => l10n.helpDeviceShopOverviewDescription,
        'offline_maps_overview' => l10n.helpOfflineMapsOverviewDescription,
        'radio_config_overview' => l10n.helpRadioConfigOverviewDescription,
        'presence_overview' => l10n.helpPresenceOverviewDescription,
        'reachability_overview' => l10n.helpReachabilityOverviewDescription,
        'mesh_health_overview' => l10n.helpMeshHealthOverviewDescription,
        'traceroute_overview' => l10n.helpTracerouteOverviewDescription,
        'nodedex_overview' => l10n.helpNodedexOverviewDescription,
        'nodedex_detail' => l10n.helpNodedexDetailDescription,
        'nodedex_album' => l10n.helpNodedexAlbumDescription,
        'nodedex_constellation' => l10n.helpNodedexConstellationDescription,
        'cloud_sync_overview' => l10n.helpCloudSyncOverviewDescription,
        'aether_overview' => l10n.helpAetherOverviewDescription,
        'tak_gateway_overview' => l10n.helpTakGatewayOverviewDescription,
        'radio_compliance' => l10n.helpRadioComplianceDescription,
        'acceptable_use' => l10n.helpAcceptableUseDescription,
        'user_responsibility' => l10n.helpUserResponsibilityDescription,
        'file_transfer_overview' => l10n.helpFileTransferOverviewDescription,
        'file_transfer_limits' => l10n.helpFileTransferLimitsDescription,
        'sip_hub_overview' => l10n.helpSipHubOverviewDescription,
        'mesh_explorer_overview' => l10n.helpMeshExplorerOverviewDescription,
        _ => topicId,
      };

  /// Returns the localized bubble text for a help step.
  static String localizedBubbleText(
    String stepId,
    AppLocalizations l10n,
  ) => switch (stepId) {
    'channel_intro' => l10n.helpChannelIntroBubble,
    'channel_name' => l10n.helpChannelNameBubble,
    'privacy_level' => l10n.helpPrivacyLevelBubble,
    'encryption_key' => l10n.helpEncryptionKeyBubble,
    'channel_complete' => l10n.helpChannelCompleteBubble,
    'encryption_intro' => l10n.helpEncryptionIntroBubble,
    'default_key' => l10n.helpDefaultKeyBubble,
    'psk_encryption' => l10n.helpPskEncryptionBubble,
    'psk_sharing' => l10n.helpPskSharingBubble,
    'routing_intro' => l10n.helpRoutingIntroBubble,
    'routing_hops' => l10n.helpRoutingHopsBubble,
    'routing_router_role' => l10n.helpRoutingRouterRoleBubble,
    'routing_store_forward' => l10n.helpRoutingStoreForwardBubble,
    'nodes_intro' => l10n.helpNodesIntroBubble,
    'nodes_status' => l10n.helpNodesStatusBubble,
    'nodes_info' => l10n.helpNodesInfoBubble,
    'nodes_filters' => l10n.helpNodesFiltersBubble,
    'nodes_actions' => l10n.helpNodesActionsBubble,
    'roles_intro' => l10n.helpRolesIntroBubble,
    'role_client' => l10n.helpRoleClientBubble,
    'role_router' => l10n.helpRoleRouterBubble,
    'role_router_late' => l10n.helpRoleRouterLateBubble,
    'role_client_base' => l10n.helpRoleClientBaseBubble,
    'region_intro' => l10n.helpRegionIntroBubble,
    'region_legal' => l10n.helpRegionLegalBubble,
    'region_bands' => l10n.helpRegionBandsBubble,
    'region_warning' => l10n.helpRegionWarningBubble,
    'connection_intro' => l10n.helpConnectionIntroBubble,
    'connection_ble' => l10n.helpConnectionBleBubble,
    'connection_usb' => l10n.helpConnectionUsbBubble,
    'connection_pairing' => l10n.helpConnectionPairingBubble,
    'connection_troubleshoot' => l10n.helpConnectionTroubleshootBubble,
    'connection_disconnect' => l10n.helpConnectionDisconnectBubble,
    'gps_intro' => l10n.helpGpsIntroBubble,
    'gps_broadcast' => l10n.helpGpsBroadcastBubble,
    'gps_privacy' => l10n.helpGpsPrivacyBubble,
    'gps_battery' => l10n.helpGpsBatteryBubble,
    'metrics_intro' => l10n.helpMetricsIntroBubble,
    'metrics_rssi' => l10n.helpMetricsRssiBubble,
    'metrics_snr' => l10n.helpMetricsSnrBubble,
    'metrics_practical' => l10n.helpMetricsPracticalBubble,
    'map_intro' => l10n.helpMapIntroBubble,
    'map_markers' => l10n.helpMapMarkersBubble,
    'map_features' => l10n.helpMapFeaturesBubble,
    'map_measure' => l10n.helpMapMeasureBubble,
    'map_filters' => l10n.helpMapFiltersBubble,
    'channels_intro' => l10n.helpChannelsIntroBubble,
    'channels_primary' => l10n.helpChannelsPrimaryBubble,
    'channels_secondary' => l10n.helpChannelsSecondaryBubble,
    'channels_encryption' => l10n.helpChannelsEncryptionBubble,
    'channels_share' => l10n.helpChannelsShareBubble,
    'automations_intro' => l10n.helpAutomationsIntroBubble,
    'automations_triggers' => l10n.helpAutomationsTriggersBubble,
    'automations_actions' => l10n.helpAutomationsActionsBubble,
    'automations_examples' => l10n.helpAutomationsExamplesBubble,
    'automations_toggle' => l10n.helpAutomationsToggleBubble,
    'dashboard_intro' => l10n.helpDashboardIntroBubble,
    'dashboard_widgets' => l10n.helpDashboardWidgetsBubble,
    'dashboard_reorder' => l10n.helpDashboardReorderBubble,
    'dashboard_tap' => l10n.helpDashboardTapBubble,
    'builder_intro' => l10n.helpBuilderIntroBubble,
    'builder_templates' => l10n.helpBuilderTemplatesBubble,
    'builder_bindings' => l10n.helpBuilderBindingsBubble,
    'builder_preview' => l10n.helpBuilderPreviewBubble,
    'marketplace_intro' => l10n.helpMarketplaceIntroBubble,
    'marketplace_browse' => l10n.helpMarketplaceBrowseBubble,
    'marketplace_install' => l10n.helpMarketplaceInstallBubble,
    'marketplace_share' => l10n.helpMarketplaceShareBubble,
    'signals_intro' => l10n.helpSignalsIntroBubble,
    'signals_create' => l10n.helpSignalsCreateBubble,
    'signals_proximity' => l10n.helpSignalsProximityBubble,
    'signals_filters' => l10n.helpSignalsFiltersBubble,
    'signals_privacy' => l10n.helpSignalsPrivacyBubble,
    'create_intro' => l10n.helpCreateIntroBubble,
    'create_text' => l10n.helpCreateTextBubble,
    'create_image' => l10n.helpCreateImageBubble,
    'create_location' => l10n.helpCreateLocationBubble,
    'create_ttl' => l10n.helpCreateTtlBubble,
    'create_intent' => l10n.helpCreateIntentBubble,
    'create_status' => l10n.helpCreateStatusBubble,
    'create_submit' => l10n.helpCreateSubmitBubble,
    'detail_intro' => l10n.helpDetailIntroBubble,
    'detail_ttl' => l10n.helpDetailTtlBubble,
    'detail_responses' => l10n.helpDetailResponsesBubble,
    'detail_voting' => l10n.helpDetailVotingBubble,
    'detail_reply' => l10n.helpDetailReplyBubble,
    'detail_actions' => l10n.helpDetailActionsBubble,
    'world_intro' => l10n.helpWorldIntroBubble,
    'world_scope' => l10n.helpWorldScopeBubble,
    'world_data' => l10n.helpWorldDataBubble,
    'world_filters' => l10n.helpWorldFiltersBubble,
    'routes_intro' => l10n.helpRoutesIntroBubble,
    'routes_record' => l10n.helpRoutesRecordBubble,
    'routes_gpx' => l10n.helpRoutesGpxBubble,
    'routes_share' => l10n.helpRoutesShareBubble,
    'position_intro' => l10n.helpPositionIntroBubble,
    'position_list_map' => l10n.helpPositionListMapBubble,
    'position_filters' => l10n.helpPositionFiltersBubble,
    'position_search' => l10n.helpPositionSearchBubble,
    'position_map_nodes' => l10n.helpPositionMapNodesBubble,
    'position_export' => l10n.helpPositionExportBubble,
    'position_good_fix' => l10n.helpPositionGoodFixBubble,
    'settings_intro' => l10n.helpSettingsIntroBubble,
    'settings_device' => l10n.helpSettingsDeviceBubble,
    'settings_app' => l10n.helpSettingsAppBubble,
    'settings_cloud' => l10n.helpSettingsCloudBubble,
    'profile_intro' => l10n.helpProfileIntroBubble,
    'profile_customize' => l10n.helpProfileCustomizeBubble,
    'profile_share' => l10n.helpProfileShareBubble,
    'profile_cloud' => l10n.helpProfileCloudBubble,
    'mesh3d_intro' => l10n.helpMesh3dIntroBubble,
    'mesh3d_nodes' => l10n.helpMesh3dNodesBubble,
    'mesh3d_colors' => l10n.helpMesh3dColorsBubble,
    'mesh3d_tap' => l10n.helpMesh3dTapBubble,
    'globe_intro' => l10n.helpGlobeIntroBubble,
    'globe_interact' => l10n.helpGlobeInteractBubble,
    'globe_arcs' => l10n.helpGlobeArcsBubble,
    'timeline_intro' => l10n.helpTimelineIntroBubble,
    'timeline_filter' => l10n.helpTimelineFilterBubble,
    'timeline_tap' => l10n.helpTimelineTapBubble,
    'shop_intro' => l10n.helpShopIntroBubble,
    'shop_compare' => l10n.helpShopCompareBubble,
    'shop_links' => l10n.helpShopLinksBubble,
    'offline_intro' => l10n.helpOfflineIntroBubble,
    'offline_download' => l10n.helpOfflineDownloadBubble,
    'offline_manage' => l10n.helpOfflineManageBubble,
    'radio_intro' => l10n.helpRadioIntroBubble,
    'radio_region' => l10n.helpRadioRegionBubble,
    'radio_modem' => l10n.helpRadioModemBubble,
    'radio_power' => l10n.helpRadioPowerBubble,
    'presence_intro' => l10n.helpPresenceIntroBubble,
    'presence_active' => l10n.helpPresenceActiveBubble,
    'presence_recent' => l10n.helpPresenceRecentBubble,
    'presence_inactive' => l10n.helpPresenceInactiveBubble,
    'presence_chart' => l10n.helpPresenceChartBubble,
    'reachability_intro' => l10n.helpReachabilityIntroBubble,
    'reachability_beta' => l10n.helpReachabilityBetaBubble,
    'reachability_high' => l10n.helpReachabilityHighBubble,
    'reachability_medium' => l10n.helpReachabilityMediumBubble,
    'reachability_low' => l10n.helpReachabilityLowBubble,
    'health_intro' => l10n.helpHealthIntroBubble,
    'health_status' => l10n.helpHealthStatusBubble,
    'health_metrics' => l10n.helpHealthMetricsBubble,
    'health_utilization' => l10n.helpHealthUtilizationBubble,
    'health_issues' => l10n.helpHealthIssuesBubble,
    'health_monitoring' => l10n.helpHealthMonitoringBubble,
    'traceroute_intro' => l10n.helpTracerouteIntroBubble,
    'traceroute_how' => l10n.helpTracerouteHowBubble,
    'traceroute_send' => l10n.helpTracerouteSendBubble,
    'traceroute_cooldown' => l10n.helpTracerouteCooldownBubble,
    'traceroute_results' => l10n.helpTracerouteResultsBubble,
    'traceroute_history' => l10n.helpTracerouteHistoryBubble,
    'traceroute_export' => l10n.helpTracerouteExportBubble,
    'traceroute_tips' => l10n.helpTracerouteTipsBubble,
    'nodedex_intro' => l10n.helpNodedexIntroBubble,
    'nodedex_sigils' => l10n.helpNodedexSigilsBubble,
    'nodedex_traits' => l10n.helpNodedexTraitsBubble,
    'nodedex_filters' => l10n.helpNodedexFiltersBubble,
    'nodedex_field_journal' => l10n.helpNodedexFieldJournalBubble,
    'nodedex_album_mode' => l10n.helpNodedexAlbumModeBubble,
    'nodedex_atmosphere' => l10n.helpNodedexAtmosphereBubble,
    'nodedex_cloud_sync' => l10n.helpNodedexCloudSyncBubble,
    'nodedex_export' => l10n.helpNodedexExportBubble,
    'nodedex_sigil' => l10n.helpNodedexSigilBubble,
    'nodedex_trait' => l10n.helpNodedexTraitBubble,
    'nodedex_auto_summary' => l10n.helpNodedexAutoSummaryBubble,
    'nodedex_observation_timeline' => l10n.helpNodedexObservationTimelineBubble,
    'nodedex_discovery' => l10n.helpNodedexDiscoveryBubble,
    'nodedex_signal' => l10n.helpNodedexSignalBubble,
    'nodedex_social_tag' => l10n.helpNodedexSocialTagBubble,
    'nodedex_note' => l10n.helpNodedexNoteBubble,
    'nodedex_regions' => l10n.helpNodedexRegionsBubble,
    'nodedex_encounters' => l10n.helpNodedexEncountersBubble,
    'nodedex_activity_timeline' => l10n.helpNodedexActivityTimelineBubble,
    'nodedex_coseen' => l10n.helpNodedexCoseenBubble,
    'nodedex_device' => l10n.helpNodedexDeviceBubble,
    'album_intro' => l10n.helpAlbumIntroBubble,
    'album_cover' => l10n.helpAlbumCoverBubble,
    'album_grouping' => l10n.helpAlbumGroupingBubble,
    'album_rarity' => l10n.helpAlbumRarityBubble,
    'album_interactions' => l10n.helpAlbumInteractionsBubble,
    'album_gallery' => l10n.helpAlbumGalleryBubble,
    'album_holographic' => l10n.helpAlbumHolographicBubble,
    'album_persistence' => l10n.helpAlbumPersistenceBubble,
    'constellation_intro' => l10n.helpConstellationIntroBubble,
    'constellation_layout' => l10n.helpConstellationLayoutBubble,
    'constellation_interactions' => l10n.helpConstellationInteractionsBubble,
    'constellation_edges' => l10n.helpConstellationEdgesBubble,
    'constellation_search' => l10n.helpConstellationSearchBubble,
    'constellation_atmosphere' => l10n.helpConstellationAtmosphereBubble,
    'constellation_data' => l10n.helpConstellationDataBubble,
    'cloud_sync_intro' => l10n.helpCloudSyncIntroBubble,
    'cloud_sync_what_syncs' => l10n.helpCloudSyncWhatSyncsBubble,
    'cloud_sync_offline_first' => l10n.helpCloudSyncOfflineFirstBubble,
    'cloud_sync_conflict' => l10n.helpCloudSyncConflictBubble,
    'cloud_sync_subscription' => l10n.helpCloudSyncSubscriptionBubble,
    'cloud_sync_without' => l10n.helpCloudSyncWithoutBubble,
    'aether_intro' => l10n.helpAetherIntroBubble,
    'aether_schedule' => l10n.helpAetherScheduleBubble,
    'aether_active' => l10n.helpAetherActiveBubble,
    'aether_reports' => l10n.helpAetherReportsBubble,
    'aether_leaderboard' => l10n.helpAetherLeaderboardBubble,
    'aether_tips' => l10n.helpAetherTipsBubble,
    'tak_intro' => l10n.helpTakIntroBubble,
    'tak_connect' => l10n.helpTakConnectBubble,
    'tak_affiliations' => l10n.helpTakAffiliationsBubble,
    'tak_filter' => l10n.helpTakFilterBubble,
    'tak_detail' => l10n.helpTakDetailBubble,
    'tak_tracking' => l10n.helpTakTrackingBubble,
    'tak_settings' => l10n.helpTakSettingsBubble,
    'radio_responsibility' => l10n.helpRadioResponsibilityBubble,
    'radio_licence' => l10n.helpRadioLicenceBubble,
    'radio_interference' => l10n.helpRadioInterferenceBubble,
    'radio_terms_link' => l10n.helpRadioTermsLinkBubble,
    'use_intro' => l10n.helpUseIntroBubble,
    'use_lawful' => l10n.helpUseLawfulBubble,
    'use_automations' => l10n.helpUseAutomationsBubble,
    'use_impersonation' => l10n.helpUseImpersonationBubble,
    'use_terms_link' => l10n.helpUseTermsLinkBubble,
    'responsibility_intro' => l10n.helpResponsibilityIntroBubble,
    'responsibility_signals' => l10n.helpResponsibilitySignalsBubble,
    'responsibility_content' => l10n.helpResponsibilityContentBubble,
    'responsibility_third_party' => l10n.helpResponsibilityThirdPartyBubble,
    'responsibility_terms_link' => l10n.helpResponsibilityTermsLinkBubble,
    'ft_intro' => l10n.helpFtIntroBubble,
    'ft_how' => l10n.helpFtHowBubble,
    'ft_nack' => l10n.helpFtNackBubble,
    'ft_limit' => l10n.helpFtLimitBubble,
    'ft_beta' => l10n.helpFtBetaBubble,
    'ft_contacts' => l10n.helpFtContactsBubble,
    'ftl_shared' => l10n.helpFtlSharedBubble,
    'ftl_toa' => l10n.helpFtlToaBubble,
    'ftl_math' => l10n.helpFtlMathBubble,
    'ftl_duty' => l10n.helpFtlDutyBubble,
    'ftl_cap' => l10n.helpFtlCapBubble,
    'ftl_usb' => l10n.helpFtlUsbBubble,
    'sip_hub_intro' => l10n.helpSipHubIntroBubble,
    'sip_hub_scan' => l10n.helpSipHubScanBubble,
    'sip_hub_handshake' => l10n.helpSipHubHandshakeBubble,
    'sip_hub_privacy' => l10n.helpSipHubPrivacyBubble,
    'mesh_explorer_intro' => l10n.helpMeshExplorerIntroBubble,
    'mesh_explorer_peers' => l10n.helpMeshExplorerPeersBubble,
    'mesh_explorer_services' => l10n.helpMeshExplorerServicesBubble,
    'mesh_explorer_scan' => l10n.helpMeshExplorerScanBubble,
    _ => stepId,
  };

  /// Returns the localized section help text for NodeDex.
  static String localizedNodeDexSectionHelp(
    String key,
    AppLocalizations l10n,
  ) => switch (key) {
    'sigil' => l10n.helpNodeDexSectionSigil,
    'trait' => l10n.helpNodeDexSectionTrait,
    'auto_summary' => l10n.helpNodeDexSectionAutoSummary,
    'observation_timeline' => l10n.helpNodeDexSectionObservationTimeline,
    'discovery' => l10n.helpNodeDexSectionDiscovery,
    'signal' => l10n.helpNodeDexSectionSignal,
    'social_tag' => l10n.helpNodeDexSectionSocialTag,
    'note' => l10n.helpNodeDexSectionNote,
    'regions' => l10n.helpNodeDexSectionRegions,
    'encounters' => l10n.helpNodeDexSectionEncounters,
    'activity_timeline' => l10n.helpNodeDexSectionActivityTimeline,
    'coseen' => l10n.helpNodeDexSectionCoseen,
    'device' => l10n.helpNodeDexSectionDevice,
    'trait_evidence' => l10n.helpNodeDexSectionTraitEvidence,
    'additional_traits' => l10n.helpNodeDexSectionAdditionalTraits,
    'pet_companion_self' => l10n.helpNodeDexSectionPetCompanionSelf,
    'pet_companion_remote' => l10n.helpNodeDexSectionPetCompanionRemote,
    'mrrp_services' => l10n.helpNodeDexSectionMrrpServices,
    'field_note' => l10n.helpNodeDexSectionFieldNote,
    'radio_compatibility' => l10n.helpNodeDexSectionRadioCompatibility,
    'album_rarity' => l10n.helpNodeDexSectionAlbumRarity,
    'album_grouping' => l10n.helpNodeDexSectionAlbumGrouping,
    'album_explorer_title' => l10n.helpNodeDexSectionAlbumExplorerTitle,
    'album_holographic' => l10n.helpNodeDexSectionAlbumHolographic,
    'album_patina' => l10n.helpNodeDexSectionAlbumPatina,
    'album_cloud_sync' => l10n.helpNodeDexSectionAlbumCloudSync,
    _ => key,
  };

  /// Returns the localized section help text for TAK.
  static String localizedTakSectionHelp(String key, AppLocalizations l10n) =>
      switch (key) {
        'status' => l10n.helpTakSectionStatus,
        'affiliation' => l10n.helpTakSectionAffiliation,
        'cot_type' => l10n.helpTakSectionCotType,
        'identity' => l10n.helpTakSectionIdentity,
        'position' => l10n.helpTakSectionPosition,
        'motion' => l10n.helpTakSectionMotion,
        'timestamps' => l10n.helpTakSectionTimestamps,
        'tracking' => l10n.helpTakSectionTracking,
        'raw_payload' => l10n.helpTakSectionRawPayload,
        'filters' => l10n.helpTakSectionFilters,
        'settings' => l10n.helpTakSectionSettings,
        _ => key,
      };

  /// Get topics sorted by priority
  static List<HelpTopic> get topicsByPriority =>
      List<HelpTopic>.from(allTopics)
        ..sort((a, b) => a.priority.compareTo(b.priority));
}
