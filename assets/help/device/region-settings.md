# Region Settings

Your Meshtastic radio must be configured for the correct **region** before it can transmit. This isn't optional — it's a legal requirement.

## Why Region Matters

Different countries allocate different radio frequency bands for unlicensed use. LoRa operates in the **ISM (Industrial, Scientific, and Medical)** bands, but the specific frequencies and power limits vary:

- **US / Australia (ANZ)** — 915 MHz band, up to 1W transmit power
- **EU (EU_868)** — 868 MHz band, with strict duty cycle limits
- **Japan / South Korea** — 923 MHz band
- **China** — 470 MHz band
- **India** — 866 MHz band

Transmitting on the wrong frequency or at too high a power can:

- **Violate the law** — even though LoRa is licence-free, you must use the correct frequencies for your country.
- **Interfere** with other services using that frequency band.
- **Fail to communicate** — radios on different frequency plans can't hear each other.

## Setting Your Region

When you connect a new Meshtastic radio for the first time, Socialmesh will prompt you to select your region. This configures:

- The **frequency band** (which radio frequencies to use)
- The **transmit power** limit
- The **duty cycle** restrictions (how much time you can spend transmitting)
- The **channel spacing** and available presets

## What If I Travel?

If you take your radio to a different country, you should change the region setting to match. Your radio will then operate within the legal parameters for that location.

Important: some hardware is designed for specific frequency bands and may not support all regions. Check your radio's specifications.

## Can I Use the Wrong Region?

Technically, the firmware allows you to select any region. But using the wrong one means:

- You won't hear other Meshtastic users in your area (they're on the correct frequency).
- You may be transmitting illegally.
- You may interfere with other radio services.

Always set the correct region for your location.
