#if GL_ES
precision highp float;
#endif

// ----------------- Settings -----------------

// Ray Marching
#define MAX_STEPS_RAY_MARCHING 180

// Render
#define SKYBOX_COLOR_MULT 0.5

#define MAX_BOUNCES 10
#define SAMPLES 4

#define ANTI_ALIASING 1

#define ACCUM 1

// Camera Settings
#define CAMERA_CENTER vec3(0.0, 0.0, 5.0)
#define CAMERA_Z_OFFSET 5.0

#define FOV 60.0

#define INITIAL_CAMERA_YAW 0.0
#define INITIAL_CAMERA_PITCH 0.0
#define INITIAL_CAMERA_ROLL 0.0

// Post Processing
#define EXPOSURE 1.0
#define TONE_MAPPING 1
#define SRGB 1

// ----------------- Definitions -----------------

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
};

// ----------------- Global Values -----------------

// Global random seed
uint seed;

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
float randomNormalizedFloatOne() { return float(wang_hash()) / float(-1u); }

// Random normalized unit vector
vec3 randomUnitVector() {
    float z = randomNormalizedFloatOne() * 2.0f - 1.0f;
    float a = randomNormalizedFloatOne() * 6.28318530718;
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
    Material materials[3];

    materials[0] = Material(vec3(0.2, 0.7, 0.3), vec3(0.0), 1.0, 0.0);
    materials[1] = Material(vec3(1.0), vec3(1.0), 1.0, 0.0);
    materials[2] = Material(vec3(0.95), vec3(0.0), 1.0, 0.0);

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

    // Check for a background/sky miss
    if (dist >= FAR) {
        return false;
    }

    // Set hit info
    hit.hit = true;
    hit.dist = dist;
    hit.normal = unpackNormal(gBuffer.xy); // Unpack the normal
    hit.hitPosition = ray.origin + ray.direction * hit.dist;

    // Send out the material
    fetchMaterial(material, int(gBuffer.w));

    return true;
}

// ----------------- Intersection Functions -----------------

SDFInfo sphereSDF(vec3 rayPosition, vec3 center, float radius, int materialID) {
    float sdfDist = length(center - rayPosition) - radius;

    return SDFInfo(sdfDist, materialID);
}

SDFInfo boxSDF(vec3 rayPosition, vec3 center, vec3 bounds, int materialID) {
    vec3 q = abs(center - rayPosition) - bounds;
    float sdfDist = length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);

    return SDFInfo(sdfDist, materialID);
}

SDFInfo roundedBoxSDF(vec3 rayPosition, vec3 center, vec3 bounds, float radius,
                      int materialID) {
    vec3 q = abs(center - rayPosition) - bounds + radius;
    float sdfDist =
        length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0) - radius;

    return SDFInfo(sdfDist, materialID);
}

SDFInfo framedBoxSDF(vec3 rayPosition, vec3 center, vec3 bounds,
                     float edgeWidth, int materialID) {

    rayPosition = abs(center - rayPosition) - bounds;
    vec3 q = abs(rayPosition + edgeWidth) - edgeWidth;

    float sdfDist = min(min(length(max(vec3(rayPosition.x, q.y, q.z), 0.0)) +
                                min(max(rayPosition.x, max(q.y, q.z)), 0.0),
                            length(max(vec3(q.x, rayPosition.y, q.z), 0.0)) +
                                min(max(q.x, max(rayPosition.y, q.z)), 0.0)),
                        length(max(vec3(q.x, q.y, rayPosition.z), 0.0)) +
                            min(max(q.x, max(q.y, rayPosition.z)), 0.0));

    return SDFInfo(sdfDist, materialID);
}

SDFInfo torusSDF(vec3 rayPosition, vec3 center, float holeRadius,
                 float bodyRadius, int materialID) {
    rayPosition = center - rayPosition;

    vec2 q = vec2(length(rayPosition.xz) - holeRadius, rayPosition.y);
    float sdfDist = length(q) - bodyRadius;

    return SDFInfo(sdfDist, materialID);
}

SDFInfo planeSDF(vec3 rayPosition, vec3 normal, float height, int materialID) {
    float sdfDist = dot(rayPosition, normal) + height;

    return SDFInfo(sdfDist, materialID);
}

