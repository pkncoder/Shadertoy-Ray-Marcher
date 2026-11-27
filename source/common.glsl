#if GL_ES
precision highp float;
#endif

// ----------------- Settings -----------------

// Ray Marching
#define MAX_STEPS_RAY_MARCHING 64

// Render
#define SKYBOX_COLOR_MULT vec3(0.1)

#define MAX_BOUNCES 10
#define SAMPLES 5

#define MIN_BOUNCE_BEFORE_RUSSIAN_ROULETTE 3

#define ANTI_ALIASING 0

#define ACCUM 0

// Camera Settings
#define CAMERA_CENTER vec3(0.0, 0.0, 0.0)
#define CAMERA_Z_OFFSET 5.0

#define FOV 65.0

#define INITIAL_CAMERA_YAW 0.0
#define INITIAL_CAMERA_PITCH 0.0
#define INITIAL_CAMERA_ROLL 0.0

// Post Processing

// Switches
#define EXPOSURE 1
#define TONE_MAPPING 1
#define SRGB 1

#define EXPOSURE_FACTOR 1.0

// ----------------- Numbers -----------------

// PI
#define PI 3.1415927
#define TWO_PI 6.2831853
#define INVERSE_PI 0.31830989
#define INVERSE_TWO_PI 0.15915494

// Eulers
#define EULERS 2.7182818

// Epsilons
#define EPSILON 0.001
#define NORMAL_NUDGE_EPSILON 0.01

// Camera
#define MIN_CAMERA_ANGLE 0.1
#define MAX_CAMERA_ANGLE (PI - MIN_CAMERA_ANGLE)

// Distance limiters
#define FAR 50.0

// ----------------- Structs -----------------

struct Ray {
    vec3 origin;
    vec3 direction;
};

struct Material {
    vec3 color;
    vec3 emmisive;

    float roughness;
    float metallic;
};

struct HitInfo {
    bool hit;

    float dist;
    vec3 hitPosition;

    vec3 normal;

    int materialID;
};

struct SDFInfo {
    float dist;
    int materialID;
    vec3 aabbMin;
    vec3 aabbMax;
    bool written;
    int reachedCount;
};

// ----------------- Global Values -----------------

// Global random seed
uint seed;

// BVH builder counter variables
int targetCount = -1;
int count = 0;

// ----------------- Helper Functions -----------------

// Taken from Demofox Path Tracing 3 "https://www.shadertoy.com/view/ttfyzN"
// Orbit camera math - slightly modified by me on camera center and displacement
void getCameraState(out vec3 cameraPos, out vec3 cameraFwd, out vec3 cameraUp,
                    out vec3 cameraRight) {
    // Get the camera vectors based on the mousepos
    vec2 mouse = iMouse.xy;

    // If the mouse hasn't moved yet, start with the initial settings
    if (dot(mouse, vec2(1.0, 1.0)) == 0.0) {
        cameraPos = CAMERA_CENTER + vec3(0.0, 0.0, -CAMERA_Z_OFFSET);
        cameraFwd = vec3(0.0, 0.0, 1.0);
        cameraUp = vec3(0.0, 1.0, 0.0);
        cameraRight = vec3(1.0, 0.0, 0.0);
        return;
    }

    // Calculate the angle x and y needed to move to from the mouse
    float angleX = -mouse.x * 16.0 / float(iResolution.x);
    float angleY =
        mix(MIN_CAMERA_ANGLE, MAX_CAMERA_ANGLE, mouse.y / float(iResolution.y));

    // Rotate the camra, centered on the origin, scaled by offset
    cameraPos.x = sin(angleX) * sin(angleY) * CAMERA_Z_OFFSET;
    cameraPos.y = -cos(angleY) * CAMERA_Z_OFFSET;
    cameraPos.z = cos(angleX) * sin(angleY) * CAMERA_Z_OFFSET;

    // Offset the camera pos to the center
    cameraPos += CAMERA_CENTER;

    // Calculate the camera vectors
    cameraFwd = normalize(CAMERA_CENTER - cameraPos);
    cameraRight = normalize(cross(vec3(0.0, 1.0, 0.0), cameraFwd));
    cameraUp = normalize(cross(cameraFwd, cameraRight));
}

