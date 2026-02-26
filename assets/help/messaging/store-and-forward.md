# Store and Forward

What happens when someone sends you a message but your radio is off? Normally, the message is lost. **Store and Forward** changes that.

## How It Works

Store and Forward is an optional Meshtastic module that runs on powered, always-on nodes (like a solar-powered router). When enabled, that node:

1. **Stores** recent messages in its memory as they pass through the mesh.
2. **Detects** when a node comes online that wasn't previously available.
3. **Forwards** any stored messages to that node.

It's like having an answering machine for the mesh.

## Requirements

Store and Forward only works when:

- A node with **sufficient memory** runs the module (typically an ESP32 device with PSRAM).
- That node is **always on** or at least online more than the recipient.
- The storing node **heard the original message** (it was within range or relay range).

## Limitations

It's important to understand what Store and Forward _can't_ do:

- **Limited storage.** Nodes have finite memory. Old messages are dropped to make room for new ones.
- **Not guaranteed delivery.** If no Store and Forward node heard the original message, it's not stored.
- **Depends on a powered node.** If all nodes are handheld and go offline, there's nothing to store messages.
- **Local only.** Store and Forward works within the range of the storing node — it doesn't sync across the entire mesh.

## When It's Useful

- A group has a solar-powered base station that's always on.
- Team members come and go from the mesh throughout the day.
- You want a "catch up" experience when you turn on your radio in the morning.

## When It's Not Enough

For reliable "offline message delivery," you need something beyond mesh-only solutions. That's where cloud sync features (when available) can complement the mesh — but Store and Forward gives you a surprising amount of coverage with zero internet.
