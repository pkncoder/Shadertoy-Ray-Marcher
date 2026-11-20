#include "common.glsl"

float map(vec3 rayPosition) {
    return smoothUnionOperation(
        sphereSDF(rayPosition, vec3(0.0, 0.0, 5.0), 1.0),
        sphereSDF(rayPosition, vec3(0.5, 0.5, 4.5), 0.5),
        max(abs(sin(iTime) / 15.0), EPSILON)
    );
}

HitInfo marchRay(Ray ray) {

    HitInfo hitInfo;
    hitInfo.hit = false;
    
    float distanceTravelled = 0.0;
    
    float mappedSceneSDF;

    for (int i = 0; i < MAX_STEPS_RAY_MARCHING; i++) {
        
        vec3 rayPosition = ray.origin + ray.direction * distanceTravelled;
        
        mappedSceneSDF = map(rayPosition);
        
        distanceTravelled += mappedSceneSDF;
        
        if (distanceTravelled > FAR) {
            break;
        }
        
        if (mappedSceneSDF < EPSILON) {
            hitInfo.hit = true;
            hitInfo.dist = distanceTravelled;
            hitInfo.hitPosition = ray.origin + ray.direction * distanceTravelled;
            hitInfo.material = Material(vec3(1.0), vec3(0.0), 1.0, 0.0);
            break;
        }
    }
    
    return hitInfo;
}

vec3 colorScene(const in Ray ray) {

    HitInfo hit = marchRay(ray);
    vec3 rayPosition = ray.origin + ray.direction * hit.dist;
    
    vec2 e = vec2(1.0,-1.0)*0.5773*0.0005;
    vec3 estimatedNormal =  normalize( e.xyy*map(rayPosition + e.xyy) + 
					  e.yyx*map(rayPosition + e.yyx ) + 
					  e.yxy*map(rayPosition + e.yxy ) + 
					  e.xxx*map(rayPosition + e.xxx ));
    
    vec3 lightPosition = vec3(3.0, 3.0, 2.0);

    return vec3(hit.hit ? vec3(max(dot(estimatedNormal, normalize(lightPosition - hit.hitPosition)), 0.1)) : vec3(0.0));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {

    vec2 uv = ((fragCoord) / iResolution.xy * 2.0 - 1.0) * vec2(iResolution.x / iResolution.y, 1.0);
    float cameraDist = 1.0f / tan(FOV * 0.5f * PI / 180.0f);

    // Get the initial ray
    vec3 cameraPos, cameraFwd, cameraUp, cameraRight;
    getCameraState(cameraPos, cameraFwd, cameraUp, cameraRight); 
    
    vec3 rayDirection = normalize(vec3(uv, cameraDist));
    rayDirection = normalize(mat3(cameraRight, cameraUp, cameraFwd) * rayDirection);
    Ray ray = Ray(
        cameraPos,
        rayDirection
    );

    fragColor = vec4(colorScene(ray), 1.0);

}
