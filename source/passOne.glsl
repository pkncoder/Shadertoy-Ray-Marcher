#include "common.glsl"

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

void mainImage(out vec4 fragColor, in vec2 fragCoord) {

    // Set the current seed number
    setSeed(fragCoord, uint(iFrame), iChannel3);

// Anti-aliasing
#if (ANTI_ALIASING == 0)
    vec2 jitter = vec2(0.0);
#else
    vec2 jitter = halton(iFrame % 16) - 0.5;
#endif

    // Calculate screen uv while taking account of aspect ratio
    vec2 uv = ((fragCoord + jitter) / iResolution.xy * 2.0 - 1.0) *
              vec2(iResolution.x / iResolution.y, 1.0);

    // Calculate the camera distance from FOV
    float cameraDist = 1.0f / tan(FOV * 0.5f * PI / 180.0f);

    // Get the current camera state & vectors
    vec3 cameraPos, cameraFwd, cameraUp, cameraRight;
    getCameraState(cameraPos, cameraFwd, cameraUp, cameraRight);

    // Calculate ray direction from the camera vectors
    vec3 rayDirection = normalize(vec3(uv, cameraDist));
    rayDirection =
        normalize(mat3(cameraRight, cameraUp, cameraFwd) * rayDirection);

    // Construct the final ray
    Ray ray = Ray(cameraPos, rayDirection);

    // Get the scene information for the g-buffer
    HitInfo sceneInfo = marchRay(ray);

    // Construct the g-buffer color
    // R & G - Packed normal
    // B - Distance
    // A - Encoded id information
    fragColor = sceneInfo.hit ? vec4(packNormal(estimateNormal(ray, sceneInfo)),
                                     sceneInfo.dist, sceneInfo.materialID)
                              : vec4(vec2(0.0), FAR, -1.0);
}
