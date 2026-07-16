# Beautiful Ghostty

A configurable cosmic shader suite for Ghostty: perspective starflight, radial
meteors, an animated nebula and galaxy, a geodesic black hole, and a matching
cursor effect. An optional wallpaper variant places Cosmos strictly behind the
terminal and uses Ghostty's per-pixel alpha to reveal it.

<p align="center">
  <a href="https://github.com/user-attachments/assets/71146e13-6d2b-40ab-b276-b58606345cbb">
    <img src="assets/demo.gif" alt="Beautiful Ghostty animated demo" width="100%">
  </a>
</p>

<p align="center">
  <strong>Starflight · meteors · galaxy · geodesic black hole · cosmic cursor</strong>
</p>

<p align="center">
  <a href="https://github.com/user-attachments/assets/71146e13-6d2b-40ab-b276-b58606345cbb">
    <strong>Watch the full one-minute demo</strong>
  </a>
</p>

## Requirements

- Linux
- Ghostty 1.3.0 or newer with custom-shader support
- Bash 4.0 or newer
- GNU coreutils (`sha256sum`, `mktemp`, `cp`, and `mv`)

## Install

```bash
git clone https://github.com/snaldos/beautiful-ghostty.git
cd beautiful-ghostty
./install.sh
```

The clone may live anywhere and may be deleted after installation. The installer:

1. copies immutable shader sources to
   `${XDG_DATA_HOME:-~/.local/share}/beautiful-ghostty`;
2. creates `~/.local/bin/beautiful-ghostty`;
3. adds one marked, optional include to the existing Ghostty config;
4. stores generated state separately under the Ghostty config directory;
5. selects Combined Cosmos with the `quality` profile on first install;
6. validates the complete Ghostty config and reloads running Ghostty processes.

The installer backs up the main config before changing it. It updates only the
block between `# BEGIN beautiful-ghostty` and `# END beautiful-ghostty`; existing
`custom-shader` settings and unrelated includes remain untouched. If the config
is a symlink, its resolved source is edited atomically without replacing the
symlink.

Ensure `~/.local/bin` is in `PATH`, then inspect the active state:

```bash
beautiful-ghostty status
```

### Custom locations

```bash
./install.sh --config /path/to/config.ghostty
./install.sh --install-dir /path/to/data --bin-dir /path/to/bin
./install.sh --no-reload
```

A command wrapper remembers a custom config path. Re-running the installer is
idempotent and preserves the current shader selections and GPU profile.

### Upgrade

```bash
cd beautiful-ghostty
git pull --ff-only
./install.sh
```

### Uninstall

```bash
./uninstall.sh
```

This removes only installer-owned files and the managed config block. Generated
state is retained so a reinstall restores the selection. Remove it too with:

```bash
./uninstall.sh --purge
```

## Clean ownership model

Source and generated files are intentionally separate:

```text
~/.local/share/beautiful-ghostty/       # installed, immutable sources
├── ghostty-shaders.sh
└── shaders/
    ├── background/cosmos.glsl
    ├── background/cosmos_wallpaper.glsl
    ├── combined/cosmos.glsl
    ├── combined/cosmos_wallpaper.glsl
    └── cursor/cosmic.glsl

~/.config/ghostty/beautiful-ghostty/   # generated machine-local state
├── active.ghostty
├── generated/*.glsl
└── state
```

`active.ghostty` references content-addressed generated shaders. Changing a
source or GPU profile changes the configured filename, ensuring that Ghostty
rebuilds its shader chain instead of retaining a cached shader at a fixed path.
Only durable sources are tracked in this repository.

## Commands

```bash
beautiful-ghostty status
beautiful-ghostty mode
beautiful-ghostty profile
beautiful-ghostty list background
beautiful-ghostty list cursor
beautiful-ghostty list combined
beautiful-ghostty list profiles
beautiful-ghostty validate
beautiful-ghostty reload
beautiful-ghostty --version
```

The backend is UI-independent. Launchers such as Fuzzel, Rofi, or a desktop menu
can invoke the same commands without modifying the manager.

## GPU profiles

```bash
beautiful-ghostty set-profile eco
beautiful-ghostty set-profile balanced
beautiful-ghostty set-profile quality
beautiful-ghostty set-profile ultra
```