// Backup seed for when the blue noise texture isn't loaded
uint getBackupSeed(vec2 fragCoord, uint inputSeed) {
    return uint(fragCoord.x) * 1973u + uint(fragCoord.y) * 9277u +
               inputSeed * 26699u |
           1u;
}

// Seed pulled from blue noise
void setSeed(vec2 fragCoord, uint inputSeed, sampler2D noise) {

    // Pick a spot on the blue noise function and sample it
    vec2 noiseUV = fragCoord / 1024.0 +
                   fract(float(inputSeed) * vec2(0.6180339887, 0.7548776662));
    float blueNoise = texture(noise, noiseUV).r;

    // Inject it into the seed
    if (blueNoise > 0.0)
        seed = uint(blueNoise * 4294967295.0) ^ (inputSeed * uint(26699));
    else
        seed = getBackupSeed(fragCoord, inputSeed);
}

// Hash function for random uint
uint wang_hash() {
    seed = uint(seed ^ uint(61)) ^ uint(seed >> uint(16));
    seed *= uint(9);
    seed = seed ^ (seed >> 4);
    seed *= uint(0x27d4eb2d);
    seed = seed ^ (seed >> 15);
    return seed;
}

// Random float one from [0-1]
float randomNormalizedFloat() { return float(wang_hash()) / float(-1u); }

// Random normalized unit vector
vec3 randomUnitVector() {
    float z = randomNormalizedFloat() * 2.0f - 1.0f;
    float a = randomNormalizedFloat() * 6.28318530718;
    float r = sqrt(1.0f - z * z);
    return vec3(r * cos(a), r * sin(a), z);
}

// Halton 2, 3 series for anti-aliasing
vec2 halton(int index) {
    const vec2 coprimes = vec2(2.0f, 3.0f);
    vec2 s = vec2(index, index);
    vec4 a = vec4(1, 1, 0, 0);
    while (s.x > 0. && s.y > 0.) {
        a.xy = a.xy / coprimes;
        a.zw += a.xy * mod(s, coprimes);
        s = floor(s / coprimes);
    }
    return a.zw;
}

// Helper to avoid sin(0) returing 0
vec2 signNotZero(vec2 v) {
    return mix(vec2(-1.0), vec2(1.0), step(vec2(0.0), v));
}

// Packs a 3D unit normal into a 2D vector in the range [-1, 1]
vec2 packNormal(vec3 normal) {
    vec2 p = normal.xy / (abs(normal.x) + abs(normal.y) + abs(normal.z));
    return (normal.z <= 0.0) ? (1.0 - abs(p.yx)) * signNotZero(p) : p;
}

// Unpacks a 2D normal vector back into a 3D normal vector
vec3 unpackNormal(vec2 packedNormal) {
    vec3 n =
        vec3(packedNormal.xy, 1.0 - abs(packedNormal.x) - abs(packedNormal.y));
    if (n.z < 0.0) {
        n.xy = (1.0 - abs(n.yx)) * signNotZero(n.xy);
    }
    return normalize(n);
}

// Fetch the material of an id from the materials list
void fetchMaterial(out Material material, int materialID) {
    Material materials[7];

    materials[0] = Material(vec3(0.2, 0.7, 0.3), vec3(0.0), 1.0, 0.0);
    materials[1] = Material(vec3(1.0), vec3(0.8), 1.0, 0.0);
    materials[2] = Material(vec3(0.7, 0.8, 0.95), vec3(0.0), 1.0, 0.0);
    materials[3] = Material(vec3(0.7, 0.5, 0.5), vec3(0.0), 1.0, 0.0);
    materials[4] = Material(vec3(1.0), vec3(0.3, 0.2, 0.9), 1.0, 0.0);
    materials[5] = Material(vec3(0.8, 0.6, 0.4), vec3(0.0), 1.0, 0.0);
    materials[6] = Material(vec3(1.0), vec3(0.5, 0.1, 0.8), 1.0, 0.0);

    material = materials[materialID];
}

