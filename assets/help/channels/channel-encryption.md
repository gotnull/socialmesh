# Channel Encryption

Every message sent on a Meshtastic channel is encrypted. This means that even though your radio signal can be received by anyone with a LoRa receiver, the actual content of your messages is protected.

## How It Works

Meshtastic uses **AES-256 encryption** — the same standard used by banks, governments, and secure messaging apps. When you create a channel, a cryptographic key is generated. This key is shared with everyone who joins the channel.

When a message is sent:

1. Your radio encrypts the message using the channel's AES-256 key.
2. The encrypted message is broadcast over LoRa.
3. Any node that has the same channel key can decrypt and read it.
4. Nodes without the key can relay the encrypted data but cannot read it.

## The Channel Key

The channel key is the secret that makes your channel private. Anyone who has the key can:

- Read all messages on that channel
- Send messages on that channel

This is why you should only share your channel key with people you trust.

## The Default Key

The default **LongFast** channel uses a publicly known key. This means it's effectively unencrypted — anyone with a Meshtastic radio can read messages on this channel. It's fine for public communication but not for anything private.

## Important Things to Know

- **Encryption protects content, not metadata.** Other nodes can see that a message was sent and its rough characteristics (size, timing), even if they can't read the content.
- **The key never changes automatically.** Once set, a channel keeps the same key until someone manually changes it.
- **Key distribution is your responsibility.** Meshtastic doesn't have a secure key exchange mechanism — you share channels via QR codes or URLs, ideally in person or through a trusted channel.
- **All members share the same key.** There's no per-user encryption within a channel. If one member's key is compromised, all messages on that channel are readable.

## Best Practices

- Create unique channels for different groups (family, work, events).
- Share channel keys in person via QR code when possible.
- Don't share channel keys over public or unsecured channels.
- Consider creating new channels periodically for sensitive groups.
