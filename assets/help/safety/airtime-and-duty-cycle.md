# Airtime and Duty Cycle

Every time your radio transmits a message, it uses **airtime** — the amount of time the radio is actively sending. Understanding airtime is crucial for being a good mesh citizen and staying within regulatory limits.

## What is Airtime?

Airtime is simply the duration your radio is transmitting. A short text message might use 200 milliseconds of airtime. A longer message or a slower spreading factor might use several seconds.

Airtime is a **shared resource**. All nodes on the same frequency share the same airtime. If too many nodes transmit too often, they start interfering with each other — a problem called **congestion**.

## What is Duty Cycle?

Duty cycle is the **percentage of time** your radio is allowed to transmit within a given period. It's expressed as a percentage.

For example, a 1% duty cycle means:

- In any one-hour period, your radio can transmit for a maximum of **36 seconds**.
- The other 59 minutes and 24 seconds must be spent listening.

## Why Duty Cycle Matters

In many regions (especially the European Union), duty cycle limits are **legally mandated**. Exceeding them is a regulatory violation. But even where no legal limit exists, respecting duty cycle is important for mesh health:

- More transmissions = more congestion = more failed deliveries
- Other nodes need airtime too — your transmissions block theirs
- LoRa is slow by design, so airtime is a precious resource

## What Uses Airtime?

Everything your radio transmits uses airtime:

- **Messages** you send (text, location, telemetry)
- **Relaying** other nodes' messages
- **Position broadcasts** your radio sends periodically
- **Telemetry broadcasts** (battery, signal info)
- **Node announcements** (your radio telling others it exists)
- **ACKs** (delivery confirmations for direct messages)

## Reducing Airtime Usage

- **Send shorter messages.** Every character adds airtime.
- **Reduce position update frequency.** Broadcasting your location every minute uses more airtime than every 15 minutes.
- **Use an appropriate role.** Client Mute nodes don't relay, saving significant airtime.
- **Use appropriate presets.** Faster presets (Short Fast) use less airtime per message than slower ones (Long Slow).
- **Avoid "chat storms."** Rapid back-and-forth conversations generate lots of traffic. LoRa is better suited for deliberate, infrequent messaging.

## Meshtastic's Airtime Management

Meshtastic tracks airtime usage and can limit transmission rates to stay within regulatory requirements. The firmware respects the duty cycle limits for your configured region. However, understanding airtime helps you make better choices about how you use the mesh.
