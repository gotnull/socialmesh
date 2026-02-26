# Primary vs Secondary Channels

Your Meshtastic radio can have multiple channels configured at once. The first one has a special role.

## The Primary Channel

The **primary channel** (channel index 0) has responsibilities beyond just messaging:

- **Node discovery** — your radio broadcasts its identity and telemetry on the primary channel. Other nodes use this information to build their node list.
- **Position sharing** — GPS coordinates are shared on the primary channel by default.
- **Network management** — administrative messages (like routing information) use the primary channel.

Because of these extra responsibilities, your primary channel determines which mesh "community" your node belongs to. Two radios will only discover each other if they share the same primary channel.

## Secondary Channels

Secondary channels (index 1 through 7) are purely for messaging. Radios on different primary channels can still communicate on a shared secondary channel, as long as a relay path exists between them.

You can have up to **8 channels total** configured on your radio — one primary and up to seven secondary.

## Practical Example

A common setup might be:

- **Primary (0):** The default LongFast channel — for community discovery and public messages
- **Secondary (1):** A private "Family" channel for your household
- **Secondary (2):** A "SAR Team" channel for your search-and-rescue group

This way, your node appears on the public mesh (through the primary LongFast channel) while maintaining private channels for specific groups.