// Helper function to unpack G-Buffer data and retrieve hit/material properties
bool unpackGBuffer(const in Ray ray, out HitInfo hit, out Material material,
                   in sampler2D gBufferChannel, vec2 fragCoord) {
    // Get the g-buffer information
    vec4 gBuffer = texelFetch(gBufferChannel, ivec2(fragCoord), 0);

    // Get the hit information
    float dist = gBuffer.z;
    float encodedID = gBuffer.w;

    // Set hit info
    hit.hit = true;
    hit.dist = dist;
    hit.normal = unpackNormal(gBuffer.xy); // Unpack the normal
    hit.hitPosition = ray.origin + ray.direction * hit.dist;

    // Check for a background/sky miss
    if (dist >= FAR) {
        return false;
    }

    // Send out the material
    fetchMaterial(material, int(gBuffer.w));

    return true;
}

// ----------------- Intersection Functions -----------------

SDFInfo sphereSDF(vec3 rayPosition, vec3 center, float radius, int materialID,
                  bool buildBVH) {
    SDFInfo sdfInfo;

    if (buildBVH && count > targetCount && targetCount != -1) {
        sdfInfo.written = false;
        return sdfInfo;
    }

    if (buildBVH) {
        sdfInfo.written = true;

        // TODO: build aabb min & max
        sdfInfo.aabbMin =
            vec3(center.x - radius, center.y - radius, center.z - radius);
        sdfInfo.aabbMax =
            vec3(center.x + radius, center.y + radius, center.z + radius);

        count += 2;

        sdfInfo.reachedCount = count;
        return sdfInfo;
    }

    float sdfDist = length(center - rayPosition) - radius;

    sdfInfo.materialID = materialID;
    sdfInfo.dist = sdfDist;

    return sdfInfo;
}

SDFInfo boxSDF(vec3 rayPosition, vec3 center, vec3 bounds, int materialID,
               bool buildBVH) {
    SDFInfo sdfInfo;

    if (buildBVH && count > targetCount && targetCount != -1) {
        sdfInfo.written = false;
        return sdfInfo;
    }

    if (buildBVH) {
        sdfInfo.written = true;

        // TODO: build aabb min & max
        sdfInfo.aabbMin = center - bounds;
        sdfInfo.aabbMax = center + bounds;

        count += 2;

        sdfInfo.reachedCount = count;
        return sdfInfo;
    }

    vec3 q = abs(center - rayPosition) - bounds;
    float sdfDist = length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);

    sdfInfo.materialID = materialID;
    sdfInfo.dist = sdfDist;

    return sdfInfo;
}

// ----------------- Entity Operations & Modifiers -----------------

// Pure Boolean operations
SDFInfo unionOperation(SDFInfo objectA, SDFInfo objectB, bool buildBVH) {
    if (buildBVH && count > targetCount && targetCount != -1) {
        if (objectB.written) {
            return objectB;
        }

        return objectA;
    }

    SDFInfo sdfInfo;

    if (buildBVH) {

        sdfInfo.aabbMin = vec3(min(objectA.aabbMin.x, objectB.aabbMin.x),
                               min(objectA.aabbMin.y, objectB.aabbMin.y),
                               min(objectA.aabbMin.z, objectB.aabbMin.z));

        sdfInfo.aabbMax = vec3(max(objectA.aabbMax.x, objectB.aabbMax.x),
                               max(objectA.aabbMax.y, objectB.aabbMax.y),
                               max(objectA.aabbMax.z, objectB.aabbMax.z));

        count += 2;

        sdfInfo.reachedCount = count;
        return sdfInfo;
    }

    bool pickA = objectA.dist < objectB.dist;

    sdfInfo.dist = pickA ? objectA.dist : objectB.dist;
    sdfInfo.materialID = pickA ? objectA.materialID : objectB.materialID;

    return sdfInfo;
}

