# Omaforge Local Control Center

A local-first Omarchy bar widget for monitoring processes owned by the current
user and gracefully stopping or best-effort restarting eligible processes
without `sudo`.

The compact popout header is **Process Center**; the full plugin identity remains
**Omaforge Local Control Center** in Omarchy's plugin registry.

## Behavior

- Lists open processes owned by the current UID using `ps`.
- Filters the list by All, Apps, System, Servers, or Ports. Ports uses read-only
  `ss` socket metadata to identify user-owned listening processes and does not
  open a connection.
- Refreshes every 10 seconds by default, configurable from 5–300 seconds.
- Sends `SIGTERM` for Stop; it never escalates to `SIGKILL` automatically.
- Restart snapshots `/proc/<pid>/cmdline` and `/proc/<pid>/cwd`, sends
  `SIGTERM`, waits up to five seconds, then relaunches the original argument
  array from its working directory with `setsid`.
- Processes whose command or working directory cannot be reconstructed remain
  monitorable; a failed action is shown as a warning.
- Session-critical processes (`quickshell`, `Hyprland`, `systemd`,
  `dbus-broker`, and `uwsm`) are visible but their Stop/Restart controls are
  disabled to prevent the dashboard from destroying its own desktop session.
- No telemetry, network access, persistence, package installation, shell-built
  command strings, or privileged operation is used.

Restart is necessarily best-effort: it preserves executable arguments and the
working directory, but it cannot guarantee that every application will restore
its prior runtime state or environment-dependent behavior.

## Requirements

Omarchy 4 with manifest schema 1, plus standard Linux `ps`, `id`, `stat`,
`readlink`, `kill`, and `setsid` commands and a readable `/proc` filesystem.

## Configuration

The only setting is the refresh interval (5–300 seconds, default 10). No project
directory or service configuration file is required.

## Privacy

Process metadata stays local. The plugin reads the current user's process table
and selected `/proc` entries, makes no network request, and stores no history.

## Development

Static checks do not execute plugin QML:

```bash
./tests/run
omaforge check .
omarchy plugin validate .
```

After reviewing the code, exercise deterministic fictional states in isolation:

```bash
./tests/runtime --trust-plugin-code --state ready
./tests/runtime --trust-plugin-code --state empty
./tests/runtime --trust-plugin-code --state error
```

## Install

```bash
omarchy plugin add "$PWD" --enable
```

Preview image is not available yet; use the isolated screenshot command
after reviewing the QML.

## Update

For this local Git checkout, commit changes and reinstall from the checkout.

Plugins execute unsandboxed in the long-lived Omarchy Shell process. Review the
source before enabling it.

## Removal

Remove it with:

```bash
omarchy plugin remove omaforge.control.center
```

## License

MIT © eddieor
