# Changelog

## 1.0.1 — 2026-07-15

- Prevent bright perspective-star halos and streaks from exposing square cell
  boundaries when Ghostty uses a short viewport.

## 1.0.0 — 2026-07-15

- Install durable shader sources under the user data directory, independent of
  the Git clone.
- Expose the `beautiful-ghostty` command under `~/.local/bin`.
- Keep source shaders immutable and store generated state separately under the
  selected Ghostty configuration directory.
- Use content-addressed generated shader filenames so Ghostty recompiles every
  changed shader or GPU profile.
- Preserve user-owned `custom-shader` settings and manage only one clearly
  marked `config-file` block.
- Add idempotent upgrades, configuration backups, rollback on validation
  failure, and an ownership-safe uninstaller.
- Remove repository-local generated shaders, fixed no-op shader stages, and the
  obsolete `shaders.ghostty` indirection.

## 0.1.0 — 2026-07-15

- Initial public release.
