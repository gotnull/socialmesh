# Position Sharing

Meshtastic nodes can share their GPS position with the mesh, allowing other users to see where they are on a map. Here's how it works and what controls you have.

## How Position Sharing Works

If your radio has a GPS module (or you set a fixed position), it can periodically broadcast its coordinates. These broadcasts travel through the mesh like any other message — other nodes receive and display them.

Position updates are sent on the **primary channel**, so anyone on the same primary channel can see your location.

## Update Frequency

Your radio sends position updates at a configurable interval — typically every few minutes. More frequent updates give better tracking accuracy but use more airtime. Less frequent updates conserve airtime but mean positions shown on maps may be outdated.

Common settings:

- **Every 2-5 minutes** — good for active tracking (hiking, events)
- **Every 15-30 minutes** — a reasonable balance for general use
- **Every hour or more** — minimal impact on airtime, but positions are often stale

## Privacy Controls

You have full control over position sharing:

- **Disable it entirely.** Your radio won't broadcast any position data.
- **Set a fixed position.** Instead of live GPS, broadcast a static location (useful for fixed installations).
- **Adjust precision.** Some firmware versions let you reduce the precision of your reported position (e.g., to neighbourhood level instead of exact coordinates).

## What Other Nodes See

When a node shares its position, other users can see:

- **Location on the map** — a pin marking the node's position
- **Distance and bearing** — how far away the node is from you
- **Movement** — if the node is moving, its position updates will trace a path
- **Last position time** — when the position was last updated

## When Position Sharing is Useful

- **Group coordination** — see where everyone in your hiking group is on the map.
- **Mesh coverage mapping** — understand where your nodes are deployed.
- **Emergency situations** — help others find you if you need assistance.
- **Fixed installations** — show where routers and repeaters are located.

## When to Turn It Off

- **Privacy concerns** — you don't want your location visible to everyone on the channel.
- **Battery conservation** — GPS and frequent transmissions use power.
- **Urban environments** — exact locations in dense areas may feel intrusive.
