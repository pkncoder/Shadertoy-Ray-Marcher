#include "common.glsl"

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    int linearFragCoord = int(fragCoord.x);
    bool isLeftNode = (linearFragCoord % 2) != 0;

    int maxCount = int(texelFetch(iChannel0, ivec2(0), 0).a);

    SDFInfo sdfInfo = buildBVH(fragCoord, maxCount);

    vec3 node = isLeftNode ? sdfInfo.aabbMin : sdfInfo.aabbMax;
    fragColor = vec4(node, sdfInfo.reachedCount);
}
