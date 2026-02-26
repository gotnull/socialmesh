# What Are Channels?

Channels are how Meshtastic organises conversations on the mesh. Think of them like walkie-talkie frequencies — everyone tuned to the same channel can hear each other.

## The Basics

A channel has two key properties:

- **A name** — a human-readable label so you know what it's for (e.g., "Family", "Hiking Group", "Emergency").
- **An encryption key** — a shared secret that controls who can read messages on that channel.

When you send a message on a channel, it's encrypted with that channel's key. Only radios that have the same channel (with the same key) can decrypt and read it.

## How Channels Work on the Mesh

All messages travel over the same LoRa radio frequencies — channels don't use different frequencies. Instead, channels are a logical separation:

1. Your radio sends an encrypted message.
2. All nearby nodes receive the radio transmission.
3. Each node tries to decrypt the message using its configured channels.
4. If a node has a matching channel key, it can read the message. Otherwise, it still relays it (because it might reach someone who can read it), but can't see the content.

This means your encrypted messages are relayed by nodes that can't read them. That's by design — it maximises reach while preserving privacy.

## The Default Channel

Every Meshtastic radio comes with a default public channel called **LongFast**. This channel uses a widely known encryption key, so it's effectively public. It's useful for:

- Discovering other Meshtastic users in your area
- Testing your radio setup
- General community communication

For private conversations, you should create your own channel with a unique key.

## Multiple Channels

Your radio can be configured with multiple channels simultaneously. You can have a public community channel, a private family channel, and an emergency channel all active at the same time. Messages are sent to a specific channel, and only nodes with that channel will see them.