| Profile | Intended use |
| --- | --- |
| `eco` | Lowest GPU usage |
| `balanced` | Daily use on lower-power hardware |
| `quality` | Recommended default |
| `ultra` | Maximum visual detail |

Profiles select compile-time bounds for star layers, meteors, black-hole
geodesics, FBM octaves, and cursor sparks.

## Shader modes

| Mode | Meaning |
| --- | --- |
| `separate` | Cursor and background stages are selected independently. |
| `combined` | One shader supplies the complete background and cursor effect. |
| `none` | No Beautiful Ghostty shader is enabled. |

### Separate shaders

```bash
beautiful-ghostty set background cosmos
beautiful-ghostty set cursor cosmic
```

Enabling either stage disables Combined mode while leaving the other separate
stage unchanged.

### Combined shader

```bash
beautiful-ghostty set combined cosmos
```

This disables both separate stages and uses the single combined source.

### Cosmos wallpaper

For Cosmos behind the terminal plus the existing foreground cursor:

```bash
beautiful-ghostty set combined cosmos_wallpaper
```

Or pair the standalone wallpaper with the same cursor in Separate mode:

```bash
beautiful-ghostty set background cosmos_wallpaper
beautiful-ghostty set cursor cosmic
```

This variant keeps the stars, nebula, galaxy, meteors, and black-hole disk, but
disables screen-space gravitational distortion of terminal geometry. It applies
no text detection, recoloring, contrast correction, or readability mask.
Instead, Ghostty's untouched terminal texture is composited over Cosmos using
its per-pixel alpha, and the cosmic cursor is drawn afterward.

`background-opacity` therefore directly controls wallpaper visibility:

- any value below `1` reveals Cosmos proportionally;
- `1` hides the Cosmos background completely while retaining the cursor effect;
- foreground pixels with alpha `1` keep their original terminal colors.

Choose how explicit cell backgrounds participate with Ghostty's own setting:

```ini
background-opacity = 0.70
background-opacity-cells = true
```

With `background-opacity-cells = true`, Visual, CursorLine, and other explicit
cell backgrounds are transparent too, so their final on-screen appearance
naturally blends with Cosmos. Set it to `false` when those cell backgrounds
should remain opaque.

### Disable a stage

```bash
beautiful-ghostty set cursor none
beautiful-ghostty set background none
beautiful-ghostty set combined none
```

`none` disables only the requested stage; it never restores another stage.

## Editing and tuning

Edit the source clone, then rerun `./install.sh` to copy the revised sources into
the installation. The manager regenerates the selected shader during the
upgrade. Do not edit files under the generated runtime directory.

Source files:

```text
shaders/background/cosmos.glsl
shaders/background/cosmos_wallpaper.glsl
shaders/combined/cosmos.glsl
shaders/combined/cosmos_wallpaper.glsl
shaders/cursor/cosmic.glsl
```

### Starfield

| Control | Effect |
| --- | --- |
| `SPACE_STAR_TRAVEL_SPEED` | Forward starflight speed |
| `SPACE_STAR_DENSITY` | Number of stars |
| `SPACE_STAR_BRIGHTNESS` | Overall star brightness |
| `SPACE_STAR_STREAK_CHANCE` | Fraction of stars receiving trails |
| `SPACE_STAR_STREAK_START` | Distance at which trails appear |
| `SPACE_STAR_STREAK_LENGTH_PX` | Trail length |
| `SPACE_STAR_STREAK_STRENGTH` | Trail brightness |
| `SPACE_STAR_TRAVEL_CENTER` | Center from which stars move outward |

Set `SPACE_STAR_TRAVEL_SPEED` to `0.0` to stop star movement and trails.

### Meteors

| Control | Effect |
| --- | --- |
| `METEOR_AMOUNT` | Probability of meteors appearing |
| `METEOR_SPEED` | Meteor travel speed |
| `METEOR_OPACITY` | Overall meteor visibility |
| `METEOR_CURVE_STRENGTH` | Trajectory variation |
| `NEAR_TRAIL_LENGTH` | Trail length for close meteors |
| `FAR_TRAIL_LENGTH` | Trail length for distant meteors |
| `TRAIL_GLOW` | Trail glow |
| `HEAD_GLOW` | Meteor-head glow |

