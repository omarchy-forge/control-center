# Forge specification: Omaforge Local Control Center

Specification status: Ready for implementation

## Product goal

Provide a branded Omarchy dashboard titled **Process Center** that monitors all processes owned by the
current user and offers unprivileged graceful Stop and best-effort Restart.

## Visual contract

Match `references/control-center-panel-design.png` closely and use
`references/omaforge-final-logo-300-app-icon.png` in the bar and header. Retain
the branded header, summary card, paired actions, framed process rows, selected
orange accent, detail console, and keyboard footer.

## Data and controls

- Enumerate the current UID's processes with a fixed array-form `ps` command.
- Show PID, process name, state, and displayed command line.
- Provide All, Apps, System, Servers, and Ports filters. Derive Ports from
  read-only listening-socket metadata correlated to current-UID PIDs.
- Refresh explicitly and every 5–300 seconds (default 10).
- Stop sends `SIGTERM` only after verifying current-UID ownership.
- Restart snapshots the NUL-delimited argv and working directory from `/proc`,
  sends `SIGTERM`, waits at most five seconds, and relaunches array-form argv.
- Never use a shell-built command, `sudo`, `pkexec`, `SIGKILL`, networking,
  telemetry, authentication, a database, or added persistence.
- Show but disable controls for session-critical processes needed by the shell,
  compositor, user service manager, and session bus.
- A restart may fail when `/proc` data is unavailable or the process does not
  stop; report that visibly and leave other processes unaffected.

## Required states

- Ready: fictional user processes including one visibly protected shell process.
- Empty: no visible user process.
- Error: process-table discovery failed.

## Acceptance

- The ID remains `omaforge.control.center` and only one instance is allowed.
- The project-directory setting and `.omaforge/services.json` dependency are gone.
- Static Forge and official Omarchy validation pass.
- A human reviews the diff and isolated screenshot before installing the QML.
