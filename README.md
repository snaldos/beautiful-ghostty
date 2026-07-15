# Beautiful Ghostty

A cosmic Ghostty shader with perspective stars, radial meteors, a moving galaxy,
a geodesic black hole, and a matching cursor effect.

<p align="center">
  <a href="https://github.com/user-attachments/assets/71146e13-6d2b-40ab-b276-b58606345cbb">
    <img
      src="assets/demo.gif"
      alt="Beautiful Ghostty animated demo"
      width="100%"
    >
  </a>
</p>

<p align="center">
  <strong>
    Perspective starflight · radial meteors · animated galaxy · geodesic black hole · cosmic cursor
  </strong>
</p>

<p align="center">
  <a href="https://github.com/user-attachments/assets/71146e13-6d2b-40ab-b276-b58606345cbb">
    Watch the full one-minute demo
  </a>
</p>

## Install

Requires **Ghostty 1.2.0 or newer**, **Bash**, and Linux.

```bash
git clone https://github.com/snaldos/beautiful-ghostty.git
cd beautiful-ghostty
./install.sh
```

The repository may be cloned anywhere.

The installer:

- finds your Ghostty config;
- creates a timestamped `.bak` backup;
- removes active `custom-shader` settings from that config;
- adds the Beautiful Ghostty shader chain using absolute paths;
- enables the Combined Cosmos shader mode;
- selects the `quality` GPU profile;
- validates the config and reloads Ghostty.

For a custom config location:

```bash
./install.sh --config /path/to/config.ghostty
```

Rerun `./install.sh` after moving the repository.

## GPU profiles

```bash
./ghostty-shaders.sh set-profile eco
./ghostty-shaders.sh set-profile balanced
./ghostty-shaders.sh set-profile quality
./ghostty-shaders.sh set-profile ultra
```

`quality` is the default.

| Profile    | Intended use                      |
| ---------- | --------------------------------- |
| `eco`      | Lowest GPU usage                  |
| `balanced` | Daily use on lower-power hardware |
| `quality`  | Recommended default               |
| `ultra`    | Maximum visual detail             |

## Shader modes

The manager uses **Separate** and **Combined** instead of the ambiguous
“single” and “multi” labels:

| Mode       | Meaning |
| ---------- | ------- |
| `separate` | Cursor and background shaders are selected independently. Enabling either one disables the Combined shader while preserving the other separate stage. |
| `combined` | One source shader supplies both effects. Enabling it disables both separate stages. |
| `none`     | No shader effect is enabled. |

Show the active mode:

```bash
./ghostty-shaders.sh mode
```

### Separate shaders

```bash
./ghostty-shaders.sh set background cosmos
./ghostty-shaders.sh set cursor cosmic
```

Each command switches to Separate mode by disabling the Combined shader. The
other separate stage is left unchanged, so cursor and background can be used
alone or together.

### Combined shader

```bash
./ghostty-shaders.sh set combined cosmos
```

This replaces both separate stages and reports the complete resulting state.

### Disable a stage

```bash
./ghostty-shaders.sh set cursor none
./ghostty-shaders.sh set background none
./ghostty-shaders.sh set combined none
```

`none` disables only the requested stage. It does not disable, enable, or
restore any other stage. Use `status` to inspect every selection and the GPU
profile:

```bash
./ghostty-shaders.sh status
```

## Tuning

Edit the source shader, not the generated `custom_*.glsl` files.

For combined mode:

```text
shaders/combined/cosmos.glsl
```

For separate mode:

```text
shaders/background/cosmos.glsl
shaders/cursor/cosmic.glsl
```

### Starfield

| Control                       | Effect                                          |
| ----------------------------- | ----------------------------------------------- |
| `SPACE_STAR_TRAVEL_SPEED`     | Forward starflight speed                        |
| `SPACE_STAR_DENSITY`          | Number of stars                                 |
| `SPACE_STAR_BRIGHTNESS`       | Overall star brightness                         |
| `SPACE_STAR_STREAK_CHANCE`    | Fraction of stars that receive trails           |
| `SPACE_STAR_STREAK_START`     | How close a star must be before a trail appears |
| `SPACE_STAR_STREAK_LENGTH_PX` | Trail length                                    |
| `SPACE_STAR_STREAK_STRENGTH`  | Trail brightness                                |
| `SPACE_STAR_TRAVEL_CENTER`    | Center from which stars move outward            |

Set `SPACE_STAR_TRAVEL_SPEED` to `0.0` to stop star movement. Star trails also
disappear when the travel speed is zero.

### Meteors

| Control                 | Effect                           |
| ----------------------- | -------------------------------- |
| `METEOR_AMOUNT`         | Probability of meteors appearing |
| `METEOR_SPEED`          | Meteor travel speed              |
| `METEOR_OPACITY`        | Overall meteor visibility        |
| `METEOR_CURVE_STRENGTH` | Amount of trajectory variation   |
| `NEAR_TRAIL_LENGTH`     | Trail length for close meteors   |
| `FAR_TRAIL_LENGTH`      | Trail length for distant meteors |
| `TRAIL_GLOW`            | Meteor trail glow                |
| `HEAD_GLOW`             | Meteor head glow                 |

Set `METEOR_AMOUNT` to `0.0` to disable meteors.

### Nebula

