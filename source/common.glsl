#if GL_ES
precision highp float;
#endif

// Settings

// Ray Marching
#define MAX_STEPS_RAY_MARCHING 64 

// Camera Settings
#define CAMERA_CENTER vec3(0.0, 0.0, 5.0)
#define CAMERA_Z_OFFSET 3.0
#define INITIAL_CAMERA_YAW 0.
#define INITIAL_CAMERA_PITCH 0.0
#define INITIAL_CAMERA_ROLL 0.0
#define MIN_CAMERA_ANGLE 0.1
#define MAX_CAMERA_ANGLE (PI - MIN_CAMERA_ANGLE)
#define FOV 60.0


// Numbers
#define PI 3.1415927
#define TWO_PI 6.2831853
#define INVERSE_PI 0.31830989
#define INVERSE_TWO_PI 0.15915494
#define EULERS 2.7182818
#define EPSILON 0.001
#define FAR 50.0

// Scruct definitions
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

    Material material;
};

struct SDFInfo {
    float dist;
    Material material;
};


// Helper Functions

// Orbit camera mathDemofox Path Tracing 3 - "https://www.shadertoy.com/view/ttfyzN"
void getCameraState(out vec3 cameraPos, out vec3 cameraFwd, out vec3 cameraUp, out vec3 cameraRight)
{
    // Get the camera vectors based on the mousepos
    vec2 mouse = iMouse.xy;
    if (dot(mouse, vec2(1.0, 1.0)) == 0.0)
    {
        cameraPos = CAMERA_CENTER + vec3(0.0, 0.0, -CAMERA_Z_OFFSET);
        cameraFwd = vec3(0.0, 0.0, 1.0);
        cameraUp = vec3(0.0, 1.0, 0.0);
        cameraRight = vec3(1.0, 0.0, 0.0);
        return;
    }
    
    // otherwise use the mouse position to calculate camera position and orientation
    
    float angleX = -mouse.x * 16.0 / float(iResolution.x);
    float angleY = mix(MIN_CAMERA_ANGLE, MAX_CAMERA_ANGLE, mouse.y / float(iResolution.y));
    
    cameraPos.x = sin(angleX) * sin(angleY) * CAMERA_Z_OFFSET;
    cameraPos.y = -cos(angleY) * CAMERA_Z_OFFSET;
    cameraPos.z = cos(angleX) * sin(angleY) * CAMERA_Z_OFFSET;
    
    cameraPos += CAMERA_CENTER;
    
    cameraFwd = normalize(CAMERA_CENTER - cameraPos);
    cameraRight = normalize(cross(vec3(0.0, 1.0, 0.0), cameraFwd));
    cameraUp = normalize(cross(cameraFwd, cameraRight));   
}

// Intersection Functions

float sphereSDF(vec3 rayPosition, vec3 origin, float radius) {
    return length(origin - rayPosition) - radius;
}


// Boolean Operations

// Pure
float unionOperation(float objectA, float objectB) {
     return min(objectA, objectB);
}

float subtractOperation(float objectA, float objectB) {
    return max(objectA, -objectB);
}

float intersectionOperation(float objectA, float objectB) {
    return max(objectA, objectB);
}

// Smooth
float smoothUnionOperation(float objectA, float objectB, float smoothnessFactor)
{
  smoothnessFactor *= 4.0;
  float h = max(smoothnessFactor - abs(objectA - objectB),0.0);
  return min(objectA, objectB) - h*h*0.25/smoothnessFactor;
}

float smoothSubtractOperation(float objectA, float objectB, float smoothnessFactor)
{
  return -smoothUnionOperation(-objectA, objectB, smoothnessFactor);
}

float smoothIntersectOperation(float objectA, float objectB, float smoothnessFactor)
{
  return -smoothUnionOperation(-objectA, -objectB, smoothnessFactor);
}
