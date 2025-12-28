# Klipper Monitor Plasmoid

Plasma 6 plasmoid to monitor and control a Klipper printer via the Moonraker WebSocket API.

## Install (local dev)

```bash
kpackagetool6 --type Plasma/Applet --install .
```

If already installed:

```bash
kpackagetool6 --type Plasma/Applet --upgrade .
```

## Configure

Open the plasmoid configuration and set:
- Host and port (Moonraker default is 7125)
- TLS if needed
- WebSocket path (default: `/websocket`)
- API key/token (appended as `?token=` to the WebSocket URL)
- Chart interval (ms)
- Default file name to start prints

## Notes

- Status updates subscribe to `print_stats`, `virtual_sdcard`, `extruder`, and `heater_bed`.
- Charts are sampled on a timer; set the interval in settings for smoother or lighter updates.
- Controls call `printer.print.start/pause/resume/cancel`.
- If your Moonraker uses header-based API keys, you may need a reverse proxy that supports query-token auth.

## Localization

This plasmoid ships a German translation catalog. The translation domain is
`plasma_applet_org.kde.plasma.klippermonitor` and catalogs live under
`contents/locale/<lang>/LC_MESSAGES/`.
