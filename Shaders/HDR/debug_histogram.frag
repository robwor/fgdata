#version 330 core

layout(location = 0) out vec4 fragColor;

in vec2 texcoord;

uniform usampler2D histogram_tex;
uniform sampler2D lum_tex;

uniform vec4 fg_Viewport;

// histogram.glsl
uint luminance_to_bin_index(float luminance);

void main()
{
    int num_bins = textureSize(histogram_tex, 0).x; // [0, 255]

    int i = int(texcoord.x * float(num_bins));
    uint hits = texelFetch(histogram_tex, ivec2(i, 0), 0).r;

    float value = log2(float(hits));
    float background = step(texcoord.y * 20.0, value);

    // Add a 1 pixel red band where the average luminance is
    float avg_lum = texelFetch(lum_tex, ivec2(0), 0).r;
    uint avg_i = luminance_to_bin_index(avg_lum);

    float pixel_width = 1.0 / fg_Viewport.z;
    float redline_x = avg_i / float(num_bins);
    float redline = 1.0 - step(pixel_width * 4.0, abs(texcoord.x - redline_x));

    vec3 color = mix(vec3(background), vec3(1.0, 0.0, 0.0), redline);

    fragColor = vec4(color, 1.0);
}
