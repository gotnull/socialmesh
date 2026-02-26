# Mesh Health

A healthy mesh delivers messages reliably, doesn't waste airtime, and gives good coverage across its area. Here's how to assess whether your mesh is performing well.

## Signs of a Healthy Mesh

- **Messages arrive consistently.** Direct messages get ACKs. Broadcast messages are seen by most nodes.
- **Node list is populated.** You can see nodes across the mesh, not just your immediate neighbours.
- **Signal quality is reasonable.** Most nodes show SNR above -10 dB.
- **Airtime usage is moderate.** Nodes aren't spending too much time transmitting relative to listening.

## Signs of Problems

**Too few nodes.** A mesh with only 2-3 nodes has limited relay paths. If the direct path between two nodes is blocked, there's no alternative route.

**All nodes in one location.** If all nodes are in the same room or building, they can all hear each other directly and the mesh relay system isn't being exercised. Spread nodes out to create a real mesh topology.

**High airtime usage.** If nodes are transmitting more than a few percent of the time, the mesh is congested. This can happen with too many nodes, too-frequent position updates, or too many messages.

**Excessive hop counts.** If messages are taking many hops to arrive, it might indicate that the mesh layout needs optimisation — strategic placement of router nodes can reduce hop counts.

**Many dropped messages.** If direct messages frequently fail to deliver, check signal quality and consider whether relay nodes are needed between the sender and recipient.

## Improving Mesh Health

- **Add routers at high points.** A single well-placed router on a hilltop can dramatically improve mesh coverage and reliability.
- **Reduce unnecessary traffic.** Lower position update frequency on nodes that don't need to report location often.
- **Use appropriate roles.** Not every node needs to relay — use Client Mute for nodes in dense areas.
- **Monitor airtime.** Keep an eye on how much each node is transmitting. LoRa has duty cycle limits in most regions.
- **Optimise hop limits.** Use the lowest hop limit that delivers your messages reliably.

## Socialmesh Tools

Socialmesh provides several views to help you understand your mesh health:

- **Mesh Health** — an overview of your mesh's performance metrics.
- **Node list** — shows signal quality for each node.
- **Map view** — visualises node positions and coverage.
- **Traceroute** — shows the path a message took through the mesh.
