# How Messages Travel

Understanding the journey of a message through the mesh helps explain why some arrive instantly and others take a moment — or don't arrive at all.

## The Journey

When you type a message and hit send:

1. **Your phone** sends the message to your Meshtastic radio over Bluetooth (BLE).
2. **Your radio** encrypts the message with the channel's key and broadcasts it over LoRa.
3. **Nearby nodes** receive the broadcast. If they have the matching channel key, they can read it. Either way, they check whether to relay it.
4. **Relaying nodes** decrement the hop counter and rebroadcast the message if hops remain.
5. **The recipient's radio** receives the message (directly or via relays) and sends it to their phone over Bluetooth.

## Broadcast vs Mesh Delivery

On LoRa, all transmissions are technically **broadcasts** - every radio within range hears every transmission. There's no direct point-to-point connection like a phone call.

What makes it feel like a direct message is the encryption and addressing. Even though everyone hears the radio transmission, only nodes with the right channel key and addressed recipient can meaningfully process it.

## Acknowledgements

For **direct messages** (sent to a specific node), the recipient's radio sends back an acknowledgement (ACK). If your radio doesn't receive an ACK, it retries. This is how you know your message was delivered.

For **broadcast messages** (sent to everyone on a channel), there's no ACK — your radio sends the message and trusts the mesh to distribute it. There's no way to confirm that every node received it.

## Why Messages Sometimes Don't Arrive

Several things can prevent delivery:

- **Out of range** — no relay path exists between sender and recipient.
- **Hop limit reached** — the message ran out of hops before reaching the recipient.
- **Congestion** — too many nodes transmitting at once can cause collisions on the radio frequency.
- **Node offline** — the recipient's radio is off or their phone isn't connected.
- **Interference** — other radio sources on the same frequency can corrupt transmissions.

## Timing

Messages typically arrive within seconds — but this varies with the number of hops, the spreading factor (radio speed setting), and how busy the mesh is. A message crossing 3 hops might take 5–10 seconds.
