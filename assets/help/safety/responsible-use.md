# Responsible Use

Being part of a mesh network means sharing radio resources with others. A few simple practices make the mesh better for everyone.

## Be Mindful of Airtime

The radio spectrum is shared. Every transmission you make uses airtime that other nodes could use. Keep messages concise and avoid unnecessary traffic. LoRa is designed for short, deliberate messages — not extended conversations.

## Set Your Region Correctly

Always configure the correct region for your location. This ensures you're transmitting on legal frequencies at legal power levels. Using the wrong region can interfere with other radio services and violate regulations.

## Use Appropriate Hop Limits

A high hop limit means your message is rebroadcast more times, consuming more collective airtime. Use the lowest hop limit that reliably delivers your messages. For most local meshes, the default of 3 is sufficient.

## Choose the Right Node Role

If you're in a dense area with plenty of relay nodes, consider using **Client Mute** to reduce unnecessary relaying. Save the **Router** role for nodes that are strategically placed to extend coverage.

## Respect the Shared Medium

- Don't spam the mesh with rapid-fire test messages.
- Don't set position updates to unnecessarily frequent intervals.
- Don't increase transmit power beyond what's needed for your use case.
- Remember that every relay node in range will rebroadcast your messages.

## Be a Good Neighbour

If you deploy fixed relay nodes (routers, repeaters), consider the impact on the local mesh:

- Place them where they genuinely improve coverage.
- Monitor their airtime usage.
- Make sure they're not creating more congestion than value.
- Keep firmware up to date for the latest optimisations and bug fixes.

## Privacy Considerations

- Remember that position sharing broadcasts your location to everyone on the channel.
- Default channel keys are publicly known — anything on the default channel is effectively public.
- Be thoughtful about what information you include in your node name and messages.
- The mesh is not anonymous — your node ID is visible to all participants.

## Emergency Use

Mesh networks can be valuable in emergencies. Keep your radio charged and accessible. If your area has an established mesh community, familiarise yourself with any emergency channels or procedures they've set up.
