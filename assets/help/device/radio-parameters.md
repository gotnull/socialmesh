# Radio Parameters

Meshtastic lets you adjust how your radio transmits data. These settings control the trade-off between range, speed, and airtime usage. Here's what the main parameters mean in plain language.

## Spreading Factor (SF)

The spreading factor controls how "spread out" each piece of data is in the radio signal.

- **Higher SF** (e.g., SF12) = longer range, slower speed, more airtime per message
- **Lower SF** (e.g., SF7) = shorter range, faster speed, less airtime per message

Think of it like speaking slowly and clearly vs speaking quickly. Speaking slowly (high SF) is easier to understand at a distance, but it takes longer to say the same thing.

## Bandwidth (BW)

Bandwidth is the width of the radio channel in kilohertz (kHz).

- **Wider bandwidth** (e.g., 500 kHz) = faster data rate, shorter range, less susceptible to frequency errors
- **Narrower bandwidth** (e.g., 125 kHz) = slower data rate, longer range, more susceptible to frequency drift

A wider bandwidth lets more data through but the signal needs to be stronger. A narrower bandwidth is more sensitive but slower.

## Coding Rate (CR)

The coding rate adds **error correction** to the transmission. More error correction means the receiver can recover data even if parts of the signal are corrupted, but it also means more total data needs to be transmitted.

- **CR 4/5** — minimal error correction, fastest transmission
- **CR 4/8** — maximum error correction, slowest transmission

For most situations, the default coding rate works well.

## Presets

Rather than configuring these individually, Meshtastic offers **presets** that bundle sensible combinations:

- **Short Fast** — short range, fast speed. Good for dense local networks.
- **Short Slow** — short range, better reliability.
- **Medium Fast** — balanced range and speed.
- **Medium Slow** — balanced but favouring range.
- **Long Fast** — long range, moderate speed. The **default** and most commonly used preset.
- **Long Moderate** — long range, slower but more reliable.
- **Long Slow** — maximum range, very slow. Best for extreme distances.
- **Very Long Slow** — absolute maximum range. Very high airtime usage.

## Which Preset Should I Use?

**Long Fast** is the default for good reason — it works well for most Meshtastic networks. Only change it if you have a specific need:

- In a dense urban mesh with many nodes close together → consider **Short Fast** to reduce airtime.
- Trying to reach a distant node at the edge of range → try **Long Slow**, but be aware that every message takes much longer to transmit.

All nodes on the same channel must use the **same preset** to communicate. If one radio is set to Long Fast and another to Short Slow, they can't hear each other.