SDFInfo cylinderSDF(vec3 rayPosition, vec3 endA, vec3 endBPosition,
                    float radius, int materialID) {
    vec3 ba = endBPosition - endA;
    vec3 pa = rayPosition - endA;
    float baba = dot(ba, ba);
    float paba = dot(pa, ba);

    float x = length(pa * baba - ba * paba) - radius * baba;
    float y = abs(paba - baba * 0.5) - baba * 0.5;
    float x2 = x * x;
    float y2 = y * y * baba;
    float d = (max(x, y) < 0.0)
                  ? -min(x2, y2)
                  : (((x > 0.0) ? x2 : 0.0) + ((y > 0.0) ? y2 : 0.0));

    float sdfDist = sign(d) * sqrt(abs(d)) / baba;

    return SDFInfo(sdfDist, materialID);
}

SDFInfo octahedronSDF(vec3 rayPosition, vec3 center, float radius,
                      int materialID) {
    rayPosition = abs(center - rayPosition);
    float m = rayPosition.x + rayPosition.y + rayPosition.z - radius;
    vec3 q;
    if (3.0 * rayPosition.x < m)
        q = rayPosition.xyz;
    else if (3.0 * rayPosition.y < m)
        q = rayPosition.yzx;
    else if (3.0 * rayPosition.z < m)
        q = rayPosition.zxy;
    else
        return SDFInfo(m * 0.57735027, materialID);

    float k = clamp(0.5 * (q.z - q.y + radius), 0.0, radius);
    float sdfDist = length(vec3(q.x, q.y - radius + k, q.z - k));

    return SDFInfo(sdfDist, materialID);
}

// ----------------- Entity Operations & Modifiers -----------------

// Pure Boolean operations
SDFInfo unionOperation(SDFInfo objectA, SDFInfo objectB) {
    bool pickA = objectA.dist < objectB.dist;

    return SDFInfo(pickA ? objectA.dist : objectB.dist,
                   pickA ? objectA.materialID : objectB.materialID);
}

SDFInfo subtractOperation(SDFInfo objectA, SDFInfo objectB) {
    bool pickA = objectA.dist > -objectB.dist;

    return SDFInfo(pickA ? objectA.dist : -objectB.dist,
                   pickA ? objectA.materialID : objectB.materialID);
}

SDFInfo intersectOperation(SDFInfo objectA, SDFInfo objectB) {
    bool pickA = objectA.dist > objectB.dist;

    return SDFInfo(pickA ? objectA.dist : objectB.dist,
                   pickA ? objectA.materialID : objectB.materialID);
}

// Smooth Boolean Operations
SDFInfo smoothUnionOperation(SDFInfo objectA, SDFInfo objectB,
                             float smoothnessFactor) {
    bool pickA = objectA.dist < objectB.dist;

    smoothnessFactor *= 4.0;
    float h = max(smoothnessFactor - abs(objectA.dist - objectB.dist), 0.0);
    return SDFInfo(min(objectA.dist, objectB.dist) -
                       h * h * 0.25 / smoothnessFactor,
                   pickA ? objectA.materialID : objectB.materialID);
}

SDFInfo smoothSubtractOperation(SDFInfo objectA, SDFInfo objectB,
                                float smoothnessFactor) {
    bool pickA = objectA.dist > -objectB.dist;

    smoothnessFactor *= 4.0;
    float h = max(smoothnessFactor - abs(objectA.dist + objectB.dist), 0.0);
    return SDFInfo(max(objectA.dist, -objectB.dist) +
                       h * h * 0.25 / smoothnessFactor,
                   pickA ? objectA.materialID : objectB.materialID);
}

SDFInfo smoothIntersectOperation(SDFInfo objectA, SDFInfo objectB,
                                 float smoothnessFactor) {
    bool pickA = objectA.dist > objectB.dist;

    smoothnessFactor *= 4.0;
    float h = max(smoothnessFactor - abs(objectA.dist - objectB.dist), 0.0);
    return SDFInfo(max(objectA.dist, objectB.dist) +
                       h * h * 0.25 / smoothnessFactor,
                   pickA ? objectA.materialID : objectB.materialID);
}

// ----------------- Macros -----------------

// TODO: Temp; will be turned into a pure macro (and won't be individually
// called)
SDFInfo map(vec3 rayPosition) {
    return unionOperation(
        smoothSubtractOperation(
            roundedBoxSDF(rayPosition, vec3(0.0, 0.0, 5.0), vec3(1.0), 0.3, 0),
            sphereSDF(rayPosition, vec3(0.9, -0.2, 4.5), 0.5, 1), 0.05),
        planeSDF(rayPosition, vec3(0.0, 1.0, 0.0), 1.0, 2));

    // return torusSDF(rayPosition, vec3(0.0, 0.0, 5.0), 2.0, 1.0, 0);
}
