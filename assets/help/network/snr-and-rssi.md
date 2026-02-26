# SNR and RSSI

When you look at signal quality in Socialmesh, you'll see two key numbers: **SNR** and **RSSI**. Together, they tell you how well your radio is communicating with another node.

## RSSI — How Strong is the Signal?

**RSSI** stands for Received Signal Strength Indicator. It's measured in **dBm** (decibels relative to one milliwatt) and tells you the absolute power level of the received radio signal.

- **-50 to -80 dBm** — Very strong. The other node is close or has excellent line of sight.
- **-80 to -100 dBm** — Good. Reliable communication expected.
- **-100 to -115 dBm** — Moderate. Should work but signal is getting weaker.
- **-115 to -125 dBm** — Weak. At the edge of usability. Some messages may be lost.
- **Below -125 dBm** — Very weak. Communication is unreliable.

RSSI is always a negative number (because the signal power is less than 1 milliwatt). A number closer to zero means a stronger signal.

## SNR — How Clear is the Signal?

**SNR** stands for Signal-to-Noise Ratio. It's measured in **dB** (decibels) and tells you how much the signal stands out from the background noise.

- **Above +5 dB** — Excellent. Signal is well above the noise.
- **0 to +5 dB** — Good. Clear communication.
- **-5 to 0 dB** — Fair. Signal is getting close to the noise floor.
- **-10 to -5 dB** — Marginal. LoRa can still decode this, but reliability drops.
- **Below -15 dB** — Poor. Most messages will fail at this level.

One of LoRa's remarkable properties is that it can decode signals **below the noise floor** — meaning the signal is actually weaker than the random noise. This is how LoRa achieves such long range.

## Which Matters More?

For LoRa communications, **SNR is generally more important than RSSI**. You can have a weak RSSI reading but still communicate reliably if the SNR is good (meaning the environment has low noise).

Conversely, a reasonable RSSI with poor SNR (lots of noise on the frequency) can result in failed communications.

## Using These Numbers

In Socialmesh, signal quality indicators are shown:

- On each node in the node list
- In message details
- On the map view (signal quality badges)
- In mesh health views

Use them to understand your mesh's performance:

- If SNR is consistently below -10 dB for a node, the link is marginal — consider repositioning your antenna.
- If RSSI is very weak (below -120 dBm), the node is at the extreme edge of range.
- Sudden changes in SNR/RSSI can indicate interference, antenna problems, or environmental changes.