Set `METEOR_AMOUNT` to `0.0` to disable meteors.

### Nebula

| Control | Effect |
| --- | --- |
| `NEBULA_STRENGTH` | Overall brightness |
| `NEBULA_POSITION` | Base screen position |
| `NEBULA_POSITION_DRIFT_AMPLITUDE` | Position movement range |
| `NEBULA_POSITION_DRIFT_SPEED` | Position movement speed |
| `NEBULA_TEXTURE_FLOW_SPEED` | Internal cloud movement |
| `NEBULA_ROTATION` | Orientation |
| `NEBULA_LARGE_WARP_STRENGTH` | Large cloud distortion |
| `NEBULA_SMALL_WARP_STRENGTH` | Fine cloud distortion |

### Galaxy

| Control | Effect |
| --- | --- |
| `GALAXY_POSITION` | Screen position |
| `GALAXY_DIAMETER` | Galaxy size |
| `GALAXY_BRIGHTNESS` | Overall brightness |
| `GALAXY_ROTATION` | Orientation |
| `GALAXY_SPIN_SPEED` | Spiral-arm rotation speed |
| `GALAXY_BREATHE_AMOUNT` | Expansion and contraction amount |
| `GALAXY_BREATHE_SPEED` | Expansion and contraction speed |
| `GALAXY_INTERNAL_DRIFT_SPEED` | Internal movement speed |

### Black hole

| Control | Effect |
| --- | --- |
| `BLACK_HOLE_RADIUS` | Black-hole size |
| `BLACK_HOLE_DRIFT_SPEED` | Movement speed |
| `BLACK_HOLE_TRAVEL_REACH` | Fraction of the permitted area traversed |
| `BLACK_HOLE_PULSE_AMOUNT` | Size-pulsing amount |
| `BLACK_HOLE_PULSE_SPEED` | Size-pulsing speed |
| `BLACK_HOLE_MOTION_MODE` | Movement path |
| `BLACK_HOLE_LOOK_MODE` | Accretion-disk appearance animation |
| `BH_EVOLVE_SECONDS` | Appearance-cycle duration |
| `BH_GLOBAL_DISK_BRIGHTNESS` | Accretion-disk brightness |
| `BH_GLOBAL_DISK_SIZE` | Accretion-disk size |

Movement modes include `BH_MOTION_ORGANIC`, `BH_MOTION_FULL_SWEEP`,
`BH_MOTION_ORBIT`, and `BH_MOTION_DIAGONAL_BOUNCE`. Appearance modes include
`BH_LOOK_FIXED`, `BH_LOOK_SHOWCASE`, `BH_LOOK_EVOLVE`, and `BH_LOOK_DUAL`.

### Cursor

| Control | Effect |
| --- | --- |
| `EFFECT_DURATION` | Duration of the cursor animation |
| `HEAD_GOLD_STRENGTH` | Destination glow brightness |
| `PHOTON_RING_STRENGTH` | Photon-ring brightness |
| `RIPPLE_STRENGTH` | Expanding ripple brightness |
| `ORBIT_STRENGTH` | Inclined orbit brightness |
| `TRAIL_CORE_STRENGTH` | Cursor trail brightness |
| `TRAIL_GLOW_STRENGTH` | Cursor trail glow |
| `SPARK_STRENGTH` | Spark brightness |

The photon ring, ripple, orbit, and nebula wake remain enabled at every profile.
The bounded spark loop scales from 0 to 6 sparks.

## Troubleshooting

```bash
beautiful-ghostty validate
beautiful-ghostty status
ghostty +show-config | grep '^custom-shader'
```

If no shader appears, confirm that Ghostty's effective config contains a path
under `beautiful-ghostty/generated/`. `ghostty +validate-config` checks config
syntax; shader compilation occurs when Ghostty creates or reloads a render
surface, so inspect Ghostty's runtime diagnostics for GLSL failures.

## License

Beautiful Ghostty is released under the MIT License.

The geodesic black-hole renderer contains MIT-licensed work adapted from
[`s0xDk/ghostty-blackhole`](https://github.com/s0xDk/ghostty-blackhole).
See [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
