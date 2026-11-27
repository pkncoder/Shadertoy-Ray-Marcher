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

// SCENE(UNION(SPHERE(vec3(0.8, 0.3, 0.8), 0.3, 0),
//            BOX(vec3(0.2, 0.6, 0.5), vec3(0.2, 0.2, 0.2), 0)))

vec3 fixVecF(vec3 v) {
    return vec3(int(v.x * 10.0), int(v.y * 10.0), int(v.z * 10.0));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor.a = 1.0; // Constant alpha color

    fragColor.rgb = texture(iChannel0, fragCoord / iResolution.xy).rgb;

    // Get the final pass's color
    if (fragCoord.x / iResolution.x > 0.5)
        fragColor.rgb = texture(iChannel2, fragCoord / iResolution.xy).rgb;

    int linearFragCoord = int(fragCoord.x);

    if (false) {
        vec3 color = texture(iChannel1, fragCoord / iResolution.xy).xyz;

        if (linearFragCoord == 1) {
            fragColor = fixVecF(color) == vec3(0, 0, 3) ? vec4(1.0) : vec4(0.0);
        } else if (linearFragCoord == 2) {
            fragColor =
                fixVecF(color) == vec3(11, 8, 11) ? vec4(1.0) : vec4(0.0);
        } else if (linearFragCoord == 3) {
            fragColor = fixVecF(color) == vec3(0, 4, 3) ? vec4(1.0) : vec4(0.0);
        } else if (linearFragCoord == 4) {
            fragColor = fixVecF(color) == vec3(4, 8, 7) ? vec4(1.0) : vec4(0.0);
        } else if (linearFragCoord == 5) {
            fragColor = fixVecF(color) == vec3(5, 0, 5) ? vec4(1.0) : vec4(0.0);
        } else if (linearFragCoord == 6) {
            fragColor =
                fixVecF(color) == vec3(11, 6, 11) ? vec4(1.0) : vec4(0.0);
        } else {
            fragColor = vec4(0.1);
        }

        fragColor = vec4(color, 1.0);

        return;
    }

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
}
