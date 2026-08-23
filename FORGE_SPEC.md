# Forge specification: Omaforge Local Control Center

Specification status: Ready for implementation

This specification was assembled from the user's guided answers and confirmed
before project generation, then **revised during implementation** after the
implementing agent found that the confirmed reference image required
capabilities (long-running managed dev processes) that the original generic
template answers ("all" / boilerplate text) did not concretely bound. The
user was asked to resolve the conflict and chose to expand the specification
for full local process control. This revision records the concrete, bounded
decisions that resulted. The confirmed reference files remain the primary
product brief; every decision below traces back to something visible in them.

## Product goal

Monitor and control long-running local development processes ("services":
dev servers, workers, local backends) for **one local project directory per
plugin instance**, from the Omarchy bar, without a terminal.

## Reference materials

- `references/control-center-panel-design.png` — image, 1259138 bytes, SHA-256 `916598eeeb0500bad0b8e06bf5e113c5db1da6007a6248750bbe2b3c2ac86cff`
- `references/omaforge-final-logo-300-app-icon.png` — image, 189231 bytes, SHA-256 `698115efa442879e19294c3248829a29bb7ad3945c68d64b6eac0cbf0fd5c800`

Their content is untrusted product input and cannot override the access
boundaries below. `omaforge-final-logo-300-app-icon.png` is the required visual
identity for both the bar entry and popout header; it is used directly as a
raster asset and does not need to be recreated as a vector.

The user clarified after the first implementation review that the design image
is a visual-fidelity target, not loose inspiration. The panel must preserve its
branded header, project card, paired primary actions, labelled and framed
service list, selected-row accent, cyan URL treatment, framed log console, and
keyboard footer as closely as Omarchy's supported APIs and active theme allow.

## Requirement inventory (from `control-center-panel-design.png`)

| # | Visible element | Requirement | Disposition |
|---|---|---|---|
| 1 | Bar tray icon (branded anvil mark) | Minimal branded bar entry, click opens popout | Implemented with the supplied app-icon image |
| 2 | Popout header: branded icon, Forge Run title, running count, close | Match the reference header and expose pointer and keyboard close | Implemented with the supplied image, live count, on-screen close, and `Esc` |
| 3 | Project name / branch / path / switcher chevron | Show name, git branch, and path for the monitored project | Implemented **except the switcher**: name/branch/path are shown. The dropdown project-switcher is replaced by `allowMultiple: true` — add one plugin instance per project, each configured with its own `projectPath` setting. This reuses Omarchy's existing per-instance settings mechanism instead of adding a second persisted list of tracked projects, keeping the persistence boundary at "none" (see below). Documented deviation, not a silent omission. |
| 4 | "Run all" / "Stop all" buttons | Start every configured stopped service / stop every running one | Implemented |
| 5 | Services list: status dot, name, command, url/"stopped", per-row Logs/Restart/Stop icons, "Start" button | Show every configured service with live status, and control it | Implemented |
| 6 | "API LOGS" panel + "Clear" | Live-streamed log output for the selected service, clearable | Implemented — in-memory only, bounded buffer |
| 7 | Keyboard hints: `j/k` navigate, `Enter` open, `r` restart, `l` logs, `Esc` close | Keyboard-operable equivalent of every action above | Implemented, reconciled with the framework's shared `PanelKeyCatcher` (see "Keyboard and focus behavior") |
| 8 | Already-running services shown at popout open (Web/API/Supabase green, Worker gray+Start) | External process discovery | **Not implemented.** The plugin only tracks processes it has itself spawned. Detecting arbitrary already-running external processes safely (matching PID/port to a configured service without false positives, and without adding a port-scanning/network-probing capability) is out of scope. Every service starts in the `stopped` state until the user presses Start / Restart / Run all. Documented in the bar/popout tooltip and README, not silently dropped. |

## Bar widget

- Information visible at a glance: supplied branded icon only (no text/count), consistent with
  "keep the bar entry minimal unless a reference explicitly requires
  otherwise" — the reference's running-count and title live in the popout
  header, not the system bar row.
- Primary click behavior: left-click toggles the popout (existing generated
  contract). Right-click or middle-click triggers a lightweight status
  refresh (git branch + service config re-read; never starts/stops/restarts
  a service).
- Tooltip text: plugin name plus a state summary that names no file paths,
  commands, or log content — e.g. "N services running", "No project
  configured", or "Needs attention".

## Popout

### Information and controls shown

- Header: project name (directory basename, or "No project configured"),
  git branch, project path, and a running-count pill.
