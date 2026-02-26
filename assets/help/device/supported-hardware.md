# Supported Hardware

Meshtastic runs on several types of LoRa radio hardware. Socialmesh works with any Meshtastic-compatible device that supports BLE (Bluetooth Low Energy) or USB serial connections.

## Common Hardware Families

### LILYGO T-Beam

A popular choice with built-in GPS, a large battery connector, and good LoRa performance. The T-Beam Supreme is the latest version with improved features.

- GPS included
- 18650 battery holder (battery sold separately)
- Good range with the included antenna
- SMA antenna connector for upgrades

### LILYGO T-Lora

A more compact option without built-in GPS. Smaller and lighter than the T-Beam, suitable for basic messaging.

- No GPS (position must be set manually or with external GPS)
- Smaller form factor
- Good for basic mesh communication

### Heltec LoRa 32

A compact, affordable board with a small OLED screen and built-in LoRa. Available in several versions.

- Small OLED display
- Affordable
- Good for experimentation and learning

### RAK WisBlock

A modular system where you combine a base board with sensor, GPS, and radio modules. Very flexible.

- Modular design
- Low power consumption
- Good for custom projects and enclosures

### Station G2

A purpose-built Meshtastic device with a good antenna and user-friendly form factor.

- Designed specifically for Meshtastic
- Good out-of-box experience
- Built-in screen and buttons

## Choosing Hardware

When selecting a Meshtastic radio, consider:

- **GPS** — do you need position sharing? If so, choose hardware with built-in GPS.
- **Battery** — for portable use, look at battery capacity and power consumption.
- **Antenna** — an SMA connector lets you upgrade to a better antenna later.
- **Form factor** — handheld vs fixed installation affects your hardware choice.
- **Frequency band** — make sure the radio supports your region's frequency (e.g., 915 MHz for US, 868 MHz for EU).

## Compatibility with Socialmesh

Socialmesh works with any Meshtastic device that runs the standard Meshtastic firmware and supports BLE. The app auto-detects the hardware model and adjusts its interface accordingly.

For USB connections (Android only), the device needs a USB serial interface — most ESP32-based Meshtastic boards support this via their USB-C or Micro-USB port.
