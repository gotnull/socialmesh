# Hop Limit Explained

When you send a message on the mesh, it doesn't travel forever. Every message carries a **hop limit** — a number that controls how many times it can be relayed before it stops.

## What is a Hop?

A hop is one relay. When your radio sends a message and another node rebroadcasts it, that's one hop. When a third node picks up that rebroadcast and sends it again, that's two hops.

## Why Hop Limits Exist

Without a hop limit, a single message would bounce around the mesh indefinitely. Every node would keep rebroadcasting it, and the network would quickly become overwhelmed with duplicate traffic. This is sometimes called a **broadcast storm**.

The hop limit prevents this. Once a message has been relayed the maximum number of times, nodes stop rebroadcasting it.

## Default Settings

Meshtastic typically defaults to **3 hops**. This means:

- Your radio sends the message (origin — not counted as a hop)
- Node A relays it (hop 1)
- Node B relays it (hop 2)
- Node C relays it (hop 3)
- Node D hears it but does **not** relay — the hop limit is reached

For most local meshes, 3 hops is sufficient. It provides good coverage without flooding the mesh with excessive traffic.

## Higher Hop Limits

You can increase the hop limit, but there are trade-offs:

- **More hops = wider reach** — your message can travel further through the mesh.
- **More hops = more airtime** — every relay uses radio airtime. More hops means more transmissions competing for the same frequencies.
- **More hops = more latency** — each relay adds a small delay.

In a dense mesh with many nodes, a high hop limit can actually _reduce_ reliability because the extra rebroadcasts create congestion.

## Finding the Right Balance

A good rule of thumb: use the **lowest hop limit that reliably delivers your messages**. Start with the default and only increase it if messages aren't reaching their destination.

If you're running a small local mesh (a hiking group, an event), 3 hops is usually ideal. For larger meshes spread over a wide area, you might need 5 or more — but be aware of the airtime cost.
