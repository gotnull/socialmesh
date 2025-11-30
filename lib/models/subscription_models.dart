// Subscription tier definitions and feature flags for monetization

/// User subscription tier levels
enum SubscriptionTier { free, premium, pro }

enum PremiumFeature {
  // Multi-device
  multiDevice,
  deviceProfiles,
  bulkConfiguration,

  // Analytics
  messageStatistics,
  networkTopology,
  signalHeatmaps,
  batteryPredictions,
  channelAnalytics,

  // Mapping
  offlineMaps,
  customMapLayers,
  routePlanning,
  geofencing,

  // Automation
  customNotificationRules,
  scheduledMessages,
  webhookIntegrations,
  positionAutomations,

  // Data & Backup
  cloudBackup,
  crossDeviceSync,
  messageExport,
  extendedHistory,

  // Pro/Business
  teamFeatures,
  sharedChannels,
  adminControls,
  prioritySupport,
  apiAccess,

  // Cosmetic
  premiumThemes,
  customRingtones,
  homeWidgets,
}

/// Subscription plan details
class SubscriptionPlan {
  final String id;
  final String name;
  final String description;
  final SubscriptionTier tier;
  final double monthlyPrice;
  final double yearlyPrice;
  final Set<PremiumFeature> features;
  final String? stripeMonthlyPriceId;
  final String? stripeYearlyPriceId;
  final String? revenueCatOfferingId;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.tier,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.features,
    this.stripeMonthlyPriceId,
    this.stripeYearlyPriceId,
    this.revenueCatOfferingId,
  });

  double get yearlySavings {
    final monthlyTotal = monthlyPrice * 12;
    return monthlyTotal - yearlyPrice;
  }

  int get yearlySavingsPercent {
    if (monthlyPrice == 0) return 0;
    final monthlyTotal = monthlyPrice * 12;
    return ((monthlyTotal - yearlyPrice) / monthlyTotal * 100).round();
  }
}

/// Available subscription plans
class SubscriptionPlans {
  static const free = SubscriptionPlan(
    id: 'free',
    name: 'Free',
    description: 'Basic mesh communication',
    tier: SubscriptionTier.free,
    monthlyPrice: 0,
    yearlyPrice: 0,
    features: {},
  );

  static const premium = SubscriptionPlan(
    id: 'premium',
    name: 'Premium',
    description: 'Enhanced features for enthusiasts',
    tier: SubscriptionTier.premium,
    monthlyPrice: 4.99,
    yearlyPrice: 29.99,
    stripeMonthlyPriceId: 'price_premium_monthly',
    stripeYearlyPriceId: 'price_premium_yearly',
    revenueCatOfferingId: 'premium',
    features: {
      // Multi-device
      PremiumFeature.multiDevice,
      PremiumFeature.deviceProfiles,

      // Analytics
      PremiumFeature.messageStatistics,
      PremiumFeature.networkTopology,
      PremiumFeature.channelAnalytics,

      // Mapping
      PremiumFeature.offlineMaps,
      PremiumFeature.customMapLayers,

      // Automation
      PremiumFeature.customNotificationRules,
      PremiumFeature.scheduledMessages,

      // Data
      PremiumFeature.cloudBackup,
      PremiumFeature.messageExport,
      PremiumFeature.extendedHistory,

      // Cosmetic
      PremiumFeature.premiumThemes,
      PremiumFeature.customRingtones,
      PremiumFeature.homeWidgets,
    },
  );

  static const pro = SubscriptionPlan(
    id: 'pro',
    name: 'Pro',
    description: 'Full power for teams & professionals',
    tier: SubscriptionTier.pro,
    monthlyPrice: 9.99,
    yearlyPrice: 79.99,
    stripeMonthlyPriceId: 'price_pro_monthly',
    stripeYearlyPriceId: 'price_pro_yearly',
    revenueCatOfferingId: 'pro',
    features: {
      // All Premium features (explicitly listed)
      PremiumFeature.multiDevice,
      PremiumFeature.deviceProfiles,
      PremiumFeature.messageStatistics,
      PremiumFeature.networkTopology,
      PremiumFeature.channelAnalytics,
      PremiumFeature.offlineMaps,
      PremiumFeature.customMapLayers,
      PremiumFeature.customNotificationRules,
      PremiumFeature.scheduledMessages,
      PremiumFeature.cloudBackup,
      PremiumFeature.messageExport,
      PremiumFeature.extendedHistory,
      PremiumFeature.premiumThemes,
      PremiumFeature.customRingtones,
      PremiumFeature.homeWidgets,

      // Additional Pro features
      PremiumFeature.bulkConfiguration,
      PremiumFeature.signalHeatmaps,
      PremiumFeature.batteryPredictions,
      PremiumFeature.routePlanning,
      PremiumFeature.geofencing,
      PremiumFeature.webhookIntegrations,
      PremiumFeature.positionAutomations,
      PremiumFeature.crossDeviceSync,

      // Pro exclusive
      PremiumFeature.teamFeatures,
      PremiumFeature.sharedChannels,
      PremiumFeature.adminControls,
      PremiumFeature.prioritySupport,
      PremiumFeature.apiAccess,
    },
  );

