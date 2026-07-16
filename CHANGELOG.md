# Changelog

## 1.1.0 — 2026-07-16

- Add standalone background and combined `cosmos_with_foreground` variants for
  daily terminal use.
- Preserve the full starfield, nebula, galaxy, meteors, and black-hole disk in
  empty regions while adaptively protecting text from bright cosmic detail.
- Keep terminal geometry undistorted by disabling gravitational lens sampling
  in the foreground-safe variants.
- Reuse the existing cosmic cursor as an unobstructed foreground effect rather
  than introducing a duplicate cursor shader.
- Document the Ghostty opacity settings and shader controls used for foreground
  detection and readability tuning.

## 1.0.0 — 2026-07-15

- Keep perspective-star spacing and halo appearance stable across viewport
  heights.
- Prevent bright perspective-star halos and streaks from exposing square cell
  boundaries in short Ghostty windows.
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
