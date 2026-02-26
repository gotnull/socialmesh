# How Mesh Networking Works

In a traditional network, devices connect to a central point — a cell tower, a Wi-Fi router, a server. If that central point goes down, communication stops. A mesh network works differently.

## Every Node is a Relay

In a mesh network, every device (called a **node**) can act as both a sender and a relay. When you send a message, your radio broadcasts it. If the recipient is within range, they hear it directly. If not, other nodes that _did_ hear it will **rebroadcast** it, extending its reach.

This means a message can travel far beyond the range of any single radio, hopping from node to node until it arrives.

## No Central Point of Failure

Because there's no central hub, the mesh is resilient:

- If one node goes offline, messages route around it.
- New nodes strengthen the network by adding more potential relay paths.
- The mesh is self-organising — nodes discover each other automatically.

## How a Message Travels

Here's a simplified example:

1. **Alice** sends a message to **Dave**.
2. Alice's radio broadcasts the message over LoRa.
3. **Bob** is within range of Alice. His radio receives the message and rebroadcasts it.
4. **Carol** is within range of Bob but not Alice. She receives the rebroadcast and relays it again.
5. **Dave** is within range of Carol. He receives the message.

Alice and Dave never needed to be in range of each other. The mesh did the work.

## Flooding vs Routing

Meshtastic uses a **flooding** approach: when a node receives a message it hasn't seen before, it rebroadcasts it. This is simple and robust, but it means every node in range processes every message.

To prevent messages from bouncing around forever, each message has a **hop limit** — a counter that decreases with each relay. When it reaches zero, the message is no longer rebroadcast.

## The Mesh Gets Stronger

The beauty of a mesh network is that it becomes more capable as more nodes join. Each new node:

- Extends the coverage area
- Adds redundant paths for messages
- Increases the chance of successful delivery

A single radio in the wilderness can only reach as far as its signal. A dozen radios spread across a valley can cover the entire area.
