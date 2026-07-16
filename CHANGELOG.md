# Changelog

## 1.1.0 — 2026-07-16

- Add standalone background and combined `cosmos_wallpaper` variants.
- Composite Ghostty's untouched terminal texture over Cosmos using per-pixel
  alpha instead of detecting, recoloring, or masking terminal content.
- Reveal the wallpaper proportionally at every opacity below `1`, while opacity
  `1` hides the Cosmos background completely.
- Preserve terminal geometry by disabling gravitational lens sampling in the
  wallpaper variants.
- Reuse the existing cosmic cursor as a foreground effect rather than adding a
  duplicate cursor shader.
- Document how `background-opacity-cells` controls whether explicit cell
  backgrounds remain opaque or blend naturally with Cosmos.

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