| Control                           | Effect                                      |
| --------------------------------- | ------------------------------------------- |
| `NEBULA_STRENGTH`                 | Overall nebula brightness                   |
| `NEBULA_POSITION`                 | Base screen position                        |
| `NEBULA_POSITION_DRIFT_AMPLITUDE` | Distance travelled around the base position |
| `NEBULA_POSITION_DRIFT_SPEED`     | Position movement speed                     |
| `NEBULA_TEXTURE_FLOW_SPEED`       | Internal cloud movement speed               |
| `NEBULA_ROTATION`                 | Nebula orientation                          |
| `NEBULA_LARGE_WARP_STRENGTH`      | Large cloud distortion                      |
| `NEBULA_SMALL_WARP_STRENGTH`      | Fine cloud distortion                       |

Set `NEBULA_STRENGTH` to `0.0` to hide the nebula.

### Galaxy

| Control                            | Effect                                   |
| ---------------------------------- | ---------------------------------------- |
| `GALAXY_POSITION`                  | Screen position                          |
| `GALAXY_DIAMETER`                  | Galaxy size                              |
| `GALAXY_BRIGHTNESS`                | Overall brightness                       |
| `GALAXY_ROTATION`                  | Galaxy orientation                       |
| `GALAXY_SPIN_SPEED`                | Spiral-arm rotation speed                |
| `GALAXY_BREATHE_AMOUNT`            | Expansion and contraction amount         |
| `GALAXY_BREATHE_SPEED`             | Expansion and contraction speed          |
| `GALAXY_INTERNAL_DRIFT_SPEED`      | Internal stellar and dust movement speed |
| `GALAXY_INTERNAL_TANGENTIAL_DRIFT` | Sideways internal movement               |
| `GALAXY_INTERNAL_RADIAL_DRIFT`     | Inward and outward internal movement     |

Set `GALAXY_BREATHE_AMOUNT` to `0.0` to disable the breathing effect.

### Black hole

| Control                     | Effect                                               |
| --------------------------- | ---------------------------------------------------- |
| `BLACK_HOLE_RADIUS`         | Black-hole size                                      |
| `BLACK_HOLE_DRIFT_SPEED`    | Movement speed                                       |
| `BLACK_HOLE_TRAVEL_REACH`   | Fraction of the permitted area it may travel through |
| `BLACK_HOLE_PULSE_AMOUNT`   | Size-pulsing amount                                  |
| `BLACK_HOLE_PULSE_SPEED`    | Size-pulsing speed                                   |
| `BLACK_HOLE_MOTION_MODE`    | Movement path                                        |
| `BLACK_HOLE_LOOK_MODE`      | Accretion-disk appearance animation                  |
| `BH_EVOLVE_SECONDS`         | Time taken to cycle through evolving looks           |
| `BH_GLOBAL_DISK_BRIGHTNESS` | Accretion-disk brightness                            |
| `BH_GLOBAL_DISK_SIZE`       | Accretion-disk size                                  |

Available movement modes:

```glsl
#define BLACK_HOLE_MOTION_MODE BH_MOTION_ORGANIC
#define BLACK_HOLE_MOTION_MODE BH_MOTION_FULL_SWEEP
#define BLACK_HOLE_MOTION_MODE BH_MOTION_ORBIT
#define BLACK_HOLE_MOTION_MODE BH_MOTION_DIAGONAL_BOUNCE
```

Available appearance modes:

```glsl
#define BLACK_HOLE_LOOK_MODE BH_LOOK_FIXED
#define BLACK_HOLE_LOOK_MODE BH_LOOK_SHOWCASE
#define BLACK_HOLE_LOOK_MODE BH_LOOK_EVOLVE
#define BLACK_HOLE_LOOK_MODE BH_LOOK_DUAL
```

### Cursor

The cursor controls are near the bottom of:

```text
shaders/combined/cosmos.glsl
```

and inside:

```text
shaders/cursor/cosmic.glsl
```

| Control                | Effect                           |
| ---------------------- | -------------------------------- |
| `EFFECT_DURATION`      | Duration of the cursor animation |
| `HEAD_GOLD_STRENGTH`   | Destination glow brightness      |
| `PHOTON_RING_STRENGTH` | Photon-ring brightness           |
| `RIPPLE_STRENGTH`      | Expanding ripple brightness      |
| `ORBIT_STRENGTH`       | Inclined orbit brightness        |
| `TRAIL_CORE_STRENGTH`  | Cursor trail brightness          |
| `TRAIL_GLOW_STRENGTH`  | Cursor trail glow                |
| `SPARK_STRENGTH`       | Spark brightness                 |

The photon ring, ripple, orbit, and nebula wake remain enabled at every GPU
profile so the cursor keeps its defining appearance. The bounded spark loop
scales with the profile: `0`, `2`, `4`, or `6` sparks.

### Apply changes

After editing the combined source:

```bash
./ghostty-shaders.sh --no-reload set combined cosmos
./ghostty-shaders.sh reload
```

After editing the separate sources:

```bash
./ghostty-shaders.sh --no-reload set background cosmos
./ghostty-shaders.sh --no-reload set cursor cosmic
./ghostty-shaders.sh reload
```

## License

Beautiful Ghostty is released under the MIT License.

The geodesic black-hole renderer contains MIT-licensed work adapted from
[`s0xDk/ghostty-blackhole`](https://github.com/s0xDk/ghostty-blackhole).
See [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
