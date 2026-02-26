# Understanding Node Info

When you look at a node's details in Socialmesh, you'll see various numbers and indicators. Here's what they mean.

## Signal Quality

**SNR (Signal-to-Noise Ratio)** — measured in decibels (dB). This tells you how clearly the signal was received compared to background noise.

- **Above 0 dB** — Excellent. The signal is well above the noise floor.
- **-5 to 0 dB** — Good. Reliable communication.
- **-10 to -5 dB** — Fair. Should work but approaching the limit.
- **Below -10 dB** — Poor. Messages may be lost or corrupted.

**RSSI (Received Signal Strength Indicator)** — measured in dBm. This is the absolute power level of the received signal.

- **Above -90 dBm** — Strong signal.
- **-90 to -110 dBm** — Moderate signal.
- **-110 to -120 dBm** — Weak signal.
- **Below -120 dBm** — Very weak. At the edge of receivability.

SNR is generally more important than RSSI for LoRa, because LoRa is specifically designed to work with signals below the noise floor.

## Last Heard

The timestamp showing when your radio last received **any packet** from this node — whether a message, a position update, or a telemetry broadcast.

Nodes broadcast their presence periodically (every few minutes to every few hours, depending on their role and settings). If a node hasn't been heard in a while, it may be offline, out of range, or in a low-power sleep mode.

## Battery Level

If the node reports battery telemetry, you'll see its battery percentage. This is reported by the firmware and may not be perfectly calibrated for all hardware.

## Distance and Bearing

If both your node and the other node share GPS positions, Socialmesh calculates the straight-line distance and compass bearing between you. This is useful for understanding your mesh's geography.

Note: this is the direct distance, not the path the radio signal takes. A node might be 2 km away in a straight line but the signal might travel a longer path via reflections.

## Hardware Model

The hardware model tells you what type of radio the node is running. Common models include T-Beam, T-Lora, Heltec, RAK, and others. This can help you understand the node's capabilities (e.g., whether it has GPS or a screen).

## Hops Away

Some information may indicate how many hops away a node is. A hop count of 0 means you're hearing the node directly. Higher numbers mean the signal is being relayed through other nodes to reach you.
