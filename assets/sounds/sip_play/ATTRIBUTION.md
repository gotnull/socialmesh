# SIP Play + Handshake sound effects

Source: Pixabay (https://pixabay.com)
License: Pixabay Content License (https://pixabay.com/service/license-summary/)
- Free for commercial and non-commercial use
- No attribution required (kept here for provenance + future audits)
- May not be redistributed as standalone files

| Asset | Original file | Author |
|---|---|---|
| `play_game.mp3` | `dragon-studio-notification-ping-372479.mp3` | Dragon Studio |
| `connection_succeeded.mp3` | `miraclei-sample_input_typing02_kofi_by_miraclei-363632.mp3` | miraclei (kofi) |
| `connection_failed.mp3` | `miraclei-sample_soft_alert02_kofi_by_miraclei-360125.mp3` | miraclei (kofi) |
| `rejected_declined.mp3` | `miraclei-sample_soft_alert04_kofi_by_miraclei-360127.mp3` | miraclei (kofi) |

Where each is played:

- `play_game.mp3` — when a SIP Play game transitions to active (offer accepted by either side)
- `connection_succeeded.mp3` — when a SIP Handshake completes (state → accepted)
- `connection_failed.mp3` — when a SIP Handshake fails or times out (NOT user-cancelled)
- `rejected_declined.mp3` — when a SIP Handshake or SIP Play offer is declined (either direction)
