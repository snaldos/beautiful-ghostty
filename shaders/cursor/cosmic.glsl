// Beautiful Ghostty — cosmic cursor
//
// Copyright (c) 2026 Arnaldo Lopes
// Released under the MIT License. See LICENSE.
//
// //
// Galaxy-themed cursor movement shader for Ghostty.
// Designed to run after the cosmos/geodesic shader in the shader chain.
//
// Effects:
//   - restrained gold destination glow;
//   - optional photon ring and expanding ripple;
//   - optional inclined orbital ring;
//   - cyan/violet comet trail with a hot gold core;
//   - optional sparse star-like sparks;
//   - no effect while stationary;
//   - compile-time GPU profiles and spatial culling;
//   - exact preservation of Ghostty transparency and the real cursor block.
//
// Ghostty order:
//   custom-shader = /path/to/cosmos_geodesic_milkyway_optimized.glsl
//   custom-shader = /path/to/cosmic_gold_cursor_optimized.glsl
//   custom-shader-animation = true
//
// Recommended cursor colors:
//   cursor-color = e0af68
//   cursor-text  = 1a1b26

// =============================================================================
// GPU PERFORMANCE PROFILE
// =============================================================================

#define CURSOR_GPU_ECO      0
#define CURSOR_GPU_BALANCED 1
#define CURSOR_GPU_HIGH     2
#define CURSOR_GPU_ULTRA    3

#ifndef GHOSTTY_GPU_PROFILE
    #define GHOSTTY_GPU_PROFILE CURSOR_GPU_HIGH
#endif

#define CURSOR_GPU_PROFILE GHOSTTY_GPU_PROFILE

// Preserve the cursor's defining rings, orbit, and nebula wake at every
// profile. These effects are spatially culled; the profile scales the bounded
// spark loop without changing the cursor's overall appearance.
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

#define PI 3.14159265359
#define TAU 6.28318530718

float easeOutCubic(float value) {
    value = clamp(value, 0.0, 1.0);
    return 1.0 - pow(1.0 - value, 3.0);
}

float fadeOut(float value) {
    value = clamp(value, 0.0, 1.0);
    return pow(1.0 - value, FADE_POWER);
}

float luminance(vec3 color) {
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

float hash12(vec2 point) {
    vec3 p3 = fract(vec3(point.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec2 rotate2D(vec2 point, float angle) {
    float cosineValue = cos(angle);
    float sineValue = sin(angle);
    return vec2(
        cosineValue * point.x - sineValue * point.y,
        sineValue * point.x + cosineValue * point.y
    );
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
    vec2 uv = fragCoord.xy / max(iResolution.xy, vec2(1.0));
    vec4 originalColor = texture(iChannel0, uv);
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
