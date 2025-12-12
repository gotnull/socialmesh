# Firebase Remote Config Implementation Plan

## Executive Summary

The Protofluff codebase has **~60 configurable values** spread across feature flags, timeouts, URLs, and UI content that would benefit from Remote Config. Firebase is already integrated (Core, Crashlytics, Auth), so adding Remote Config is straightforward.

---

## Current State

| Aspect | Status |
|--------|--------|
| Firebase Core | ✅ Integrated |
| Firebase Crashlytics | ✅ Integrated |
| Firebase Auth | ✅ Integrated |
| **Firebase Remote Config** | ❌ **Not implemented** |

---

## 🎯 Priority 1: Safety & Critical Operations (Week 1)

These provide immediate value and emergency controls:

| Key | Type | Default | Purpose |
|-----|------|---------|---------|
| `maintenance_mode` | bool | `false` | **Kill switch** - disable app functionality during outages |
| `force_update_min_version` | string | `""` | Force users to update when critical bugs found |
| `force_update_message` | string | `""` | Message to show on forced update screen |
| `api_endpoints_enabled` | bool | `true` | Quickly disable external API calls |

---

## 🎯 Priority 2: Feature Flags (Week 1-2)

Replace `.env`-based admin flags with remote control:

| Key | Type | Default | Currently In |
|-----|------|---------|--------------|
| `admin_debug_mode` | bool | `false` | `lib/config/admin_config.dart` |
| `feature_world_mesh_enabled` | bool | `true` | Feature toggle |
| `feature_automations_enabled` | bool | `true` | Premium feature |
| `feature_ifttt_enabled` | bool | `true` | Premium feature |
| `feature_marketplace_enabled` | bool | `true` | New feature rollout |

**Benefits:**
- Enable features for beta testers by user audience
- Gradual rollouts (5% → 25% → 100%)
- Instant rollback without app update

---

## 🎯 Priority 3: Operational Parameters (Week 2-3)

Tune app behavior without releases:

| Key | Type | Default | Currently In |
|-----|------|---------|--------------|
| `ble_scan_timeout_seconds` | int | `10` | `ble_scanner.dart` |
| `api_timeout_seconds` | int | `30` | API services |
| `max_retry_count` | int | `3` | Various services |
| `position_update_interval_seconds` | int | `30` | `location_service.dart` |
| `max_message_storage` | int | `500` | `message_service.dart` |
| `message_cleanup_days` | int | `30` | Database cleanup |
| `meshmap_api_url` | string | `https://meshmap.net/nodes.json` | `world_mesh_service.dart` |

**Benefits:**
- Fix timeout issues for slow networks remotely
- Adjust behavior per region/platform
- A/B test different configurations

---

## 🎯 Priority 4: Logging Controls (Week 3)

Currently 17+ logging toggles in `.env.example`:

| Key | Type | Default | Purpose |
|-----|------|---------|---------|
| `logging_ble_enabled` | bool | `false` | BLE debugging |
| `logging_protocol_enabled` | bool | `false` | Protocol debugging |
| `logging_messages_enabled` | bool | `false` | Message debugging |
| `logging_verbose_all` | bool | `false` | Enable all logs |

**Benefits:**
- Enable verbose logging for specific users having issues
- Debug production problems without requiring them to modify files

---

## 🎯 Priority 5: UI/UX Configuration (Week 4)

| Key | Type | Default | Purpose |
|-----|------|---------|---------|
| `app_tagline` | string | `"Off-grid communication."` | Rotating promotional taglines |
| `onboarding_variant` | string | `"default"` | A/B test onboarding flows |
| `promo_banner_enabled` | bool | `false` | Show promotional banner |
| `promo_banner_text` | string | `""` | Banner content |
| `promo_banner_action_url` | string | `""` | Deep link for banner tap |
| `default_map_lat` | double | `-33.8688` | Regional map defaults |
| `default_map_lon` | double | `151.2093` | Regional map defaults |

**Benefits:**
- Update copy without app release
- Regional customization
- Seasonal/holiday messaging

---

## 🎯 Priority 6: A/B Testing Infrastructure (Week 4+)

