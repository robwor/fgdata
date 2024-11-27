$FG_GLSL_VERSION
/*
 * Bloom - upsampling step
 * "Next Generation Post Processing in Call of Duty Advanced Warfare"
 *      ACM Siggraph (2014)
 * Based on the implementation by Alexander Christensen
 * https://learnopengl.com/Guest-Articles/2022/Phys.-Based-Bloom
 */

layout(location = 0) out vec3 fragColor;

in vec2 texcoord;

vec3 bloom_upsample(vec2 uv);

void main()
{
    fragColor = bloom_upsample(texcoord);
}
