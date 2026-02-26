# Message Reliability

On a mesh network, message delivery isn't guaranteed in the same way it is on the internet. Understanding what affects reliability helps you set realistic expectations and improve your setup.

## What "Delivered" Means

When you see a delivery confirmation in Socialmesh, it means:

- The **recipient's radio** received and decoded the message.
- The recipient's radio sent an **acknowledgement (ACK)** back.
- Your radio received that ACK.

This only happens for **direct messages**. Broadcast messages have no delivery confirmation.

## What Affects Reliability

Several factors determine whether a message gets through:

**Signal quality.** Weak signals (low SNR, low RSSI) mean some packets may be corrupted in transit and never decoded. Improving antenna placement and height helps dramatically.

**Mesh density.** More nodes between sender and recipient means more relay paths. A sparse mesh with few nodes has fewer options if the direct path is blocked.

**Airtime congestion.** LoRa is a shared medium — all nodes on the same frequency take turns transmitting. On a busy mesh, packets can collide, causing some to be lost. The mesh handles this through retries, but heavy congestion degrades reliability.

**Hop limit.** If the message needs more hops than the configured limit, it won't reach distant nodes. Increasing the hop limit can help, but at the cost of more airtime usage.

**Node availability.** If the recipient's radio is off or disconnected from their phone, the message is delivered to the radio level but may not reach the user until they reconnect.

## Improving Reliability

- **Elevate your antenna.** Even a metre or two of height helps.
- **Use an appropriate hop limit.** Don't set it too low for your mesh's geography.
- **Avoid excessive traffic.** Short, infrequent messages are more likely to arrive than a stream of long ones.
- **Check signal metrics.** SNR above -10 dB and RSSI above -120 dBm are generally usable.
- **Add relay nodes.** Placing powered nodes at strategic locations (hilltops, rooftops) strengthens the mesh.

## Expectations

In a well-configured local mesh with good signal, message delivery reliability is high — comparable to walkie-talkies. Over longer distances or through marginal relay paths, some messages may not arrive. This is normal for radio communication and doesn't indicate a problem with your equipment.
