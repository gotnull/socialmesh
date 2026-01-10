# Content Alignment: Signals v1

This document identifies all content surfaces that need updating to accurately reflect the Signals feature implementation. Signals are proximity-based, ephemeral mesh messages—not a social network.

---

## Language Rules (For All Future Content)

### Never Use
- Social network, social media, social features
- Feed (use "presence" instead)
- Post, posting (use "signal" instead)
- Share, sharing (use "broadcast" or "leave a trace")
- Followers, following, likes, hearts
- Trending, viral, algorithm
- Audience, creators, engagement
- Notification (for signal-related; use "nearby activity")

### Always Use
- **Signal** — the primary unit of content
- **Nearby** — instead of global or public
- **Presence** — instead of social
- **Unlock** — instead of reveal or share (for images)
- **Expires / Fades** — instead of delete
- **Broadcast** — instead of post or share
- **Trace** — for the ephemeral nature

### Tone
- Calm, matter-of-fact
- Slightly technical but human
- No hype, no growth language
- No emojis in web/docs (OK sparingly in-app)

---

## Content Surfaces Found

### 1. README.md

**Current (Lines 1-5):**
```markdown
# Socialmesh

A powerful Meshtastic companion app for iOS and Android. Connect to your mesh radio, send messages, track nodes, and configure your device — all without internet.
```

**Proposed:**
```markdown
# Socialmesh

A Meshtastic companion app for iOS and Android. Connect to your mesh radio, exchange messages, track nearby nodes, and configure your device — all without internet.

**Signals** — Leave short, ephemeral traces for people nearby. Signals expire automatically and never leave the mesh. No followers. No likes. Just presence.
```

---

### 2. marketing.md

**REMOVE ENTIRELY or REWRITE.** This file contains social network language that contradicts Signals.

**Lines to Remove:**
- "Socialmesh turns Meshtastic mesh radios into a private, decentralized social network"
- "Build private communities"
- "the off-grid social network"
- "A privacy-first social network built on Meshtastic mesh radios"

**Proposed Short Description (30 words):**
```
Communicate off-grid with Meshtastic mesh radios. Send encrypted messages, see nearby nodes on maps, and leave ephemeral signals — all without cellular or WiFi.
```

**Proposed Full Description:**
```markdown
### Mesh-First Communication

Socialmesh connects you to Meshtastic radios for off-grid communication. Messages hop between devices, reaching people nearby without cell towers or internet.

### Signals: Presence, Not Performance

Leave short, ephemeral traces for people nearby. Signals expire automatically and never get ranked or promoted. No followers. No likes. Just nearby awareness.

- Signals are temporary (15m to 24h)
- Signals stay local — no global feed
- Images unlock based on proximity or authentication
- Works without an account

### No Internet? No Problem.
Connect via Bluetooth to affordable Meshtastic radios. Your messages travel through the mesh, bouncing between devices until they reach their destination.

### Privacy by Design
- End-to-end encryption on all messages
- No accounts required
- No servers storing your data
- Works fully offline
```

---

### 3. docs/support.md

**Current (Lines 7-9):**
```markdown
**Socialmesh**  
**Your Off-Grid Communication Companion**
```

**Proposed:**
```markdown
**Socialmesh**  
**Meshtastic Companion for iOS & Android**
```

**Add new FAQ section:**
```markdown
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
```

---

### 4. docs/privacy-policy.md

**Current (Lines 19-22) mentions "No Analytics or Tracking"** — this is accurate for Signals.

**Add clarification:**
```markdown
## Signals Feature

Signals are ephemeral messages broadcast over the Meshtastic mesh network. They:
- Are stored locally on your device until they expire
- Are never uploaded to any server unless you sign in
- Expire automatically based on the TTL you select
- Never contain analytics or tracking data
```

---

### 5. web/index.html

**Current Hero (Lines 77-88):**
```html
<h1>
  Meshtastic<br>
  <span class="gradient-text">Reimagined</span>
</h1>

<p class="hero-description">
  The most powerful Meshtastic client for serious operators. Real-time 3D visualization,
  intelligent automations, custom dashboards, and tools that transform your mesh network
  into a mission-critical communication system. Built for emergency responders, SAR teams,
  event coordinators, and off-grid enthusiasts who demand more.
</p>
```

**Proposed Hero:**
```html
<h1>
  Meshtastic<br>
  <span class="gradient-text">Companion</span>
</h1>

<p class="hero-description">
  A complete Meshtastic client for iOS and Android. Send messages, track nearby nodes,
  configure your radio, and leave ephemeral signals for people in your area.
  Built for off-grid communication without internet or accounts.
</p>
```

---

### 6. web/faq.html

