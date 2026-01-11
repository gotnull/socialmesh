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
            "**Store & Forward** is awesome! If the recipient is offline, I'll hold onto the message and deliver it when they come back online!",
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
            "**Green dot** means online and ready. **Yellow** means they were here recently. **Gray** means they've been quiet for a while.",
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
            "Use the **filters** at the top to find specific nodes. You can show only online nodes, favorites, or nodes with GPS.",
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
            "Use **filters** to show only online nodes, or nodes with GPS. Helps when your map gets crowded!",
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
            "Every automation starts with a **trigger**. Like when a node goes offline, battery gets low, or you enter an area!",
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
  // ALL TOPICS
  // ============================================================================

  static final List<HelpTopic> allTopics = [
    channelCreation,
    channelsOverview,
    encryptionLevels,
    deviceConnection,
    regionSelection,
    nodesOverview,
    nodeRoles,
    mapOverview,
    messageRouting,
    automationsOverview,
    gpsSettings,
    signalMetrics,
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
  ];

  /// Get topics sorted by priority
  static List<HelpTopic> get topicsByPriority =>
      List<HelpTopic>.from(allTopics)
        ..sort((a, b) => a.priority.compareTo(b.priority));
}
