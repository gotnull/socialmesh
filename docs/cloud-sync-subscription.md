# Cloud Sync Subscription Implementation

## Overview

This document describes the implementation of paid cloud sync subscriptions for Socialmesh.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         FLUTTER APP                              │
│  ┌────────────────────┐  ┌──────────────────────────────────┐   │
│  │ Local Mode (FREE)  │  │ CloudSyncEntitlementService      │   │
│  │ - Meshtastic comms │  │ - Checks RevenueCat subscription │   │
│  │ - Local storage    │  │ - Checks Firestore grandfathered │   │
│  │ - All core features│  │ - Caches state locally           │   │
│  └────────────────────┘  └──────────────┬───────────────────┘   │
└─────────────────────────────────────────┼───────────────────────┘
                                          │
         ┌────────────────────────────────┼────────────────────────┐
         │                                │                        │
         ▼                                ▼                        │
┌─────────────────────┐      ┌───────────────────────┐            │
│     REVENUECAT      │      │       FIREBASE        │            │
│                     │      │                       │            │
│ Products:           │      │ user_entitlements/    │            │
│ - cloud_monthly     │─────▶│ - cloud_sync status   │            │
│ - cloud_yearly      │      │ - expires_at          │            │
│                     │      │ - grandfathered flag  │            │
│ Entitlement:        │      │                       │            │
│ - cloud_sync        │      │ Security Rules:       │            │
│                     │      │ - Check entitlement   │            │
│ Webhooks ──────────────────│   before write        │            │
└─────────────────────┘      └───────────────────────┘            │
```

## Entitlement States

| State | Can Write | Can Read | Description |
|-------|-----------|----------|-------------|
| `active` | ✅ | ✅ | Active subscription |
| `grace_period` | ✅ | ✅ | Billing issue, temporary access |
| `grandfathered` | ✅ | ✅ | Used cloud sync before cutoff (permanent) |
| `expired` | ❌ | ✅ | Subscription ended, read-only |
| `none` | ❌ | ❌ | Never subscribed |

## RevenueCat Setup

### Products (Create in RevenueCat Dashboard)

| Product ID | Type | Price (USD) |
|------------|------|-------------|
| `cloud_monthly` | Auto-renewable subscription | $2.99/month |
| `cloud_yearly` | Auto-renewable subscription | $19.99/year |

### Entitlement
- **ID:** `cloud_sync`
- **Products:** Both monthly and yearly grant this entitlement

### Webhook Configuration
1. Go to RevenueCat Dashboard → Project Settings → Integrations
2. Add webhook URL: `https://<region>-<project>.cloudfunctions.net/onRevenueCatWebhook`
3. Copy webhook signing secret
4. Set in Firebase config: `firebase functions:config:set revenuecat.webhook_secret="your-secret"`

## Firestore Schema

### Collection: `user_entitlements`

```typescript
{
  cloud_sync: 'active' | 'expired' | 'grandfathered' | 'grace_period',
  source: 'subscription' | 'legacy',
  expires_at: Timestamp | null,
  grace_period_ends_at: Timestamp | null,
  product_id: string | null,
  revenuecat_app_user_id: string,
  last_sync_at: Timestamp | null,
  created_at: Timestamp,
  updated_at: Timestamp
}
```

## Files Created/Modified

### New Files
- `lib/services/subscription/cloud_sync_entitlement_service.dart` - Core entitlement logic
- `lib/providers/cloud_sync_entitlement_providers.dart` - Riverpod providers
- `lib/features/settings/widgets/cloud_sync_paywall.dart` - Paywall UI
- `functions/src/cloud_sync_entitlements.ts` - Cloud Functions

### Modified Files
- `lib/main.dart` - Initialize cloud sync entitlement service
- `functions/src/index.ts` - Export cloud sync functions
- `firestore.rules` - Add cloud sync enforcement rules

## Grandfathering Strategy

Users who used cloud sync before February 1, 2025 get permanent free access.

### How It Works
1. Check `users/{uid}.cloud_sync_used_at` timestamp
2. If before cutoff date, mark as grandfathered
3. Store in `user_entitlements/{uid}.cloud_sync = 'grandfathered'`
4. Grandfathered users bypass RevenueCat checks

### Migration Script
Run ONCE before enabling enforcement:
```bash
curl -X POST \
  -H "x-admin-key: YOUR_ADMIN_KEY" \
  https://<region>-<project>.cloudfunctions.net/grandfatherExistingUsers
```

## Deployment Checklist

### RevenueCat
- [ ] Create subscription products in App Store Connect
- [ ] Create subscription products in Google Play Console
- [ ] Add products to RevenueCat
- [ ] Create `cloud_sync` entitlement
- [ ] Configure webhook

### Firebase
- [ ] Deploy Cloud Functions: `firebase deploy --only functions`
- [ ] Deploy Firestore rules: `firebase deploy --only firestore:rules`
- [ ] Set webhook secret: `firebase functions:config:set revenuecat.webhook_secret="..."`
- [ ] Set admin key: `firebase functions:config:set admin.key="..."`

### App
- [ ] Run grandfathering migration
- [ ] Test subscription flow in sandbox
- [ ] Test restore purchases
- [ ] Test grandfathered access
- [ ] Test expired read-only access

## Rollout Plan

### Phase 1: Silent Launch (Week 1)
- Deploy all code with enforcement disabled
- Track cloud sync usage to mark existing users
- Test subscription flow with internal testers

### Phase 2: Soft Launch (Week 2)
- Enable soft paywall (non-blocking)
- Show banner to non-subscribed users
- Allow continued free access

### Phase 3: Full Launch (Week 3+)
- Enable hard enforcement
- New users require subscription
- Grandfathered users continue free

## Pricing Recommendation (AUD)

| Plan | Price | Notes |
|------|-------|-------|
| Monthly | $2.99/month | Standard price point |
| Yearly | $24.99/year | ~30% discount, $2.08/month effective |

## In-App Copy

### Paywall Title
> Unlock Cloud Sync

### Paywall Description
> Sync your mesh data across devices. Your local data always stays free and accessible.

### Features
- ✅ Sync across all your devices
- ✅ Automatic cloud backup
- ✅ Share profiles & settings
- ✅ Local mode always free

### Expired Banner
> Your Cloud Sync subscription has expired. Your data is read-only.

### Grace Period Banner
> There's an issue with your payment. Please update your payment method.