| Key | Type | Purpose |
|-----|------|---------|
| `subscription_screen_variant` | string | Test purchase UI layouts |
| `free_theme_count` | int | Test conversion with free themes |
| `onboarding_page_count` | int | Test shorter vs longer onboarding |

---

## Implementation Architecture

### New Files to Create:

```
lib/services/remote_config/
├── remote_config_service.dart      # Main service
├── remote_config_keys.dart         # All key constants
└── remote_config_defaults.dart     # Default values
```

### Integration Points:

```dart
// main.dart - Initialize early
await RemoteConfigService.instance.initialize();

// Usage anywhere
final timeout = RemoteConfigService.instance.getInt(RemoteConfigKeys.apiTimeout);
final isMaintenanceMode = RemoteConfigService.instance.getBool(RemoteConfigKeys.maintenanceMode);
```

---

## Conditions to Set Up in Firebase Console

| Condition Name | Rule | Use Case |
|----------------|------|----------|
| `Beta Testers` | User in audience "beta_testers" | Early access features |
| `iOS Users` | Platform == iOS | Platform-specific configs |
| `Android Users` | Platform == Android | Platform-specific configs |
| `Australia` | Country/Region in AU | Regional defaults |
| `Random 10%` | User in random percentile ≤ 10% | Gradual rollouts |
| `Debug Build` | App version contains "debug" | Development configs |

---

## Detailed Audit Findings

### 1. Existing Configuration Patterns

#### 1.1 Config Classes (`lib/config/`)

| File | Purpose | Remote Config Opportunity |
|------|---------|---------------------------|
| `admin_config.dart` | Admin/debug feature flags via `.env` | **HIGH** - Perfect for remote feature toggles |
| `iap_config.dart` | IAP product IDs and pricing | **MEDIUM** - Product IDs could be remotely configurable |

#### 1.2 Environment Variables (`.env.example`)

**17+ logging toggles** that could be remotely controlled:
- `BLE_LOGGING_ENABLED`
- `PROTOCOL_LOGGING_ENABLED`
- `WIDGET_BUILDER_LOGGING_ENABLED`
- `LIVE_ACTIVITY_LOGGING_ENABLED`
- `AUTOMATIONS_LOGGING_ENABLED`
- `MESSAGES_LOGGING_ENABLED`
- `IFTTT_LOGGING_ENABLED`
- `TELEMETRY_LOGGING_ENABLED`
- `CONNECTION_LOGGING_ENABLED`
- `NODES_LOGGING_ENABLED`
- `CHANNELS_LOGGING_ENABLED`
- `APP_LOGGING_ENABLED`
- `SUBSCRIPTIONS_LOGGING_ENABLED`
- `NOTIFICATIONS_LOGGING_ENABLED`
- `AUDIO_LOGGING_ENABLED`
- `MAPS_LOGGING_ENABLED`
- `FIRMWARE_LOGGING_ENABLED`
- `SETTINGS_LOGGING_ENABLED`
- `DEBUG_LOGGING_ENABLED`

---

### 2. Hardcoded Values That Should Be Configurable

#### 2.1 URLs and Endpoints

| Location | Value | Remote Config Use Case |
|----------|-------|------------------------|
| `world_mesh_service.dart` | `https://meshmap.net/nodes.json` | API endpoint migration |
| `ifttt_service.dart` | `https://maker.ifttt.com/trigger` | IFTTT API versioning |
| `map_tile_provider.dart` | 4 tile server URLs | Map provider switching |
| `constants.dart` | `API_BASE_URL`, `MARKETPLACE_URL` | Environment switching |

#### 2.2 Timeouts and Intervals

| Location | Value | Remote Config Use Case |
|----------|-------|------------------------|
| `firebase_service.dart` | Firebase timeout: `5 seconds` | Adjust for slow networks |
| `ble_scanner.dart` | BLE scan: `8 seconds` | Device-specific tuning |
| `api_service.dart` | API timeout: `30 seconds` | Network condition adaptation |
| `location_service.dart` | Position update: `30 seconds` | Battery optimization |
| `ble_scanner.dart` | Scan duration: `10 seconds` | Regional Bluetooth differences |
| `ble_adapter.dart` | Adapter timeout: `3 seconds` | Device compatibility |
| `tapback_service.dart` | Cleanup: `30 days` | Storage management |

#### 2.3 Retry Counts and Limits