  static const allPlans = [free, premium, pro];

  static SubscriptionPlan getPlan(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return free;
      case SubscriptionTier.premium:
        return premium;
      case SubscriptionTier.pro:
        return pro;
    }
  }
}

/// Current subscription state
class SubscriptionState {
  final SubscriptionTier tier;
  final DateTime? expiresAt;
  final bool isTrialing;
  final int trialDaysRemaining;
  final String? customerId;
  final String? subscriptionId;
  final bool willRenew;

  const SubscriptionState({
    this.tier = SubscriptionTier.free,
    this.expiresAt,
    this.isTrialing = false,
    this.trialDaysRemaining = 0,
    this.customerId,
    this.subscriptionId,
    this.willRenew = true,
  });

  bool get isActive =>
      tier != SubscriptionTier.free &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  bool get isPremium => tier == SubscriptionTier.premium && isActive;
  bool get isPro => tier == SubscriptionTier.pro && isActive;
  bool get isPremiumOrHigher => isPremium || isPro;

  bool hasFeature(PremiumFeature feature) {
    if (!isActive && tier != SubscriptionTier.free) return false;
    return SubscriptionPlans.getPlan(tier).features.contains(feature);
  }

  SubscriptionState copyWith({
    SubscriptionTier? tier,
    DateTime? expiresAt,
    bool? isTrialing,
    int? trialDaysRemaining,
    String? customerId,
    String? subscriptionId,
    bool? willRenew,
  }) {
    return SubscriptionState(
      tier: tier ?? this.tier,
      expiresAt: expiresAt ?? this.expiresAt,
      isTrialing: isTrialing ?? this.isTrialing,
      trialDaysRemaining: trialDaysRemaining ?? this.trialDaysRemaining,
      customerId: customerId ?? this.customerId,
      subscriptionId: subscriptionId ?? this.subscriptionId,
      willRenew: willRenew ?? this.willRenew,
    );
  }

  static const initial = SubscriptionState();
}

/// One-time purchasable items
class OneTimePurchase {
  final String id;
  final String name;
  final String description;
  final double price;
  final String stripePriceId;
  final PremiumFeature? unlocksFeature;

  const OneTimePurchase({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.stripePriceId,
    this.unlocksFeature,
  });
}

class OneTimePurchases {
  static const themePack = OneTimePurchase(
    id: 'theme_pack',
    name: 'Theme Pack',
    description: 'Unlock 12 premium color themes',
    price: 1.99,
    stripePriceId: 'price_theme_pack',
    unlocksFeature: PremiumFeature.premiumThemes,
  );

  static const ringtonePack = OneTimePurchase(
    id: 'ringtone_pack',
    name: 'Ringtone Pack',
    description: '25 additional RTTTL ringtones',
    price: 0.99,
    stripePriceId: 'price_ringtone_pack',
    unlocksFeature: PremiumFeature.customRingtones,
  );

  static const widgetPack = OneTimePurchase(
    id: 'widget_pack',
    name: 'Widget Pack',
    description: 'Home screen widgets for quick actions',
    price: 2.99,
    stripePriceId: 'price_widget_pack',
    unlocksFeature: PremiumFeature.homeWidgets,
  );

  static const allPurchases = [themePack, ringtonePack, widgetPack];
}

/// Feature metadata for UI display
class FeatureInfo {
  final PremiumFeature feature;
  final String name;
  final String description;
  final String icon;
  final SubscriptionTier minimumTier;

  const FeatureInfo({
    required this.feature,
    required this.name,
    required this.description,
    required this.icon,
    required this.minimumTier,
  });