**Add Signals section after "Messaging":**
```html
<h2>Signals</h2>

<div class="faq-item">
  <div class="faq-question" onclick="toggleFaq(this)">
    <h3>What are Signals?</h3>
    <span class="faq-toggle">+</span>
  </div>
  <div class="faq-answer">
    <div class="faq-answer-inner">
      <p>Signals are short, ephemeral messages you broadcast to nearby mesh nodes. Unlike direct messages, Signals:</p>
      <ul>
        <li>Expire automatically (15 minutes to 24 hours)</li>
        <li>Are sorted by proximity, not time or popularity</li>
        <li>Have no likes, comments, or followers</li>
        <li>Stay local — there is no global feed</li>
      </ul>
      <p>Think of Signals as leaving a temporary trace for people nearby.</p>
    </div>
  </div>
</div>

<div class="faq-item">
  <div class="faq-question" onclick="toggleFaq(this)">
    <h3>Why do some Signal images appear locked?</h3>
    <span class="faq-toggle">+</span>
  </div>
  <div class="faq-answer">
    <div class="faq-answer-inner">
      <p>Images unlock based on presence:</p>
      <ul>
        <li><strong>Authenticated:</strong> If you're signed in, all images are unlocked</li>
        <li><strong>Proximity:</strong> If you've been near the sender's node for 5+ minutes, images unlock</li>
      </ul>
      <p>This ensures images don't spread beyond their intended local context.</p>
    </div>
  </div>
</div>

<div class="faq-item">
  <div class="faq-question" onclick="toggleFaq(this)">
    <h3>Do Signals require an account?</h3>
    <span class="faq-toggle">+</span>
  </div>
  <div class="faq-answer">
    <div class="faq-answer-inner">
      <p>No. Signals work entirely over the mesh without authentication. Your mesh node ID is your identity.</p>
      <p>Signing in enables optional features like cloud backup and image uploads, but the core Signal functionality works offline without an account.</p>
    </div>
  </div>
</div>
```

---

### 7. In-App Copy: lib/features/signals/screens/presence_feed_screen.dart

**Current Empty State (Lines 153-159):**
```dart
'No Active Signals',
...
'Signals are ephemeral mesh messages that expire.\nBe the first to broadcast your presence.',
```

**Status: CORRECT** — This copy is aligned with Signals terminology.

---

### 8. In-App Copy: lib/features/signals/screens/create_signal_screen.dart

**Current Hint (Line 344):**
```dart
hintText: 'What\'s your signal?',
```

**Status: CORRECT** — Good terminology.

**Current Submit Button (Lines 275-276):**
```dart
'Broadcast',
```

**Status: CORRECT** — "Broadcast" is preferred over "Post" or "Share".

---

### 9. In-App Copy: lib/features/settings/settings_screen.dart

**Current (Lines 847, 2595-2597):**
```dart
subtitle: 'Meshtastic companion app',
'Meshtastic companion app • Version $v',
```

**Status: CORRECT** — No social language.

---

### 10. lib/features/onboarding/onboarding_screen.dart

**Current Page Titles (Lines 44-80):**
- "The Mesh"
- "Off-Grid Comms"
- "Zero Knowledge"
- "Grow the Network"
- "Your Command Center"
- "Go Live"

**Status: MOSTLY CORRECT** — No explicit Signals mention, but no social language either.

**Optional Enhancement:** Add Signals page between "Zero Knowledge" and "Grow the Network":
```dart
_OnboardingPage(
  title: 'Signals',
  description:
      'Leave short, ephemeral traces for people nearby.\nNo followers. No likes. Just presence.',
  advisorText:
      "Signals are different. They fade. They stay local. They're not about building an audience — they're about noticing who's nearby right now.",
  mood: MeshBrainMood.speaking,
  accentColor: AccentColors.cyan,
),
```

---

## Content to Remove Entirely

1. **marketing.md** — Rewrite entirely or remove. Contains "social network" language throughout.

2. **Any reference to:**
   - "Build private communities"
   - "Social features"
   - "Feed" (when referring to Signals)
   - Competitive comparison tables with WhatsApp, Signal, Zello

3. **Screenshots captions in marketing.md (Lines 174-179):**
   Remove "broadcast to all" phrasing. Signals don't broadcast globally.

---

## Summary of Required Changes

| Surface | Status | Action |
|---------|--------|--------|
| README.md | ✅ Complete | Added Signals description |
| marketing.md | ✅ Complete | Removed social network language, rewrote descriptions |
| docs/support.md | ✅ Complete | Added Signals FAQ section |
| docs/privacy-policy.md | ✅ Complete | Added Signals clarification |
| web/index.html | ✅ Complete | Softened hero copy, removed "mission-critical" hype |
| web/faq.html | ✅ Complete | Added Signals FAQ section |
| presence_feed_screen.dart | ✅ Correct | No change needed |
| create_signal_screen.dart | ✅ Correct | No change needed |
| settings_screen.dart | ✅ Correct | No change needed |
| onboarding_screen.dart | Optional | Consider adding Signals page |

---

## Success Criteria

After these changes, a new user should think:

> "This helps me notice and leave traces of people who are physically nearby, without turning it into a performance."

If any copy suggests broadcasting to an audience, building a following, or competing for attention — it contradicts Signals and must be revised.
