# Your First Steps

You've got a Meshtastic radio and Socialmesh on your phone. Here's what happens next.

## 1. Set Your Region

Before your radio can transmit, it needs to know which country you're in. Different countries use different radio frequencies, and transmitting on the wrong one can be illegal.

When you first connect, Socialmesh will prompt you to select your region. This configures the correct frequency band and power limits for your location. Once set, your radio will only operate within the legal parameters for your area.

## 2. Connect Over Bluetooth

Socialmesh connects to your Meshtastic radio using **Bluetooth Low Energy (BLE)**. Turn on your radio, open the scanner in Socialmesh, and tap your device when it appears.

Once paired, your phone becomes the interface for your radio. You type messages on your phone, and the radio transmits them over LoRa to the mesh.

## 3. Join the Default Channel

Every Meshtastic radio comes preconfigured with a default **LongFast** channel. This is a public, unencrypted channel that all Meshtastic users in your area can hear. It's a good starting point — you can see who else is nearby and test your connection.

## 4. See Who's Out There

The node list in Socialmesh shows every Meshtastic radio your device has heard. Each entry shows:

- The node's **name** (or a short ID if no name is set)
- The **last time** it was heard
- **Signal quality** indicators (SNR and RSSI)
- **Distance** and direction (if the node shares its position)

## 5. Send a Message

Try sending a message on the default channel. If other nodes in your area receive it, you'll see delivery confirmations. If you don't see anyone, don't worry — you might need to adjust your antenna placement or find a spot with better line of sight.

## What's Next?

- **Create a private channel** to talk securely with friends.
- **Explore node roles** to optimise how your radio participates in the mesh.
- **Check your signal quality** to understand how well you're reaching other nodes.
- **Read about mesh networking** to understand how your messages travel.
