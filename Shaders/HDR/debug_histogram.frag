#version 330 core

layout(location = 0) out vec4 fragColor;

in vec2 texcoord;

uniform usampler2D histogram_tex;

void main()
{
    int num_bins = textureSize(histogram_tex, 0).x; // [0, 255]

    int i = int(texcoord.x * float(num_bins));
    uint hits = texelFetch(histogram_tex, ivec2(i, 0), 0).r;

    float value = log2(float(hits));
    float color = step(texcoord.y * 20.0, value);

    fragColor = vec4(vec3(color), 1.0);
}
