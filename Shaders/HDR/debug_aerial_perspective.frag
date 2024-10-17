#version 330 core

layout(location = 0) out vec4 fragColor;

in vec2 texcoord;

uniform sampler2D aerial_perspective_tex;

uniform vec4 fg_Viewport;

// exposure.glsl
vec3 apply_exposure(vec3 color);

void main()
{
    vec2 pixel_size = (5.0*8.0) / fg_Viewport.zw;
    float col = texcoord.x * 8;
    float row = texcoord.y * 8;
    float row2 = texcoord.y * 4;
    float slice = (3-floor(row2))*8 + floor(col);
    vec2 uv = vec2((slice + fract(col))/32, fract(row));

    vec3 color;
    if (fract(row2) < 0.5) {
        // Transmittance
        color = vec3(texture(aerial_perspective_tex, uv).a);
    } else {
        // In-scattering
        color = texture(aerial_perspective_tex, uv).rgb;

        // Pre-expose
        color = apply_exposure(color);
    }

    // Cell borders
    vec2 redline = step(pixel_size, vec2(fract(col), fract(row)));
    color = mix(vec3(1.0, 0.0, 0.0), vec3(color), redline.x * redline.y);

    fragColor = vec4(color, 1.0);
}