| Location | Value | Remote Config Use Case |
|----------|-------|------------------------|
| `api_service.dart` | `maxRetries = 3` | Network reliability tuning |
| `message_queue.dart` | `retryCount >= 3` | Queue behavior |
| `ble_connection.dart` | `maxRetries = 8` | Connection reliability |
| `message_service.dart` | `_maxMessages = 500` | Storage limits |

#### 2.4 Validation Constants

| Constant | Value | Remote Config Use Case |
|----------|-------|------------------------|
| `maxChannelNameLength` | 11 | Protocol updates |
| `maxLongNameLength` | 39 | Character limit changes |
| `maxShortNameLength` | 4 | Protocol updates |

#### 2.5 Map Configuration

| Constant | Value | Remote Config Use Case |
|----------|-------|------------------------|
| `defaultLat` | -33.8688 (Sydney) | Regional defaults |
| `defaultLon` | 151.2093 | Regional defaults |
| `defaultZoom` | 13.0 | UX optimization |
| `minZoom` | 3.0 | Map behavior |
| `maxZoom` | 18.0 | Tile server limits |

---

### 3. UI/UX Configuration

#### 3.1 Onboarding Content

**6 onboarding pages** with hardcoded content in `onboarding_screen.dart`:

- A/B test onboarding copy
- Seasonal/promotional messaging
- Localized content updates without app release

#### 3.2 App Taglines (`app_strings.dart`)

```dart
const appTaglines = [
  'Off-grid communication.',
  'No towers. No subscriptions.',
  'Your voice. Your network.',
  'Zero knowledge. Zero tracking.',
  'Device to device. Mile after mile.',
  'Build infrastructure together.',
];
```

Could rotate promotional taglines, seasonal messages.

#### 3.3 Theme Colors

12 accent colors defined. Could enable:
- Seasonal color palettes
- Holiday themes
- A/B testing color preferences

---

### 4. Business Logic That Could Be Toggled

#### 4.1 Subscription/Pricing (`iap_config.dart`)

| Product | Price | Remote Config Use Case |
|---------|-------|------------------------|
| Theme Pack | $1.99 | Regional pricing, promotions |
| Ringtone Pack | $0.99 | A/B price testing |
| Widget Pack | $2.99 | Bundle experiments |
| Automations Pack | $3.99 | Feature value testing |
| IFTTT Pack | $2.99 | Partner promotions |
| Complete Pack | $9.99 | Discount campaigns |

#### 4.2 IFTTT Default Thresholds

| Threshold | Default | Remote Config Use Case |
|-----------|---------|------------------------|
| Battery threshold | 20% | User preference defaults |
| Temperature threshold | 40.0°C | Regional differences |
| Geofence radius | 1000m | Use case optimization |
| Geofence throttle | 30 minutes | Battery vs. accuracy |

#### 4.3 Mesh Network Constants

| Constant | Value | Remote Config Use Case |
|----------|-------|------------------------|
| `maxHopCount` | 7 | Network topology tuning |
| `defaultTtlHops` | 3 | Message propagation |
| `packetRetryCount` | 3 | Reliability tuning |
| `discoveryIntervalSeconds` | 30 | Battery/discovery balance |
| `presenceTimeoutSeconds` | 300 | Node presence detection |

---

## Summary Statistics

| Category | Count | Impact |
|----------|-------|--------|
| Feature flags identified | 15+ | HIGH |
| Timeout/interval values | 12+ | MEDIUM |
| URL endpoints | 6+ | MEDIUM |
| Retry/limit values | 8+ | MEDIUM |
| UI content items | 10+ | LOW-MEDIUM |
| Pricing display values | 6 | MEDIUM |
| **Total configurable items** | **~60** | **HIGH** |

---

## Next Steps

1. **Add dependency** to `pubspec.yaml`: `firebase_remote_config: ^5.1.4`
2. **Create Remote Config service** with kill switch + force update
3. **Replace `AdminConfig`** to use Remote Config instead of `.env`
4. **Set up Firebase Console** with conditions and parameters
5. **Migrate operational parameters** (timeouts, retries)
6. **Enable content updates** (onboarding, taglines)
7. **Implement A/B testing** infrastructure

---

*Document created: December 12, 2025*
