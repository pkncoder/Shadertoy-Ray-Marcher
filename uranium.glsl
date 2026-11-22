// ----------------- Settings -----------------

// Ray Marching
#define MAX_STEPS_RAY_MARCHING 240

// Render
#define SKYBOX_COLOR_MULT vec3(0.95, 0.25, 0.15)

#define MAX_BOUNCES 30
#define SAMPLES 4

#define MIN_BOUNCE_BEFORE_RUSSIAN_ROULETTE 3

#define ANTI_ALIASING 1

#define ACCUM 1

// Camera Settings
#define CAMERA_CENTER vec3(0.0, 0.0, 5.0)
#define CAMERA_Z_OFFSET 5.0

#define FOV 45.0

#define INITIAL_CAMERA_YAW 0.0
#define INITIAL_CAMERA_PITCH 0.0
#define INITIAL_CAMERA_ROLL 0.0

// Post Processing

// Switches
#define EXPOSURE 1
#define TONE_MAPPING 1
#define SRGB 1
#define FOG 1
#define VIGNETTE 1

// Settings
#define EXPOSURE_FACTOR 1.0

#define FOG_COLOR vec3(0.6, 0.1, 0.2)
#define FOG_DENSITY 0.6
#define FOG_ALPHA 0.7

#define VIGNETTE_COLOR vec3(0.0)
#define VIGNETTE_RADIUS 1.8
#define VIGNETTE_SOFTNESS 2.0
// Fetch the material of an id from the materials list
void fetchMaterial(out Material material, int materialID) {
    Material materials[4];

    materials[0] =
        Material(vec3(0.13, 1.0, 0.4), vec3(0.13, 1.0, 0.4) * 0.01, 1.0, 0.0);
    materials[1] = Material(vec3(1.0), vec3(0.13, 0.73, 1.0) * 0.2, 1.0, 0.0);
    materials[2] = Material(vec3(0.7, 0.8, 0.95), vec3(0.0), 1.0, 0.0);
    materials[3] =
        Material(vec3(0.9, 0.3, 0.8), vec3(0.13, 0.73, 1.0) * 0.16, 1.0, 0.0);

    material = materials[materialID];
}

SDFInfo map(vec3 rayPosition) {
    return smoothUnionOperation(
        unionOperation(
            smoothSubtractOperation(
                smoothSubtractOperation(
                    roundedBoxSDF(rayPosition, vec3(0.0, 0.0, 5.0), vec3(1.0),
                                  0.3, 0),
                    sphereSDF(rayPosition, vec3(0.7, -0.2, 4.2), 0.45, 1),
                    0.05),
                cylinderSDF(rayPosition, vec3(-0.15, -0.25, 4.03),
                            vec3(0.0, 0.0, 6.97), 0.35, 1),
                0.04),
            planeSDF(rayPosition, vec3(0.0, 1.0, 0.0), 1.0, 2)),
        torusSDF(createRotationMatrix(vec3(-0.6, -0.9, 0.2)) *
                     (vec3(-0.6, 0.9, 4.1) - rayPosition),
                 vec3(0.0), 0.7, 0.3, 3),
        0.06);
}
