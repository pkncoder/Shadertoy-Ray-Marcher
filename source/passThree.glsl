#include "common.glsl"

const float KEY_SPACE = 32.5 / 256.0;

// Run the ray marching (sphere tracing) algorithm
HitInfo marchRay(const in Ray ray) {

    // Clone the immutable ray to be used mutabily
    Ray cameraRay = ray;

    // Setup the base hit information
    HitInfo hitInfo;
    hitInfo.hit = false;

    // Save the total distance travelled
    float totalDistanceTravelled = 0.0;

    // Repeat sdf return info from the mapping function
    SDFInfo mappedSceneSDF;
    mappedSceneSDF.dist = 0.0;

    // Loop until broken or max steps have been reached
    for (int i = 0; i < MAX_STEPS_RAY_MARCHING; i++) {

        // Step forward the ray by the last itteration's travel distance
        cameraRay.origin += cameraRay.direction * mappedSceneSDF.dist;

        // Map the current scene from the new ray origin
        mappedSceneSDF = map(cameraRay.origin);

        // Update the total distance traveled
        totalDistanceTravelled += mappedSceneSDF.dist;

        // No hit condition
        if (totalDistanceTravelled > FAR) {
            break;
        }

        // Hit condition
        if (mappedSceneSDF.dist < EPSILON) {
            hitInfo.hit = true;
            hitInfo.dist = totalDistanceTravelled;
            hitInfo.hitPosition = cameraRay.origin;
            hitInfo.materialID = mappedSceneSDF.materialID;
            break;
        }
    }

    // Final hit info
    return hitInfo;
}

// Estimate the normal with a 4-tap - code taken from iq
vec3 estimateNormal(const in Ray ray, const in HitInfo originalHit) {
    vec3 rayPosition = ray.origin + ray.direction * originalHit.dist;

    vec2 e = vec2(1.0, -1.0) * 0.5773 * 0.0005;
    return normalize(e.xyy * map(rayPosition + e.xyy).dist +
                     e.yyx * map(rayPosition + e.yyx).dist +
                     e.yxy * map(rayPosition + e.yxy).dist +
                     e.xxx * map(rayPosition + e.xxx).dist);
}

// Do the bounce logic for the path tracing
void processBounce(inout Ray ray, const in HitInfo hit,
                   const in Material material) {

    // Update the ray information for a basic and random diffuse
    ray.origin = hit.hitPosition + hit.normal * NORMAL_NUDGE_EPSILON;
    ray.direction = normalize(hit.normal + randomUnitVector());
}

// Sky coloring
vec3 colorSky(const in Ray ray) {
    vec3 sunDir = normalize(vec3(0.4, 0.8, 0.3));
    float sunDot = max(dot(ray.direction, sunDir), 0.0);

    // Horizon/zenith gradient
    float t = max(ray.direction.y, 0.0);
    vec3 sky = mix(vec3(0.7, 0.85, 1.0), vec3(0.15, 0.35, 0.7), pow(t, 0.6));

    // Sun disc + halo
    sky += vec3(1.2, 1.0, 0.6) * pow(sunDot, 128.0) * 8.0; // disc
    sky += vec3(0.9, 0.7, 0.4) * pow(sunDot, 4.0) * 0.4;   // halo

    // Multiply the final sky color by an exposure amount
    return sky * SKYBOX_COLOR_MULT;
}

// Full render pass
vec3 colorScene(const in Ray ray, vec2 fragCoord) {

    // Save a copy of the immutable ray to use in the function
    Ray cameraRay = ray;

    // Hit and material information gotten from marchRay & fetchMaterial
    HitInfo hit;
    Material material;

    // G-buffer starting info
    if (!unpackGBuffer(cameraRay, hit, material, iChannel0, fragCoord)) {
        return colorSky(cameraRay);
    }

    // Process the bounce to update the ray
    processBounce(cameraRay, hit, material);

    // Set starting color and throughput
    vec3 color = material.emmisive;
    vec3 colorMult = material.color;

    // Loop over until broken or max bounces - starts at 1 because of g-buffer
    for (int bounce = 1; bounce < MAX_BOUNCES; bounce++) {

        // March the ray to get a hit
        hit = marchRay(cameraRay);

        // Check for hit
        if (!hit.hit) {
            color += colorSky(cameraRay) * colorMult; // No hit-sky
            break;
        }

        // Process the bounce
        processBounce(cameraRay, hit, material);

        // Fetch the material
        fetchMaterial(material, int(hit.materialID));

        // Update color and throughput
        color += material.emmisive * colorMult;
        colorMult *= material.color;

        // Russian roulette
        if (bounce > MIN_BOUNCE_BEFORE_RUSSIAN_ROULETTE) {
            // Find the largest color weight
            float p = max(colorMult.r, max(colorMult.g, colorMult.b));

            // If the random chance is bigger than the largest color weight
            if (randomNormalizedFloat() > p)
                break;

            // Account for lost energy
            colorMult /= p;
        }
    }

    return color;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {

    // Set the seed for use later
    setSeed(fragCoord, uint(iFrame), iChannel3);

    // Anti-aliasing
#if (ANTI_ALIASING == 0)
    vec2 jitter = vec2(0.0);
#else
    vec2 jitter = halton(iFrame % 16) - 0.5;
#endif

    // Calculate the screen uv w/ aspect ratio accounted for
    vec2 uv = ((fragCoord + jitter) / iResolution.xy * 2.0 - 1.0) *
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

    // Construct the final ray
    Ray ray = Ray(cameraPos, rayDirection);

    // Loop as many times as samples, adding to color
    vec3 color;
    for (int i = 0; i < SAMPLES; i++) {
        // Run the render function
        color += colorScene(ray, fragCoord);
    }

    // Average the color for each sample
    color /= float(SAMPLES);

#if ACCUM == 0
    // Pure output
    fragColor = vec4(color, 1.0);
#else
    // Reset
    bool spacePressed = (texture(iChannel2, vec2(KEY_SPACE, 0.25)).x > 0.1);

    // Last frame color & blend for basic accumulation
    vec4 lastFrameColor = texture(iChannel1, fragCoord / iResolution.xy);
    float blend = (iMouse.z > 0.0 || spacePressed || lastFrameColor.a == 0.0)
                      ? 1.0
                      : 1.0 / (1.0 + (1.0 / lastFrameColor.a));
    fragColor = vec4(mix(lastFrameColor.rgb, color, blend), blend);
#endif
}
