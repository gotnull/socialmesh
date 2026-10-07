# Radio Regulations

LoRa operates on licence-free radio frequencies, but "licence-free" does not mean "rule-free." There are regulations you must follow.

## ISM Bands

Meshtastic operates in the **ISM (Industrial, Scientific, and Medical)** bands. These frequencies are set aside by governments for unlicensed use, but they come with conditions:

- **Power limits** — you can't transmit above a certain power level (measured in milliwatts or dBm).
- **Duty cycle limits** — in some regions (especially the EU), you can only transmit for a certain percentage of the time.
- **Frequency limits** — you must stay within the allocated band for your region.

## Regional Rules

### United States (FCC)

- **Band:** 902-928 MHz
- **Power:** Up to 1W conducted power (before antenna gain)
- **Bandwidth:** Digital modulation systems operating under FCC Part 15.247 need a 6 dB bandwidth of at least 500 kHz. Frequency hopping systems and other rule paths have different requirements.
- **Meshtastic default:** Meshtastic 2.8 and later sets up new US nodes on Long Turbo (500 kHz). A node configured earlier keeps its preset, which may be an older one such as Long Fast (250 kHz). SocialMesh shows a notice on the LoRa settings screen when a US node runs below 500 kHz.

What applies to you depends on how your device is authorised and how it is configured. Use settings that suit your equipment and location.

### European Union (ETSI)

- **Band:** 863–870 MHz
- **Power:** Up to 25 mW ERP (some sub-bands allow higher)
- **Duty cycle:** Strict limits — typically 1% or 10% depending on sub-band
- This means you can transmit for a maximum of 36 seconds per hour on a 1% duty cycle band

### Australia / New Zealand

- **Band:** 915–928 MHz
- **Power:** Up to 1W EIRP
- **Duty cycle:** No specific limit, but must not cause interference

### Other Regions

Each country has its own regulations. Meshtastic's region setting applies the band and power limits the firmware holds for your location. Always use the correct region setting.

## Why This Matters

Violating radio regulations can:

- **Interfere** with other users and services sharing the band.
- **Result in fines** — regulatory agencies can enforce compliance.
- **Degrade your own mesh** — exceeding airtime limits contributes to congestion.

## Meshtastic Helps

When you set your region, Meshtastic applies region-specific defaults and radio limits such as the band, maximum power and duty cycle. Firmware version, modem preset, your device's authorisation and local rules can still affect which settings are permitted.

However, some settings (like increasing transmit power or hop limits) can push you closer to regulatory limits. Be mindful of airtime usage, especially in EU regions with strict duty cycle rules.
