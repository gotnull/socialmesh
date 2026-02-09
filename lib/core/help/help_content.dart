// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:socialmesh/features/onboarding/widgets/mesh_node_brain.dart';

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
            "**Green dot** means **Active** (heard very recently). **Yellow** means **Seen recently**. **Gray** means **Inactive**. LoRa has no offline signal—status is inferred.",
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
            "Use the **filters** at the top to find specific nodes. You can show only **Active** nodes, favorites, or nodes with GPS.",
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
        id: 'role_router_client',
        bubbleText:
            "**ROUTER_CLIENT**: Best of both worlds - you relay messages AND have normal client features. Most people use this!",
        icoMood: MeshBrainMood.approving,
      ),
      HelpStep(
        id: 'role_repeater',
        bubbleText:
            "**REPEATER**: Only forwards messages, no phone connection needed. Perfect for **mountaintops** or fixed installations!",
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
            "Use **filters** to show only **Active** nodes, or nodes with GPS. Helps when your map gets crowded!",
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
  // SIGNALS / PRESENCE FEED HELP
  // ============================================================================

  static final HelpTopic signalsOverview = HelpTopic(
    id: 'signals_overview',
    title: 'Presence Feed',
    description: 'Broadcast ephemeral signals to your mesh',
    icon: Icons.sensors,
    category: catMessaging,
    priority: 6,
    steps: [
      HelpStep(
        id: 'signals_intro',
        bubbleText:
            "Welcome to **Presence**! Broadcast moments to your mesh. Signals are **ephemeral** - you choose how long they last, from **15 minutes** up to **24 hours**.",
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
            "Signals are **mesh-first** - they travel through the radio network. When they fade, they're gone. True ephemeral, off-grid presence!",
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
            "Enable **Cloud Sync** to backup your settings and access them on other devices. Your data, encrypted!",
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
            "Your profile is **optional and private by default**. Only people you share your QR code with can see your details.",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'profile_share',
        bubbleText:
            "Share your **profile QR code** to connect with friends. They can save your details to their contacts!",
        icoMood: MeshBrainMood.approving,
      ),
      HelpStep(
        id: 'profile_cloud',
        bubbleText:
            "**Cloud Sync** backs up your settings across devices. Sign in to keep everything in sync!",
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
            "**Active** nodes (green) sent a message in the last 2 minutes. They're definitely online!",
        icoMood: MeshBrainMood.approving,
      ),
      HelpStep(
        id: 'presence_recent',
        bubbleText:
            "**Recently seen** nodes (yellow) were active 2-10 minutes ago. Probably still around.",
        icoMood: MeshBrainMood.curious,
      ),
      HelpStep(
        id: 'presence_inactive',
        bubbleText:
            "**Inactive** nodes (gray) haven't been heard from in over 10 minutes. They might be out of range or powered off.",
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
        id: 'nodedex_export',
        bubbleText:
            "Use the **menu** to **export** your NodeDex as a JSON file for backup, or **import** one from another device. Your field journal travels with you!",
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
  };

  // ============================================================================
  // LEGAL & SAFETY HELP TOPICS
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
    description: 'What you can and cannot do with Socialmesh',
    icon: Icons.gavel_rounded,
    category: catLegal,
    priority: 2,
    steps: [
      HelpStep(
        id: 'use_intro',
        bubbleText:
            "Socialmesh is a powerful tool — automations, signals, and mesh messaging give you a lot of capability. With that comes responsibility!",
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
    description: 'How Socialmesh handles data and what you are responsible for',
    icon: Icons.security_rounded,
    category: catLegal,
    priority: 3,
    steps: [
      HelpStep(
        id: 'responsibility_intro',
        bubbleText:
            "Socialmesh is designed to be **privacy-first**. Your messages and data stay on your device — we do not store them on any server.",
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

  /// Get topics sorted by priority
  static List<HelpTopic> get topicsByPriority =>
      List<HelpTopic>.from(allTopics)
        ..sort((a, b) => a.priority.compareTo(b.priority));
}