  static const allFeatures = <FeatureInfo>[
    // Multi-device
    FeatureInfo(
      feature: PremiumFeature.multiDevice,
      name: 'Multi-Device',
      description: 'Connect and manage multiple Meshtastic devices',
      icon: 'devices',
      minimumTier: SubscriptionTier.premium,
    ),
    FeatureInfo(
      feature: PremiumFeature.deviceProfiles,
      name: 'Device Profiles',
      description: 'Save and restore device configurations',
      icon: 'save',
      minimumTier: SubscriptionTier.premium,
    ),
    FeatureInfo(
      feature: PremiumFeature.bulkConfiguration,
      name: 'Bulk Configuration',
      description: 'Deploy settings to multiple devices at once',
      icon: 'dynamic_feed',
      minimumTier: SubscriptionTier.pro,
    ),

    // Analytics
    FeatureInfo(
      feature: PremiumFeature.messageStatistics,
      name: 'Message Statistics',
      description: 'View historical message and activity graphs',
      icon: 'bar_chart',
      minimumTier: SubscriptionTier.premium,
    ),
    FeatureInfo(
      feature: PremiumFeature.networkTopology,
      name: 'Network Topology',
      description: 'Visualize your mesh network structure',
      icon: 'hub',
      minimumTier: SubscriptionTier.premium,
    ),
    FeatureInfo(
      feature: PremiumFeature.signalHeatmaps,
      name: 'Signal Heatmaps',
      description: 'Track signal strength over time and location',
      icon: 'gradient',
      minimumTier: SubscriptionTier.pro,
    ),

    // Mapping
    FeatureInfo(
      feature: PremiumFeature.offlineMaps,
      name: 'Offline Maps',
      description: 'Download maps for offline use',
      icon: 'download_for_offline',
      minimumTier: SubscriptionTier.premium,
    ),
    FeatureInfo(
      feature: PremiumFeature.geofencing,
      name: 'Geofencing',
      description: 'Set up location-based alerts',
      icon: 'fence',
      minimumTier: SubscriptionTier.pro,
    ),

    // Automation
    FeatureInfo(
      feature: PremiumFeature.customNotificationRules,
      name: 'Custom Alerts',
      description: 'Create custom notification rules',
      icon: 'notification_add',
      minimumTier: SubscriptionTier.premium,
    ),
    FeatureInfo(
      feature: PremiumFeature.scheduledMessages,
      name: 'Scheduled Messages',
      description: 'Schedule messages to send later',
      icon: 'schedule_send',
      minimumTier: SubscriptionTier.premium,
    ),
    FeatureInfo(
      feature: PremiumFeature.webhookIntegrations,
      name: 'Webhooks',
      description: 'Connect to external services via webhooks',
      icon: 'webhook',
      minimumTier: SubscriptionTier.pro,
    ),

    // Data
    FeatureInfo(
      feature: PremiumFeature.cloudBackup,
      name: 'Cloud Backup',
      description: 'Automatically backup messages and settings',
      icon: 'cloud_upload',
      minimumTier: SubscriptionTier.premium,
    ),
    FeatureInfo(
      feature: PremiumFeature.crossDeviceSync,
      name: 'Cross-Device Sync',
      description: 'Sync data across all your devices',
      icon: 'sync',
      minimumTier: SubscriptionTier.pro,
    ),
    FeatureInfo(
      feature: PremiumFeature.messageExport,
      name: 'Message Export',
      description: 'Export messages to PDF or CSV',
      icon: 'file_download',
      minimumTier: SubscriptionTier.premium,
    ),

    // Pro
    FeatureInfo(
      feature: PremiumFeature.teamFeatures,
      name: 'Team Management',
      description: 'Manage team members and permissions',
      icon: 'groups',
      minimumTier: SubscriptionTier.pro,
    ),
    FeatureInfo(
      feature: PremiumFeature.apiAccess,
      name: 'API Access',
      description: 'Build custom integrations with our API',
      icon: 'api',
      minimumTier: SubscriptionTier.pro,
    ),
    FeatureInfo(
      feature: PremiumFeature.prioritySupport,
      name: 'Priority Support',
      description: '24-hour response time from our team',
      icon: 'support_agent',
      minimumTier: SubscriptionTier.pro,
    ),
  ];

  static FeatureInfo? getInfo(PremiumFeature feature) {
    return allFeatures.where((f) => f.feature == feature).firstOrNull;
  }
}
