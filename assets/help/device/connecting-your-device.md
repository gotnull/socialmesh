# Connecting Your Device

Socialmesh communicates with your Meshtastic radio over **Bluetooth Low Energy (BLE)**. Here's how the connection works and what to expect.

## How BLE Works

Bluetooth Low Energy is a wireless technology designed for short-range communication with minimal power consumption. Your phone uses BLE to exchange data with your Meshtastic radio — sending commands, receiving messages, and syncing node information.

The BLE connection is separate from the LoRa mesh. Think of it as:

- **BLE** = the cable between your phone and your radio (short range, fast)
- **LoRa** = the radio signal between mesh nodes (long range, slow)

## The Scanning Process

When you open the scanner in Socialmesh:

1. Your phone scans for nearby BLE devices advertising as Meshtastic radios.
2. Discovered radios appear in the list with their name, signal strength, and hardware model.
3. You tap a radio to connect.
4. The app establishes a BLE connection and begins syncing data.

## Connection Range

BLE range is typically **10 to 30 metres**, depending on your phone, the radio hardware, and obstacles between them. In practice, you want your radio within a few metres for reliable communication.

If the BLE connection drops, Socialmesh will attempt to reconnect automatically.

## What Happens During Connection

When Socialmesh connects to your radio:

- It reads the radio's current configuration (channels, settings, node info).
- It syncs the node list (all nodes the radio has heard).
- It retrieves any messages received while the phone wasn't connected.
- It begins streaming live data — new messages, position updates, telemetry.

## USB Connection

Some Meshtastic radios also support **USB serial** connections. This is an alternative to BLE that provides a faster, more stable connection — useful for stationary setups. Socialmesh supports USB connections on Android devices.

## Tips for Reliable Connections

- Keep your phone within a few metres of your radio.
- Make sure Bluetooth is enabled on your phone.
- Grant location permissions when prompted — Android requires this for BLE scanning.
- If connection is unreliable, try turning your radio off and on.
- Some phones work better with BLE than others — this is a hardware limitation.
