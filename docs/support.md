# Support

**Socialmesh**  
**Meshtastic Companion for iOS & Android**

---

## Getting Started

### What is Socialmesh?

Socialmesh is a mobile app for communicating over Meshtastic mesh radio networks. It allows you to send messages, share locations, and stay connected without relying on cellular networks or the internet.

### Requirements

- **iOS 15.0 or later** / **Android 8.0 or later**
- A compatible **Meshtastic radio device** (e.g., LILYGO T-Beam, Heltec V3, RAK WisBlock)
- **Bluetooth** enabled on your phone

### Quick Start

1. **Turn on your Meshtastic device** and ensure Bluetooth is enabled
2. **Open Socialmesh** and tap "Connect Device"
3. **Select your device** from the list of available Bluetooth devices
4. **Start messaging!** You're now connected to the mesh network

---

## Frequently Asked Questions

### Connection Issues

**Q: My device isn't appearing in the scan list**
- Ensure your Meshtastic device is powered on
- Check that Bluetooth is enabled on your phone
- Make sure no other app is connected to the device
- Try restarting both your phone and the Meshtastic device

**Q: I keep getting disconnected**
- Move closer to your Meshtastic device
- Check the battery level of your device
- Disable battery optimization for Socialmesh in your phone settings
- Try "forgetting" the device in Bluetooth settings and re-pairing

### Messaging

**Q: My messages aren't being delivered**
- Check that you're connected to a Meshtastic device
- Ensure there are other nodes within range
- Messages may take time to propagate through the mesh network
- Verify the recipient's node is online and within mesh range

**Q: What's the range of the mesh network?**
- Range depends on your device, antenna, and terrain
- Typical line-of-sight range: 1-10+ km
- Urban areas with obstacles: 0.5-2 km
- Using repeater nodes can extend range significantly

### Signals

**Q: What is a Signal?**
A Signal is a short, ephemeral message broadcast to nearby mesh nodes. Unlike regular messages, Signals expire automatically (from 15 minutes to 24 hours) and are sorted by proximity, not popularity.

**Q: Do Signals last forever?**
No. Every Signal has a time-to-live (TTL). When it expires, it fades from all devices. There is no archive.

**Q: Why can't I see images on some Signals?**
Images unlock based on presence. If you've been near the sender's node for a sustained period, or if you're signed in, images become visible. This prevents images from spreading beyond local context.

**Q: Do I need an account to use Signals?**
No. Signals work entirely over the mesh without authentication. Signing in enables optional cloud backup and image uploads, but is not required.

**Q: Is there a global feed of Signals?**
No. You only see Signals from nearby nodes. There is no discovery, no trending, and no algorithm.

### In-App Purchases

**Q: How do I restore my purchases?**
- Go to Settings → Upgrades
- Tap "Restore Purchases"
- Sign in with the same App Store/Play Store account used for the original purchase

**Q: My purchase isn't showing as unlocked**
- Ensure you're signed into the correct App Store/Play Store account
- Try the "Restore Purchases" option
- Check your internet connection
- Restart the app

### Premium Features

**Q: What's included in each pack?**

| Pack | Features |
|------|----------|
| **Theme Pack** | 12 premium color themes |
| **Ringtone Pack** | 25 custom RTTTL notification tones |
| **Widget Pack** | Home screen widgets for quick actions |
| **Automations Pack** | Custom triggers, actions & scheduled tasks |
| **IFTTT Pack** | Connect to 700+ apps via IFTTT webhooks |

---

## Troubleshooting

### App Crashes

If the app crashes frequently:

1. Update to the latest version of Socialmesh
2. Restart your phone
3. Clear the app cache (Settings → Apps → Socialmesh → Clear Cache)
4. If problems persist, try reinstalling the app

### Battery Drain

To reduce battery usage:

1. Disable "Keep screen on" if enabled
2. Reduce location update frequency in settings
3. Use power-saving modes on your Meshtastic device
4. Disable live activities if not needed

### Data Export

You can export your message history:

1. Go to Settings → Data & Storage
2. Tap "Export Messages"
3. Choose your export format (PDF or CSV)

---

## Contact Support

If you can't find an answer to your question, we're here to help!

**Email**: support@socialmesh.app

Please include:
- Your device model and OS version
- Socialmesh app version
- A description of the issue
- Screenshots if applicable

**Response Time**: We aim to respond within 24-48 hours.

---

## Community Resources

- **Meshtastic Documentation**: https://meshtastic.org/docs
- **Meshtastic Discord**: https://discord.gg/meshtastic
- **Reddit Community**: r/meshtastic

---

## Report a Bug

Found a bug? Help us improve by reporting it:

**Email**: bugs@socialmesh.app

Please include:
- Steps to reproduce the issue
- Expected vs actual behavior
- Device and OS information
- Screenshots or screen recordings

---

## Feature Requests

Have an idea for a new feature? We'd love to hear it!

**Email**: feedback@socialmesh.app

---

**Website**: https://socialmesh.app

© 2025 Socialmesh. All rights reserved.
