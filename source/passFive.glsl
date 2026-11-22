#include "common.glsl"

// ----------------- SRGB -----------------

// Returns 1.0 or 0.0 (bool) if it is less than the comparator
vec3 LessThan(vec3 inputVector, float comparator) {
    return vec3((inputVector.x < comparator) ? 1.0f : 0.0f,
                (inputVector.y < comparator) ? 1.0f : 0.0f,
                (inputVector.z < comparator) ? 1.0f : 0.0f);
}

// Changes the input vec3's rgb color space to srgb
vec3 LinearToSRGB(vec3 rgb) {
    rgb = clamp(rgb, 0.0f, 1.0f);
    return mix(pow(rgb, vec3(1.0f / 2.4f)) * 1.055f - 0.055f, rgb * 12.92f,
               LessThan(rgb, 0.0031308f));
}

// Canges the input vec3's srgb color space to rgb
vec3 SRGBToLinear(vec3 srgb) {
    srgb = clamp(srgb, 0.0f, 1.0f);
    return mix(pow(((srgb + 0.055f) / 1.055f), vec3(2.4f)), srgb / 12.92f,
               LessThan(srgb, 0.04045f));
}

/* ----------------- Tone Mapping ----------------- */

// Tone maps the inputColor and returns the output
vec3 ACESFilm(vec3 inputColor) {
    float a = 2.51f;
    float b = 0.03f;
    float c = 2.43f;
    float d = 0.59f;
    float e = 0.14f;
    return clamp((inputColor * (a * inputColor + b)) /
                     (inputColor * (c * inputColor + d) + e),
                 0.0f, 1.0f);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor.a = 1.0; // Constant alpha color
    // Set the seed to match the jitter across frames
    setSeed(fragCoord, uint(iFrame), iChannel3);

    // Anti-aliasing
#if (ANTI_ALIASING == 0)
    vec2 jitter = vec2(0.0);
#else
    vec2 jitter = halton(iFrame % 16) - 0.5;
#endif

    vec2 uv = ((fragCoord) / iResolution.xy * 2.0 - 1.0) *
              vec2(iResolution.x / iResolution.y, 1.0);

    // Calculate the camera distance from the FOV
    float cameraDist = 1.0f / tan(FOV * 0.5f * PI / 180.0f);

    // Get the current camera state
    vec3 cameraPos, cameraFwd, cameraUp, cameraRight;
    getCameraState(cameraPos, cameraFwd, cameraUp, cameraRight);

    // Calculate the ray durection
    vec3 rayDirection = normalize(vec3(uv, cameraDist));
    rayDirection =
        normalize(mat3(cameraRight, cameraUp, cameraFwd) * rayDirection);

    Ray cameraRay = Ray(cameraPos, rayDirection);
    HitInfo hit;
    Material material;

    // Load the gBuffer for sceen space calculations
    unpackGBuffer(cameraRay, hit, material, iChannel1, fragCoord);

    // Get the final pass's color
    fragColor.rgb = texture(iChannel0, fragCoord / iResolution.xy).rgb;

#if EXPOSURE == 1
    // Multiply by the exposure
    fragColor.rgb *= EXPOSURE_FACTOR;
#endif

// HDR -> SDR
#if TONE_MAPPING == 1
    fragColor.rgb = ACESFilm(fragColor.rgb);
#endif

// Linear -> SRGB
#if SRGB == 1
    fragColor.rgb = LinearToSRGB(fragColor.rgb);
#endif

#if FOG == 1
    // Fog
    float fogDist = length(cameraPos - hit.hitPosition);
    float fogFactor = exp(-pow(fogDist * FOG_DENSITY, 2.0));
    fogFactor = clamp(fogFactor, FOG_ALPHA, 1.0);
    fragColor.rgb = mix(FOG_COLOR, fragColor.rgb, fogFactor);
#endif

#if VIGNETTE == 1
    // Vigette
    vec2 centerCoord = fragCoord / iResolution.xy * 2.0 - 1.0;
    float centerDist = length(centerCoord);
    float vignette = smoothstep(
        VIGNETTE_RADIUS, VIGNETTE_RADIUS - VIGNETTE_SOFTNESS, centerDist);
    fragColor.rgb *= vignette;
#endif
}
