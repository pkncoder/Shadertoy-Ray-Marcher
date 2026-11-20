#include "common.glsl"

void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
    // Get the frag color
    fragColor = vec4(texture(iChannel0, fragCoord / iResolution.xy).rgb, 0.0);
}