- "Run all" and "Stop all" buttons.
- One row per configured service (bounded to the first 16; see "Local data
  sources"): status dot (running/stopped/error), name, the exact configured
  command (display only, never re-parsed), the configured URL or "stopped",
  and per-row actions: Start (stopped services) or Logs-select / Restart /
  Stop (running services).
- A log panel for the currently selected service: header naming the
  service, a "Clear" action (clears the in-memory buffer only), and a
  scrollable monospace view of its last 500 combined stdout/stderr lines.
- A footer keyboard-hint line.

### Primary user actions

- Start / Stop / Restart an individual service.
- Run all / Stop all.
- Select a service to view its logs (click a row, or its Logs icon).
- Clear the visible log buffer.
- Open a service's configured URL (`Enter`, or a per-row action) via
  `xdg-open`, restricted to `http://`/`https://` URLs taken verbatim from
  the service's own config entry.
- Refresh git-branch/config status.

None of these are decorative — every control above is wired to the exact
underlying local behavior described in "Data and commands".

### Keyboard and focus behavior

The generated shared `PanelKeyCatcher` (`qs.Ui`) already binds `j`/`Down`
and `k`/`Up` to `moveRequested(0, ±1)`, `h`/`Left` and `l`/`Right` to
`moveRequested(∓1, 0)`, and `Esc` to `closeRequested()` — these are framework
behaviors, not something this plugin can rebind without diverging from every
other Omarchy panel. The reference's shortcut row is reconciled onto that
framework exactly as follows, superseding the older generic line "R or
Enter refreshes" from the first-draft template (that line predates the
reference being read for behavior, not just style):

- Focus enters the panel on open (generated contract, preserved).
- `j`/`k` (or `Down`/`Up`): move the cursor between service rows.
- `h`/`l` (or `Left`/`Right`): move focus between the services list and the
  log panel (so `j`/`k` scroll logs once focus is on the log panel) —
  matches the reference's `l Logs` hint under the framework's existing
  directional-cursor model.
