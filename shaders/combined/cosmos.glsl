// Beautiful Ghostty — combined Cosmos background and cursor
//
// Copyright (c) 2026 Arnaldo Lopes
// Released under the MIT License. See LICENSE.
//
// Geodesic black-hole portions are adapted from s0xDk/ghostty-blackhole,
// also under the MIT License. See THIRD_PARTY_NOTICES.md and
// LICENSES/ghostty-blackhole-MIT.txt.
//
// The starfield in this version is an independently written perspective
// flight renderer.
//
//
// One-pass transparent cosmic scene and galaxy-themed cursor for Ghostty.
//
// Background features:
//   - classic layered space-sparkle stars;
//   - a bounded nebula;
//   - a Milky-Way-style spiral galaxy with inter-arm stardust;
//   - bright arm-aligned stellar trails and star-forming complexes;
//   - perspective meteors aligned with the star flight field;
//   - a geodesic-traced Schwarzschild black hole;
//   - reserved areas measured in fractions, pixels, or terminal cells;
//   - named black-hole appearance and movement modes;
//   - compile-time GPU quality profiles;
//   - transparency-aware compositing.
//
// Cursor features:
//   - gold destination glow;
//   - photon ring, ripple, and inclined orbit;
//   - cyan/violet/gold comet trail;
//   - optional star-like sparks;
//   - no added effect while stationary.
//
// Ghostty:
//   custom-shader = /path/to/cosmos_geodesic_with_cosmic_cursor.glsl
//   custom-shader-animation = true
//
// Recommended cursor colors:
//   cursor-color = e0af68
//   cursor-text  = 1a1b26
//
// Uses: iChannel0, iResolution, iTime, cursor uniforms, mainImage

// =============================================================================
// GPU PERFORMANCE PROFILE
// =============================================================================
//
// ECO:      low power; removes secondary detail and shortens expensive loops.
// BALANCED: daily-use profile for lower heat and power.
// HIGH:     nearly complete appearance; recommended default.
// ULTRA:    full quality for screenshots and demonstrations.

#define GPU_ECO      0
#define GPU_BALANCED 1
#define GPU_HIGH     2
#define GPU_ULTRA    3

#ifndef GHOSTTY_GPU_PROFILE
    #define GHOSTTY_GPU_PROFILE GPU_HIGH
#endif

#define GPU_PROFILE GHOSTTY_GPU_PROFILE

#if GPU_PROFILE == GPU_ECO
    #define PERF_STAR_LAYERS              5
    #define PERF_STAR_GAIN                1.15
    #define PERF_STAR_STREAKS             0
    #define PERF_STAR_STREAK_CHANCE_GAIN  0.00
    #define PERF_METEOR_LAYERS            4
    #define PERF_METEOR_DENSITY_GAIN      4.50
    #define PERF_FBM_OCTAVES              3
    #define PERF_BH_STEPS                 24
    #define PERF_BH_WINDOW_CUTOFF         0.0120
    #define PERF_CHROMATIC_LENS           0
    #define PERF_FIVE_TAP_ALPHA           0
    #define PERF_DIRECTIONAL_LENS_STARS   0
    #define PERF_BH_SECOND_STREAK         0
    #define PERF_NEBULA_SMALL_WARP        0
    #define PERF_NEBULA_DETAIL            0
    #define PERF_REUSE_GALAXY_NOISE       1
    #define PERF_GALAXY_FILAMENTS         0
    #define PERF_STAR_FORMING_COMPLEXES   0
    #define PERF_SUPER_COMPLEXES          0
#elif GPU_PROFILE == GPU_BALANCED
    #define PERF_STAR_LAYERS              8
    #define PERF_STAR_GAIN                1.08
    #define PERF_STAR_STREAKS             1
    #define PERF_STAR_STREAK_CHANCE_GAIN  0.65
    #define PERF_METEOR_LAYERS            8
    #define PERF_METEOR_DENSITY_GAIN      2.25
    #define PERF_FBM_OCTAVES              4
    #define PERF_BH_STEPS                 32
    #define PERF_BH_WINDOW_CUTOFF         0.0050
    #define PERF_CHROMATIC_LENS           0
    #define PERF_FIVE_TAP_ALPHA           0
    #define PERF_DIRECTIONAL_LENS_STARS   1
    #define PERF_BH_SECOND_STREAK         1
    #define PERF_NEBULA_SMALL_WARP        1
    #define PERF_NEBULA_DETAIL            1
    #define PERF_REUSE_GALAXY_NOISE       1
    #define PERF_GALAXY_FILAMENTS         0
    #define PERF_STAR_FORMING_COMPLEXES   1
    #define PERF_SUPER_COMPLEXES          0
#elif GPU_PROFILE == GPU_HIGH
    #define PERF_STAR_LAYERS              11
    #define PERF_STAR_GAIN                1.00
    #define PERF_STAR_STREAKS             1
    #define PERF_STAR_STREAK_CHANCE_GAIN  1.00
    #define PERF_METEOR_LAYERS            12
    #define PERF_METEOR_DENSITY_GAIN      1.50
    #define PERF_FBM_OCTAVES              5
    #define PERF_BH_STEPS                 40
    #define PERF_BH_WINDOW_CUTOFF         0.0015
    #define PERF_CHROMATIC_LENS           1
    #define PERF_FIVE_TAP_ALPHA           1
    #define PERF_DIRECTIONAL_LENS_STARS   1
    #define PERF_BH_SECOND_STREAK         1
    #define PERF_NEBULA_SMALL_WARP        1
    #define PERF_NEBULA_DETAIL            1
    #define PERF_REUSE_GALAXY_NOISE       0
    #define PERF_GALAXY_FILAMENTS         1
    #define PERF_STAR_FORMING_COMPLEXES   1
    #define PERF_SUPER_COMPLEXES          1
#else
    #define PERF_STAR_LAYERS              11
    #define PERF_STAR_GAIN                1.00
    #define PERF_STAR_STREAKS             1
    #define PERF_STAR_STREAK_CHANCE_GAIN  1.15
    #define PERF_METEOR_LAYERS            18
    #define PERF_METEOR_DENSITY_GAIN      1.00
    #define PERF_FBM_OCTAVES              5
    #define PERF_BH_STEPS                 48
    #define PERF_BH_WINDOW_CUTOFF         0.00005
    #define PERF_CHROMATIC_LENS           1
    #define PERF_FIVE_TAP_ALPHA           1
    #define PERF_DIRECTIONAL_LENS_STARS   1
    #define PERF_BH_SECOND_STREAK         1
    #define PERF_NEBULA_SMALL_WARP        1
    #define PERF_NEBULA_DETAIL            1
    #define PERF_REUSE_GALAXY_NOISE       0
    #define PERF_GALAXY_FILAMENTS         1
    #define PERF_STAR_FORMING_COMPLEXES   1
    #define PERF_SUPER_COMPLEXES          1
#endif

// =============================================================================
// MASTER / TRANSPARENCY
// =============================================================================

#define SPACE_ALPHA_BOOST 0.14
#define BLACK_HOLE_SHADOW_ALPHA_BOOST 0.045
#define BACKGROUND_DARKEN 1.00
#define BACKGROUND_THRESHOLD 0.30
#define TEXT_PROTECTION 0.50
#define SPACE_EXPOSURE 1.00
#define SPACE_BRIGHTNESS 1.00
#define SPACE_SATURATION 1.00
#define VIGNETTE_STRENGTH 0.18

// =============================================================================
// STARFIELD — PERSPECTIVE FLIGHT FIELD
// =============================================================================
//
// Independently written perspective starfield. Stars occupy repeating depth
// slices and move radially away from the focal point as they approach the
// viewer. Each layer samples neighbouring cells so stars remain circular when
// they cross cell boundaries.

#define SPACE_STAR_LAYERS PERF_STAR_LAYERS
#define SPACE_STAR_GRID_DENSITY 20.0
#define SPACE_STAR_DENSITY 0.050
#define SPACE_STAR_TRAVEL_SPEED 0.085
#define SPACE_STAR_TRAVEL_CENTER vec2(0.50, 0.50)
#define SPACE_STAR_FAR_DEPTH 4.80
#define SPACE_STAR_NEAR_DEPTH 0.30
#define SPACE_STAR_WRAP_FADE_IN 0.08
#define SPACE_STAR_WRAP_FADE_OUT 0.90
#define SPACE_STAR_BRIGHTNESS 0.96
#define SPACE_STAR_SIZE_FAR_PX 0.40
#define SPACE_STAR_SIZE_NEAR_PX 1.55
#define SPACE_STAR_SIZE_VARIATION 0.72
#define SPACE_STAR_CORE_SHARPNESS 2.65
#define SPACE_STAR_BIG_THRESHOLD 0.985
#define SPACE_STAR_BIG_SIZE_GAIN 1.75
#define SPACE_STAR_HALO_RADIUS 3.80
#define SPACE_STAR_HALO_STRENGTH 0.20

// Only a subset of stars receive motion trails. Set to 0 to disable them.
#define SPACE_STAR_STREAKS_ENABLED 1
#define SPACE_STAR_STREAK_CHANCE 0.080
#define SPACE_STAR_STREAK_BIG_STAR_BONUS 0.12
#define SPACE_STAR_STREAK_SPEED_REFERENCE 0.085
#define SPACE_STAR_STREAK_SPEED_POWER 1.00
#define SPACE_STAR_STREAK_START 0.48
#define SPACE_STAR_STREAK_LENGTH_PX 18.0
#define SPACE_STAR_STREAK_WIDTH_PX 0.62
#define SPACE_STAR_STREAK_STRENGTH 0.42
#define SPACE_STAR_TWINKLE_STRENGTH 0.13
#define SPACE_STAR_TWINKLE_SPEED_MIN 0.35
#define SPACE_STAR_TWINKLE_SPEED_MAX 1.40
#define SPACE_STAR_WHITE_CUTOFF 0.76
#define SPACE_STAR_CYAN_CUTOFF 0.87
#define SPACE_STAR_YELLOW_CUTOFF 0.95
#define SPACE_STAR_BLUE   vec3(0.200, 0.251, 0.765)
#define SPACE_STAR_CYAN   vec3(0.459, 0.980, 0.996)
#define SPACE_STAR_WHITE  vec3(1.000, 1.000, 1.000)
#define SPACE_STAR_YELLOW vec3(0.984, 0.961, 0.173)
#define SPACE_STAR_RED    vec3(0.969, 0.008, 0.078)
#define SPACE_STAR_COLOR_STRENGTH 0.68

// =============================================================================
// NEBULA — POSITION, SHAPE, AND BOUNDED MOTION
// =============================================================================

#define NEBULA_STRENGTH 0.26
#define NEBULA_POSITION vec2(0.68, 0.38)
#define NEBULA_POSITION_DRIFT_AMPLITUDE vec2(0.10, 0.08)
#define NEBULA_POSITION_DRIFT_SPEED 0.055
#define NEBULA_POSITION_SECONDARY_SPEED 0.031
#define NEBULA_POSITION_MIN vec2(0.08, 0.08)
#define NEBULA_POSITION_MAX vec2(0.92, 0.90)
#define NEBULA_TEXTURE_FLOW_AMPLITUDE vec2(0.18, 0.10)
#define NEBULA_TEXTURE_FLOW_SPEED 0.045
#define NEBULA_TEXTURE_FLOW_SECONDARY_SPEED 0.027
#define NEBULA_ROTATION -0.42
#define NEBULA_LARGE_WARP_SCALE 0.80
#define NEBULA_SMALL_WARP_SCALE 2.10
#define NEBULA_LARGE_WARP_STRENGTH 0.15
#define NEBULA_SMALL_WARP_STRENGTH 0.05
#define NEBULA_BAND_SHARPNESS 2.60
#define NEBULA_CLOUD_SCALE 1.25
#define NEBULA_DETAIL_SCALE 3.10
#define NEBULA_CLOUD_THRESHOLD_LOW 0.33
#define NEBULA_CLOUD_THRESHOLD_HIGH 0.66
#define NEBULA_DETAIL_DENSITY_MIN 0.88
#define NEBULA_DETAIL_DENSITY_MAX 1.32
#define NEBULA_HAZE_STRENGTH 0.28
#define NEBULA_HAZE_SHARPNESS 1.45
#define NEBULA_COLOR_MIX_LOW 0.34
#define NEBULA_COLOR_MIX_HIGH 0.74
#define NEBULA_DETAIL_COLOR_LOW 0.44
#define NEBULA_DETAIL_COLOR_HIGH 0.88
#define NEBULA_COLOR_A vec3(0.10, 0.14, 0.34)
#define NEBULA_COLOR_B vec3(0.28, 0.14, 0.42)
#define NEBULA_COLOR_C vec3(0.08, 0.30, 0.42)
#define NEBULA_HAZE_COLOR vec3(0.20, 0.18, 0.42)

// =============================================================================
// GALAXY — MILKY-WAY-STYLE CONTROLS
// =============================================================================

#define GALAXY_POSITION vec2(0.86, 0.78)
#define GALAXY_DIAMETER 0.50
#define GALAXY_BRIGHTNESS 0.26
#define GALAXY_DENSITY 2.35
#define GALAXY_ROTATION -0.18
#define GALAXY_SPIN_SPEED 0.042
#define GALAXY_FLATTENING 1.30
#define GALAXY_BREATHE_AMOUNT 0.035
#define GALAXY_BREATHE_SPEED 0.18
#define GALAXY_BREATHE_BRIGHTNESS 0.035
#define GALAXY_INTERNAL_TANGENTIAL_DRIFT 0.012
#define GALAXY_INTERNAL_RADIAL_DRIFT 0.008
#define GALAXY_INTERNAL_DRIFT_SPEED 0.23
#define GALAXY_ARM_COUNT 2.0
#define GALAXY_ARM_TIGHTNESS 5.8
#define GALAXY_ARM_CORE_WIDTH 0.40
#define GALAXY_ARM_SOFT_WIDTH 0.64
#define GALAXY_ARM_SOFT_STRENGTH 0.70
#define GALAXY_ARM_CORE_SHARPNESS 2.15
#define GALAXY_ARM_BRIGHTNESS 0.42
#define GALAXY_ARM_RADIAL_FALLOFF 1.80
#define GALAXY_ARM_OUTER_FADE_START 1.05
#define GALAXY_ARM_OUTER_FADE_END 1.48
#define GALAXY_ARM_INNER_SOFTEN 0.00
#define GALAXY_HAZE_BRIGHTNESS 0.075
#define GALAXY_HAZE_FALLOFF 0.95
#define GALAXY_DIFFUSE_DISK_BRIGHTNESS 0.10
#define GALAXY_DIFFUSE_DISK_FALLOFF 1.55
#define GALAXY_CORE_SIZE 15.0
#define GALAXY_CORE_BRIGHTNESS 1.10
#define GALAXY_CORE_NOISE_MIX_LOW 0.85
#define GALAXY_CORE_NOISE_MIX_HIGH 1.15

