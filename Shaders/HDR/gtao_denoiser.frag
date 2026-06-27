$FG_GLSL_VERSION

layout(location = 0) out float fragColor;

uniform sampler2D ao_tex;

uniform vec2 fg_PixelSize;

in vec2 texcoord;

void main()
{
    vec2 coord = texcoord - fg_PixelSize * 1.5;
    float ao = 0.0;

    // Average 4x4 pixels around the fragment
    // Sample 2x2 pixels at a time using bilinear interpolation
    ao += texture(ao_tex, coord).r;
    ao += textureOffset(ao_tex, coord, ivec2(2, 0)).r;
    ao += textureOffset(ao_tex, coord, ivec2(0, 2)).r;
    ao += textureOffset(ao_tex, coord, ivec2(2, 2)).r;

    ao /= 4.0;

    fragColor = ao;
}
