# Changelog

## Unreleased

## 0.1.3 - 2026-08-24

- Fix excessive horizontal space between the Omaforge logo and Process Center
  title by replacing the automatic header layout with explicit anchored
  geometry and a four-unit title margin.

## 0.1.2 - 2026-08-24

- Add a consistent Omaforge brand label above the Process Center title while
  preserving the established plugin identity and product name.

## 0.1.1 - 2026-08-24

- Standardize the manifest and registry-facing plugin name as
  `omaforge-control-center`, matching the repository directory while preserving
  the stable `omaforge.control.center` plugin ID and Process Center panel title.
- Add a deterministic plugin-only Process Center preview to the repository and
  README without capturing desktop or real process data.
- Rename the popout header from Forge Run to Process Center so its purpose is
  immediately clear without changing the plugin ID or registry name.
- Add All, Apps, System, Servers, and Ports filters above the process list;
  Ports correlates listening TCP sockets with user-owned PIDs via read-only
  `ss` output and requires no sudo.
- Replace the mistaken per-project service model with a dashboard of all
  processes owned by the current user, including graceful Stop and best-effort
  Restart controls without sudo and protection for session-critical processes.
- Reworked the bar icon and ready-state popout to match the confirmed visual
  design, including the supplied Forge mark, branded header, project card,
  paired actions, framed services, selected-row accent, cyan URLs, log console,
  and keyboard footer.
- Initial Forge-generated plugin foundation.
- Implemented the full local dev-process control center described in
  `FORGE_SPEC.md`: per-project service list read from
  `.omaforge/services.json`, start/stop/restart of managed processes, live
  in-memory log streaming with Clear, Run all / Stop all, git-branch status,
  and an "open service URL" action via `xdg-open`.
- Reworked the popout keyboard contract to `j`/`k` navigate,
  `h`/`l` focus services vs. logs, `Enter` open, `r` restart, `x` stop,
  `R` refresh, `Esc` close.
- Added `projectPath` (type `path`) setting and set `allowMultiple: true` so
  one instance can be added per monitored project.
- Revised `FORGE_SPEC.md` to replace unfilled "all"-scoped network/
  persistence placeholders with concrete, bounded decisions, after
  confirming with the user that the reference design required managed
  long-running processes beyond the generated template's shape.