// Inter-arm stardust.
#define GALAXY_INTERARM_STARDUST_BRIGHTNESS 0.28
#define GALAXY_INTERARM_SEPARATION_POWER 1.65
#define GALAXY_INTERARM_CLOUD_CONTRAST 1.35
#define GALAXY_INTERARM_INNER_START 0.10
#define GALAXY_INTERARM_INNER_END 0.28
#define GALAXY_INTERARM_OUTER_START 0.84
#define GALAXY_INTERARM_OUTER_END 1.34
#define GALAXY_STARDUST_NOISE_SCALE 11.0
#define GALAXY_STARDUST_DETAIL_SCALE 27.0
#define GALAXY_STARDUST_NOISE_LOW 0.34
#define GALAXY_STARDUST_NOISE_HIGH 0.76
#define GALAXY_STARDUST_CLOUD_MIN 0.42
#define GALAXY_STARDUST_CLOUD_MAX 1.18
#define GALAXY_INTERARM_FILAMENT_STRENGTH 0.46
#define GALAXY_INTERARM_FILAMENT_SCALE 38.0
#define GALAXY_INTERARM_FILAMENT_THRESHOLD_LOW 0.42
#define GALAXY_INTERARM_FILAMENT_THRESHOLD_HIGH 0.73
#define GALAXY_STARDUST_SPARKLE_STRENGTH 0.34
#define GALAXY_STARDUST_SPARKLE_DENSITY 0.070
#define GALAXY_STARDUST_SPARKLE_GRID 118.0
#define GALAXY_STARDUST_SPARKLE_SIZE 150.0
#define GALAXY_STARDUST_SPARKLE_RANDOM_MIN 0.35
#define GALAXY_STARDUST_SPARKLE_RANDOM_MAX 1.00
#define GALAXY_STARDUST_OUTER_COLOR vec3(0.56, 0.67, 1.00)
#define GALAXY_STARDUST_INNER_COLOR vec3(1.00, 0.84, 0.56)
#define GALAXY_STARDUST_WARMING_SIZE 3.8

// Stellar trails and star-forming complexes along the arms.
#define GALAXY_ARM_STARDUST_BRIGHTNESS 0.18
#define GALAXY_ARM_STARDUST_NOISE_SCALE 18.0
#define GALAXY_ARM_STARDUST_DETAIL_SCALE 43.0
#define GALAXY_ARM_STARDUST_CONTRAST 1.45
#define GALAXY_ARM_STARDUST_CORE_BIAS 1.35
#define GALAXY_ARM_STAR_TRAIL_STRENGTH 0.54
#define GALAXY_ARM_STAR_TRAIL_DENSITY 0.125
#define GALAXY_ARM_STAR_TRAIL_GRID 132.0
#define GALAXY_ARM_STAR_TRAIL_SIZE 185.0
#define GALAXY_ARM_STAR_TRAIL_ARM_POWER 1.32
#define GALAXY_ARM_STAR_TRAIL_INNER_START 0.12
#define GALAXY_ARM_STAR_TRAIL_INNER_END 0.24
#define GALAXY_ARM_STAR_TRAIL_OUTER_START 0.88
#define GALAXY_ARM_STAR_TRAIL_OUTER_END 1.38
#define GALAXY_ARM_BRIGHT_KNOT_THRESHOLD 0.976
#define GALAXY_ARM_BRIGHT_KNOT_STRENGTH 0.58
#define GALAXY_ARM_BRIGHT_KNOT_SIZE 52.0
#define GALAXY_ARM_STAR_FORMING_STRENGTH 0.76
#define GALAXY_ARM_STAR_FORMING_DENSITY 0.082
#define GALAXY_ARM_STAR_FORMING_GRID 56.0
#define GALAXY_ARM_STAR_FORMING_CORE_SIZE 118.0
#define GALAXY_ARM_STAR_FORMING_HALO_SIZE 17.0
#define GALAXY_ARM_STAR_FORMING_HALO_STRENGTH 0.58
#define GALAXY_ARM_STAR_FORMING_ARM_POWER 1.16
#define GALAXY_ARM_STAR_FORMING_RANDOM_MIN 0.56
#define GALAXY_ARM_STAR_FORMING_RANDOM_MAX 1.28
#define GALAXY_ARM_STAR_FORMING_TWINKLE 0.08
#define GALAXY_ARM_STAR_FORMING_TWINKLE_SPEED 0.72
#define GALAXY_ARM_SUPER_COMPLEX_THRESHOLD 0.970
#define GALAXY_ARM_SUPER_COMPLEX_STRENGTH 0.70
#define GALAXY_ARM_SUPER_COMPLEX_SIZE 7.5
#define GALAXY_ARM_STAR_OUTER_COLOR vec3(0.66, 0.78, 1.00)
#define GALAXY_ARM_STAR_INNER_COLOR vec3(1.00, 0.86, 0.58)
#define GALAXY_ARM_STAR_WARMING_SIZE 4.3
#define GALAXY_ARM_FORMING_OUTER_COLOR vec3(0.70, 0.86, 1.00)
#define GALAXY_ARM_FORMING_INNER_COLOR vec3(1.00, 0.90, 0.67)
#define GALAXY_ARM_FORMING_WARMING_SIZE 4.8

// Warm center.
#define GALAXY_BULGE_SIZE 5.6
#define GALAXY_BULGE_BRIGHTNESS 0.50
#define GALAXY_BULGE_COLOR vec3(1.00, 0.72, 0.35)
#define GALAXY_NUCLEUS_SIZE 42.0
#define GALAXY_NUCLEUS_BRIGHTNESS 1.25
#define GALAXY_NUCLEUS_COLOR vec3(1.00, 0.94, 0.66)
#define GALAXY_CORE_HALO_SIZE 2.2
#define GALAXY_CORE_HALO_BRIGHTNESS 0.16
#define GALAXY_CORE_HALO_COLOR vec3(1.00, 0.66, 0.30)

// Dust lanes and structure.
#define GALAXY_DUST_STRENGTH 0.34
#define GALAXY_DUST_POWER 2.6
#define GALAXY_DUST_PHASE_OFFSET 2.04203522483
#define GALAXY_DUST_INNER_START 0.16
#define GALAXY_DUST_INNER_END 0.98
#define GALAXY_DUST_OUTER_START 0.78
#define GALAXY_DUST_OUTER_END 1.35
#define GALAXY_CLUMPINESS 0.55
#define GALAXY_DETAIL_SCALE 7.0
#define GALAXY_FINE_DETAIL_MULTIPLIER 2.4
#define GALAXY_DETAIL_TIME_X 0.7
#define GALAXY_DETAIL_TIME_Y -0.4
#define GALAXY_STAR_CLUSTER_STRENGTH 0.28
#define GALAXY_CLUSTER_GRID_SCALE 70.0
#define GALAXY_CLUSTER_THRESHOLD_SCALE 0.025
#define GALAXY_CLUSTER_THRESHOLD_MAX 0.18
#define GALAXY_CLUSTER_SIZE 95.0
#define GALAXY_CLUSTER_ARM_BIAS 0.35
#define GALAXY_OUTER_COLOR vec3(0.42, 0.52, 0.95)
#define GALAXY_MID_COLOR   vec3(0.68, 0.58, 0.92)
#define GALAXY_CORE_COLOR  vec3(1.00, 0.90, 0.74)

// =============================================================================
// METEORS
// =============================================================================

#define METEOR_LAYERS PERF_METEOR_LAYERS
#define METEOR_AMOUNT 0.0003
#define METEOR_OPACITY 0.62
#define MAX_METEOR_BRIGHTNESS 0.92
#define METEOR_SPEED 0.11
#define METEOR_GRID_DENSITY 8.5
#define METEOR_FAR_DEPTH 4.20
#define METEOR_NEAR_DEPTH 0.42
#define METEOR_WRAP_FADE_IN 0.06
#define METEOR_WRAP_FADE_OUT 0.94
#define METEOR_LAYER_SCALE_NEAR 2.1
#define METEOR_LAYER_SCALE_FAR 7.8
#define NEAR_TRAIL_LENGTH 86.0
#define FAR_TRAIL_LENGTH 18.0
#define NEAR_TRAIL_WIDTH 1.30
#define FAR_TRAIL_WIDTH 0.52
#define LENGTH_VARIATION 0.65
#define WIDTH_VARIATION 0.42
#define METEOR_CURVE_STRENGTH 0.16
#define METEOR_GUST_STRENGTH 0.022
#define METEOR_GUST_SPEED 0.32
#define TRAIL_GLOW 0.58
#define HEAD_GLOW 0.82
#define DISTANCE_BRIGHTNESS 0.40
#define METEOR_RANDOM_BRIGHTNESS_MIN 0.48
#define METEOR_RANDOM_BRIGHTNESS_MAX 1.00
#define METEOR_FLICKER_MIN 0.82
#define METEOR_FLICKER_MAX 1.12
#define METEOR_FLICKER_SPEED 8.0
#define TRAIL_COLOR vec3(0.66, 0.80, 1.00)
#define HEAD_COLOR vec3(1.00, 0.76, 0.46)

// =============================================================================
// BLACK-HOLE PLACEMENT / RESERVED AREA / ANIMATION
// =============================================================================

#define BH_TRAVEL_LOCAL 0
#define BH_TRAVEL_BOUNDS 1
#define BLACK_HOLE_TRAVEL_MODE BH_TRAVEL_BOUNDS

#define BH_MOTION_ORGANIC 0
#define BH_MOTION_FULL_SWEEP 1
#define BH_MOTION_ORBIT 2
#define BH_MOTION_DIAGONAL_BOUNCE 3
#define BLACK_HOLE_MOTION_MODE BH_MOTION_ORGANIC

#define BLACK_HOLE_BASE_POSITION vec2(0.72, 0.23)
#define BLACK_HOLE_DRIFT vec2(0.045, 0.035)
#define BLACK_HOLE_TRAVEL_MIN vec2(0.00, 0.04)
#define BLACK_HOLE_TRAVEL_MAX vec2(0.98, 0.94)

#define BH_RESERVE_FRACTION 0
#define BH_RESERVE_PIXELS 1
#define BH_RESERVE_CELLS 2
#define BLACK_HOLE_RESERVE_UNITS BH_RESERVE_CELLS
#define BLACK_HOLE_TEXT_CELL_SIZE_PX vec2(9.0, 18.0)
#define BLACK_HOLE_RESERVED_LEFT 150.0
#define BLACK_HOLE_RESERVED_RIGHT 0.0
#define BLACK_HOLE_RESERVED_TOP 0.0
#define BLACK_HOLE_RESERVED_BOTTOM 0.0
#define BLACK_HOLE_RESERVED_AREA_ACCESS 0.00

#define BLACK_HOLE_TRAVEL_REACH 1.00
#define BLACK_HOLE_KEEP_DISK_ON_SCREEN 1
#define BLACK_HOLE_TRAVEL_AXIS_SCALE vec2(1.00, 1.00)
#define BLACK_HOLE_DRIFT_SPEED 0.11
#define BLACK_HOLE_PRIMARY_WANDER_WEIGHT 0.72
#define BLACK_HOLE_SECONDARY_WANDER_WEIGHT 0.28
#define BLACK_HOLE_SWEEP_X_RATE 0.63
#define BLACK_HOLE_SWEEP_Y_RATE 0.41
#define BLACK_HOLE_SWEEP_Y_PHASE 0.27
#define BLACK_HOLE_ORBIT_X_FREQUENCY 0.74
#define BLACK_HOLE_ORBIT_Y_FREQUENCY 0.53
#define BLACK_HOLE_ORBIT_PHASE 1.10
#define BLACK_HOLE_RADIUS 0.020
#define BLACK_HOLE_PULSE_AMOUNT 0.42
#define BLACK_HOLE_PULSE_SPEED 0.34
#define BLACK_HOLE_PULSE_SECONDARY_MIX 0.35
#define BLACK_HOLE_PULSE_TERTIARY_MIX 0.18
#define BLACK_HOLE_PULSE_MIN_SCALE 0.30
#define BLACK_HOLE_PULSE_MAX_SCALE 1.68
#define BLACK_HOLE_LENS_MIX 1.00
#define BLACK_HOLE_LENS_DEPTH 13.0
#define BLACK_HOLE_WORK_AREA 0.00
#define BLACK_HOLE_CLAMP_MARGIN 0.02
#define BLACK_HOLE_MAX_CLAMP_EXTENT 0.34
#define N_STEPS PERF_BH_STEPS

// =============================================================================
// GEODESIC BLACK-HOLE DISK
// =============================================================================

#define BH_DISK_INNER 1.80
#define BH_DISK_OUTER 8.00
#define BH_DISK_INCLINATION 1.50
#define BH_DISK_ROLL 0.35
#define BH_DISK_GAIN 2.20
#define BH_DISK_OPACITY 0.90
#define BH_DISK_TEMPERATURE 5500.0
#define BH_DOPPLER_MIX 0.60
#define BH_DISK_BEAM 2.50
#define BH_DISK_SPEED 5.00
#define BH_DISK_WIND 7.00
#define BH_DISK_CONTRAST 1.60
#define BH_EXPOSURE 1.40
#define BH_GLOBAL_DISK_SIZE 1.00
#define BH_GLOBAL_DISK_BRIGHTNESS 1.00
#define BH_GLOBAL_DISK_OPACITY 1.00
#define BH_GLOBAL_TEMPERATURE 1.00
#define BH_GLOBAL_DOPPLER 1.00
#define BH_GLOBAL_BEAM 1.00
#define BH_GLOBAL_DISK_SPEED 1.00
#define BH_GLOBAL_DISK_WIND 1.00
#define BH_GLOBAL_DISK_CONTRAST 1.00
#define BH_GLOBAL_EXPOSURE 1.00
#define BH_GLOBAL_INCLINATION_OFFSET 0.00
#define BH_GLOBAL_ROLL_OFFSET 0.00
#define BH_DILATION_MIN 0.20
#define BH_LENSED_STAR_GAIN 0.035
#define BH_DIRECTIONAL_STARS_WINDOW_SCALE 1.00

// Appearance modes.
#define BH_LOOK_FIXED 0
#define BH_LOOK_SHOWCASE 1
#define BH_LOOK_EVOLVE 2
#define BH_LOOK_DUAL 3
#define BLACK_HOLE_LOOK_MODE BH_LOOK_EVOLVE
#define BH_SHOWCASE_SECONDS 42.0
#define BH_SHOWCASE_CROSSFADE 0.18
#define BH_EVOLVE_SECONDS 150.0
#define BH_EVOLVE_EASE 1.00
#define BH_PRESET_INFERNO 0
#define BH_PRESET_GARGANTUA 1
#define BH_PRESET_M87 2
#define BH_PRESET_EMBER 3
#define BH_PRESET_QUASAR 4
#define BH_PRESET_BLAZAR 5
#define BH_PRESET_PURE_LENS 6
#define BH_PRESET_INFERNO_RETURN 7
#define BH_DUAL_PRESET_A BH_PRESET_INFERNO
#define BH_DUAL_PRESET_B BH_PRESET_QUASAR
#define BH_DUAL_SECONDS 34.0
#define BH_INTENSITY_MIN 0.45
#define BH_INTENSITY_MAX 1.00
#define BH_INTENSITY_SPEED 0.070

// =============================================================================
// INTERNAL CONSTANTS / HELPERS
// =============================================================================

#define PI 3.14159265359
#define TAU 6.28318530718
#define B_CRIT 2.5980762

