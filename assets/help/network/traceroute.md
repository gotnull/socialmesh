# Traceroute

Traceroute is a diagnostic tool that reveals the **exact path** a message took through the mesh. It's invaluable for understanding your mesh topology and debugging communication issues.

## How It Works

When you run a traceroute to a specific node:

1. Your radio sends a special traceroute request packet.
2. Each node that relays the packet **adds its own identity** to the packet.
3. The destination node receives the request and sends back a response — also through the mesh, collecting relay identities along the way.
4. When the response arrives, you can see every node the packet passed through in both directions.

## What You Learn

A traceroute shows you:

- **How many hops** your message needed to reach the destination.
- **Which specific nodes** relayed the message.
- **The relay chain** — the order nodes handled the packet.
- **Whether the path is symmetric** — the outbound and return paths might differ.

## Practical Use

Traceroute is useful for:

- **Verifying relay nodes.** You set up a router on a hilltop — traceroute confirms messages actually go through it.
- **Diagnosing failures.** If you can't reach a node, traceroute to a node near it might reveal where the chain breaks.
- **Understanding mesh topology.** See how messages actually flow through your network, which might not match your assumptions.
- **Measuring hop counts.** Verify that your hop limit is sufficient for the paths your messages need to take.

## Limitations

- Traceroute only works with nodes that are currently online and reachable.
- The path shown is the path for _that specific_ traceroute packet — other messages might take different routes depending on timing and which nodes are available.
- Traceroute adds extra airtime usage, so use it for diagnostics rather than running it constantly.
