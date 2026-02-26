# What is Meshtastic?

Meshtastic is an open-source project that turns inexpensive LoRa radios into a mesh communication network. It lets you send text messages, share your location, and exchange data with other people — all without needing cellular service, Wi-Fi, or any internet connection at all.

## How It Works

Every Meshtastic radio is a **node** on the mesh. When you send a message, your radio transmits it over LoRa (a long-range radio technology). If the recipient is within range, they receive it directly. If not, other nodes in between can **relay** your message, hopping it along until it reaches its destination.

This relay behaviour is what makes it a _mesh_ network — there's no central tower or server. Every node helps every other node communicate.

## Why It Matters

- **No infrastructure required.** Works in remote areas, during power outages, and in emergencies.
- **Free to use.** No subscriptions, no SIM cards, no data plans.
- **Long range.** LoRa signals can travel kilometres — even tens of kilometres with line of sight.
- **Private.** Messages are encrypted. Only people on the same channel can read them.
- **Open source.** The firmware, the protocol, and the apps are all community-built.

## Where Socialmesh Fits In

Socialmesh is a companion app for Meshtastic radios. It connects to your radio over Bluetooth (BLE) or USB and gives you a full-featured interface for messaging, mapping your mesh, monitoring signal quality, and managing your device settings.

Think of it this way: Meshtastic is the engine — Socialmesh is the dashboard.

## Common Uses

People use Meshtastic for all kinds of things:

- **Hiking and camping** — stay in touch with your group when there's no phone signal.
- **Events and festivals** — coordinate across a large area without relying on overloaded cellular networks.
- **Emergency preparedness** — have a backup communication system that works when everything else is down.
- **Community networks** — build a local mesh that keeps your neighbourhood connected.