float luminance(vec3 color) {
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

float hash12(vec2 point) {
    vec3 p3 = fract(vec3(point.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float hash13(vec3 point) {
    point = fract(point * 0.1031);
    point += dot(point, point.yzx + 33.33);
    return fract((point.x + point.y) * point.z);
}

vec2 hash22(vec2 point) {
    float value = hash12(point);
    return vec2(value, hash12(point + value + 17.17));
}

vec2 hash23(vec3 point) {
    return vec2(
        hash13(point + vec3(17.17, 43.71, 11.13)),
        hash13(point + vec3(83.91, 19.19, 61.73))
    );
}

float hash21(vec2 point) {
    point = fract(point * vec2(234.34, 435.345));
    point += dot(point, point + 34.23);
    return fract(point.x * point.y);
}

vec2 rotate2D(vec2 point, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return vec2(c * point.x - s * point.y, s * point.x + c * point.y);
}

vec2 mirrorUV(vec2 point) {
    return 1.0 - abs(1.0 - mod(point, 2.0));
}

vec2 lissa(float timeValue) {
    return vec2(
        0.75 * sin(timeValue * 0.37) + 0.25 * sin(timeValue * 0.83 + 1.0),
        0.70 * sin(timeValue * 0.54 + 2.1) + 0.30 * sin(timeValue * 1.07)
    );
}

float triangleWave(float phase) {
    return 1.0 - 4.0 * abs(fract(phase) - 0.5);
}

vec4 blackHoleReservedUv(vec2 resolution) {
    vec4 reserved = vec4(
        BLACK_HOLE_RESERVED_LEFT,
        BLACK_HOLE_RESERVED_TOP,
        BLACK_HOLE_RESERVED_RIGHT,
        BLACK_HOLE_RESERVED_BOTTOM
    );

    if (BLACK_HOLE_RESERVE_UNITS == BH_RESERVE_PIXELS) {
        reserved /= vec4(resolution.x, resolution.y, resolution.x, resolution.y);
    } else if (BLACK_HOLE_RESERVE_UNITS == BH_RESERVE_CELLS) {
        reserved *= vec4(
            BLACK_HOLE_TEXT_CELL_SIZE_PX.x,
            BLACK_HOLE_TEXT_CELL_SIZE_PX.y,
            BLACK_HOLE_TEXT_CELL_SIZE_PX.x,
            BLACK_HOLE_TEXT_CELL_SIZE_PX.y
        );
        reserved /= vec4(resolution.x, resolution.y, resolution.x, resolution.y);
    }

    reserved = clamp(reserved, 0.0, 1.0);
    return reserved * (1.0 - clamp(BLACK_HOLE_RESERVED_AREA_ACCESS, 0.0, 1.0));
}

vec2 blackHoleMotionVector(float motionTime) {
    vec2 organicPrimary = lissa(motionTime);
    vec2 organicSecondary = vec2(
        sin(motionTime * 0.41 + 3.3),
        sin(motionTime * 1.27 + 0.4)
    );

    float totalWeight = max(
        BLACK_HOLE_PRIMARY_WANDER_WEIGHT + BLACK_HOLE_SECONDARY_WANDER_WEIGHT,
        0.0001
    );

    vec2 motion = (
        organicPrimary * BLACK_HOLE_PRIMARY_WANDER_WEIGHT
        + organicSecondary * BLACK_HOLE_SECONDARY_WANDER_WEIGHT
    ) / totalWeight;

    if (BLACK_HOLE_MOTION_MODE == BH_MOTION_FULL_SWEEP) {
        motion = vec2(
            triangleWave(motionTime * BLACK_HOLE_SWEEP_X_RATE),
            triangleWave(motionTime * BLACK_HOLE_SWEEP_Y_RATE + BLACK_HOLE_SWEEP_Y_PHASE)
        );
    } else if (BLACK_HOLE_MOTION_MODE == BH_MOTION_ORBIT) {
        motion = vec2(
            cos(motionTime * BLACK_HOLE_ORBIT_X_FREQUENCY),
            sin(motionTime * BLACK_HOLE_ORBIT_Y_FREQUENCY + BLACK_HOLE_ORBIT_PHASE)
        );
    } else if (BLACK_HOLE_MOTION_MODE == BH_MOTION_DIAGONAL_BOUNCE) {
        float diagonal = triangleWave(motionTime * BLACK_HOLE_SWEEP_X_RATE);
        motion = vec2(
            diagonal,
            triangleWave(
                motionTime * BLACK_HOLE_SWEEP_Y_RATE
                + BLACK_HOLE_SWEEP_Y_PHASE
                + diagonal * 0.13
            )
        );
    }

    return clamp(
        motion * BLACK_HOLE_TRAVEL_AXIS_SCALE,
        vec2(-1.0),
        vec2(1.0)
    );
}

float valueNoise(vec2 point) {
    vec2 cell = floor(point);
    vec2 local = fract(point);
    local = local * local * (3.0 - 2.0 * local);

    float a = hash12(cell + vec2(0.0, 0.0));
    float b = hash12(cell + vec2(1.0, 0.0));
    float c = hash12(cell + vec2(0.0, 1.0));
    float d = hash12(cell + vec2(1.0, 1.0));

    return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}

float fbm(vec2 point) {
    float result = 0.0;
    float amplitude = 0.50;

    for (int octave = 0; octave < PERF_FBM_OCTAVES; octave++) {
        result += amplitude * valueNoise(point);
        point = rotate2D(point * 2.03, 0.37) + vec2(7.1, 13.7);
        amplitude *= 0.50;
    }

    return result;
}

float vnoiseWrapY(vec2 point, float periodY) {
    vec2 cell = floor(point);
    vec2 local = fract(point);
    local = local * local * (3.0 - 2.0 * local);

    float y0 = mod(cell.y, periodY);
    float y1 = mod(cell.y + 1.0, periodY);

    return mix(
        mix(hash21(vec2(cell.x, y0)), hash21(vec2(cell.x + 1.0, y0)), local.x),
        mix(hash21(vec2(cell.x, y1)), hash21(vec2(cell.x + 1.0, y1)), local.x),
        local.y
    );
}

vec3 blackbody(float temperature) {
    float t = clamp(temperature, 1500.0, 40000.0) / 100.0;
    float r = t <= 66.0 ? 1.0 : clamp(1.292936 * pow(t - 60.0, -0.1332047), 0.0, 1.0);
    float g = t <= 66.0
        ? clamp(0.3900816 * log(t) - 0.6318414, 0.0, 1.0)
        : clamp(1.1298909 * pow(t - 60.0, -0.0755148), 0.0, 1.0);
    float b = t >= 66.0
        ? 1.0
        : (t <= 19.0 ? 0.0 : clamp(0.5432068 * log(t - 10.0) - 1.1962540, 0.0, 1.0));
    return vec3(r, g, b);
}

vec3 applySaturation(vec3 color, float saturation) {
    float grey = luminance(color);
    return mix(vec3(grey), color, saturation);
}

float backgroundMaskFromTerminal(vec4 terminalColor) {
    float terminalLuma = luminance(terminalColor.rgb);
    float lumaMask = 1.0 - smoothstep(
        BACKGROUND_THRESHOLD * 0.55,
        BACKGROUND_THRESHOLD,
        terminalLuma
    );
    float alphaMask = 1.0 - smoothstep(0.20, 0.95, terminalColor.a);
    return clamp(max(lumaMask, alphaMask), 0.0, 1.0);
}

float localBackgroundAlpha(vec2 uv) {
    float alpha = texture(iChannel0, uv).a;
#if PERF_FIVE_TAP_ALPHA
    vec2 pixel = 1.0 / max(iResolution.xy, vec2(1.0));
    alpha = min(alpha, texture(iChannel0, uv + vec2(pixel.x, 0.0)).a);
    alpha = min(alpha, texture(iChannel0, uv - vec2(pixel.x, 0.0)).a);
    alpha = min(alpha, texture(iChannel0, uv + vec2(0.0, pixel.y)).a);
    alpha = min(alpha, texture(iChannel0, uv - vec2(0.0, pixel.y)).a);
#endif
    return alpha;
}

vec3 directionalLensStars(vec3 direction) {
    vec2 spherical = vec2(
        atan(direction.x, -direction.z),
        asin(clamp(direction.y, -1.0, 1.0))
    );
    vec2 grid = spherical * 40.0;
    vec2 identity = floor(grid);
    float randomValue = hash21(identity);
    if (randomValue < 0.92) return vec3(0.0);

    vec2 local = fract(grid) - 0.5;
    vec2 offset = (
        vec2(hash21(identity + 17.3), hash21(identity + 31.7)) - 0.5
    ) * 0.7;
    float spark = smoothstep(0.10, 0.0, length(local - offset));
    float twinkle = 0.7 + 0.3 * sin(
        iTime * (0.5 + 2.0 * hash21(identity + 5.1)) + 40.0 * randomValue
    );
    vec3 tint = mix(
        vec3(1.0, 0.82, 0.60),
        vec3(0.75, 0.85, 1.0),
        hash21(identity + 2.9)
    );
    return tint * spark * twinkle * ((randomValue - 0.92) / 0.08);
}

// =============================================================================
// STARFIELD
// =============================================================================

vec3 spaceStarTint(float randomValue) {
    vec3 colored;

    if (randomValue < SPACE_STAR_WHITE_CUTOFF) {
        colored = SPACE_STAR_WHITE;
    } else if (randomValue < SPACE_STAR_CYAN_CUTOFF) {
        float blueMix = smoothstep(
            SPACE_STAR_WHITE_CUTOFF,
            SPACE_STAR_CYAN_CUTOFF,
            randomValue
        );
        colored = mix(SPACE_STAR_BLUE, SPACE_STAR_CYAN, blueMix);
    } else if (randomValue < SPACE_STAR_YELLOW_CUTOFF) {
        colored = SPACE_STAR_YELLOW;
    } else {
        colored = SPACE_STAR_RED;
    }

    return mix(
        SPACE_STAR_WHITE,
        colored,
        clamp(SPACE_STAR_COLOR_STRENGTH, 0.0, 1.0)
    );
}

vec3 renderPerspectiveStarLayer(
    vec2 uv,
    vec2 resolution,
    float layerIndex
) {
    float layerCount = max(float(SPACE_STAR_LAYERS), 1.0);
    float layerOffset = (layerIndex + 0.5) / layerCount;
    float layerClock = iTime * SPACE_STAR_TRAVEL_SPEED + layerOffset;
    float travel = fract(layerClock);
    float generation = floor(layerClock);

    // Constant forward movement in depth naturally accelerates the apparent
    // radial motion as a star gets close to the viewer.
    float depth = mix(
        SPACE_STAR_FAR_DEPTH,
        SPACE_STAR_NEAR_DEPTH,
        travel
    );
    float nearFactor = 1.0 - (
        depth - SPACE_STAR_NEAR_DEPTH
    ) / max(
        SPACE_STAR_FAR_DEPTH - SPACE_STAR_NEAR_DEPTH,
        0.0001
    );
    nearFactor = clamp(nearFactor, 0.0, 1.0);

    float lifecycle = smoothstep(
        0.0,
        SPACE_STAR_WRAP_FADE_IN,
        travel
    ) * (
        1.0 - smoothstep(
            SPACE_STAR_WRAP_FADE_OUT,
            1.0,
            travel
        )
    );

    float aspect = resolution.x / max(resolution.y, 1.0);
    vec2 screenPoint = (uv - SPACE_STAR_TRAVEL_CENTER)
        * vec2(aspect, 1.0);

    // A point in the star plane projects as screen = world / depth.
    // Sampling world = screen * depth therefore makes the field expand
    // outward while the depth decreases.
    vec2 planePoint = screenPoint
        * depth
        * SPACE_STAR_GRID_DENSITY;

    vec2 layerSeed = vec2(
        layerIndex * 71.17 + generation * 19.73,
        layerIndex * 37.91 + generation * 83.11
    );
    planePoint += (
        hash22(layerSeed + 41.7) - 0.5
    ) * vec2(211.0, 173.0);

    vec2 baseCell = floor(planePoint);
    vec2 local = fract(planePoint) - 0.5;

    // One plane-space cell occupies this many screen pixels at the current
    // depth. This keeps the star core smoothly round at every distance.
    float pixelsPerCell = resolution.y / max(
        depth * SPACE_STAR_GRID_DENSITY,
        0.0001
    );

    vec2 radialDirection = screenPoint;
    float radialLength = length(radialDirection);
    radialDirection = radialLength > 0.0001
        ? radialDirection / radialLength
        : vec2(0.0, 1.0);
    vec2 tangentDirection = vec2(
        -radialDirection.y,
        radialDirection.x
    );

    vec3 layerColor = vec3(0.0);

    // Sampling adjacent cells prevents Gaussian cores and halos from being
    // clipped into visible squares at grid boundaries.
    for (int neighborY = -1; neighborY <= 1; neighborY++) {
        for (int neighborX = -1; neighborX <= 1; neighborX++) {
            vec2 neighbor = vec2(
                float(neighborX),
                float(neighborY)
            );
            vec2 cell = baseCell + neighbor;
            vec2 identity = cell + layerSeed;

            float population = hash12(identity + 13.7);
            float present = step(
                1.0 - clamp(SPACE_STAR_DENSITY, 0.0, 1.0),
                population
            );

            if (present < 0.5) {
                continue;
            }

            vec2 starOffset = (
                hash22(identity + 29.3) - 0.5
            ) * 0.78;
            vec2 deltaCell = local - neighbor - starOffset;
            vec2 deltaPixels = deltaCell * pixelsPerCell;

            float sizeRandom = hash12(identity + 53.1);
            float sizePixels = mix(
                SPACE_STAR_SIZE_FAR_PX,
                SPACE_STAR_SIZE_NEAR_PX,
                nearFactor
            );
            sizePixels *= mix(
                1.0 - 0.45 * SPACE_STAR_SIZE_VARIATION,
                1.0 + 0.65 * SPACE_STAR_SIZE_VARIATION,
                sizeRandom
            );

            float bigStar = step(
                SPACE_STAR_BIG_THRESHOLD,
                hash12(identity + 97.3)
            );
            sizePixels *= mix(
                1.0,
                SPACE_STAR_BIG_SIZE_GAIN,
                bigStar
            );

            float radiusSquared = dot(
                deltaPixels,
                deltaPixels
            ) / max(
                sizePixels * sizePixels,
                0.0001
            );
            float core = exp(
                -SPACE_STAR_CORE_SHARPNESS * radiusSquared
            );

            float distancePixels = sqrt(
                max(dot(deltaPixels, deltaPixels), 0.0)
            );
            float halo = exp(
                -distancePixels / max(
                    sizePixels * SPACE_STAR_HALO_RADIUS,
                    0.0001
                )
            ) * SPACE_STAR_HALO_STRENGTH * bigStar;

            // Motion trails are probabilistic and scale with actual travel
            // speed. At SPACE_STAR_TRAVEL_SPEED == 0 they disappear entirely.
            float streak = 0.0;

#if SPACE_STAR_STREAKS_ENABLED && PERF_STAR_STREAKS
            float speedFactor = clamp(
                abs(SPACE_STAR_TRAVEL_SPEED)
                    / max(SPACE_STAR_STREAK_SPEED_REFERENCE, 0.0001),
                0.0,
                1.0
            );
            speedFactor = pow(
                speedFactor,
                max(SPACE_STAR_STREAK_SPEED_POWER, 0.0001)
            );

            if (speedFactor > 0.0001) {
                float streakChance = clamp(
                    (
                        SPACE_STAR_STREAK_CHANCE
                        + bigStar * SPACE_STAR_STREAK_BIG_STAR_BONUS
                    ) * PERF_STAR_STREAK_CHANCE_GAIN,
                    0.0,
                    1.0
                );
                float streakEligible = step(
                    1.0 - streakChance,
                    hash12(identity + 251.7)
                );

                vec2 motionDirection = radialDirection
                    * (SPACE_STAR_TRAVEL_SPEED >= 0.0 ? 1.0 : -1.0);
                vec2 motionTangent = vec2(
                    -motionDirection.y,
                    motionDirection.x
                );

                float along = dot(
                    deltaPixels,
                    motionDirection
                );
                float across = dot(
                    deltaPixels,
                    motionTangent
                );
                float behind = max(-along, 0.0);
                float behindMask = 1.0 - smoothstep(
                    0.0,
                    max(sizePixels * 0.85, 0.10),
                    along
                );
                float streakWidth = max(
                    SPACE_STAR_STREAK_WIDTH_PX
                        * mix(0.75, 1.35, nearFactor),
                    0.10
                );
                float streakLength = max(
                    SPACE_STAR_STREAK_LENGTH_PX
                        * nearFactor
                        * nearFactor
                        * speedFactor,
                    0.10
                );

                streak = exp(
                    -(across * across)
                    / max(streakWidth * streakWidth, 0.0001)
                ) * exp(
                    -behind / streakLength
                ) * behindMask;

                streak *= smoothstep(
                    SPACE_STAR_STREAK_START,
                    1.0,
                    nearFactor
                )
                    * SPACE_STAR_STREAK_STRENGTH
                    * streakEligible
                    * speedFactor;
            }
#endif

            float twinklePhase = TAU * hash12(
                identity + 131.9
            );
            float twinkleSpeed = mix(
                SPACE_STAR_TWINKLE_SPEED_MIN,
                SPACE_STAR_TWINKLE_SPEED_MAX,
                hash12(identity + 173.3)
            );
            float twinkle = mix(
                1.0,
                0.84 + 0.16 * sin(
                    iTime * twinkleSpeed + twinklePhase
                ),
                clamp(
                    SPACE_STAR_TWINKLE_STRENGTH,
                    0.0,
                    1.0
                )
            );

            vec3 tint = spaceStarTint(
                hash12(identity + 211.7)
            );

            float distanceGain = mix(
                0.42,
                1.18,
                nearFactor
            );
            layerColor += tint
                * (core + halo + streak)
                * twinkle
                * distanceGain;
        }
    }

    float layerGain = 1.45 * inversesqrt(layerCount);

    return layerColor
        * lifecycle
        * layerGain
        * SPACE_STAR_BRIGHTNESS
        * PERF_STAR_GAIN;
}

vec3 renderSpaceStars(vec2 uv, vec2 resolution) {
    vec3 color = vec3(0.0);

    for (int layer = 0; layer < SPACE_STAR_LAYERS; layer++) {
        color += renderPerspectiveStarLayer(
            uv,
            resolution,
            float(layer)
        );
    }

    return color;
}

// =============================================================================
// NEBULA
// =============================================================================

vec3 renderNebula(vec2 world, float aspect) {
    float t = iTime;

    vec2 centerMotion = vec2(
        sin(t * NEBULA_POSITION_DRIFT_SPEED + 0.7)
            + 0.32 * sin(t * NEBULA_POSITION_SECONDARY_SPEED + 2.4),
        cos(t * NEBULA_POSITION_DRIFT_SPEED * 0.79 + 1.5)
            + 0.28 * sin(t * NEBULA_POSITION_SECONDARY_SPEED * 1.37 + 4.1)
    );
    centerMotion /= vec2(1.32, 1.28);

    vec2 centerUv = NEBULA_POSITION
        + centerMotion * NEBULA_POSITION_DRIFT_AMPLITUDE;
    centerUv = clamp(centerUv, NEBULA_POSITION_MIN, NEBULA_POSITION_MAX);

    vec2 centerWorld = (centerUv - 0.5) * vec2(aspect, 1.0);
    vec2 point = rotate2D(world - centerWorld, NEBULA_ROTATION);

    vec2 textureFlow = vec2(
        sin(t * NEBULA_TEXTURE_FLOW_SPEED + 0.3)
            + 0.36 * sin(t * NEBULA_TEXTURE_FLOW_SECONDARY_SPEED + 2.6),
        cos(t * NEBULA_TEXTURE_FLOW_SPEED * 0.73 + 1.7)
            + 0.31 * sin(t * NEBULA_TEXTURE_FLOW_SECONDARY_SPEED * 1.41 + 0.9)
    );
    textureFlow /= vec2(1.36, 1.31);
    point += textureFlow * NEBULA_TEXTURE_FLOW_AMPLITUDE;

    float largeWarp = fbm(
        point * NEBULA_LARGE_WARP_SCALE + vec2(7.7, 17.3)
    ) - 0.5;

#if PERF_NEBULA_SMALL_WARP
    float smallWarp = fbm(
        point * NEBULA_SMALL_WARP_SCALE + vec2(-4.1, 21.9)
    ) - 0.5;
#else
    float smallWarp = 0.0;
#endif

    float warpedY = point.y
        + largeWarp * NEBULA_LARGE_WARP_STRENGTH
        + smallWarp * NEBULA_SMALL_WARP_STRENGTH;

    float band = exp(-abs(warpedY) * NEBULA_BAND_SHARPNESS);
    float hazeBand = exp(-abs(warpedY) * NEBULA_HAZE_SHARPNESS);
    float cloud = fbm(point * NEBULA_CLOUD_SCALE + vec2(13.1, -9.7));

#if PERF_NEBULA_DETAIL
    float detail = fbm(point * NEBULA_DETAIL_SCALE + vec2(-31.0, 7.0));
#else
    float detail = 0.5;
#endif

    float density = band * smoothstep(
        NEBULA_CLOUD_THRESHOLD_LOW,
        NEBULA_CLOUD_THRESHOLD_HIGH,
        cloud
    );
    density *= mix(
        NEBULA_DETAIL_DENSITY_MIN,
        NEBULA_DETAIL_DENSITY_MAX,
        detail
    );

    float hazeDensity = hazeBand
        * smoothstep(0.26, 0.72, cloud)
        * NEBULA_HAZE_STRENGTH;

    vec3 tint = mix(
        NEBULA_COLOR_A,
        NEBULA_COLOR_B,
        smoothstep(NEBULA_COLOR_MIX_LOW, NEBULA_COLOR_MIX_HIGH, cloud)
    );
    tint = mix(
        tint,
        NEBULA_COLOR_C,
        smoothstep(NEBULA_DETAIL_COLOR_LOW, NEBULA_DETAIL_COLOR_HIGH, detail)
    );

    return (
        tint * density
        + NEBULA_HAZE_COLOR * hazeDensity
    ) * NEBULA_STRENGTH;
}

// =============================================================================
// GALAXY
// =============================================================================

vec3 renderGalaxy(vec2 world, float aspect) {
    vec2 center = (GALAXY_POSITION - 0.5) * vec2(aspect, 1.0);
    float breathe = 1.0 + GALAXY_BREATHE_AMOUNT * sin(iTime * GALAXY_BREATHE_SPEED + 0.8);
    float radius = 0.5 * GALAXY_DIAMETER * aspect * breathe;

    vec2 point = rotate2D(world - center, GALAXY_ROTATION);
    point.y *= GALAXY_FLATTENING;

    vec2 normalizedPoint = point / max(radius, 0.0001);
    float radialDistance = length(normalizedPoint);

    if (radialDistance >= GALAXY_ARM_OUTER_FADE_END) {
        return vec3(0.0);
    }

    vec2 radialDirection = radialDistance > 0.0001
        ? normalizedPoint / radialDistance
        : vec2(1.0, 0.0);
    vec2 tangentialDirection = vec2(-radialDirection.y, radialDirection.x);
    float interiorMotionMask = 1.0 - smoothstep(0.10, 1.20, radialDistance);

    vec2 detailPoint = normalizedPoint
        + tangentialDirection
            * sin(iTime * GALAXY_INTERNAL_DRIFT_SPEED + radialDistance * 10.0)
            * GALAXY_INTERNAL_TANGENTIAL_DRIFT
            * interiorMotionMask
        + radialDirection
            * sin(iTime * GALAXY_INTERNAL_DRIFT_SPEED * 0.61 - radialDistance * 6.0)
            * GALAXY_INTERNAL_RADIAL_DRIFT
            * interiorMotionMask;

    float angle = atan(normalizedPoint.y, normalizedPoint.x);
    float spin = iTime * GALAXY_SPIN_SPEED;
    float spiralPhase = angle
        - radialDistance * GALAXY_ARM_TIGHTNESS
        + spin;

    float armWave = 0.5 + 0.5 * cos(GALAXY_ARM_COUNT * spiralPhase);
    float armDistance = 1.0 - armWave;

    float armCore = 1.0 - smoothstep(
        0.0,
        GALAXY_ARM_CORE_WIDTH,
        armDistance
    );
    armCore = pow(max(armCore, 0.0), GALAXY_ARM_CORE_SHARPNESS);

    float armSoft = exp(-pow(
        armDistance / max(GALAXY_ARM_SOFT_WIDTH, 0.0001),
        2.0
    ));

    float armMask = mix(
        armCore,
        max(armCore, armSoft),
        GALAXY_ARM_SOFT_STRENGTH
    );

    float detailNoise = fbm(
        detailPoint * GALAXY_DETAIL_SCALE
        + vec2(spin * GALAXY_DETAIL_TIME_X, spin * GALAXY_DETAIL_TIME_Y)
    );

    float fineNoise = fbm(
        detailPoint * GALAXY_DETAIL_SCALE * GALAXY_FINE_DETAIL_MULTIPLIER
        + vec2(-13.7, 9.1)
        + tangentialDirection * spin * 0.09
    );

#if PERF_REUSE_GALAXY_NOISE
    float stardustNoise = detailNoise;
    float stardustDetail = fineNoise;
    float filamentNoise = mix(detailNoise, fineNoise, 0.45);
    float armDustNoise = mix(detailNoise, fineNoise, 0.30);
    float armDustDetail = fineNoise;
#else
    float stardustNoise = fbm(
        detailPoint * GALAXY_STARDUST_NOISE_SCALE
        + vec2(spin * 0.18, -spin * 0.12)
        + vec2(23.7, -11.9)
    );
    float stardustDetail = fbm(
        detailPoint * GALAXY_STARDUST_DETAIL_SCALE
        + vec2(-31.1, 17.4)
        + tangentialDirection * spin * 0.06
    );
    float filamentNoise = fbm(
        detailPoint * GALAXY_INTERARM_FILAMENT_SCALE
        + vec2(-spin * 0.31, spin * 0.17)
        + vec2(41.7, -22.4)
    );
    float armDustNoise = fbm(
        detailPoint * GALAXY_ARM_STARDUST_NOISE_SCALE
        + vec2(spin * 0.32, -spin * 0.21)
        + vec2(-7.3, 29.1)
    );
    float armDustDetail = fbm(
        detailPoint * GALAXY_ARM_STARDUST_DETAIL_SCALE
        + vec2(19.2, -37.6)
        + radialDirection * spin * 0.04
    );
#endif

    float diskEnvelope = exp(
        -radialDistance * radialDistance * GALAXY_ARM_RADIAL_FALLOFF
    );
    float hazeEnvelope = exp(
        -radialDistance * radialDistance * GALAXY_HAZE_FALLOFF
    );
    float diffuseEnvelope = exp(
        -radialDistance * radialDistance * GALAXY_DIFFUSE_DISK_FALLOFF
    );
    float coreEnvelope = exp(
        -radialDistance * radialDistance * GALAXY_CORE_SIZE
    );
    float bulgeEnvelope = exp(
        -radialDistance * radialDistance * GALAXY_BULGE_SIZE
    );
    float nucleusEnvelope = exp(
        -radialDistance * radialDistance * GALAXY_NUCLEUS_SIZE
    );
    float coreHaloEnvelope = exp(
        -radialDistance * radialDistance * GALAXY_CORE_HALO_SIZE
    );

    float clumps = mix(
        1.0 - GALAXY_CLUMPINESS * 0.45,
        1.0 + GALAXY_CLUMPINESS * 0.55,
        detailNoise
    );

    float dustWave = 0.5 + 0.5 * cos(
        GALAXY_ARM_COUNT * spiralPhase + GALAXY_DUST_PHASE_OFFSET
    );
    float dust = pow(clamp(dustWave, 0.0, 1.0), GALAXY_DUST_POWER)
        * smoothstep(
            GALAXY_DUST_INNER_START,
            GALAXY_DUST_INNER_END,
            radialDistance
        )
        * (1.0 - smoothstep(
            GALAXY_DUST_OUTER_START,
            GALAXY_DUST_OUTER_END,
            radialDistance
        ));

    float dustAttenuation = 1.0 - clamp(
        dust
        * GALAXY_DUST_STRENGTH
        * mix(0.72, 1.18, detailNoise),
        0.0,
        0.92
    );

    float armDensity = diskEnvelope
        * armMask
        * GALAXY_ARM_BRIGHTNESS
        * clumps
        * GALAXY_DENSITY
        * dustAttenuation;

    vec2 clusterGrid = (detailPoint + tangentialDirection * spin * 0.015)
        * GALAXY_CLUSTER_GRID_SCALE;
    vec2 clusterCell = floor(clusterGrid);
    vec2 clusterLocal = fract(clusterGrid) - 0.5;
    vec2 clusterOffset = (hash22(clusterCell + 9.7) - 0.5) * 0.72;
    float clusterPresence = step(
        1.0 - clamp(
            GALAXY_CLUSTER_THRESHOLD_SCALE * GALAXY_DENSITY,
            0.0,
            GALAXY_CLUSTER_THRESHOLD_MAX
        ),
        hash12(clusterCell + 71.3)
    );
    float clusterSpark = exp(
        -dot(clusterLocal - clusterOffset, clusterLocal - clusterOffset)
        * GALAXY_CLUSTER_SIZE
    ) * clusterPresence;
    clusterSpark *= diskEnvelope
        * (GALAXY_CLUSTER_ARM_BIAS
            + (1.0 - GALAXY_CLUSTER_ARM_BIAS) * armMask)
        * GALAXY_STAR_CLUSTER_STRENGTH
        * dustAttenuation;

    float haze = hazeEnvelope
        * GALAXY_HAZE_BRIGHTNESS
        * GALAXY_DENSITY
        * mix(1.0, dustAttenuation, 0.38);

    float diffuseDisk = diffuseEnvelope
        * GALAXY_DIFFUSE_DISK_BRIGHTNESS
        * GALAXY_DENSITY
        * mix(1.0, dustAttenuation, 0.55);

    float noisyCore = coreEnvelope
        * GALAXY_CORE_BRIGHTNESS
        * mix(
            GALAXY_CORE_NOISE_MIX_LOW,
            GALAXY_CORE_NOISE_MIX_HIGH,
            fineNoise
        );

    float interArmMask = pow(
        clamp(1.0 - armMask, 0.0, 1.0),
        GALAXY_INTERARM_SEPARATION_POWER
    );
    float interArmRadial = smoothstep(
        GALAXY_INTERARM_INNER_START,
        GALAXY_INTERARM_INNER_END,
        radialDistance
    ) * (1.0 - smoothstep(
        GALAXY_INTERARM_OUTER_START,
        GALAXY_INTERARM_OUTER_END,
        radialDistance
    ));

    float stardustCloud = smoothstep(
        GALAXY_STARDUST_NOISE_LOW,
        GALAXY_STARDUST_NOISE_HIGH,
        stardustNoise
    );
    stardustCloud = pow(
        max(stardustCloud, 0.0),
        GALAXY_INTERARM_CLOUD_CONTRAST
    ) * mix(
        GALAXY_STARDUST_CLOUD_MIN,
        GALAXY_STARDUST_CLOUD_MAX,
        stardustDetail
    );

#if PERF_GALAXY_FILAMENTS
    float filaments = smoothstep(
        GALAXY_INTERARM_FILAMENT_THRESHOLD_LOW,
        GALAXY_INTERARM_FILAMENT_THRESHOLD_HIGH,
        filamentNoise
    );
    stardustCloud *= mix(
        1.0,
        0.58 + 0.84 * filaments,
        GALAXY_INTERARM_FILAMENT_STRENGTH
    );
#endif

    float interArmDust = interArmMask
        * interArmRadial
        * diskEnvelope
        * stardustCloud
        * GALAXY_INTERARM_STARDUST_BRIGHTNESS
        * GALAXY_DENSITY
        * mix(1.0, dustAttenuation, 0.42);

    vec2 dustGrid = (detailPoint + tangentialDirection * spin * 0.020)
        * GALAXY_STARDUST_SPARKLE_GRID;
    vec2 dustCell = floor(dustGrid);
    vec2 dustLocal = fract(dustGrid) - 0.5;
    vec2 dustOffset = (hash22(dustCell + 43.7) - 0.5) * 0.78;
    float dustPresence = step(
        1.0 - clamp(
            GALAXY_STARDUST_SPARKLE_DENSITY * GALAXY_DENSITY,
            0.0,
            0.38
        ),
        hash12(dustCell + 97.1)
    );
    float dustSparkle = exp(
        -dot(dustLocal - dustOffset, dustLocal - dustOffset)
        * GALAXY_STARDUST_SPARKLE_SIZE
    ) * dustPresence;
    dustSparkle *= interArmMask
        * interArmRadial
        * diskEnvelope
        * GALAXY_STARDUST_SPARKLE_STRENGTH
        * mix(
            GALAXY_STARDUST_SPARKLE_RANDOM_MIN,
            GALAXY_STARDUST_SPARKLE_RANDOM_MAX,
            hash12(dustCell + 13.4)
        );

    float stardustWarmth = exp(
        -radialDistance * radialDistance * GALAXY_STARDUST_WARMING_SIZE
    );
    vec3 stardustColor = mix(
        GALAXY_STARDUST_OUTER_COLOR,
        GALAXY_STARDUST_INNER_COLOR,
        stardustWarmth
    );

    float armTrailRadial = smoothstep(
        GALAXY_ARM_STAR_TRAIL_INNER_START,
        GALAXY_ARM_STAR_TRAIL_INNER_END,
        radialDistance
    ) * (1.0 - smoothstep(
        GALAXY_ARM_STAR_TRAIL_OUTER_START,
        GALAXY_ARM_STAR_TRAIL_OUTER_END,
        radialDistance
    ));

    float armTrailMask = pow(
        clamp(armMask, 0.0, 1.0),
        GALAXY_ARM_STAR_TRAIL_ARM_POWER
    ) * armTrailRadial * diskEnvelope;

    float armGranularDust = pow(
        smoothstep(0.30, 0.76, armDustNoise),
        GALAXY_ARM_STARDUST_CONTRAST
    ) * mix(0.55, 1.22, armDustDetail);

    float armStardust = armTrailMask
        * armGranularDust
        * GALAXY_ARM_STARDUST_BRIGHTNESS
        * pow(max(armMask, 0.0), GALAXY_ARM_STARDUST_CORE_BIAS)
        * GALAXY_DENSITY;

    vec2 armStarGrid = (detailPoint + tangentialDirection * spin * 0.028)
        * GALAXY_ARM_STAR_TRAIL_GRID;
    vec2 armStarCell = floor(armStarGrid);
    vec2 armStarLocal = fract(armStarGrid) - 0.5;
    vec2 armStarOffset = (hash22(armStarCell + 63.1) - 0.5) * 0.78;
    float armStarPresence = step(
        1.0 - clamp(
            GALAXY_ARM_STAR_TRAIL_DENSITY * GALAXY_DENSITY,
            0.0,
            0.42
        ),
        hash12(armStarCell + 151.7)
    );
    float armStarDistance2 = dot(
        armStarLocal - armStarOffset,
        armStarLocal - armStarOffset
    );
    float armStarSpark = exp(
        -armStarDistance2 * GALAXY_ARM_STAR_TRAIL_SIZE
    ) * armStarPresence;
    armStarSpark *= armTrailMask
        * GALAXY_ARM_STAR_TRAIL_STRENGTH
        * mix(0.52, 1.18, hash12(armStarCell + 27.4));

    float brightKnot = step(
        GALAXY_ARM_BRIGHT_KNOT_THRESHOLD,
        hash12(armStarCell + 241.9)
    );
    float knotGlow = exp(
        -armStarDistance2 * GALAXY_ARM_BRIGHT_KNOT_SIZE
    ) * brightKnot
      * armTrailMask
      * GALAXY_ARM_BRIGHT_KNOT_STRENGTH;

    float starFormingComplex = 0.0;
    float superComplex = 0.0;

#if PERF_STAR_FORMING_COMPLEXES
    vec2 formingGrid = (detailPoint + tangentialDirection * spin * 0.032)
        * GALAXY_ARM_STAR_FORMING_GRID;
    vec2 formingCell = floor(formingGrid);
    vec2 formingLocal = fract(formingGrid) - 0.5;
    vec2 formingOffset = (hash22(formingCell + 83.4) - 0.5) * 0.76;
    vec2 formingDelta = formingLocal - formingOffset;
    float formingDistanceSquared = dot(formingDelta, formingDelta);
    float formingPresence = step(
        1.0 - clamp(
            GALAXY_ARM_STAR_FORMING_DENSITY * GALAXY_DENSITY,
            0.0,
            0.40
        ),
        hash12(formingCell + 173.9)
    );
    float formingArmMask = pow(
        clamp(max(armMask, armSoft), 0.0, 1.0),
        GALAXY_ARM_STAR_FORMING_ARM_POWER
    ) * armTrailRadial * diskEnvelope;
    float formingCore = exp(
        -formingDistanceSquared * GALAXY_ARM_STAR_FORMING_CORE_SIZE
    );
    float formingHalo = exp(
        -formingDistanceSquared * GALAXY_ARM_STAR_FORMING_HALO_SIZE
    );
    float formingRandom = mix(
        GALAXY_ARM_STAR_FORMING_RANDOM_MIN,
        GALAXY_ARM_STAR_FORMING_RANDOM_MAX,
        hash12(formingCell + 37.1)
    );
    float formingTwinkle = mix(
        1.0,
        0.86 + 0.14 * sin(
            iTime * GALAXY_ARM_STAR_FORMING_TWINKLE_SPEED
            + TAU * hash12(formingCell + 211.3)
        ),
        GALAXY_ARM_STAR_FORMING_TWINKLE
    );
    starFormingComplex = (
        formingCore
        + formingHalo * GALAXY_ARM_STAR_FORMING_HALO_STRENGTH
    ) * formingPresence
      * formingArmMask
      * formingRandom
      * formingTwinkle
      * GALAXY_ARM_STAR_FORMING_STRENGTH;

#if PERF_SUPER_COMPLEXES
    float superComplexPresence = step(
        GALAXY_ARM_SUPER_COMPLEX_THRESHOLD,
        hash12(formingCell + 317.7)
    );
    superComplex = exp(
        -formingDistanceSquared * GALAXY_ARM_SUPER_COMPLEX_SIZE
    ) * superComplexPresence
      * formingArmMask
      * GALAXY_ARM_SUPER_COMPLEX_STRENGTH;
#endif
#endif

    float armStarWarmth = exp(
        -radialDistance * radialDistance * GALAXY_ARM_STAR_WARMING_SIZE
    );
    vec3 armStarColor = mix(
        GALAXY_ARM_STAR_OUTER_COLOR,
        GALAXY_ARM_STAR_INNER_COLOR,
        armStarWarmth
    );

    float formingWarmth = exp(
        -radialDistance * radialDistance * GALAXY_ARM_FORMING_WARMING_SIZE
    );
    vec3 formingColor = mix(
        GALAXY_ARM_FORMING_OUTER_COLOR,
        GALAXY_ARM_FORMING_INNER_COLOR,
        formingWarmth
    );

    vec3 diskColor = mix(
        GALAXY_OUTER_COLOR,
        GALAXY_MID_COLOR,
        smoothstep(1.20, 0.25, radialDistance)
    );
    diskColor = mix(diskColor, GALAXY_CORE_COLOR, coreEnvelope);

    vec3 diskEmission = diskColor * (
        diffuseDisk + haze + armDensity + clusterSpark
    );
    vec3 stardustEmission = stardustColor * (
        interArmDust + dustSparkle
    );
    vec3 armTrailEmission = armStarColor * (
        armStardust + armStarSpark + knotGlow
    ) + formingColor * (
        starFormingComplex + superComplex
    );
    vec3 coreEmission = GALAXY_CORE_COLOR * noisyCore
        + GALAXY_BULGE_COLOR
            * bulgeEnvelope
            * GALAXY_BULGE_BRIGHTNESS
        + GALAXY_NUCLEUS_COLOR
            * nucleusEnvelope
            * GALAXY_NUCLEUS_BRIGHTNESS
        + GALAXY_CORE_HALO_COLOR
            * coreHaloEnvelope
            * GALAXY_CORE_HALO_BRIGHTNESS;

    float innerVisibility = smoothstep(
        GALAXY_ARM_INNER_SOFTEN,
        GALAXY_ARM_INNER_SOFTEN + 0.06,
        radialDistance + 0.0001
    );
    diskEmission *= innerVisibility;
    stardustEmission *= innerVisibility;
    armTrailEmission *= innerVisibility;

    float outerVisibility = 1.0 - smoothstep(
        GALAXY_ARM_OUTER_FADE_START,
        GALAXY_ARM_OUTER_FADE_END,
        radialDistance
    );

    float breatheBrightness = 1.0
        + GALAXY_BREATHE_BRIGHTNESS * sin(iTime * GALAXY_BREATHE_SPEED + 0.3);

    return (
        diskEmission
        + stardustEmission
        + armTrailEmission
        + coreEmission
    ) * outerVisibility
      * GALAXY_BRIGHTNESS
      * breatheBrightness;
}


// =============================================================================
// METEORS
// =============================================================================

vec4 meteorShape(
    vec2 point,
    vec2 axis,
    float trailLength,
    float trailWidth,
    float antialiasWidth
) {
    axis = normalize(axis);
    vec2 normal = vec2(axis.y, -axis.x);
    float along = dot(point, axis);
    float across = abs(dot(point, normal));
    float aa = max(antialiasWidth, 0.00001);

    float trailMask = smoothstep(
        -trailLength - aa,
        -trailLength + aa,
        along
    ) * (1.0 - smoothstep(0.0, aa, along));

    float trailPosition = clamp(
        -along / max(trailLength, 0.00001),
        0.0,
        1.0
    );

    float taperedWidth = trailWidth * mix(1.25, 0.16, trailPosition);
    float widthMask = 1.0 - smoothstep(
        taperedWidth,
        taperedWidth + aa,
        across
    );

    float trailCore = widthMask
        * trailMask
        * pow(max(1.0 - trailPosition, 0.0), 0.55);

    float trailGlow = (
        1.0 - smoothstep(
            taperedWidth * 3.2,
            taperedWidth * 4.4 + aa,
            across
        )
    ) * trailMask
      * pow(max(1.0 - trailPosition, 0.0), 0.40);

    float headRadius = trailWidth * 1.55;
    float headDistance = length(point);
    float head = 1.0 - smoothstep(
        headRadius,
        headRadius + aa,
        headDistance
    );
    float headGlow = 1.0 - smoothstep(
        headRadius * 1.2,
        headRadius * 4.0 + aa,
        headDistance
    );

    return vec4(max(trailCore, head * 0.65), trailGlow, head, headGlow);
}

void renderMeteors(
    vec2 world,
    vec2 resolution,
    out vec3 meteorColor,
    out float meteorEnergy
) {
    float trailAccumulation = 0.0;
    float trailGlowAccumulation = 0.0;
    float headAccumulation = 0.0;
    float headGlowAccumulation = 0.0;

    float aspect = resolution.x / max(resolution.y, 1.0);
    vec2 focalCenter = (SPACE_STAR_TRAVEL_CENTER - 0.5) * vec2(aspect, 1.0);
    vec2 screenPoint = world - focalCenter;

    for (int i = 0; i < METEOR_LAYERS; i++) {
        float layerIndex = float(i);
        float layerCount = max(float(METEOR_LAYERS), 1.0);
        float layerOffset = (layerIndex + 0.5) / layerCount;
        float layerRandom = hash13(vec3(layerIndex, 19.31, 47.73));

        float layerClock = iTime
            * METEOR_SPEED
            * mix(1.26, 0.68, layerOffset)
            * mix(0.90, 1.15, layerRandom)
            + layerOffset;

        float travel = fract(layerClock);
        float generation = floor(layerClock);

        float depth = mix(
            METEOR_FAR_DEPTH,
            METEOR_NEAR_DEPTH,
            travel
        );
        float nearFactor = 1.0 - (
            depth - METEOR_NEAR_DEPTH
        ) / max(
            METEOR_FAR_DEPTH - METEOR_NEAR_DEPTH,
            0.0001
        );
        nearFactor = clamp(nearFactor, 0.0, 1.0);

        float lifecycle = smoothstep(
            0.0,
            METEOR_WRAP_FADE_IN,
            travel
        ) * (
            1.0 - smoothstep(
                METEOR_WRAP_FADE_OUT,
                1.0,
                travel
            )
        );

        vec2 layerSeed = vec2(
            layerIndex * 53.7 + generation * 17.3,
            layerIndex * 89.1 + generation * 41.9
        );

        vec2 planeOffset = (
            hash22(layerSeed + 11.7) - 0.5
        ) * vec2(147.0, 119.0);

        vec2 planePoint = screenPoint * depth * METEOR_GRID_DENSITY;
        planePoint += planeOffset;

        vec2 baseCell = floor(planePoint);
        vec2 local = fract(planePoint) - 0.5;
        float pixelsPerCell = resolution.y / max(
            depth * METEOR_GRID_DENSITY,
            0.0001
        );

        for (int neighborY = -1; neighborY <= 1; neighborY++) {
            for (int neighborX = -1; neighborX <= 1; neighborX++) {
                vec2 neighbor = vec2(float(neighborX), float(neighborY));
                vec2 cell = baseCell + neighbor;
                vec3 seed = vec3(cell, layerIndex + generation * 13.0);

                float layerAmount = METEOR_AMOUNT
                    * PERF_METEOR_DENSITY_GAIN
                    * mix(1.0, 0.20, layerOffset);

                float keepMeteor = step(
                    1.0 - clamp(layerAmount, 0.0, 1.0),
                    hash13(seed + vec3(13.7, 71.3, 29.1))
                );

                if (keepMeteor < 0.5) {
                    continue;
                }

                vec2 randomOffset = hash23(seed + vec3(5.3, 41.9, 17.1));
                vec2 meteorOffset = (randomOffset - 0.5) * vec2(0.82, 0.82);
                vec2 headPlane = cell + meteorOffset;
                vec2 headScreen = (headPlane - planeOffset)
                    / (depth * METEOR_GRID_DENSITY);

                vec2 radialDirection = headScreen;
                float radialLength = length(radialDirection);
                radialDirection = radialLength > 0.0001
                    ? radialDirection / radialLength
                    : vec2(0.0, -1.0);
                vec2 tangentDirection = vec2(
                    -radialDirection.y,
                    radialDirection.x
                );

                float gustPhase = TAU * hash13(seed + vec3(7.71, 91.17, 3.1));
                float gust = sin(
                    iTime * METEOR_GUST_SPEED
                    + gustPhase
                    + radialLength * 5.0
                ) * METEOR_GUST_STRENGTH
                  * mix(0.45, 1.0, nearFactor);

                float curve = (
                    hash13(seed + vec3(23.1, 89.7, 3.9)) * 2.0 - 1.0
                ) * METEOR_CURVE_STRENGTH * mix(0.35, 1.0, nearFactor);

                radialDirection = normalize(
                    radialDirection + tangentDirection * curve
                );
                tangentDirection = vec2(
                    -radialDirection.y,
                    radialDirection.x
                );
                headScreen += tangentDirection * gust;

                vec2 deltaPixels = (screenPoint - headScreen) * resolution.y;

                float lengthRandom = hash13(seed + vec3(47.1, 5.7, 91.3));
                float widthRandom = hash13(seed + vec3(67.3, 11.9, 41.7));
                float lengthMultiplier = mix(
                    1.0 - 0.58 * LENGTH_VARIATION,
                    1.0 + 0.88 * LENGTH_VARIATION,
                    lengthRandom
                );
                float widthMultiplier = mix(
                    1.0 - 0.45 * WIDTH_VARIATION,
                    1.0 + 0.70 * WIDTH_VARIATION,
                    widthRandom
                );

                float trailLengthPixels = mix(
                    NEAR_TRAIL_LENGTH,
                    FAR_TRAIL_LENGTH,
                    layerOffset
                ) * lengthMultiplier;
                float trailWidthPixels = mix(
                    NEAR_TRAIL_WIDTH,
                    FAR_TRAIL_WIDTH,
                    layerOffset
                ) * widthMultiplier;
                float antialiasWidth = mix(0.85, 1.30, layerOffset);

                vec4 meteor = meteorShape(
                    deltaPixels,
                    radialDirection,
                    trailLengthPixels,
                    trailWidthPixels,
                    antialiasWidth
                );

                float randomBrightness = mix(
                    METEOR_RANDOM_BRIGHTNESS_MIN,
                    METEOR_RANDOM_BRIGHTNESS_MAX,
                    hash13(seed + vec3(7.3, 59.1, 23.7))
                );
                float flickerPhase = TAU * hash13(seed + vec3(101.3, 31.7, 9.1));
                float flicker = mix(
                    METEOR_FLICKER_MIN,
                    METEOR_FLICKER_MAX,
                    0.5 + 0.5 * sin(iTime * METEOR_FLICKER_SPEED + flickerPhase)
                );
                float distanceBrightness = mix(1.0, DISTANCE_BRIGHTNESS, layerOffset);
                float brightness = randomBrightness
                    * distanceBrightness
                    * lifecycle
                    * mix(0.75, 1.30, nearFactor);

                trailAccumulation += meteor.x * brightness;
                trailGlowAccumulation += meteor.y * brightness;
                headAccumulation += meteor.z * brightness * flicker;
                headGlowAccumulation += meteor.w * brightness * flicker;
            }
        }
    }

    float trailBrightness = trailAccumulation
        + trailGlowAccumulation * TRAIL_GLOW;
    float headBrightness = headAccumulation
        + headGlowAccumulation * HEAD_GLOW;
    meteorEnergy = trailBrightness + headBrightness;

    float limiter = min(
        1.0,
        MAX_METEOR_BRIGHTNESS / max(meteorEnergy, 0.00001)
    );

    meteorColor = (
        TRAIL_COLOR * trailBrightness
        + HEAD_COLOR * headBrightness
    ) * limiter
      * METEOR_OPACITY;
}


// =============================================================================
// COSMIC SCENE COMPOSITION
// =============================================================================

vec4 composeCosmicScene(
    vec2 uv,
    vec3 terminalRgb,
    vec4 terminalCentral
) {
    vec2 resolution = max(iResolution.xy, vec2(1.0));
    float aspect = resolution.x / resolution.y;
    vec2 world = (uv - 0.5) * vec2(aspect, 1.0);

    float backgroundMask = backgroundMaskFromTerminal(terminalCentral);
    float terminalLuma = luminance(terminalRgb);

    vec3 stars = renderSpaceStars(uv, resolution);
    vec3 nebula = renderNebula(world, aspect);
    vec3 galaxy = renderGalaxy(world, aspect);
    vec3 spaceColor = stars + nebula + galaxy;

    vec2 vignettePoint = (uv - 0.5) * vec2(aspect, 1.0);
    float vignette = 1.0 - VIGNETTE_STRENGTH * smoothstep(
        0.28,
        1.30,
        length(vignettePoint)
    );

    spaceColor *= vignette;
    spaceColor *= SPACE_BRIGHTNESS;
    spaceColor = applySaturation(spaceColor, SPACE_SATURATION);
    spaceColor = vec3(1.0) - exp(-spaceColor * SPACE_EXPOSURE);

    vec3 baseColor = terminalRgb * mix(
        1.0,
        BACKGROUND_DARKEN,
        backgroundMask
    );
    baseColor += spaceColor * backgroundMask;

    vec3 meteorColor;
    float meteorEnergy;
    renderMeteors(world, resolution, meteorColor, meteorEnergy);

    float protectionMask = mix(
        1.0,
        1.0 - smoothstep(0.20, 0.90, terminalLuma),
        clamp(TEXT_PROTECTION, 0.0, 1.0)
    );

    vec3 finalColor = baseColor + meteorColor * protectionMask;
    float sceneVisibility = clamp(
        luminance(spaceColor) * 1.8
        + meteorEnergy * 0.30,
        0.0,
        1.0
    );
    float finalAlpha = max(
        terminalCentral.a,
        backgroundMask * SPACE_ALPHA_BOOST * sceneVisibility
    );

    return vec4(finalColor, finalAlpha);
}

vec4 sampleCosmicScene(vec2 uv) {
    vec4 terminal = texture(iChannel0, uv);
    return composeCosmicScene(uv, terminal.rgb, terminal);
}

// =============================================================================
// VARIABLE BLACK-HOLE DISK LOOK MODES
// =============================================================================

struct DiskLook {
    float temp;
    float incl;
    float roll;
    float inner;
    float outer;
    float opac;
    float dopp;
    float beam;
    float gain;
    float contr;
    float wind;
    float speed;
    float expo;
    float star;
};

const DiskLook LOOK_DEFAULT = DiskLook(
    BH_DISK_TEMPERATURE,
    BH_DISK_INCLINATION,
    BH_DISK_ROLL,
    BH_DISK_INNER,
    BH_DISK_OUTER,
    BH_DISK_OPACITY,
    BH_DOPPLER_MIX,
    BH_DISK_BEAM,
    BH_DISK_GAIN,
    BH_DISK_CONTRAST,
    BH_DISK_WIND,
    BH_DISK_SPEED,
    BH_EXPOSURE,
    BH_LENSED_STAR_GAIN
);

#define BH_PRESET_COUNT 8

const DiskLook BH_LOOK_PRESETS[BH_PRESET_COUNT] = DiskLook[BH_PRESET_COUNT](
    DiskLook( 5500.0, 1.50,  0.35, 1.8,  8.0, 0.90, 0.60, 2.5, 2.2, 1.6, 7.0, 5.0, 1.40, BH_LENSED_STAR_GAIN),
    DiskLook( 4500.0, 1.52,  0.10, 2.2,  7.0, 0.85, 0.35, 2.0, 1.4, 0.5, 7.0, 5.0, 1.20, BH_LENSED_STAR_GAIN),
    DiskLook( 3800.0, 0.55, -0.30, 2.2,  6.0, 0.45, 0.90, 3.5, 1.6, 0.4, 3.0, 2.5, 1.10, BH_LENSED_STAR_GAIN),
    DiskLook( 6500.0, 0.30,  0.00, 3.0, 10.0, 0.50, 0.80, 2.5, 1.0, 1.1, 7.0, 5.0, 1.00, BH_LENSED_STAR_GAIN),
    DiskLook(15000.0, 1.30,  0.35, 3.0, 14.0, 0.35, 1.00, 4.0, 1.2, 1.3, 8.0, 5.0, 0.80, BH_LENSED_STAR_GAIN),
    DiskLook(18000.0, 1.05,  0.55, 3.0, 16.0, 0.30, 1.00, 5.0, 1.0, 1.5, 9.0, 6.0, 0.75, BH_LENSED_STAR_GAIN),
    DiskLook( 5500.0, 1.50,  0.35, 1.8,  8.0, 0.00, 1.00, 2.5, 0.0, 1.6, 7.0, 5.0, 1.00, 0.12),
    DiskLook( 5500.0, 1.50,  0.35, 1.8,  8.0, 0.90, 0.60, 2.5, 2.2, 1.6, 7.0, 5.0, 1.40, BH_LENSED_STAR_GAIN)
);

DiskLook mixLook(DiskLook a, DiskLook b, float factor) {
    return DiskLook(
        mix(a.temp,  b.temp,  factor),
        mix(a.incl,  b.incl,  factor),
        mix(a.roll,  b.roll,  factor),
        mix(a.inner, b.inner, factor),
        mix(a.outer, b.outer, factor),
        mix(a.opac,  b.opac,  factor),
        mix(a.dopp,  b.dopp,  factor),
        mix(a.beam,  b.beam,  factor),
        mix(a.gain,  b.gain,  factor),
        mix(a.contr, b.contr, factor),
        mix(a.wind,  b.wind,  factor),
        mix(a.speed, b.speed, factor),
        mix(a.expo,  b.expo,  factor),
        mix(a.star,  b.star,  factor)
    );
}

DiskLook showcaseDiskLook() {
    float clock = mod(iTime, BH_SHOWCASE_SECONDS)
        / BH_SHOWCASE_SECONDS
        * float(BH_PRESET_COUNT);
    int index = int(min(clock, float(BH_PRESET_COUNT) - 0.001));
    float factor = smoothstep(
        1.0 - BH_SHOWCASE_CROSSFADE,
        1.0,
        fract(clock)
    );
    return mixLook(
        BH_LOOK_PRESETS[index],
        BH_LOOK_PRESETS[(index + 1) % BH_PRESET_COUNT],
        factor
    );
}

DiskLook evolvingDiskLook() {
    float clock = mod(iTime, BH_EVOLVE_SECONDS)
        / BH_EVOLVE_SECONDS
        * float(BH_PRESET_COUNT);
    int index = int(min(clock, float(BH_PRESET_COUNT) - 0.001));
    float easedFactor = smoothstep(0.0, 1.0, fract(clock));
    easedFactor = pow(
        clamp(easedFactor, 0.0, 1.0),
        max(BH_EVOLVE_EASE, 0.0001)
    );
    return mixLook(
        BH_LOOK_PRESETS[index],
        BH_LOOK_PRESETS[(index + 1) % BH_PRESET_COUNT],
        easedFactor
    );
}

DiskLook dualDiskLook() {
    int indexA = clamp(BH_DUAL_PRESET_A, 0, BH_PRESET_COUNT - 1);
    int indexB = clamp(BH_DUAL_PRESET_B, 0, BH_PRESET_COUNT - 1);
    float factor = 0.5 + 0.5 * sin(
        TAU * iTime / max(BH_DUAL_SECONDS, 0.001)
    );
    factor = smoothstep(0.0, 1.0, factor);
    return mixLook(BH_LOOK_PRESETS[indexA], BH_LOOK_PRESETS[indexB], factor);
}

DiskLook animatedDiskLook() {
    if (BLACK_HOLE_LOOK_MODE == BH_LOOK_FIXED) return LOOK_DEFAULT;
    if (BLACK_HOLE_LOOK_MODE == BH_LOOK_SHOWCASE) return showcaseDiskLook();
    if (BLACK_HOLE_LOOK_MODE == BH_LOOK_DUAL) return dualDiskLook();
    return evolvingDiskLook();
}

// =============================================================================
// BLACK-HOLE MOTION / SIZE STATE
// =============================================================================

void animatedBlackHoleState(
    float aspect,
    float outerDiskRadius,
    out vec2 center,
    out float intensity,
    out float sizeScale
) {
    float motionTime = iTime * BLACK_HOLE_DRIFT_SPEED;
    vec2 organicMotion = blackHoleMotionVector(motionTime);

    float primaryPulse = sin(iTime * BLACK_HOLE_PULSE_SPEED);
    float secondaryPulse = sin(
        iTime * BLACK_HOLE_PULSE_SPEED * 1.83 + 1.4
    );
    float tertiaryPulse = sin(
        iTime * BLACK_HOLE_PULSE_SPEED * 0.47 + 4.2
    );

    sizeScale = 1.0 + BLACK_HOLE_PULSE_AMOUNT * (
        primaryPulse
        + BLACK_HOLE_PULSE_SECONDARY_MIX * secondaryPulse
        + BLACK_HOLE_PULSE_TERTIARY_MIX * tertiaryPulse
    );
    sizeScale = clamp(
        sizeScale,
        BLACK_HOLE_PULSE_MIN_SCALE,
        BLACK_HOLE_PULSE_MAX_SCALE
    );

    float intensityWave = 0.5 + 0.5 * sin(
        iTime * BH_INTENSITY_SPEED + 1.1
    );
    float intensityWave2 = 0.5 + 0.5 * sin(
        iTime * BH_INTENSITY_SPEED * 0.43 + 3.7
    );
    intensity = mix(
        BH_INTENSITY_MIN,
        BH_INTENSITY_MAX,
        intensityWave * 0.72 + intensityWave2 * 0.28
    );

    float shadowRadius = BLACK_HOLE_RADIUS * sizeScale;
    float extent = min(
        outerDiskRadius / B_CRIT * shadowRadius,
        BLACK_HOLE_MAX_CLAMP_EXTENT
    );
    vec2 diskPadding = vec2(
        extent / max(aspect, 0.0001),
        extent
    ) + vec2(BLACK_HOLE_CLAMP_MARGIN);

    if (BLACK_HOLE_TRAVEL_MODE == BH_TRAVEL_BOUNDS) {
        vec2 requestedLow = min(BLACK_HOLE_TRAVEL_MIN, BLACK_HOLE_TRAVEL_MAX);
        vec2 requestedHigh = max(BLACK_HOLE_TRAVEL_MIN, BLACK_HOLE_TRAVEL_MAX);
        vec4 reservedUv = blackHoleReservedUv(max(iResolution.xy, vec2(1.0)));
        requestedLow = max(requestedLow, vec2(reservedUv.x, reservedUv.y));
        requestedHigh = min(
            requestedHigh,
            vec2(1.0 - reservedUv.z, 1.0 - reservedUv.w)
        );

        if (BLACK_HOLE_KEEP_DISK_ON_SCREEN != 0) {
            requestedLow = max(requestedLow, diskPadding);
            requestedHigh = min(requestedHigh, vec2(1.0) - diskPadding);
        }

        vec2 safeLow = min(requestedLow, requestedHigh);
        vec2 safeHigh = max(requestedLow, requestedHigh);
        vec2 rectangleCenter = 0.5 * (safeLow + safeHigh);
        vec2 rectangleHalfExtent = max(
            0.5 * (safeHigh - safeLow),
            vec2(0.0)
        );

        center = rectangleCenter
            + organicMotion
                * rectangleHalfExtent
                * clamp(BLACK_HOLE_TRAVEL_REACH, 0.0, 1.0);
    } else {
        center = BLACK_HOLE_BASE_POSITION + organicMotion * BLACK_HOLE_DRIFT;
        if (BLACK_HOLE_KEEP_DISK_ON_SCREEN != 0) {
            center = clamp(center, diskPadding, vec2(1.0) - diskPadding);
        }
    }
}

// =============================================================================
// MAIN — COSMIC SCENE THROUGH GEODESIC BLACK HOLE
// =============================================================================

void renderCosmosImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 resolution = max(iResolution.xy, vec2(1.0));
    vec2 uv = fragCoord / resolution;
    float aspect = resolution.x / resolution.y;

    DiskLook look = animatedDiskLook();
    look.inner *= BH_GLOBAL_DISK_SIZE;
    look.outer *= BH_GLOBAL_DISK_SIZE;
    look.gain *= BH_GLOBAL_DISK_BRIGHTNESS;
    look.opac = clamp(look.opac * BH_GLOBAL_DISK_OPACITY, 0.0, 1.0);
    look.temp *= BH_GLOBAL_TEMPERATURE;
    look.dopp = clamp(look.dopp * BH_GLOBAL_DOPPLER, 0.0, 1.0);
    look.beam *= BH_GLOBAL_BEAM;
    look.speed *= BH_GLOBAL_DISK_SPEED;
    look.wind *= BH_GLOBAL_DISK_WIND;
    look.contr *= BH_GLOBAL_DISK_CONTRAST;
    look.expo *= BH_GLOBAL_EXPOSURE;
    look.incl += BH_GLOBAL_INCLINATION_OFFSET;
    look.roll += BH_GLOBAL_ROLL_OFFSET;

    float innerDiskRadius = max(look.inner, 1.6);
    float outerDiskRadius = max(look.outer, innerDiskRadius + 0.5);

    vec2 center;
    float intensity;
    float sizeScale;
    animatedBlackHoleState(
        aspect,
        outerDiskRadius,
        center,
        intensity,
        sizeScale
    );

    float visibility = smoothstep(0.0, 0.10, intensity);
    float shadowRadius = BLACK_HOLE_RADIUS * sizeScale;
    float yUp = 1.0 - uv.y;

    float shield = visibility;
    if (BLACK_HOLE_WORK_AREA > 0.0) {
        shield *= smoothstep(
            BLACK_HOLE_WORK_AREA,
            BLACK_HOLE_WORK_AREA + 0.18,
            yUp
        );
    }

    vec2 screenPoint = (uv - center) * vec2(aspect, 1.0);
    float screenDistance = length(screenPoint);
    float worldScale = B_CRIT / max(shadowRadius, 0.0001);
    vec2 rayPlanePoint = rotate2D(
        vec2(screenPoint.x, -screenPoint.y),
        look.roll
    ) * worldScale;
    float impactParameter = length(rayPlanePoint);

    float distanceWindow = exp(-pow(
        screenDistance / max(7.0 * shadowRadius, 0.0001),
        2.0
    ));
    float blackHoleWindow = distanceWindow * shield;

    // Outside the visible lens/disk region, bypass all black-hole work.
    if (blackHoleWindow < PERF_BH_WINDOW_CUTOFF) {
        fragColor = sampleCosmicScene(uv);
        return;
    }

    float geodesicBoundary = outerDiskRadius + 3.0;
    float cameraDistance = max(14.0, outerDiskRadius + 5.0);

    // -------------------------------------------------------------------------
    // FAR FIELD — analytic weak deflection
    // -------------------------------------------------------------------------
    if (impactParameter >= geodesicBoundary) {
        float cameraFactor = cameraDistance * inversesqrt(
            cameraDistance * cameraDistance
            + impactParameter * impactParameter
        );

        float deflection = (2.0 / (worldScale * worldScale))
            / max(screenDistance, 0.0001)
            * (1.29 * cameraFactor + 0.07)
            * max(
                BLACK_HOLE_LENS_DEPTH - 2.14 * cameraFactor + 0.75,
                0.0
            )
            * blackHoleWindow
            * BLACK_HOLE_LENS_MIX;

        vec2 radialDirection = screenPoint / max(screenDistance, 0.00001);
        vec2 centralPoint = screenPoint - radialDirection * deflection;
        vec2 centralUv = mirrorUV(
            center + centralPoint / vec2(aspect, 1.0)
        );

        vec4 terminalCentral = texture(iChannel0, centralUv);
        vec3 terminalRgb = terminalCentral.rgb;

#if PERF_CHROMATIC_LENS
        float aberration = 0.035 * smoothstep(
            1.0,
            2.0,
            impactParameter / geodesicBoundary
        );

        for (int channel = 0; channel < 3; channel++) {
            float channelScale = 1.0
                + (float(channel) - 1.0) * aberration;
            vec2 displacedPoint = screenPoint
                - radialDirection * deflection * channelScale;
            vec2 displacedUv = mirrorUV(
                center + displacedPoint / vec2(aspect, 1.0)
            );
            terminalRgb[channel] = texture(iChannel0, displacedUv)[channel];
        }
#endif

        fragColor = composeCosmicScene(
            centralUv,
            terminalRgb,
            terminalCentral
        );
        return;
    }

    // -------------------------------------------------------------------------
    // NEAR FIELD — Schwarzschild null-geodesic integration
    // -------------------------------------------------------------------------
    vec3 rayPosition = vec3(rayPlanePoint, cameraDistance);
    vec3 rayVelocity = vec3(0.0, 0.0, -1.0);
    float angularMomentumSquared = dot(rayPlanePoint, rayPlanePoint);

    float cosineInclination = cos(look.incl);
    float sineInclination = sin(look.incl);
    vec3 diskNormal = vec3(0.0, sineInclination, cosineInclination);
    vec3 diskAxis = vec3(0.0, cosineInclination, -sineInclination);

    float rotationDirection = look.speed < 0.0 ? -1.0 : 1.0;
    float diskSpeed = abs(look.speed);
    vec3 emittedLight = vec3(0.0);
    float transmittance = 1.0;
    bool captured = false;
    float previousPlaneSide = dot(rayPosition, diskNormal);
    vec3 previousPosition = rayPosition;
    float dilation = mix(1.0, BH_DILATION_MIN, intensity);

    for (int stepIndex = 0; stepIndex < N_STEPS; stepIndex++) {
        float radiusSquared = dot(rayPosition, rayPosition);
        if (radiusSquared < 1.0) {
            captured = true;
            break;
        }
        if (rayPosition.z < -cameraDistance && rayVelocity.z < 0.0) break;
        if (radiusSquared > 4.0 * cameraDistance * cameraDistance) break;

        float radius = sqrt(radiusSquared);
        float timeStep = clamp(0.16 * radius, 0.03, 1.5);
        vec3 acceleration = -1.5
            * angularMomentumSquared
            * rayPosition
            / (radiusSquared * radiusSquared * radius);

        rayVelocity += acceleration * (0.5 * timeStep);
        rayPosition += rayVelocity * timeStep;

        radiusSquared = dot(rayPosition, rayPosition);
        radius = sqrt(radiusSquared);
        acceleration = -1.5
            * angularMomentumSquared
            * rayPosition
            / (radiusSquared * radiusSquared * radius);
        rayVelocity += acceleration * (0.5 * timeStep);

        float planeSide = dot(rayPosition, diskNormal);
        if (planeSide * previousPlaneSide < 0.0 && transmittance > 0.02) {
            float crossingFraction = previousPlaneSide
                / (previousPlaneSide - planeSide);
            vec3 crossingPosition = mix(
                previousPosition,
                rayPosition,
                crossingFraction
            );
            float crossingRadius = length(crossingPosition);

            if (crossingRadius > innerDiskRadius
                && crossingRadius < outerDiskRadius) {
                float radialBand = smoothstep(
                    innerDiskRadius,
                    innerDiskRadius * 1.25,
                    crossingRadius
                ) * (1.0 - smoothstep(
                    outerDiskRadius * 0.70,
                    outerDiskRadius,
                    crossingRadius
                ));

                float azimuth = atan(
                    dot(crossingPosition, diskAxis),
                    crossingPosition.x
                );
                float turns = azimuth / TAU;
                float keplerianRate = pow(
                    innerDiskRadius / crossingRadius,
                    1.5
                );
                float localTimeFactor = sqrt(max(
                    1.0 - 1.5 / crossingRadius,
                    0.02
                ));
                float swirl = crossingRadius * look.wind * 0.12
                    - iTime
                        * keplerianRate
                        * diskSpeed
                        * localTimeFactor
                        * dilation
                        * rotationDirection;

                float streaks = vnoiseWrapY(
                    vec2(
                        crossingRadius * 2.8,
                        turns * 19.0 + swirl * 3.0
                    ),
                    19.0
                );

#if PERF_BH_SECOND_STREAK
                float secondaryStreak = vnoiseWrapY(
                    vec2(
                        crossingRadius,
                        turns * 9.0 + swirl * 1.5 + 7.0
                    ),
                    9.0
                );
                streaks = streaks * 0.65 + secondaryStreak * 0.35;
#endif

                streaks = 0.35 + look.contr * streaks * streaks;

                vec3 gasDirection = normalize(
                    cross(diskNormal, crossingPosition)
                ) * rotationDirection;
                float beta = clamp(
                    inversesqrt(max(2.0 * (crossingRadius - 1.0), 0.2)),
                    0.0,
                    0.99
                );
                float shift = localTimeFactor
                    / max(
                        1.0 + beta * dot(
                            gasDirection,
                            normalize(rayVelocity)
                        ),
                        0.05
                    );
                shift = mix(1.0, shift, look.dopp);

                float innerFalloff = max(
                    1.0 - sqrt(innerDiskRadius / crossingRadius),
                    0.0
                );
                float temperatureProfile = pow(
                    innerDiskRadius / crossingRadius,
                    0.75
                ) * pow(innerFalloff, 0.25)
                  / 0.488;
                vec3 blackbodyColor = blackbody(
                    look.temp * temperatureProfile * shift
                );
                float relativisticBoost = pow(shift, look.beam);
                float density = radialBand * streaks;

                emittedLight += transmittance
                    * blackbodyColor
                    * (
                        look.gain
                        * 2.2
                        * density
                        * temperatureProfile
                        * temperatureProfile
                        * relativisticBoost
                    );
                transmittance *= 1.0 - clamp(
                    look.opac * density,
                    0.0,
                    1.0
                );
            }
        }

        previousPlaneSide = planeSide;
        previousPosition = rayPosition;
    }

    if (!captured && dot(rayPosition, rayPosition) < 4.0) {
        captured = true;
    }

    // -------------------------------------------------------------------------
    // BACKGROUND SKY / TERMINAL PROJECTION
    // -------------------------------------------------------------------------
    vec3 backgroundColor = vec3(0.0);
    float baseShadowAlpha = max(
        localBackgroundAlpha(uv),
        BLACK_HOLE_SHADOW_ALPHA_BOOST * visibility
    );
    float backgroundAlpha = baseShadowAlpha;

    if (!captured) {
        vec3 exitDirection = normalize(rayVelocity);

#if PERF_DIRECTIONAL_LENS_STARS
        backgroundColor += directionalLensStars(exitDirection)
            * look.star
            * blackHoleWindow
            * BH_DIRECTIONAL_STARS_WINDOW_SCALE;
#endif

        if (exitDirection.z < -0.05) {
            float projectionTime = (
                -BLACK_HOLE_LENS_DEPTH - rayPosition.z
            ) / exitDirection.z;
            vec3 projectedPoint = rayPosition
                + exitDirection * projectionTime;
            vec2 unrolledPoint = rotate2D(
                projectedPoint.xy,
                -look.roll
            ) / worldScale;
            vec2 projectedScreenPoint = vec2(
                unrolledPoint.x,
                -unrolledPoint.y
            );
            vec2 exactWarpedUv = mirrorUV(
                center + projectedScreenPoint / vec2(aspect, 1.0)
            );
            vec2 warpedUv = mirrorUV(mix(
                uv,
                exactWarpedUv,
                blackHoleWindow * BLACK_HOLE_LENS_MIX
            ));
            float towardSkyPlane = smoothstep(
                0.05,
                0.35,
                -exitDirection.z
            );
            vec4 warpedScene = sampleCosmicScene(warpedUv);
            backgroundColor += warpedScene.rgb * towardSkyPlane;
            backgroundAlpha = mix(
                baseShadowAlpha,
                warpedScene.a,
                towardSkyPlane
            );
        }
    }

    vec3 diskLight = vec3(1.0) - exp(-emittedLight * look.expo);
    vec3 finalColor = backgroundColor * transmittance + diskLight;
    float diskAlpha = SPACE_ALPHA_BOOST * clamp(
        luminance(diskLight) * 1.8,
        0.0,
        1.0
    );
    fragColor = vec4(finalColor, max(backgroundAlpha, diskAlpha));
}

// =============================================================================
// CURSOR MOVEMENT OVERLAY
// =============================================================================
// This section was previously a second Ghostty shader pass. In this combined
// file it consumes renderCosmosImage() directly, so only one custom-shader
// entry is required.

// =============================================================================
// CURSOR EFFECT — GPU PERFORMANCE PROFILE
// =============================================================================
//
// The cursor profile follows the background GPU_PROFILE automatically.
// Preserve its defining rings, orbit, and nebula wake at every profile. These
// effects are spatially culled; only the bounded spark loop scales down.

#define CURSOR_GPU_ECO      0
#define CURSOR_GPU_BALANCED 1
#define CURSOR_GPU_HIGH     2
#define CURSOR_GPU_ULTRA    3

#define CURSOR_GPU_PROFILE GPU_PROFILE

#define CURSOR_ENABLE_PHOTON_RING  1
#define CURSOR_ENABLE_RIPPLE       1
#define CURSOR_ENABLE_ORBIT        1
#define CURSOR_ENABLE_NEBULA_WAKE  1

#if CURSOR_GPU_PROFILE == CURSOR_GPU_ECO
    #define CURSOR_SPARK_COUNT 0
#elif CURSOR_GPU_PROFILE == CURSOR_GPU_BALANCED
    #define CURSOR_SPARK_COUNT 2
#elif CURSOR_GPU_PROFILE == CURSOR_GPU_HIGH
    #define CURSOR_SPARK_COUNT 4
#else
    #define CURSOR_SPARK_COUNT 6
#endif

// =============================================================================
// MASTER TIMING
// =============================================================================

const float EFFECT_DURATION = 0.24;
const float MIN_MOVEMENT = 0.0;
const float MAX_MOVEMENT_DISTANCE = 8.0;
const float FADE_POWER = 2.15;
const float CONTENT_PROTECTION = 0.18;

// =============================================================================
// DESTINATION GLOW
// =============================================================================

const float HEAD_RADIUS_MIN = 0.92;
const float HEAD_RADIUS_MAX = 1.72;
const float HEAD_EXPANSION_AMOUNT = 0.18;
const float HEAD_GOLD_STRENGTH = 0.13;
const float HEAD_GOLD_INNER_RATIO = 0.20;
const float HEAD_COSMIC_HALO_RADIUS = 1.85;
const float HEAD_COSMIC_HALO_STRENGTH = 0.075;

// =============================================================================
// PHOTON RING / ORBITAL RING
// =============================================================================

const float PHOTON_RING_RADIUS = 1.10;
const float PHOTON_RING_WIDTH = 0.055;
const float PHOTON_RING_STRENGTH = 0.22;
const float RIPPLE_START_RADIUS = 0.75;
const float RIPPLE_END_RADIUS = 2.25;
const float RIPPLE_WIDTH = 0.070;
const float RIPPLE_STRENGTH = 0.075;
const float ORBIT_RADIUS = 1.36;
const float ORBIT_COMPRESSION = 2.35;
const float ORBIT_WIDTH = 0.060;
const float ORBIT_STRENGTH = 0.15;
const float ORBIT_ROTATION = -0.34;
const float ORBIT_SPIN_SPEED = 1.10;
const float ORBIT_ASYMMETRY = 0.38;

// =============================================================================
// COMET TRAIL
// =============================================================================

const float TRAIL_RADIUS_MIN = 0.17;
const float TRAIL_RADIUS_MAX = 0.33;
const float TRAIL_GLOW_WIDTH = 2.80;
const float TRAIL_GLOW_STRENGTH = 0.075;
const float TRAIL_CORE_STRENGTH = 0.24;
const float TRAIL_HOT_CORE_WIDTH = 0.48;
const float TRAIL_HOT_CORE_STRENGTH = 0.20;
const float TRAIL_NEBULA_WIDTH = 5.20;
const float TRAIL_NEBULA_STRENGTH = 0.026;
const float TRAIL_TAIL_FADE = 0.26;
const float TRAIL_HEAD_BIAS = 0.46;

// =============================================================================
// SPARKS
// =============================================================================

#define SPARK_COUNT CURSOR_SPARK_COUNT
const float SPARK_RADIUS_MIN = 0.035;
const float SPARK_RADIUS_MAX = 0.075;
const float SPARK_SPREAD = 0.62;
const float SPARK_STRENGTH = 0.22;
const float SPARK_MOVEMENT_THRESHOLD = 0.12;

// =============================================================================
// COLORS
// =============================================================================

const vec3 GOLD_BODY = vec3(0.88, 0.69, 0.41);
const vec3 GOLD_HOT  = vec3(1.00, 0.84, 0.38);
const vec3 COSMIC_BLUE   = vec3(0.42, 0.58, 1.00);
const vec3 NEBULA_VIOLET = vec3(0.61, 0.43, 0.92);
const vec3 STAR_WHITE    = vec3(0.96, 0.97, 1.00);

// =============================================================================
// HELPERS
// =============================================================================

float easeOutCubic(float value) {
    value = clamp(value, 0.0, 1.0);
    return 1.0 - pow(1.0 - value, 3.0);
}

float fadeOut(float value) {
    value = clamp(value, 0.0, 1.0);
    return pow(1.0 - value, FADE_POWER);
}

vec2 normalizeScreen(vec2 value, float isPosition) {
    return (
        value * 2.0 - iResolution.xy * isPosition
    ) / max(iResolution.y, 1.0);
}

float sdRectangle(vec2 point, vec2 center, vec2 halfSize) {
    vec2 distanceVector = abs(point - center) - halfSize;
    return length(max(distanceVector, 0.0))
        + min(max(distanceVector.x, distanceVector.y), 0.0);
}

float sdCapsule(
    vec2 point,
    vec2 startPoint,
    vec2 endPoint,
    float radius
) {
    vec2 relativePoint = point - startPoint;
    vec2 segment = endPoint - startPoint;
    float position = clamp(
        dot(relativePoint, segment)
            / max(dot(segment, segment), 0.000001),
        0.0,
        1.0
    );
    return length(relativePoint - segment * position) - radius;
}

float antialiasMask(float distanceValue) {
    float pixelWidth = normalizeScreen(vec2(1.5), 0.0).x;
    return 1.0 - smoothstep(0.0, pixelWidth, distanceValue);
}

float ringMask(float distanceValue, float radius, float width) {
    float pixelWidth = normalizeScreen(vec2(1.0), 0.0).x;
    float ringDistance = abs(distanceValue - radius);
    return 1.0 - smoothstep(
        width,
        width + pixelWidth,
        ringDistance
    );
}

vec2 cursorCenter(vec4 cursor) {
    return vec2(
        cursor.x + cursor.z * 0.5,
        cursor.y - cursor.w * 0.5
    );
}

// =============================================================================
// MAIN
// =============================================================================

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Render the complete cosmos/geodesic scene first, then composite the
    // cursor movement effect over that exact per-pixel result.
    vec4 originalColor;
    renderCosmosImage(originalColor, fragCoord);
    fragColor = originalColor;

    vec2 point = normalizeScreen(fragCoord, 1.0);
    vec4 currentCursor = vec4(
        normalizeScreen(iCurrentCursor.xy, 1.0),
        normalizeScreen(iCurrentCursor.zw, 0.0)
    );
    vec4 previousCursor = vec4(
        normalizeScreen(iPreviousCursor.xy, 1.0),
        normalizeScreen(iPreviousCursor.zw, 0.0)
    );

    vec2 head = cursorCenter(currentCursor);
    vec2 tail = cursorCenter(previousCursor);
    float cursorSize = max(currentCursor.z, currentCursor.w);
    float distanceMoved = distance(head, tail);
    float age = clamp(
        (iTime - iTimeCursorChange) / EFFECT_DURATION,
        0.0,
        1.0
    );

    bool movementActive =
        distanceMoved > MIN_MOVEMENT * cursorSize
        && age < 1.0;

    if (!movementActive) {
        return;
    }

    // Conservative coherent culling rectangle. Pixels outside the cursor path
    // skip rings, trail geometry, orbit calculations, and spark loops.
    float maximumHeadScale = HEAD_RADIUS_MAX
        * (1.0 + HEAD_EXPANSION_AMOUNT);
    float maximumEffectRadius = cursorSize * max(
        maximumHeadScale * max(
            HEAD_COSMIC_HALO_RADIUS,
            max(RIPPLE_END_RADIUS, ORBIT_RADIUS + ORBIT_WIDTH)
        ),
        max(
            TRAIL_RADIUS_MAX * TRAIL_NEBULA_WIDTH,
            SPARK_SPREAD + SPARK_RADIUS_MAX + 0.20
        )
    );

    vec2 effectMinimum = min(head, tail) - vec2(maximumEffectRadius);
    vec2 effectMaximum = max(head, tail) + vec2(maximumEffectRadius);

    if (
        any(lessThan(point, effectMinimum))
        || any(greaterThan(point, effectMaximum))
    ) {
        return;
    }

    float easedAge = easeOutCubic(age);
    float life = fadeOut(easedAge);
    float pulse = sin(age * PI);
    float expansion = 1.0 + HEAD_EXPANSION_AMOUNT * pulse;
    float movementFactor = smoothstep(
        MIN_MOVEMENT * cursorSize,
        MAX_MOVEMENT_DISTANCE * cursorSize,
        distanceMoved
    );

    float contentMask = mix(
        1.0,
        1.0 - smoothstep(0.30, 0.92, luminance(originalColor.rgb)),
        CONTENT_PROTECTION
    );

    // Head glow.
    float headRadius = cursorSize
        * mix(HEAD_RADIUS_MIN, HEAD_RADIUS_MAX, movementFactor)
        * expansion;
    vec2 headVector = point - head;
    float headDistance = length(headVector);
    float headGold = 1.0 - smoothstep(
        headRadius * HEAD_GOLD_INNER_RATIO,
        headRadius,
        headDistance
    );
    float headHalo = 1.0 - smoothstep(
        headRadius * 0.45,
        headRadius * HEAD_COSMIC_HALO_RADIUS,
        headDistance
    );
    headGold *= life;
    headHalo *= life;

    float photonRing = 0.0;
    float ripple = 0.0;
    float orbit = 0.0;
    float orbitPhase = 0.0;

#if CURSOR_ENABLE_PHOTON_RING
    photonRing = ringMask(
        headDistance,
        headRadius * PHOTON_RING_RADIUS,
        cursorSize * PHOTON_RING_WIDTH
    ) * life;
#endif

#if CURSOR_ENABLE_RIPPLE
    float rippleRadius = headRadius * mix(
        RIPPLE_START_RADIUS,
        RIPPLE_END_RADIUS,
        easedAge
    );
    ripple = ringMask(
        headDistance,
        rippleRadius,
        cursorSize * RIPPLE_WIDTH
    );
    ripple *= life * (1.0 - easedAge);
#endif

#if CURSOR_ENABLE_ORBIT
    float orbitAngle = ORBIT_ROTATION + iTime * ORBIT_SPIN_SPEED;
    vec2 orbitPoint = rotate2D(headVector, orbitAngle);
    orbitPoint.y *= ORBIT_COMPRESSION;
    float orbitDistance = length(orbitPoint);
    orbit = ringMask(
        orbitDistance,
        headRadius * ORBIT_RADIUS,
        cursorSize * ORBIT_WIDTH
    );
    orbitPhase = atan(orbitPoint.y, orbitPoint.x);
    float orbitBrightness = mix(
        1.0 - ORBIT_ASYMMETRY,
        1.0 + ORBIT_ASYMMETRY,
        0.5 + 0.5 * cos(orbitPhase - 0.75)
    );
    orbit *= life * orbitBrightness;
#endif

    // Comet trail.
    float trailRadius = cursorSize * mix(
        TRAIL_RADIUS_MIN,
        TRAIL_RADIUS_MAX,
        movementFactor
    );
    float trailDistance = sdCapsule(point, tail, head, trailRadius);
    vec2 movement = head - tail;
    float movementLengthSquared = max(dot(movement, movement), 0.000001);
    float along = clamp(
        dot(point - tail, movement) / movementLengthSquared,
        0.0,
        1.0
    );
    float tailFade = smoothstep(0.0, TRAIL_TAIL_FADE, along);
    float headBias = mix(
        1.0 - TRAIL_HEAD_BIAS,
        1.0,
        smoothstep(0.0, 1.0, along)
    );

    float trailCore = antialiasMask(trailDistance)
        * life
        * tailFade
        * headBias;
    float trailGlow = (
        1.0 - smoothstep(
            0.0,
            trailRadius * TRAIL_GLOW_WIDTH,
            max(trailDistance, 0.0)
        )
    ) * life
      * tailFade
      * headBias;
    float hotTrail = (
        1.0 - smoothstep(
            0.0,
            trailRadius * TRAIL_HOT_CORE_WIDTH,
            max(trailDistance, 0.0)
        )
    ) * life
      * tailFade
      * smoothstep(0.38, 1.0, along);

    float nebulaWake = 0.0;
#if CURSOR_ENABLE_NEBULA_WAKE
    nebulaWake = (
        1.0 - smoothstep(
            0.0,
            trailRadius * TRAIL_NEBULA_WIDTH,
            max(trailDistance, 0.0)
        )
    ) * life
      * tailFade
      * (0.55 + 0.45 * sin(along * PI));
#endif

    vec3 trailColor = mix(
        NEBULA_VIOLET,
        COSMIC_BLUE,
        smoothstep(0.05, 0.62, along)
    );
    trailColor = mix(
        trailColor,
        GOLD_BODY,
        smoothstep(0.62, 1.0, along)
    );

    // Sparks.
    float sparkField = 0.0;
    vec3 sparkColor = vec3(0.0);

#if CURSOR_SPARK_COUNT > 0
    if (movementFactor >= SPARK_MOVEMENT_THRESHOLD) {
        vec2 movementDirection = movement / max(distanceMoved, 0.000001);
        vec2 movementNormal = vec2(-movementDirection.y, movementDirection.x);
        vec2 eventSeed = head * 37.31 + tail * 91.73;

        for (int sparkIndex = 0; sparkIndex < SPARK_COUNT; sparkIndex++) {
            float indexValue = float(sparkIndex);
            float positionRandom = hash12(
                eventSeed + vec2(indexValue * 11.7, indexValue * 31.9)
            );
            float sideRandom = hash12(
                eventSeed + vec2(indexValue * 43.1, indexValue * 7.3)
            );
            float sizeRandom = hash12(
                eventSeed + vec2(indexValue * 19.7, indexValue * 53.3)
            );

            float sparkAlong = mix(0.18, 0.98, positionRandom);
            float sparkSide = (sideRandom * 2.0 - 1.0)
                * cursorSize
                * SPARK_SPREAD
                * (0.45 + 0.55 * sin(sparkAlong * PI));
            vec2 sparkPosition = mix(tail, head, sparkAlong)
                + movementNormal * sparkSide;
            float sparkRadius = cursorSize * mix(
                SPARK_RADIUS_MIN,
                SPARK_RADIUS_MAX,
                sizeRandom
            );
            float spark = exp(
                -dot(point - sparkPosition, point - sparkPosition)
                / max(sparkRadius * sparkRadius, 0.000001)
            );
            spark *= life
                * smoothstep(0.0, 0.22, sparkAlong)
                * (1.0 - smoothstep(0.94, 1.0, sparkAlong));

            vec3 localSparkColor = mix(COSMIC_BLUE, STAR_WHITE, sizeRandom);
            localSparkColor = mix(
                localSparkColor,
                GOLD_HOT,
                smoothstep(0.72, 1.0, sparkAlong)
            );

            sparkField += spark;
            sparkColor += localSparkColor * spark;
        }

        sparkColor /= max(sparkField, 1.0);
    }
#endif

    // Composition.
    vec4 outputColor = originalColor;

#if CURSOR_ENABLE_NEBULA_WAKE
    outputColor.rgb = mix(
        outputColor.rgb,
        NEBULA_VIOLET,
        nebulaWake * TRAIL_NEBULA_STRENGTH * contentMask
    );
#endif

    outputColor.rgb = mix(
        outputColor.rgb,
        trailColor,
        trailGlow * TRAIL_GLOW_STRENGTH * contentMask
    );
    outputColor.rgb = mix(
        outputColor.rgb,
        trailColor,
        trailCore * TRAIL_CORE_STRENGTH * contentMask
    );
    outputColor.rgb = mix(
        outputColor.rgb,
        GOLD_HOT,
        hotTrail * TRAIL_HOT_CORE_STRENGTH * contentMask
    );
    outputColor.rgb = mix(
        outputColor.rgb,
        COSMIC_BLUE,
        headHalo * HEAD_COSMIC_HALO_STRENGTH * contentMask
    );
    outputColor.rgb = mix(
        outputColor.rgb,
        GOLD_BODY,
        headGold * HEAD_GOLD_STRENGTH * contentMask
    );

#if CURSOR_ENABLE_PHOTON_RING
    vec3 photonColor = mix(STAR_WHITE, GOLD_HOT, 0.62);
    outputColor.rgb = mix(
        outputColor.rgb,
        photonColor,
        photonRing * PHOTON_RING_STRENGTH * contentMask
    );
#endif

#if CURSOR_ENABLE_RIPPLE
    vec3 rippleColor = mix(NEBULA_VIOLET, COSMIC_BLUE, easedAge);
    outputColor.rgb = mix(
        outputColor.rgb,
        rippleColor,
        ripple * RIPPLE_STRENGTH * contentMask
    );
#endif

#if CURSOR_ENABLE_ORBIT
    float orbitWarmth = 0.5 + 0.5 * cos(orbitPhase - 0.75);
    vec3 orbitColor = mix(COSMIC_BLUE, GOLD_HOT, orbitWarmth);
    outputColor.rgb = mix(
        outputColor.rgb,
        orbitColor,
        orbit * ORBIT_STRENGTH * contentMask
    );
#endif

#if CURSOR_SPARK_COUNT > 0
    outputColor.rgb = mix(
        outputColor.rgb,
        sparkColor,
        clamp(sparkField, 0.0, 1.0) * SPARK_STRENGTH * contentMask
    );
#endif

    float cursorDistance = sdRectangle(
        point,
        head,
        currentCursor.zw * 0.5
    );

    fragColor = mix(
        outputColor,
        originalColor,
        step(cursorDistance, 0.0)
    );
    fragColor.a = originalColor.a;
}
