# Changelog

## Unreleased

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