SDFInfo aabbSDF(vec3 rayPosition, vec3 aabbMin, vec3 aabbMax, int materialID) {
    vec3 center = (aabbMin + aabbMax) * 0.5;
    vec3 bounds = (aabbMax - aabbMin) * 0.5;
    return boxSDF(rayPosition, center, bounds, materialID, false);
}

SDFInfo aabbMap(vec3 rayPosition, sampler2D aabbChannel) {
    vec3 aabbMinOne = texelFetch(aabbChannel, ivec2(3, 0), 0).rgb;
    vec3 aabbMaxOne = texelFetch(aabbChannel, ivec2(4, 0), 0).rgb;
    SDFInfo sdfInfoOne = aabbSDF(rayPosition, aabbMinOne, aabbMaxOne, 0);

    vec3 aabbMinTwo = texelFetch(aabbChannel, ivec2(5, 0), 0).rgb;
    vec3 aabbMaxTwo = texelFetch(aabbChannel, ivec2(6, 0), 0).rgb;
    SDFInfo sdfInfoTwo = aabbSDF(rayPosition, aabbMinTwo, aabbMaxTwo, 0);

    vec3 aabbMinThree = texelFetch(aabbChannel, ivec2(1, 0), 0).rgb;
    vec3 aabbMaxThree = texelFetch(aabbChannel, ivec2(2, 0), 0).rgb;
    SDFInfo sdfInfoThree = aabbSDF(rayPosition, aabbMinThree, aabbMaxThree, 0);

    SDFInfo sdfInfo = unionOperation(sdfInfoOne, sdfInfoTwo, false);

    return sdfInfoThree;
}

// ----------------- Macros -----------------

#define SCENE(tree)                                                            \
    SDFInfo map(vec3 rayPosition) {                                            \
        bool buildBVH = false;                                                 \
                                                                               \
        count = 0;                                                             \
        SDFInfo sdfInfo = (tree);                                              \
                                                                               \
        return sdfInfo;                                                        \
    }                                                                          \
    SDFInfo buildBVH(vec2 fragCoord, int maxSceneCount) {                      \
        bool buildBVH = true;                                                  \
                                                                               \
        int linearFragCoord = int(fragCoord.x);                                \
        targetCount = maxSceneCount;                                           \
        count = linearFragCoord;                                               \
                                                                               \
        vec3 rayPosition = vec3(0.0);                                          \
                                                                               \
        SDFInfo sdfInfo = (tree);                                              \
                                                                               \
        return sdfInfo;                                                        \
    }

#define SPHERE(center, radius, materialID)                                     \
    sphereSDF(rayPosition, (center), (radius), (materialID), (buildBVH))
#define BOX(center, bounds, materialID)                                        \
    boxSDF(rayPosition, (center), (bounds), (materialID), (buildBVH))

#define UNION(objectA, objectB) unionOperation((objectA), (objectB), (buildBVH))

SCENE(UNION(SPHERE(vec3(0.8, 0.3, 0.8), 0.4, 0),
            BOX(vec3(0.2, 0.6, 0.5), vec3(0.6, 0.1, 0.9), 0)))

// SCENE(UNION(UNION(SPHERE(vec3(-1.5, 0.0, 4.0), 1.0, 0),
//                   UNION(BOX(vec3(0.0, 0.0, 5.0), vec3(1.0), 0),
//                         SPHERE(vec3(0.6, 0.6, 4.4), 1.0, 0))),
//             SPHERE(vec3(1.4, 1.6, 3.5), 0.4, 1)))
