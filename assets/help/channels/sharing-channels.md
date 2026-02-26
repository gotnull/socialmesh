# Sharing Channels

To communicate privately on a channel, everyone in the group needs the same channel configuration — including the encryption key. Meshtastic provides a few ways to share this information.

## QR Codes

The most common and secure way to share a channel is via **QR code**. The QR code encodes the channel name, encryption key, and settings into a scannable format.

To share: generate a QR code from your channel settings. The other person scans it with their Meshtastic-compatible app, and the channel is automatically configured on their radio.

This is the recommended method because the key is transferred directly between devices — it's never sent over the internet or the mesh itself.

## Channel URLs

Channels can also be shared as a **URL**. This URL contains the same information as the QR code in a text format. You can send it via any messaging platform.

Be careful with URLs — anyone who has the URL has the encryption key. Only share channel URLs through trusted, private channels (like an encrypted messaging app or in person).

## In-Person Sharing

The best practice for sensitive channels is to share them **in person**:

1. Show the QR code on your screen.
2. The other person scans it.
3. The key never leaves the two devices.

This eliminates any risk of the key being intercepted in transit.

## What Gets Shared

When you share a channel, the recipient receives:

- The channel **name**
- The **encryption key**
- The channel **settings** (like the LoRa preset)
- The channel **index** (primary or which secondary slot)

The recipient's radio is configured to match, so messages sent on the channel are readable by both parties.
