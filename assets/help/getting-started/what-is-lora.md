# What is LoRa?

LoRa stands for **Long Range**. It's a type of radio modulation — a way of encoding data into radio waves — that trades speed for distance. Where Wi-Fi might give you hundreds of megabits per second over 30 metres, LoRa gives you a few kilobits per second over several kilometres.

## Why LoRa?

LoRa was designed for the Internet of Things (IoT) — sensors, trackers, and devices that need to send small amounts of data over long distances using very little power. It turned out to be perfect for mesh communication too.

Key properties:

- **Long range.** Typical line-of-sight range is 5–15 km. Some users have achieved over 200 km in ideal conditions.
- **Low power.** A LoRa radio can run for days or weeks on a small battery.
- **Licence-free.** LoRa operates on ISM (Industrial, Scientific, and Medical) frequency bands that don't require a radio licence in most countries.
- **Penetrating.** LoRa signals can travel through walls, trees, and some obstacles better than higher-frequency technologies.

## The Trade-Off

The catch is **bandwidth**. LoRa is slow — deliberately so. You can send short text messages, GPS coordinates, and small telemetry packets, but you can't stream video or transfer files. This is by design: the slower the data rate, the longer the range and the better the sensitivity.

Think of it like this: a whisper carries further in a quiet room than a shout. LoRa is the whisper.

## Frequency Bands

LoRa operates on different frequency bands depending on your region:

- **915 MHz** — US, Australia, and parts of Asia
- **868 MHz** — Europe
- **923 MHz** — Japan, South Korea
- **433 MHz** — Some countries (shorter range, different characteristics)

Your Meshtastic radio must be configured for the correct region. Using the wrong frequency band can be illegal and will prevent communication with other nodes in your area.

## LoRa vs LoRaWAN

You might see the term **LoRaWAN** — this is different from what Meshtastic uses. LoRaWAN is a network protocol designed for IoT devices that connect to centralised gateways, which then forward data to the internet.

Meshtastic uses **raw LoRa** — no gateways, no internet, no central infrastructure. Every node is equal, and the mesh is self-organising.
