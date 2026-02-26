# Direct vs Broadcast Messages

Meshtastic supports two ways to send messages: **direct** (to a specific person) and **broadcast** (to everyone on a channel).

## Direct Messages

A direct message (DM) is addressed to a **specific node**. Only that node's radio can decrypt and display the message.

Key characteristics:

- **Acknowledged.** The recipient's radio sends back an ACK to confirm delivery. If no ACK is received, your radio retries automatically.
- **Encrypted.** The message is encrypted with the channel key, like all Meshtastic messages.
- **Still broadcast over radio.** Technically, all nodes within range hear the transmission. But only the addressed node processes it as a message — others treat it as relay traffic.
- **Retry behaviour.** If the first attempt doesn't receive an ACK, your radio will retry several times before giving up and marking the message as undelivered.

## Broadcast Messages

A broadcast message goes to **all nodes** on the channel. Every node with the matching channel key will see it.

Key characteristics:

- **No acknowledgement.** Since the message is for everyone, there's no single recipient to ACK it. You won't get delivery confirmation.
- **Wider reach.** All nodes relay broadcast messages within the hop limit.
- **Chatroom-style.** Think of it as sending a message to a group chat where everyone on the channel participates.

## When to Use Each

- **Direct** — personal conversations, checking if a specific person is reachable, sending location requests to a specific node.
- **Broadcast** — group coordination, announcements, general chat, community discussions.

## Practical Notes

On a busy mesh, broadcast messages generate more traffic than direct messages because every node processes and displays them. On a quiet mesh with just a few nodes, the difference is minimal.

Both types of messages are encrypted with the channel key and travel through the same mesh relay system. The only differences are addressing and acknowledgement behaviour.