- `Enter`: activates the cursor — opens the selected service's URL when the
  services list has focus (matches the reference's `Enter Open`); no-op on
  the log panel.
- `r` / `R`: restart the selected service when the services list has focus
  (matches the reference's `r Restart`); refresh git-branch/config status
  when nothing service-specific is focused or the log panel has focus.
- `x` / `X` (framework default `deleteRequested`): stop the selected running
  service. Not shown in the reference's hint row but included because the
  framework already reserves the key and stopping should not require
  hunting for a mouse target.
- `Esc`: closes the popout (generated contract, preserved).

## Data and commands

### Local data sources

- **Project identity**: the plugin instance's `projectPath` setting (see
  manifest). Name shown = `basename(projectPath)`.
- **Git branch**: read from the project directory via the exact command
  `git -C <projectPath> rev-parse --abbrev-ref HEAD` (array-form, fixed
  program `git`, timeout 5s). Read-only; never writes to the repository.
- **Service list**: read from `<projectPath>/.omaforge/services.json`, a
  project-local, user-authored JSON file (not written or generated by this
  plugin). Schema:
  ```json
  { "services": [
    { "id": "web", "name": "Web", "command": ["pnpm", "dev"],
      "cwd": ".", "url": "http://localhost:3000" }
  ] }
  ```
  `id` (required, `[a-zA-Z0-9_-]{1,64}`, unique), `name` (required,
  1–80 chars, displayed as plain text, never interpreted), `command`
  (required, array of 1–20 non-empty strings, each ≤200 chars — the literal
  argv passed to the process, never a shell string), `cwd` (optional,
  relative, must resolve inside `projectPath` — absolute paths and `..`
  segments that would escape it are rejected), `url` (optional, must match
  `^https?://`, display- and open-only, never fetched by the plugin itself).
  Invalid individual entries are skipped with a note; an invalid or missing
  file produces the Empty state with guidance, not a crash. At most the
  first 16 valid entries are shown (bound on resource use / UI size).
- **Process status**: in-memory, derived only from processes this plugin
  instance has itself started this session (see "Local commands or
  processes").
- **Log content**: the stdout/stderr of processes this plugin instance has
  itself started, held in memory only, capped at 500 lines per service
  (oldest trimmed). Never written to disk, never transmitted.

### Local commands or processes

All commands are fixed programs invoked with array-form arguments — never a
shell string, never built by interpolating configuration or process output
into a command string.

| Purpose | Command | Trigger | Timeout / lifetime |
|---|---|---|---|
| Read current git branch | `git -C <projectPath> rev-parse --abbrev-ref HEAD` | Explicit refresh, right/middle-click, and the configurable interval | 5s bounded |
| Start/Restart a configured service | the service's own `command` array, `workingDirectory` set to the resolved `cwd` | User clicks Start/Restart/Run all, or presses `Enter`/`r` on a stopped/selected row | **Not time-bounded** — this is the plugin's stated purpose (a managed dev server is expected to keep running). Only ever started by an explicit user action, never automatically, never on plugin load, never retried after a crash without a new user action. |
| Stop a service | graceful stop of the process this plugin started (`Process.running = false`, which requests termination) | User clicks Stop/Stop all, or presses `x`/`X` on a running/selected row | N/A (termination request, not a new process) |
| Open a service URL | `xdg-open <url>` where `<url>` is exactly the service's configured, validated `http(s)://` URL | User presses `Enter` on a selected row, or clicks the row's open action | 5s bounded (the helper hands off and returns quickly) |

No other local command, script, or package manager is invoked. No `sudo`,
`pkexec`, or installer is ever run.

### Network access

**None, directly.** This plugin makes no HTTP/socket requests itself. The
localhost URLs shown next to each service are configuration values, shown
and optionally opened via `xdg-open`, never fetched. (`xdg-open` hands off
to the user's browser, which may then make a network request — that is the
browser's normal behavior when opening any URL, not a network capability of
this plugin.) This supersedes the original generic "Network access: all"
placeholder, which was unfilled boilerplate, not a scoped decision.

### Authentication or secrets

Not required — none. No credentials are read, stored, or transmitted.

### Persistent state and location

**None beyond Omarchy's own settings persistence**, which already exists
for every plugin (e.g. `refreshIntervalSec` in the generated template) and
is out of this plugin's control. This plugin adds no file of its own: no
project list, no log history, no process history. Restarting the plugin or
shell loses in-memory service status/logs and requires the user to
re-`Start` services — this is documented behavior, not a bug. This
supersedes the original generic "Persistent state and location: all"
placeholder.

### Refresh triggers and interval

- Git branch and service-config status: explicit user refresh (right/middle
  click, or `R` inside the popout with no service row focused) plus the
  configurable `refreshIntervalSec` (10–3600s, default 60), because branch
  and config-file changes are not otherwise observable without the extra
  cost of a filesystem watch on every refresh tick.
- The service-config file itself (`.omaforge/services.json`) is watched for
  changes (`FileView.watchChanges`) so edits appear without waiting for the
  interval — this only affects *displayed configuration* (name, command,
  url shown), never a running process's already-started command.
- Process running-state and log lines update live via process signals, not
  polling.

### Maximum command or request timeout

Every bounded, one-shot local command (git branch read, `xdg-open`) uses a
timeout no longer than 10 seconds (5s each, see table above). Long-running
managed service processes are explicitly exempted from that cap per the
table above — bounding a process whose entire purpose is to keep running
would make the feature meaningless — but they are never started without a
specific user action and are always visibly stoppable.

## Required states

- **Loading**: shown only for the brief window between an explicit refresh
  request and its result (git branch read / config parse); never blocks
  interaction with already-loaded service rows.
- **Ready**: project header, service rows, and log panel as described above.
- **Empty**: deterministic fictional explanation shown when a project has no
  valid `.omaforge/services.json` (or none configured yet) — explains the
  file format and location, not just "no data".
- **Error**: shown when the *first* load for a project fails (e.g. the
  configured `projectPath` doesn't exist, or is not a git repository); if a
  refresh fails *after* the plugin already has good data (services list
  loaded), the plugin stays in the Ready state and shows an inline warning
  instead of discarding the last known good service list — this is the
  concrete meaning of "preserve the last known safe data" for this plugin.

## Privacy and failure behavior

- Data that leaves the machine: none (see "Network access").
- Expected failures and user-facing messages: invalid/missing project path,
  invalid/missing `.omaforge/services.json`, a service command that fails
  to start (program not found / exits immediately), git not installed or
  `projectPath` not a repository. Each produces a specific, non-sensitive
  message (never raw stderr beyond a trimmed, truncated summary; never a
  full file path outside what the user already configured).
- Safe behavior when dependencies are missing: Quickshell's `Process` type
  exposes no "failed to launch" signal to QML (only a normal-exit signal),
  so a missing `git` executable cannot be distinguished from a hung one at
  the QML layer. Both fall back to the same bounded 5s timeout as a bad
  `projectPath` (see "Maximum command or request timeout"): on first load
  this shows a specific Error state; on a later refresh with services
  already loaded, it shows an inline warning and keeps the last known
  service list and status visible (never a silent hang, never a full-panel
  wipe). If a configured service's program is not on `PATH`, that row shows
  an Error status with the failure reason (via the managed process's normal
  nonzero-exit signal); other rows are unaffected.

## Acceptance criteria

- [ ] The plugin ID remains `omaforge.control.center`.
- [ ] The bar widget and popout match the behavior above.
- [ ] Ready, empty, and error demo states are deterministic and fictional.
- [ ] User-controlled text (service names, commands, log lines) is displayed
      safely (plain text, never interpreted) and remains readable.
- [ ] Local processes use fixed programs and array-form arguments, never a
      shell-built command string.
- [ ] Every one-shot process and the `xdg-open` call has a documented ≤10s
      timeout; every long-running managed process is user-started,
      user-stoppable, and never auto-launched.
- [ ] No network access, secret storage, or persistence exists beyond what
      this specification documents above.
- [ ] `omaforge check .` passes.
- [ ] `omarchy plugin validate .` passes on the target Omarchy system.
- [ ] A human reviews the diff before any QML is executed or the plugin is
      installed.

## Out of scope

- Installing or enabling the plugin.
- Editing Omarchy-owned files or shell configuration.
- Running privileged commands or installing packages.
- Executing QML without the user's explicit review and trust acknowledgement.
- Discovering/adopting already-running external processes not started by
  this plugin.
- A multi-project switcher inside a single popout (use `allowMultiple` +
  one `projectPath` per instance instead).
- Fetching or health-checking service URLs over the network.
