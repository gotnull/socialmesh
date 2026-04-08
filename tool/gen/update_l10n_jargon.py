#!/usr/bin/env python3
"""Update existing l10n values to remove protocol jargon and use human-readable language."""
import json

ARB = "/Users/fulvio/development/socialmesh/lib/l10n/app_en.arb"

with open(ARB, "r") as f:
    data = json.load(f)

# ── Jargon replacements: same keys, friendlier values ──
updates = {
    # Discovery screen
    "sipDiscoveryTitle": "Find people nearby",
    "sipDiscoveryPeersNearby": "{count} {count, plural, =1{person} other{people}} nearby",
    "sipDiscoveryNoPeers": "No one nearby yet",
    "sipDiscoveryNoPeersDescription": "People using Socialmesh will appear here when they\u2019re in range.",
    "sipDiscoveryScanButton": "Look for people",
    "sipDiscoveryPeerAnonymous": "Mesh User",
    "sipDiscoveryDeviceClass": "{deviceClass}",

    # Handshake → Connect
    "sipHandshakeAction": "Connect",
    "sipHandshakeInProgress": "Connecting\u2026",
    "sipHandshakeComplete": "Connected",
    "sipHandshakeFailed": "Could not connect",
    "sipHandshakePendingLabel": "Request sent",

    # DM → Conversation
    "sipDmTitle": "Mesh message",
    "sipDmBudgetExhausted": "Sending paused \u2014 mesh bandwidth limit reached. Try again shortly.",
    "sipDmSessionClosed": "This conversation has ended.",

    # Peer detail
    "sipPeerDetailTitle": "About this person",
    "sipPeerDetailDeviceClass": "Device type",
    "sipPeerDetailFeatures": "Capabilities",
    "sipPeerDetailMtu": "Signal strength hint",
    "sipPeerDetailCapabilities": "What they support",
    "sipPeerDetailSupportsSip1": "Identity & secure connection",
    "sipPeerDetailSupportsSip3": "Contact exchange",

    # Hub sections
    "sipHubSectionPeers": "People",
    "sipHubSectionConversations": "Conversations",
    "sipHubSectionIncomingRequests": "Connection requests",

    # Hub empty taglines
    "sipHubScanningTagline1": "Listening for nearby users\u2026",
    "sipHubScanningTagline2": "Tap Look for people to send a signal\u2026",
    "sipHubScanningTagline3": "Others will appear when found\u2026",
    "sipHubScanningTagline4": "Keep the app open to discover more\u2026",

    # Hub status badges
    "sipHubHandshaking": "Connecting\u2026",
    "sipHubReady": "Ready to chat",
    "sipHubConnected": "Connected",

    # Auto-scan
    "sipAutoScanEnabled": "Auto-discovery on",
    "sipAutoScanDisabled": "Auto-discovery off",
}

changed = 0
for key, value in updates.items():
    if key in data and not key.startswith("@"):
        old = data[key]
        if old != value:
            data[key] = value
            changed += 1

with open(ARB, "w") as f:
    json.dump(data, f, indent=4, ensure_ascii=False)

print(f"OK: Updated {changed} l10n values to human-readable language")
