# Node Roles Explained

Not every node on the mesh needs to do the same job. Meshtastic defines several **roles** that control how a node behaves — specifically, how aggressively it relays messages and how much telemetry it broadcasts.

## Client (Default)

The standard role for a handheld radio carried by a person.

- Relays messages for others
- Broadcasts position and telemetry at normal intervals
- Ideal for most users

This is the role your radio starts with, and it's the right choice for the majority of situations.

## Client Mute

Like a Client, but **doesn't relay** messages for other nodes.

- Receives all messages addressed to it or its channels
- Does **not** rebroadcast other nodes' messages
- Reduces airtime usage

Use this if you want to participate in the mesh but don't want your radio contributing relay traffic — for example, if you're in a dense area and there are plenty of other relays.

## Router

Designed for fixed, always-on nodes whose primary purpose is extending the mesh.

- **Prioritises relaying** — routes messages more aggressively
- Broadcasts its own telemetry less frequently (to save airtime for relaying)
- Intended for powered installations (rooftops, towers, solar setups)

Routers are the backbone of a mesh network. A well-placed router on a hilltop can dramatically extend coverage for an entire area.

## Router Client

A hybrid — acts as a router but also behaves as a regular client.

- Relays messages aggressively like a Router
- Also broadcasts full telemetry and position like a Client
- Good for nodes that serve double duty (e.g., someone's home radio that is also a relay point)

## Repeater

A minimal relay-only node.

- Relays all messages it receives
- Broadcasts **no identity or telemetry** — it's invisible in node lists
- Purely extends range without adding clutter to the mesh

Repeaters are useful for filling coverage gaps. Place one on a hilltop and it silently extends the mesh without appearing as a node to other users.

## Tracker

Optimised for GPS tracking devices.

- Broadcasts position frequently
- Minimal messaging capability
- Designed for asset tracking (vehicles, pets, equipment)

## Sensor

Optimised for IoT sensor nodes.

- Broadcasts telemetry data (temperature, humidity, etc.)
- Minimal user interaction expected
- Designed for environmental monitoring setups

## Choosing the Right Role

For most people, **Client** is the right choice. Only change roles if you have a specific need:

- Setting up a permanent relay point → **Router** or **Repeater**
- In a very dense mesh and want to reduce traffic → **Client Mute**
- Running a home base station → **Router Client**
- Tracking a moving asset → **Tracker**
