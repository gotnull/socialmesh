# Range and Coverage

How far can a Meshtastic radio reach? The answer is: it depends. Range is influenced by several factors, and understanding them helps you get the most out of your setup.

## Line of Sight

The single biggest factor affecting LoRa range is **line of sight**. If your radio's antenna can "see" the other antenna with nothing in between, you'll get the best possible range. Some users have achieved links over 200 km with clear line of sight.

In practice, you rarely have perfect line of sight. Hills, buildings, trees, and terrain all block or weaken the signal.

## Antenna Height

Height makes a dramatic difference. A radio on a table inside a house might reach 1-2 km. The same radio mounted on a rooftop or hilltop might reach 10-20 km or more.

This is because higher antennas can "see" over obstacles. Even a few metres of elevation gain can significantly improve your coverage.

## Antenna Quality

The antenna that comes with your radio is usually adequate, but aftermarket antennas can improve performance considerably. A well-tuned antenna matched to your frequency band will both transmit and receive more efficiently.

Important: the antenna must be designed for the frequency band your radio uses (e.g., 915 MHz for US, 868 MHz for Europe). A mismatched antenna can actually reduce performance.

## Obstacles and Terrain

Different materials attenuate (weaken) LoRa signals differently:

- **Open air** — minimal loss
- **Trees and foliage** — moderate loss, varies with density and moisture
- **Wooden buildings** — moderate loss
- **Brick and concrete** — significant loss
- **Metal** — very high loss (can block signals almost completely)
- **Hills and mountains** — if the signal path is blocked, the signal doesn't get through

## Spreading Factor

Your radio settings also affect range. A higher **spreading factor** (SF) gives longer range but slower data rates. The default Meshtastic settings (LongFast preset) use a spreading factor that balances range and speed well for most situations.

## Real-World Expectations

For a typical handheld Meshtastic radio with a stock antenna:

- **Urban environment** — 500 m to 2 km
- **Suburban** — 1 to 5 km
- **Rural/open terrain** — 5 to 20 km
- **Elevated position with clear line of sight** — 20 km or more

Remember: the mesh helps. Even if you can't reach a distant node directly, intermediate nodes can relay your message.
