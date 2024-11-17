#version 330 core

layout(location = 0) out vec4 fragColor;

in vec2 texcoord;

uniform usampler2D histogram_tex;
uniform bool is_linear;
uniform vec4 fg_Viewport;

void main()
{
    int num_bins = textureSize(histogram_tex, 0).x; // [0, 255]

    int i = int(texcoord.x * float(num_bins));
    uint hits = texelFetch(histogram_tex, ivec2(i, 0), 0).r;

    float value = float(hits);
    float max_value = fg_Viewport.z * fg_Viewport.w;
    if (!is_linear) {
        value = log2(value);
        max_value = log2(max_value);
    }
    float color = step(texcoord.y * max_value, value);

    fragColor = vec4(vec3(color), 1.0);
}
