# What is a Node?

In Meshtastic, a **node** is any radio device participating in the mesh network. Your handheld radio is a node. Your friend's radio is a node. A solar-powered repeater on a hilltop is a node.

## Node Identity

Every node has:

- **A node number** — a unique numeric identifier assigned when the firmware is first installed.
- **A short name** — a 4-character abbreviation (e.g., "FM01") used in compact displays.
- **A long name** — a human-readable name you choose (e.g., "Fulvio's T-Beam").
- **A hardware model** — identifying what type of radio it is.

## What Nodes Do

Every node on the mesh:

- **Receives** messages from other nodes.
- **Relays** messages to extend the mesh's reach (depending on its role).
- **Broadcasts** its identity and telemetry periodically so other nodes know it exists.
- **Reports** its position (if GPS-equipped and position sharing is enabled).

## How You See Nodes

In Socialmesh, the node list shows every node your radio has heard. Each entry displays:

- The node's name
- When it was last heard
- Signal quality (SNR and RSSI values)
- Battery level (if reported)
- Distance and bearing (if positions are known)
- Hardware type and firmware version

Nodes that haven't been heard recently fade in the list. New nodes appear automatically when your radio picks up their broadcasts.

## Your Node

Your own radio is also a node on the mesh. Other people see your node in their lists, just as you see theirs. The name, position, and telemetry your radio broadcasts is what other users see — so it's worth setting a meaningful name.
